package ezlite;

use strict;
use CGI qw/standard escapeHTML/;
use URI::Escape;

sub new {
  my $type = shift;
  my ($pathPrivate) = @_;

  my $query;
  my $input = new CGI;
  my @array = $input->param;
  foreach my $var (@array) {
    $var =~ s/[^a-zA-Z0-9\_\-]//g;
    $query->{$var} = &CGI::escapeHTML($input->param($var));
  }

  $ezlite::query = &sanitizeData($query);
  $ezlite::function = $ezlite::query->{'function'}; # easily accessiable function value
  $ezlite::tapCnt = $ezlite::query->{'tapCnt'} + 1; # keep track of how many times page is loaded in succession

  $ezlite::basket = {};
  $ezlite::displayHTML = '';

  &initializeConfig($pathPrivate);
  &loadProductBasket();

  return [], $type;
}

sub initializeConfig {
  # define base configuration & initalizes certain static variables
  my ($pathPrivate) = @_;

  $ezlite::config = {};

  open(CONFIG,'<',"$pathPrivate/ezlite.cfg") or die "Can't open ezlite.cfg for reading. $!";
  while(<CONFIG>) {
    my $line = $_;
    chop $line;
    if ((substr($line,0,1) eq '#') || ($line !~ /\=\>/)) {
      next; # skip comments & lines without name/value pairs
    }
    my ($name,$value) = split(/\=\>/,$line,2);
    $name =~ s/^\s+|\s+$//g; # strip leading/trailing whitespace
    $name =~ s/[^a-zA-Z0-9\-\_]//g;
    $value =~ s/^\s+|\s+$//g; # strip leading/trailing whitespace
    $value =~ s/^\'+|\'+$//g; # strip leading/trailing whitespace
    if (($name ne '') && ($value ne '')) {
      $ezlite::config->{$name} = $value;
    }
  }
  close(CONFIG);

  $ezlite::script     = 'https://' . $ENV{'SERVER_NAME'} . $ENV{'SCRIPT_NAME'};
  $ezlite::userToken  = '';
  $ezlite::basketFile = '';
  &getUserToken();
}

sub sanitizeData {
  # scrub the input data, to prevent abuse
  my ($data) = @_;

  # setup field data filter requirements
  # format: 'field_name' => ['max_chars', 'regex_filter'],
  my %filter_data = (
    'function'     => [25,  "^a-zA-Z\_"],
    'refsite'      => [10,  "^a-zA-Z0-9\_\-\:\/\."],
    'language'     => [2,   "^a-z"],
    'acctcode'     => [25,  "^a-zA-Z0-9\-\ \:\."],
    'client'       => [25,  "^a-z"],
    'checkstock'   => [3,   "^a-z"],
    'order-id'     => [23,  "^a-zA-Z0-9\_\-"],
    'ezc_shipping' => [10,  "^a-z"],
    'tapCnt'       => [2,   "^0-9"],    
  );

  foreach my $key (sort keys %$data) {
    if ($data->{$key} ne '') {
      # do basic filtering
      if ($filter_data{$key}[0] > 0) {
        $data->{$key} = substr($data->{$key}, 0, $filter_data{$key}[0]);
      }
      if ($filter_data{$key}[1] =~ /\w/) {
        my $regex = $filter_data{$key}[1];
        $data->{$key} =~ s/[$regex]//g;
      }
      if ($key =~ /^item\d+$/) {
        $data->{$key} =~ s/[^a-zA-Z0-9\_\-\.]//g;
        $data->{$key} = substr($data->{$key}, 0, 23); # max 23 chars
      }
      elsif ($key =~ /^quantity\d+$/) {
        $data->{$key} =~ s/[^0-9\.]//g;
        if ($data->{$key} > 99999) { $data->{$key} = 99999; } # max 99999 qty
      }
      elsif ($key =~ /^(descra|descrb|descrc)\d+$/) {
        $data->{$key} =~ s/[^a-zA-Z0-9\-\_\.\ ]//g;
        $data->{$key} = substr($data->{$key}, 0, 1024); # max 1k chars
      }
      else {
        # should no filter exist, purge all dangerous characters
        $data->{$key} =~ s/(\$|\'|\"|\`|\<|\>|\/|\;|\!|\^|\|)//g;
        # remove dollar signs, single/double quotes, backticks, greater/less thens, slashes, semi-colons, exclimations, carrots, pipes
      }
      $data->{$key} =~ s/^\s+|\s+$//g; # strip leading/trailing whitespace

      if ($data->{$key} !~ /\w/) {
        # only keep fields with data in it
        delete $data->{$key};
      }
    }
    else {
      # only keep fields with data in it
      delete $data->{$key};
    }
  }

  return $data;
}

sub URLDecode {
  my $theURL = $_[0];
  $theURL =~ tr/+/ /;
  $theURL = &URI::Escape::uri_unescape($theURL);
  $theURL =~ s/<!--(.|\n)*-->//g;
  return $theURL;
}

sub URLEncode {
  my $theURL = $_[0];
  $theURL = &URI::Escape::uri_escape_utf8($theURL);
  return $theURL;
}

sub getUserToken {
  # used to collect the userToken in different ways, dependant upon method selected
  # will create a new userToken when none exists
  if ($ezlite::config->{'tokenMethod'} eq 'javascript') {
    # javascript method should have it set in a cookie
    my $cookie = $ENV{'HTTP_COOKIE'};
    my @all = split(/\;/, $cookie);
    foreach my $data (@all) {
      my ($name, $value) = split(/\=/, $data, 2);
      if (($name eq 'userToken') && ($value ne '')) {
        $value =~ s/[^a-zA-Z0-9]/\-/g;
        $value = substr($value, 0, 250); # prevent overflow 
        if (-e $ezlite::config->{'pathBaskets'} . '/' . $value . '.txt') {
          $ezlite::userToken = $value;
          last;
        }
      }
    }
  } 
  elsif ($ezlite::config->{'tokenMethod'} eq 'ip-browser') {
    # assume IP-browser token method. its generated on the fly, so nothing to load.
    $ezlite::userToken = $ENV{'REMOTE_ADDR'} . $ENV{'HTTP_USER_AGENT'};
  }
  else {
    # assume IP token method. its generated on the fly, so nothing to load.
    $ezlite::userToken = '';
  }

  # set userToken &sketFile
  if ($ezlite::userToken eq '') { 
    $ezlite::userToken = &createUserToken();
  }
  $ezlite::basketFile = $ezlite::config->{'pathBaskets'} . '/' . $ezlite::userToken . '.txt';
}

sub createUserToken {
  # create user token, for linking cart data to user
  my @now = gmtime(time);
  my $year = sprintf("%04d", $now[5]+1900);

  my $tokenString = '';
  if ($ezlite::config->{'sessionMethod'} eq 'javascript') {
    $tokenString = sprintf("%s\-%04d%02d%02d\-%02d%02d%02d\-%05d", $ENV{'REMOTE_ADDR'}, $now[5]+1900, $now[4]+1, $now[3], $now[2], $now[1], $now[0], $$);
  }
  if ($ezlite::config->{'sessionMethod'} eq 'ip-browser') {
    $tokenString = $ENV{'REMOTE_ADDR'} . $ENV{'HTTP_USER_AGENT'};
  }
  else {
    $tokenString = $ENV{'REMOTE_ADDR'};
  }
  
  my $userToken = crypt($tokenString, $year);
  $userToken =~ s/[^a-zA-Z0-9]/\-/g;
  return $userToken;
}

sub loadProductBasket {
  # loads all stored products back into user's basket
  if (-e $ezlite::basketFile) {
    open(BASKET,'<',$ezlite::basketFile) or die "Can't open $ezlite::basketFile for reading. $!";
    while(<BASKET>) {
      my $row = $_;
      chop $row;
      my ($sku, $qty, $opt1, $opt2, $opt3) = split(/\t/, $row, 5);
      $sku =~ s/[^a-zA-Z0-9\-\_\.]//g;
      $qty =~ s/[^0-9\.]//g;
      $opt1 =~ s/[^a-zA-Z0-9\-\_\.\ ]//g;
      $opt2 =~ s/[^a-zA-Z0-9\-\_\.\ ]//g;
      $opt3 =~ s/[^a-zA-Z0-9\-\_\.\ ]//g;
      if ($sku ne '') {
        &inBasket($sku, $qty, $opt1, $opt2, $opt3);
      }
    }
    close(BASKET);
  }
}

sub saveProductBasket {
  # saves all products that are in user's basket for later use
  my $cnt = scalar keys %$ezlite::basket;
  if ($cnt < 1) {
    unlink($ezlite::basketFile);
    return;
  }

  open(BASKET,'>',$ezlite::basketFile) or die "Can't open $ezlite::basketFile for writing. $!";
  foreach my $sku (sort keys %$ezlite::basket) {
    if ($ezlite::config->{'decimalQty'}) { $ezlite::basket->{$sku}->{'qty'} = sprintf("%.2f", $ezlite::basket->{$sku}->{'qty'}); }
     else { $ezlite::basket->{$sku}->{'qty'} = sprintf("%0d", $ezlite::basket->{$sku}->{'qty'}); }
    printf BASKET ("%s\t%s\t%s\t%s\t%s\n", $sku, $ezlite::basket->{$sku}->{'qty'}, $ezlite::basket->{$sku}->{'opt1'}, $ezlite::basket->{$sku}->{'opt2'}, $ezlite::basket->{$sku}->{'opt3'});
  }
  close(BASKET);
  chmod(0666, $ezlite::basketFile);

  # use random value to select when to do a little self clean-up
  my $chance = 25; # set the 1-in-X chance range
  my $role = int(rand $chance) + 1; # roles random num between 1 & [chance_num]
  if ($role == 3) { # only purge when it's 3
    &purgeProductBaskets();
  }
}

sub purgeProductBaskets {
  # clean-up product baskets, by removing baskets over 14 days old
  opendir(my $dh, $ezlite::config->{'pathBaskets'}) or die "Can't open pathBaskets directory. $!";
  while (readdir $dh) {
    my $fn = $_;
    if ((-f $fn) && ($fn =~ /\.txt$/) && (-M $fn > 14)) {
      unlink("$ezlite::config->{'pathBaskets'}/$fn") or warn "Can't unlink pathBaskets $fn. $!";
    }
  }
  closedir $dh;
}


sub basketAdd {
  # add/update 1+ items in basket

  foreach my $key (sort keys %$ezlite::query) {
    if ($key =~ /^(item\d+)$/) {
      my $num = $key;
      $num =~ s/[^0-9]//g;
      if ($ezlite::query->{"quantity$num"} > 0) {
        &inBasket($ezlite::query->{"item$num"}, $ezlite::query->{"quantity$num"}, $ezlite::query->{"descra$num"}, $ezlite::query->{"descrb$num"}, $ezlite::query->{"descrc$num"});
      }
    }
  }
  &saveProductBasket();
  &basketCheckout();
}

sub basketDelete {
  # deletes 1+ items from basket

  foreach my $key (sort keys %$ezlite::query) {
    if ($key =~ /^(item\d+)$/) {
      my $num = $key;
      $num =~ s/[^0-9]//g;
      if (($ezlite::query->{"quantity$num"} ne '') && ($ezlite::query->{"quantity$num"} < 1)) {
        &outBasket($ezlite::query->{"item$num"});
      }
    }
  }
  &saveProductBasket();
  &basketCheckout();
}

sub basketIncrement {
  # adds 1 to quantity

  foreach my $key (sort keys %$ezlite::query) {
    if ($key =~ /^(item\d+)$/) {
      my $num = $key;
      $num =~ s/[^0-9]//g;
	  &setBasketItemQty($ezlite::query->{"item$num"},&getBasketItemQty($ezlite::query->{"item$num"}) + 1);
    }
  }
  &saveProductBasket();
  &basketCheckout();
}

sub basketDecrement {
  # subtracts 1 from quantity deletes sku from basket if < 1

  foreach my $key (sort keys %$ezlite::query) {
    if ($key =~ /^(item\d+)$/) {
      my $num = $key;
      $num =~ s/[^0-9]//g;
	  my $val = &getBasketItemQty($ezlite::query->{"item$num"}) - 1;
	  if($val < 1) {
 	    &outBasket($ezlite::query->{"item$num"});
	  }
	  else {
  	    &setBasketItemQty($ezlite::query->{"item$num"},$val);
	  }
    }
  }
  &saveProductBasket();
  &basketCheckout();
}

sub basketEmpty {
  # removes all items from basket

  foreach my $key (sort keys %$ezlite::basket) {
    &outBasket($key);
  }
  &saveProductBasket(); 

  $ezlite::displayHTML .= "<div class='emptyBasketNotice'></div>\n";
}

sub basketCheckout {
  # view basket contents w/checkout option

  if (scalar keys %$ezlite::basket == 0) {
    $ezlite::displayHTML .= "<div class='emptyBasketNotice'></div>\n";
    return;
  }

  my @skus;
  foreach my $key (sort keys %$ezlite::basket) {
    push(@skus, $key);
  }

  my $div = "<div class='checkoutTable'>\n";
  $div .= "  <div class='rowTitle'>\n";
  for (my $i = 0; $i <= 4; $i++) {
    $div .= "    <span class='column'></span>\n";
  }
  $div .= "  </div>\n";

  my $subtotal = 0;
  my $products = &getProducts(@skus);
  foreach my $key (sort keys %$ezlite::basket) {
    my $deleteButton = "<a href='$ezlite::script\?function=delete\&item1=$key\&quantity1=0\&tapCnt=$ezlite::tapCnt' class='deleteItemButton'></a>\n";

    my $description = $products->{$key}->{'description'};
    if ($ezlite::basket->{$key}->{'opt1'} ne '') { $description .= ', ' . $ezlite::basket->{$key}->{'opt1'}; }
    if ($ezlite::basket->{$key}->{'opt2'} ne '') { $description .= ', ' . $ezlite::basket->{$key}->{'opt2'}; }
    if ($ezlite::basket->{$key}->{'opt3'} ne '') { $description .= ', ' . $ezlite::basket->{$key}->{'opt3'}; }
    my @array = ($products->{$key}->{'productid'}, $description, $ezlite::basket->{$key}->{'qty'}, $ezlite::config->{'curSymbol'}.$products->{$key}->{'unitprice'}, $deleteButton);
    $subtotal += ($ezlite::basket->{$key}->{'qty'} * $products->{$key}->{'unitprice'});
    $div .= "  <div class='rowProduct'>\n";
    foreach my $val (@array) {
      $div .= sprintf("    <span class='column'>%s</span>\n", $val);
    }
    $div .= "  </div>\n";
  }

  $subtotal = sprintf("%.02f", $subtotal);
  $div .= "  <div class='rowSubtotal'>\n";
  $div .= sprintf("    <span class='column'>%s</span>\n", ' ');
  $div .= sprintf("    <span class='column'>%s</span>\n", $ezlite::config->{'curSymbol'}.$subtotal);
  $div .= sprintf("    <span class='column'>%s</span>\n", ' ');
  $div .= "  </div>\n";

  $div .= "</div>\n";

  $div .= "<div class='taxShipNotice'></div>\n";
  if ($ezlite::config->{'ssVersion'} eq '2') {
    $div .= &paymentSSv2Form($products);
  } else {
    $div .= &paymentSSv1Form($products);
  }
  $ezlite::displayHTML .= $div;
}

sub basketFinal {
  # clear basket contents & redirect to final URL

  foreach my $key (sort keys %$ezlite::basket) {
    &outBasket($key);
  }
  &saveProductBasket();

  $ezlite::displayHTML .= "<br>Thank you for your order...<br>\n";
  if ($ezlite::basket->{'finalURL'} =~ /^(http|https):\/\/\w/) {
    $ezlite::displayHTML .= "<a href='$ezlite::basket->{'finalURL'}'>Click Here To Continue</a>\n";
  }
}

sub displayTemplate {
  # load template, substute in cart content & display to user
  open(TEMPLATE,'<',$ezlite::config->{'pathTemplate'}) or die "Can't open template file for reading. $!";
  while (<TEMPLATE>) {
    my $line = $_;
    if ($line =~ /\[table\]/i) {
      $line =~ s/\[table\]/$ezlite::displayHTML/g;
    }
    if ($line =~ /\[userToken\]/) {
      $line =~ s/\[userToken\]/$ezlite::userToken/g;
    }
    if ($line =~ /\[emptycart\]/) {
      my $button = &emptyButton();
      $line =~ s/\[emptycart\]/$button/g;
    }
    if ($line =~ /\[continue\]/) {
      my $button = &continueButton();
      $line =~ s/\[continue\]/$button/g;
    }
    print $line;
  }
  close(TEMPLATE);
}

sub getProducts {
  # loads details of selected products from product database
  my @skus = @_;
  my $matchSkus = join("\|", @skus);

  my $products;
  my @header;
  my $skuCol = 0;

  open(DB,'<',$ezlite::config->{'pathDatabase'}) or die "Can't open pathDatabase for reading. $!"; 
  while(<DB>) {
    my $line = $_;
    $line =~ s/^\s+|\s+$//g; # strip leading/trailing whitespace
    if ($line =~ /^shipping /i) {
      $line = lc($line);
      my @tmp = split(/ /, $line, 3);
      $ezlite::config->{'shipping'} = $tmp[1];
    }
    elsif ($line =~ /^tax /i) {
      $line = lc($line);
      my @tmp = split(/ /, $line, 3);
      $ezlite::config->{'taxRate'} = $tmp[1];
      $ezlite::config->{'taxState'} = $tmp[2];
    }
    elsif ($line =~ /^cardtype /i) {
      $line = lc($line);
      my @tmp = split(/ /, $line, 2);
      $ezlite::config->{'cardtype'} = $tmp[1];
    }
    elsif ($line =~ /^header /i) {
      $line = lc($line);
      $line =~ s/^header //g;
      @header = split(/\t|\",\"/, $line);
      $header[0] =~ s/^\"//;  # remove leading double quote
      $header[-1] =~ s/\"$//; # remove trailing doublen quote
      foreach (my $k = 0; $k <= $#header; $k++) {
        if ($header[$k] =~ /ProductID/i) {
          $skuCol = $k;
          next;
        }
      }
    }
    elsif ($line =~ /(\t|\",\")/) {
      my @row = split(/\t|\",\"/, $line);
      $row[0] =~ s/^\"//;  # remove leading double quote
      $row[-1] =~ s/\"$//; # remove trailing doublen quote 
      if ($row[$skuCol] =~ /^($matchSkus)$/) {
        my $sku = $row[$skuCol];
        for (my $k = 0; $k <= $#header; $k++) {
          my $colName = $header[$k];
          $row[$k] =~ s/(\t|\r|\n|\r\n)//g;
          $products->{$sku}->{$colName} = $row[$k];
        }
      }
    }
  }
  close(DB);

  return $products;
}

sub inBasket {
  # use to put item into active basket contents list
  my ($sku, $qty, $opt1, $opt2, $opt3) = @_;
 
  $ezlite::basket->{$sku} = {
    'qty'  => $qty,
    'opt1' => $opt1,
    'opt2' => $opt2,
    'opt3' => $opt3,
  }
}

sub outBasket {
  # use to take item out of active basket contents list
  my ($sku) = @_;

  delete $ezlite::basket->{$sku};
}

sub paymentSSv1Form {
  my ($products) = @_;

  my $shipTotal   = $ezlite::config->{'shipping'};
  my $weightTotal = 0;

  my $pairs = {
    'publisher-name'  => $ezlite::config->{'username'},
    'client'          => 'EZLite',
    'easycart'        => 1,
    'currency_symbol' => $ezlite::config->{'curSymbol'},
    'currency'        => $ezlite::config->{'currency'}, 
    'success-link'    => $ezlite::script,
    'shipinfo'        => $ezlite::config->{'shipinfo'},
    'taxrate'         => $ezlite::config->{'taxRate'},
    'taxstate'        => $ezlite::config->{'taxstate'},
    'taxship'         => $ezlite::config->{'taxShip'},
    'card-allowed'    => $ezlite::config->{'cardtype'},

    'publisher-email' => $ezlite::config->{'publisher_email'},
	'required'        => $ezlite::config->{'required'},
    'paymethod'       => $ezlite::config->{'paymethod'},
    'paytemplate'     => $ezlite::config->{'paytemplate'},
  };

  my $pos = 1;
  foreach my $key (sort keys %$ezlite::basket) {
    $pairs->{"item$pos"}        = $products->{$key}->{'productid'};
    $pairs->{"description$pos"} = $products->{$key}->{'description'};
    $pairs->{"quantity$pos"}    = $ezlite::basket->{$key}->{'qty'};
    $pairs->{"cost$pos"}        = $products->{$key}->{'unitprice'};

    if ($products->{$key}->{'shipping'} > 0) {
      $shipTotal += ($products->{$key}->{'shipping'} * $ezlite::basket->{$key}->{'qty'});
    }
    if ($products->{$key}->{'taxable'} =~ /y|n/i) {
      $pairs->{"taxable$pos"} = lc($products->{$key}->{'taxable'});
    }
    if ($products->{$key}->{'weight'} > 0) {
      $weightTotal += ($products->{$key}->{'weight'} * $ezlite::basket->{$key}->{'qty'});
    }
    if ($products->{$key}->{'plan'} ne '') {
      $pairs->{'plan'}  = $products->{$key}->{'plan'}; # only keep last planID seen
    }

    if ($ezlite::basket->{$key}->{'opt1'} ne '') {
      $pairs->{"description$pos"} .= ', ' . $ezlite::basket->{$key}->{'opt1'};
    }
    if ($ezlite::basket->{$key}->{'opt2'} ne '') {
      $pairs->{"description$pos"} .= ', ' . $ezlite::basket->{$key}->{'opt2'};
    }
    if ($ezlite::basket->{$key}->{'opt3'} ne '') {
      $pairs->{"description$pos"} .= ', ' . $ezlite::basket->{$key}->{'opt3'};
    }

    if ($products->{$key}->{'supplieremail'} ne '') {
      $pairs->{"supplieremail$pos"} = $products->{$key}->{'supplieremail'};
    }
    if ($products->{$key}->{'fulfillmap'} ne '') {
      $pairs->{"fulfillmap$pos"} = $products->{$key}->{'fulfillmap'};
    }
    $pos++;
  }

  if ($shipTotal > 0) {
    $pairs->{'shipping'} = $shipTotal;
  }
  if ($weightTotal > 0) {
    $pairs->{'totalwgt'} = $weightTotal;
  }

  my $frm = "<form id='paymentSSv1' method=post action='https://pay1.plugnpay.com/payment/pay.cgi'>\n";
  foreach my $key (sort keys %$pairs) {
    $frm .= sprintf("<input type=hidden name='%s' value='%s'>\n", $key, $pairs->{$key});
  }
  $frm .= "<a href='javascript:void(0);' class='paymentButton' onclick=\"document.getElementById('paymentSSv1').submit();\"></a>\n";
  $frm .= "</form>\n";

  return $frm;
}

sub paymentSSv2Form {
  my ($products) = @_;

  my $shipTotal   = $ezlite::config->{'shipping'};
  my $weightTotal = 0;

  my $pairs = {
    'pt_gateway_account'   => $ezlite::config->{'username'},
    'pt_client_identifier' => 'EZLite',
    'pd_display_items'     => 'yes',
    'pd_currency_symbol'   => $ezlite::config->{'curSymbol'},
    'pt_currency'          => $ezlite::config->{'currency'},
    'pb_success_url'       => $ezlite::script,
    'pt_tax_rate'          => $ezlite::config->{'taxRate'},
    'pt_tax_state'         => $ezlite::config->{'taxstate'},
    'pb_cards_allowed'     => $ezlite::config->{'cardtype'},

    'pd_transaction_payment_type' => $ezlite::config{'pd_transaction_payment_type'},
  };

  if ($ezlite::config->{'shipinfo'} eq '1') {
    $pairs->{'pd_collect_shipping_information'} = 'yes';
  } else {
    $pairs->{'pd_collect_shipping_information'} = 'no';
  }

  my $pos = 1;
  foreach my $key (sort keys %$ezlite::basket) {
    $pairs->{"pt_item_identifier_$pos"}        = $products->{$key}->{'productid'};
    $pairs->{"pt_item_description_$pos"} = $products->{$key}->{'description'};
    $pairs->{"pt_item_quantity_$pos"}    = $ezlite::basket->{$key}->{'qty'};
    $pairs->{"pt_item_cost_$pos"}        = $products->{$key}->{'unitprice'};

    if ($products->{$key}->{'shipping'} > 0) {
      $shipTotal += ($products->{$key}->{'shipping'} * $ezlite::basket->{$key}->{'qty'});
    }
    if ($products->{$key}->{'taxable'} =~ /y|n/i) {
      if ($products->{$key}->{'taxable'} =~ /y/i) {
        $pairs->{"pt_item_is_taxable_$pos"} = 'yes';
      } else {
        $pairs->{"pt_item_is_taxable_$pos"} = 'no';
      }
    }
    #if ($products->{$key}->{'weight'} > 0) {
    #  $weightTotal += ($products->{$key}->{'weight'} * $ezlite::basket->{$key}->{'qty'});
    #}
    if ($products->{$key}->{'plan'} ne '') {
      $pairs->{'pr_plan_id'}  = $products->{$key}->{'plan'}; # only keep last planID seen
    }

    if ($ezlite::basket->{$key}->{'opt1'} ne '') {
      $pairs->{"pt_item_description_$pos"} .= ', ' . $ezlite::basket->{$key}->{'opt1'};
    }
    if ($ezlite::basket->{$key}->{'opt2'} ne '') {
      $pairs->{"pt_item_description_$pos"} .= ', ' . $ezlite::basket->{$key}->{'opt2'};
    }
    if ($ezlite::basket->{$key}->{'opt3'} ne '') {
      $pairs->{"pt_item_description_$pos"} .= ', ' . $ezlite::basket->{$key}->{'opt3'};
    }

    #if ($products->{$key}->{'supplieremail'} ne '') {
    #  $pairs->{"supplieremail$pos"} = $products->{$key}->{'supplieremail'};
    #}
    #if ($products->{$key}->{'fulfillmap'} ne '') {
    #  $pairs->{"fulfillmap$pos"} = $products->{$key}->{'fulfillmap'};
    #}
    $pos++;
  }

  if ($shipTotal > 0) {
    $pairs->{'shipping'} = $shipTotal;
  }
  if ($weightTotal > 0) {
    $pairs->{'totalwgt'} = $weightTotal;
  }

  my $frm = "<form id='paymentSSv2' method=post action='https://pay1.plugnpay.com/pay/'>\n";
  foreach my $key (sort keys %$pairs) {
    $frm .= sprintf("<input type=hidden name='%s' value='%s'>\n", $key, $pairs->{$key});
  }
  $frm .= "<a href='javascript:void(0);' class='paymentButton' onclick=\"document.getElementById('paymentSSv2').submit();\"></a>\n";
  $frm .= "</form>\n";

  return $frm;
}

sub continueButton {
  return "<a name='xxx' class='continueButton' onclick=\"javascript:history.go(\-$ezlite::tapCnt);\"></a>\n";
}

sub emptyButton {
  return "<a href='$ezlite::script\?function=empty\&tapCnt=$ezlite::tapCnt' class='emptyButton'></a>\n";
}

1;
