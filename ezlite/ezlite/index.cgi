#!/usr/bin/perl

require 5.8.0;
$| = 1;

my $pathPrivate;
BEGIN {
  $pathPrivate = './private';
}
use lib $pathPrivate;
use CGI::Carp qw(fatalsToBrowser);
use ezlite;
use strict;

my $ezlite = new ezlite($pathPrivate);

print "Content-Type: text/html\n\n";

my %functions = (
  'add'      => sub { &ezlite::basketAdd() },
  'delete'   => sub { &ezlite::basketDelete() },
  'empty'    => sub { &ezlite::basketEmpty() },
  'checkout' => sub { &ezlite::basketCheckout() },
  'success'  => sub { &ezlite::basketFinal() },
);

my $runAction = exists($functions{$ezlite::function}) ? $ezlite::function : 'checkout';
$functions{$runAction}->();

&ezlite::displayTemplate();

exit;

