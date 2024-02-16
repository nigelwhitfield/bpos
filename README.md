# B-POS Android point of sale app

B-POS is a fairly simple point of sale app that's designed to run on a tablet and enable the sale of merchandise at events.
We're a member supported club, and this is an important source of revenue for us. It's intended to be used with a standalone
card reader, like a Square or MyPOS device, and can link to a Bluetooth ESC/POS printer to produce receipts.

## Key features
+ Grid display of products with images and prices
+ Automatic totalling of current sale
+ Support for applying a discount percentage
+ Support for sales refunds
+ Products can be configured to require a custom data field
+ Logging of sales to internal database
+ Printing of receipts via a Bluetooth printer
+ Printing of sales summaries
+ Support for VAT, including different rates on different products
+ Basic stock control, showing quantities and out of stock items
+ Emailing of sales summaries as CSV files
+ POSTing of transactions as JSON to a remote server
+ Product details can be downloaded from a remote server
+ Business details can be entered manually, or downloaded from a remote server

This app is supplied as a [B4X Project](bpos.zip), and can be built using [B4A](https://www.b4x.com/b4a.html) from 
Anywhere Software.


## Important notes
This is a work in progress; it's had sufficient features added and tested for us to use at a forthcoming event, but there's
some work needed to make the printing more reliable, especially around requesting permissons on different Android devices.

Additionally, the current build has been designed to work with the [Samsung Galaxy Tab A9](https://www.samsung.com/uk/tablets/galaxy-tab-a9/buy/?modelCode=SM-X110NZAEEUB) that we're using, and little work
has been done so far on adapting screen layouts for other size devices. You'll always get a grid with five products across,
for example. No work has been done to accommodate split screens or other fripperies; it's assumed you'll be using the app
as the sole task on the device.

Print functions have been designed and tested with a [Munbyn IMP001](https://pos.munbyn.com/munbyn-imp001-series-mini-bluetooth-pos-receipt-printer/) Bluetooth ESC/POS printer. In theory, they should work with other
similar printers, but cheap ESC/POS devices are fickle things, and trying to do something as basic as printing currency
symbols can tie you up in knots.

## Getting started
By default, the app will generate a dummy set of ten products, with random prices, so that you can see how it works without
having to spend time importing data.

To add a product to the basket, tap its image. To add more, tap the same image again. To remove a product, tap the trash icon
next to the product in the Current Sale list. You'll be asked if you want to remove just one, or remove the product from 
the list entirely.

When all products are added, you grab your card machine, enter the total shown on screen, and ask the customer to pay. If 
the payment succeeds, tap the green tick button, and you'll be asked if you want to print a receipt. If the transaction failed,
tap cancel. Tap No to proceed without a receipt. Either way, the sale will be recorded in the logs. Tap Cancel if you do not
want the sale logged.

The current sale can be cleared by pressing the red cross button.

To issue a refund, put an item in the basket, and long press the red cross button.

To apply a discount to a sale, tap the gift icon at the top right, and enter the percentage amount as a number, eg 5 for a 5% discount.
You can tap the trash icon in the sale list to remove the discount. If you apply a different discount, it will replace the first
one - there can only be one discount applied to a sale. 

A press on the printer button should enable Bluetooth. Long press to connect to the printer, if it doesn't happen automatically.
When the printer is connected, the button will turn green.

Long press on a product photo to set the stock level. If a passcode is required for accessing settings, it will also be required to
update an item's stock level. 

## Receipts
+ If one instance of an item is added, it will appear as a single line on the receipt
+ If more than one of an item is added, a second line will show the individual item price
+ If a custom field was requested for a product, a line will show the value entered
+ If a discount has been applied to the sale, individual lines will show the discounted price, and the discount percentage and total
saving will be shown below the items.

If there are multiple VAT rates for products, the VAT rate will be shown for each product. If all products have the same rate,
it will be printed once, below all the items. VAT information is only printed if a VAT id has been configured.

A default logo will be printed on receipts. This can be updated via a data import (see below). A black and white JPG should
work fine, around 360 x 80 pixels, 96dpi, but as previously noted, ESC/POS printers are fussy beasts. Multiples of 8 pixels seem
to keep my printer happy.

## Settings
Tap the cog button to open the settings screen. The left hand half contains spaces to enter your business details, which are
principally used for receipts. VAT amounts will only be calculated if you have entered a VAT id. This will create separate 'goods'
and 'VAT' lines on the receipt, as well as the total including VAT.

The order prefix is prefixed to the four digit sale number. Two or three letters should be sufficient.

The currency name should be the standard three letter code, like EUR, GBP or USD, and will be printed on receipts.

The currency symbol is displayed on screen only.

If the Show stock levels option is ticked, then a red circle will be displayed on each product for which stock control is enabled,
with the current stock level (or no number if zero). Adding a product for which the system believes there is no stock will display
a warning dialogue, but will not stop it from being added to the sale.

The Set Passcode button allows you to enter an alphanumeric code that will be required for access to the settings page in future.

The red cross button will return to the main screen without updating any changes to your settings, and the green tick will save
your changes, and return.

## Tools
Tap Print sales logs to print out a summary of all the sales, with number of items and gross amount, followed by any refunds, and 
then the gross amount (sales - refunds). Next follows a list of the SKUs sold, and the number of each, and if a VAT id is 
configured, a summary of the total goods and total VAT.

Email sales logs will prompt for an email address and then launch the default email client with a new message that has two attachments.
sales.csv is the summary of each sale, with salesref, date, amount and number of items. lineitems.csv contains all the individual
items sold, with the salesref, sku, quantity, price, vatrate and total.

Post sales log will post transactions in JSON format to a remote URL. This option is described in more detail later.

Reset sales logs will delete all sales logs, and reset the sales counter to zero. You will be prompted twice before the logs are
deleted.

Import products allows a new batch of products to be imported. See following description for more details.

Import settings allows you to import your business settings. See following description for more details.

A long press on the Import settings button will delete all products, and all settings (but not the sales log). When this is done,
the app will rebuild a list of dummy products.

## Importing products
When this button is tapped, you will be prompted for the URL path to a products.csv file. An https connection is assumed. The
app is fairly flexible; if your file is located at https://my.example.com/pos/products.csv you can enter either the full URL or
any of my.example.com/pos or my.example.com/pos/ or my.example.com/pos/products.csv

The products.csv file is a text file which must contain five, six or seven fields. There should be no header line, and all fields
are enclosed in double quotation marks. The fields, in order, are

+ SKU: an integer number representing the item in your product catalogue
+ Item: The description that will be displayed on screen and on receipts
+ Imagefile: a photo (ideally around 300px square) of the item, in png or jpg format, in the same folder on the server as the products.csv file.
If no image is give, or cannot be downloaded, a default image is used.
+ VAT rate: the VAT rate charged, if applicable, for this product
+ Price: in basic currency units, eg cents for Euros and dollars, pence for Pounds. And item costing EUR 10.00 should have the price 1000

If only five fields are present, the items will be imported and marked as not subject to stock control, and having no custom options

If a sixth field is present, it should contain the number of stock items for the product, or -1 if you do not want to track stock
for that product.

If a seventh field is present, it should contain a text description that will be prompted for when adding the item to a sale. For example,
we allow people to donate when purchasing, with an item like this

		"9999","BLUF Donation €10","","0","1000","-1","member id"

When adding this item to the sale, a prompt appears "Enter member id for BLUF Donation €10" and the member id will be listed
on the receipt and in sales records. If the field is empty, there will be no prompt.

## Importing settings
When this button is tapped, you will be prompted for the URL path to a business.ini file. An https connection is assumed, and as with
product import, the app is similarly flexible. You should usually put the business.ini file in the same folder as your product
information. 

The business.ini file is a text file. When loaded, the app will ignore lines that start with a ; or a # 
Lines that contain an = symbol are assumed to be configuration items, and will be used to set the business options, and configure
some additional advanced settings. All settings names should be in lower case.

### Business settings 
These settings can also be updated via the app's user interface:

+ companyname: The legal name of your company, eg Megacorp LLC
+ shopname: The trading name of your shop, eg Mega Shop
+ address1: The first line of your company address
+ address2: The second line of your company address
+ vatid: If required, your VAT registration number, eg GB000000001
+ orderprefix: Two or three letters to prefix order numbers, eg to indicate the event you are selling at
+ currencyname: The name of the currency to print on receipts, eg EUR or GBP
+ currencysymbol: The currency symbol to display on screen, eg € or £
+ passcode: An alphanumeric passcode that will be required to access the settings screen
+ showstock: If set, stock levels will be shown on products, where configured

These options cannot be altered via the app's user interface:
+ receiptlogo: The name of an image file in the same folder as business.ini, which will be printed at the top of receipts 
+ vatname: if set, will replace 'VAT' on receipts, eg MwSt or TVA

#### Advanced options
+ productsurl: If present, then after the business settings have been updated, you will be asked if you want to load products 
from this location. As with manual entry, there is flexibility, so you can just set this to my.example.com/pos/ instead of 
adding the https:// and products.csv
+ postback: If set, and the postbackurl is also set, controls posting of transactions to a remote server. When set to 'transaction'
each sale will be posted when it's confirmed. When set to Batch, un-posted sales are sent, one at a time, when the Post sales log button
is pressed
+ postbackurl: Set to the path of your postback script, eg my.exmple.com/pos/postback.php. https:// is assumed.
+ postbacksecret: A phrase that will be included with posted transactions, so your script can ignore other requests

## Postback format
When postback is enabled, transactions are posted, one per call, to the specified URL as a JSON message. This enables remote processing,
such as integrating with existing store or stock control systems, or sending emails. The example [postback.php](postback.php) file included is a simple
script that sends a notification of a sale or refund to a specified email address.

Example JSON data:

		{
		 "salesref": "DL0005",
		 "timestamp": "1707149136",
		 "date": "5 Feb 2024 16:05",
		 "currency": "EUR",
		 "total": "45.00",
		 "items": 2,
		 "lineitems": [
		   {
			 "sku": 500,
			 "quantity": 1,
			 "description": "Calendar",
			 "price": "25.00",
			 "vatrate": "21",
			 "goods": "20.66",
			 "total": "25.00"
		   },
		   {
			 "sku": 999,
			 "quantity": 1,
			 "description": "BLUF Donation 20; member id = 1533",
			 "price": "20.00",
			 "vatrate": "0",
			 "goods": "20.00",
			 "total": "20.00"
		   }
		 ],
		 "secret": "This-Is-My-Special-Secret"
		}
		
### PrestaShop stock integration
Also included is an alternative postback script, [postback-presta.php](postback-presta.php) which illustrates how you can use 
the postback functionality to update available stock levels in a [PrestaShop](https://prestashop.com) store. Please make sure you read the notes in the
code carefully; though it's been tested and works (with PrestaShop 1.7.8), if you are processing high volumes, or do not have
a reliable internet connection where you're selling, there are some obvious improvements that could be made, for better
performance and reliability. 

Consider it more of a proof-of-concept.

### Ecwid stock integration
I have also included [postback-ecwid.php](postback-ecwid.php), which illustrates how you can use the [Ecwid](https://www.ecwid.com) v3 API (not available
on free plans) to update the stock levels in an Ecwid online store. Note that I have not had an Ecwid store since 2022, so 
this code is based on old internal scripts, and I have not been able to test it against a live store, but if they are still
using the same API, it should work.

## Changelog
+ 1.01: Added the ability to set stock levels on products; tweaks to sales log report format; changed code to use Resultset instead of Cursor; discount
and stock dialogs are set to numeric input mode; better reporting of postback actions; changed printer module to use async dialog; added status display
on settings screen
