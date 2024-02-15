<?php

// Simple Ecwid stock integration for B-POS

// IMPORTANT: This is a simple proof-of-concept
//
// As I no longer have an Ecwid store, this is based on old code from when I did have one
// which was back in 2022. So, while the methods used here worked with their v3 api at that
// time, I have not tested them since, and this should instead be used as a starting point
// for your own integration.
//
// To get started, you will need one of the paid Ecwid plans that allows API access, and you
// need to generate an app secret, following the instructions at
// https://support.ecwid.com/hc/en-us/articles/4938302203932-Adding-more-features-to-your-store-via-Ecwid-s-API
//

// Set these variables for your Ecwid store;

define('ECWID_API', 'https://app.ecwid.com/api/v3/') ;
define('ECWID_SECRET', 'secret_key_for_your_ecwid_app') ;
define('ECWID_STORE_ID', 1234567890) ;

// This has to match the secret configured in the B-POS app
define('POSTBACK_SECRET', 'This-Is-My-Special-Secret') ;

$postdata = file_get_contents('php://input') ;

$sale = json_decode($postdata) ;

if ($sale->secret == POSTBACK_SECRET) {
	foreach ($sale->lineitems as $line) {

		// In my shop, I have certain items that are exclusively sold at events, and not
		// available in my online store. I have given these all skus from 9000 upwards

		if ($line->sku < 9000) {
			update_ecwid_stock($line->sku, $line->quantity) ;
		}
	}
}

function update_ecwid_stock($sku, $qty_sold)
{
	// update the stock levels in an Ecwid store

	// In your ecwid store, you have the SKU that you assign to a product, and there is
	// an additional id field, which is assigned by Ecwid.

	// You can retrieve a list of the products in your Ecwid store by calling the API like this
	//
	// https:// ECWID_API / ECWID_STORE_ID / products?token= ECWID_SECRET
	//
	// This will return products JSON object, which contains an array called items
	//
	// For each item, you will find item->sku and item->id
	// This is the number you will need to use in the sku_stock_map array below
	// For example, for product with SKU 2 in my store, the id was 159458345

	$sku_stock_map = array( 1 => 159451878, 2 => 159458345, 3 => 159458349 ) ;

	$ecwid_id = $sku_stock_map[$sku] ;

	// now call the EEcwid API and update the stock - Ecwid allows you to just supply the delta (change)

	$curl = curl_init();

	$update = json_encode(array('quantityDelta' => $qty_sold)) ;

	curl_setopt_array($curl, [
	  CURLOPT_URL => ECWID_API . ECWID_STORE_ID . '/products/' . $ecwid_id . '/inventory?token=' . ECWID_SECRET,
	  CURLOPT_RETURNTRANSFER => true,
	  CURLOPT_ENCODING => "",
	  CURLOPT_MAXREDIRS => 10,
	  CURLOPT_TIMEOUT => 30,
	  CURLOPT_HTTP_VERSION => CURL_HTTP_VERSION_1_1,
	  CURLOPT_POSTFIELDS => $update,
	  CURLOPT_CUSTOMREQUEST => "PUT",
	  CURLOPT_HTTPHEADER => [
		"Content-Type: application/json;charset=utf-8",
		"Content-Length: " . strlen($update)
	  ],
	]);

	$response = curl_exec($curl);
	$err = curl_error($curl);


	curl_close($curl);

	if ($err) {
		echo "cURL Error #:" . $err;
	}
}
