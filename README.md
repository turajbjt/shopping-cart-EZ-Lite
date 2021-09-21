# shopping-cart-EZ-Lite
EZ Lite Shopping Cart - an EasyCart shopping cart replacement

Effective Janurary 1st 2022, PlugnPay will no longer be offering their EasyCart shopping cart.
This project is intended to be a somewhat drop-in replacement for PlugnPay's EasyCart shopping cart.

More detailed instructions are to come, but in the mean time, here's a summery of what to do.
- download & then decompress this ezlite.zip file into your site's web directory
(for this example, I'll assume you'll put cart's files in a folder name 'ezlite' off the web root)
- go into the cart's 'private' folder & edit the values within the ezlite.cfg file (chmod 644 the file)
(it should be clear what goes where, but the xxxSOMETHINGxxx values are pretty much what you need to adjust)
- ensure you have the required 'basket' & 'logs' folders created wherever you've set them (chmod 777 the folders)
- download a copy of your EasyCart product database from PlugnPay's EasyCart admin area
- replace the existing orderfrm.prices file in the 'private' fiolder with your EasyCart product database
- finally perform a recurssive substution of all EasyCart links in your site's HTM to point to the new EZ Lite cart 
(i.e. change 'https://easycart.plugnpay.com/easycart.cgi' to 'https://xxxYourDomainxxx/ezlite/index.cgi')
- pretty much that's all there is to it.  All EasyCart forms/buttons on your site should now work wite EZ Lite...
[optional] edit the template.htm & ezlite.css files to match your site's look feel
* Note: Most of the languange used in EZ Lite are set via the exlite.css file, so you don't need to mess with Perl.
 
