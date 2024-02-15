<?php

// Simple PrestaShop stock integration for B-POS

// IMPORTANT: This is a simple proof-of-concept and not really intended for production use
// Take it as a starting point
//
// Calls to the PrestaShop web service can be a bit slow, so for a large order, it may
// take several seconds to update all the stock, and the behaviour of the app and this script
// if the connection is lost can best be described as "undefined"
//
// For more reliable production use, I would suggest simply saving the data received into a
// database, and then processing it asynchronously, for example via a cron job, to ensure
// the B-POS app isn't hanging around waiting for PrestaShop's web service to do its thing

// You will need the PrestaShop web service library, which can be installed via composer:
//			composer require prestashop/prestashop-webservice-lib

require_once('vendor/autoload.php') ; // gets us our PrestaShop webservice module

// Set these variables for your PrestaShop; you can generate a key via the
// Advanced options -> Webservice
// Grant full access to products and stock_availables

define('PRESTA_STORE_URL', 'https://prestashop.example.com') ;
define('PRESTA_WEBSERVICE_KEY', '1234567890abcdef123456') ;

// This has to match the secret configured in the B-POS app
define('POSTBACK_SECRET', 'This-Is-My-Special-Secret') ;

$postdata = file_get_contents('php://input') ;

$sale = json_decode($postdata) ;

if ($sale->secret == POSTBACK_SECRET) {
	foreach ($sale->lineitems as $line) {

		// In my shop, I have certain items that are exclusively sold at events, and not
		// available in my PrestaShop store. I have given these all skus from 9000 upwards

		if ($line->sku < 9000) {
			update_presta_stock($line->sku, $line->quantity) ;
		}
	}
}


function update_presta_stock($sku, $qty_sold)
{
	// update the stock levels in a PrestaShop store

	// note that the SKU here is not necessarily the product ID in your PrestaShop store.
	// It might be something else, like the reference
	// You need to find the 'stock_availables' id, which is the thing that actually has
	// to be updated

	// If you have a web service key, and you know that the Presta product ID is, say, 2
	// you can get the JSON data for that product with a call like
	//
	// 	https://prestashop.example.com/api/products/21?output_format=JSON
	//
	// When the browser prompts you for username & password, enter the web service key
	// as the username
	//
	// Look through the data and you will find associations -> stock_availables -> [0] -> id
	// This is the number you will need to use in the sku_stock_map array below
	// For example, for product with reference (SKU) 2 in my store, the stock_availables id is 71

	$sku_stock_map = array( 1 => 59, 2 => 71, 3 => 72 ) ;

	$sa_id = $sku_stock_map[$sku] ;

	// now call the PrestaShop web service to get the current stock_available item
	// Yay! Fun with XML (said no one, ever)

	try {
		$webService = new PrestaShopWebservice(PRESTA_STORE_URL, PRESTA_WEBSERVICE_KEY, false);
		$opt = array('resource' => 'stock_availables');
		$opt['id'] = $sa_id ;
		$xml = $webService->get($opt);

		// Here we get the elements from children of prestashop root markup
		$resources = $xml->children()->children();
	} catch (PrestaShopWebserviceException $e) {
		// Here we are dealing with errors
		$trace = $e->getTrace();
		if ($trace[0]['args'][0] == 404) {
			echo 'Bad ID';
		} elseif ($trace[0]['args'][0] == 401) {
			echo 'Bad auth key';
		} else {
			echo 'Other error<br />'.$e->getMessage();
		}
	}

	// update the data we got from the store
	// Note that this is very basic; it doesn't take account of selling out
	// I guess, just don't take all your stock to the event!

	$resources->quantity = ($resources->quantity - $qty_sold) ;

	// Now, use the web service library to write this data back to the shop
	try {
		$opt = array('resource' => 'stock_availables');
		$opt['putXml'] = $xml->asXML();
		$opt['id'] = $sa_id ;
		$xml = $webService->edit($opt);
		// if WebService doesn't throw an exception the action worked
	} catch (PrestaShopWebserviceException $ex) {
		// Here we are dealing with errors
		$trace = $ex->getTrace();
		if ($trace[0]['args'][0] == 404) {
			echo 'Bad ID';
		} elseif ($trace[0]['args'][0] == 401) {
			echo 'Bad auth key';
		} else {
			echo 'Other error<br />'.$ex->getMessage();
		}
	}
}
