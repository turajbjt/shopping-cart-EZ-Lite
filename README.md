# shopping-cart-EZ-Lite
EZ Lite Shopping Cart - an EasyCart shopping cart replacement

Effective Janurary 1st 2022, PlugnPay will no longer be offering their EasyCart shopping cart.
This Perl project is intended to be a somewhat drop-in replacement for that cart.

More detailed instructions are to come, but for now, here's a summery of what to do:
- download & then decompress this ezlite.zip file into your site's web directory
(for this example, I'll assume you'll put cart's files in a folder name 'ezlite' off the web root)
- go into the cart's 'private' folder & edit the values within the ezlite.cfg file (chmod 644 the file)
(it should be clear what goes where, but the xxxSOMETHINGxxx values are pretty much what you need to adjust)
- ensure you have the required 'baskets' & 'logs' folders created wherever you've set them (chmod 777 the folders)
- download a copy of your EasyCart product database from PlugnPay, if you don't have it already
- replace the existing orderfrm.prices file in the 'private' folder with your EasyCart product database
- finally perform a recurssive substution of all EasyCart links in your site's HTML to point to the new EZ Lite cart 
(i.e. change 'https://easycart.plugnpay.com/easycart.cgi' to 'https://xxxYourDomainxxx/ezlite/index.cgi')
- pretty much that's all there is to it.  All EasyCart forms/buttons on your site should now work with EZ Lite...
[optional] You may edit the template.htm & ezlite.css files to match your site's look feel
* Note: Most wording displayed in EZ Lite are set via the ezlite.css file, so you don't need to mess with Perl.

Beyond that you are pretty much on your own.  This cart & its related code are pretty simple, so it's highly recommend you try to figure things out yourself.  And if how this cart is designed is way over your head, you should hire a good web developer, as it will save you a lot of headaches in the log run - should you not know know how to do such things.  But YMMV, so go luck & enjoy this free Perl script.
