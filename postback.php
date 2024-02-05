<?php

// BLUF v5 commerce tools - postback for event POS
// this is a simple example to send a notification email
// it could be extended to update stock levels, or create a sales invoice
// software like PrestaShop or Ecwid

require('lib/commerce/store_email.php') ;

define('STORE', 'eu') ;
define("NOTIFY_EMAIL", 'nigel@nigelwhitfield.eu') ;
define('NOTIFY_SUBJECT', 'Retail sale') ;

define('POSTBACK_SECRET', 'This-Is-My-Special-Secret') ;

$postdata = file_get_contents('php://input') ;

$sale = json_decode($postdata) ;

if ($sale->secret == POSTBACK_SECRET) {
	$subject = NOTIFY_SUBJECT . ' ' . $sale->salesref ;

	if ($sale->total < 0) {
		$message = '<h3>New refund posted from B-POS with reference ' . $sale->salesref . ' at ' . $sale->date . '</h3>' ;
	} else {
		$message = '<h3>New sale posted from B-POS with reference ' . $sale->salesref . ' at ' . $sale->date . '</h3>' ;
	}


	$message .= '<p>Total ' . $sale->currency . ' ' . $sale->total . '</p>' ;

	$message .= '<table><thead><tr><td>SKU</td><td>Quantity</td><td>Item</td><td>Price</td><td>VAT %</td><td>Goods</td><td>Total</td></tr></thead>' ;

	$message .= '<tbody>' ;

	$goods = 0 ;
	foreach ($sale->lineitems as $line) {
		$goods = $goods + $line->goods ;
		$message .= sprintf("<tr><td>%d</td><td>%d</td><td>%s</td><td>%0.2f</td><td>%s</td><td>%0.2f</td><td>%0.2f</td></tr>", $line->sku, $line->quantity, $line->description, $line->price, $line->vatrate, $line->goods, $line->total) ;
	}
	$message .= '</tbody></table>' ;

	$message .= sprintf("<p>Total goods: %0.2f</p>", $goods) ;
	$message .= sprintf("<p>Total VAT  : %0.2f</p>", $sale->total-$goods) ;

	$message .= '<p></p><p><b>' . $sale->currency . ' ' . $sale->total . '</p>' ;

	send_store_email(STORE, NOTIFY_EMAIL, $subject, $message, STORE_LOGO_EU) ;
}
