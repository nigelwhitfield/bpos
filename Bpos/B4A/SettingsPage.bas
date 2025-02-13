B4A=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=10.7
@EndOfDesignText@
Sub Class_Globals
	Private Root As B4XView 'ignore
	Private xui As XUI 'ignore
	
	Private dialog As B4XDialog
	
	Private Button_PIN As Button
	Private Button_Cancel As Button
	Private Button_Confirm As Button
	Private Button_Emaillog As Button
	Private Button_Import As Button
	Private Button_ImportBusiness As Button
	Private Button_Printlog As Button
	Private Button_Postlog As Button
	Private Button_Reset As Button
	Private set_address1 As EditText
	Private set_address2 As EditText
	Private set_companyname As EditText
	Private set_ref As EditText
	Private set_shopname As EditText
	Private set_vatid As EditText
	Private set_currency As EditText
	Private set_symbol As EditText
	Private Check_Showstock As CheckBox
	Private mainpage As B4XMainPage = B4XPages.GetPage("MainPage")
	Private Label_Status As Label
	
	Public provider As FileProvider
End Sub

'You can add more parameters here.
Public Sub Initialize As Object
	Return Me
	
End Sub

'This event will be called once, before the page becomes visible.
Private Sub B4XPage_Created (Root1 As B4XView)
	Root = Root1
	'load the layout to Root
	Root.LoadLayout("settings")
	B4XPages.SetTitle(Me, "B-POS settings")
	
	provider.Initialize
	
End Sub

private Sub B4XPage_appear
	Dim mainpage As B4XMainPage = B4XPages.GetPage("MainPage")
	
	dialog.Initialize(Root)
	
	set_companyname.text = mainpage.settingsdb.GetDefault("companyname","")
	set_shopname.text = mainpage.settingsdb.GetDefault("shopname","")
	set_address1.Text = mainpage.settingsdb.GetDefault("address1","")
	set_address2.Text = mainpage.settingsdb.GetDefault("address2","")
	set_vatid.Text = mainpage.settingsdb.GetDefault("vatid","")
	set_ref.Text = mainpage.settingsdb.GetDefault("orderprefix","")
	set_currency.Text = mainpage.settingsdb.GetDefault("currencyname","EUR")
	set_symbol.Text = mainpage.settingsdb.GetDefault("currencysymbol","€")
	If mainpage.settingsdb.ContainsKey("showstock") Then
		Check_Showstock.Checked = True
	Else
		Check_Showstock.Checked = False
	End If

	refresh_status
End Sub

'You can see the list of page related events in the B4XPagesManager object. The event name is B4XPage.
Private Sub Button_Confirm_Click
	Public mainpage As B4XMainPage = B4XPages.GetPage("MainPage")
	
	mainpage.settingsdb.Put("companyname",set_companyname.text)
	mainpage.settingsdb.Put("shopname",set_shopname.text)
	mainpage.settingsdb.Put("address1",set_address1.text)
	mainpage.settingsdb.Put("address2",set_address2.Text)
	mainpage.settingsdb.Put("vatid",set_vatid.Text)
	mainpage.settingsdb.Put("orderprefix",set_ref.text)
	mainpage.settingsdb.Put("currencyname",set_currency.text)
	mainpage.settingsdb.Put("currencysymbol",set_symbol.text)
	
	If Check_Showstock.Checked Then
		mainpage.settingsdb.Put("showstock",True)
	Else
		mainpage.settingsdb.Remove("showstock")
	End If
	
	B4XPages.ClosePage(Me)
	
End Sub


Private Sub Button_Reset_Click
	Msgbox2Async("Do you really want to reset the logs? This will delete all records of sales. You should probably print or email the logs first.", "Reset sales logs?", "Yes", "", "No", Null, False)
	Wait For Msgbox_Result (Result As Int)
	If Result = DialogResponse.POSITIVE Then
		
		Msgbox2Async("Are you really, really sure? This cannot be undone","Delete sales logs","Yes","","No",Null,False)
		If Result = DialogResponse.POSITIVE Then
			mainpage.saleslog.ExecNonQuery("DELETE FROM lineitems")
			mainpage.saleslog.ExecNonQuery("DELETE FROM sales")
		End If
	End If
End Sub

Private Sub Button_Printlog_Click
	If mainpage.Printer1.IsConnected = False Then
		MsgboxAsync("Printer is not connected. Return to the main screen and tap the printer icon","Printer unavailable")
	Else
		mainpage.Printer1.Reset
		mainpage.Printer1.codepage = 71 ' Western Europe
		
		mainpage.Printer1.leftmargin =25
		mainpage.Printer1.WriteString(mainpage.Printer1.BOLD & mainpage.shopname & " sales log" & mainpage.Printer1.NOBOLD & CRLF & CRLF)
		
		mainpage.Printer1.LeftMargin = 10
		
		DateTime.DateFormat = "d MMM yyyy"
		DateTime.TimeFormat = "HH:mm"
		
		mainpage.Printer1.WriteString(DateTime.Date(DateTime.now) & " " & DateTime.Time(DateTime.now) & CRLF & CRLF )
		Dim tabs() As Int = Array As Int(3,24)
		mainpage.Printer1.TabPositions = tabs

		Dim sales As Float = 0
		Dim refunds As Float = 0

		' get sales items
		Dim cursor As ResultSet
		cursor = mainpage.saleslog.ExecQuery("SELECT rowid, * FROM sales WHERE amount > 0 ORDER BY ts")
		
		mainpage.Printer1.WriteString(CRLF & mainpage.Printer1.WIDE & cursor.RowCount & " sales" & mainpage.Printer1.SINGLE & CRLF)
		

		Do While cursor.NextRow
			Dim ref As String = cursor.GetString("rowid")
			Dim amount As Float = cursor.GetDouble("amount")/100
			Dim items As Int = cursor.GetInt("items")
			Dim skus As Int = cursor.GetInt("skucount")
			Dim pfx As String = cursor.GetString("prefix")
			
			sales = sales + amount 
			mainpage.Printer1.WriteString(pfx & NumberFormat2(ref,4,0,0,False) & ": " & items & " items " & skus & " SKUs" & mainpage.Printer1.HT & NumberFormat2(amount,1,2,2,False) & CRLF)
		Loop
		cursor.close
		
		mainpage.Printer1.WriteString(mainpage.Printer1.BOLD & mainpage.currencyname & " " & NumberFormat2(sales,1,2,2,True) &mainpage.Printer1.NOBOLD & CRLF)
		
		
		' get refund items
		Dim cursor As ResultSet
		cursor = mainpage.saleslog.ExecQuery("SELECT rowid, * FROM sales WHERE amount < 0 ORDER BY ts")
		
		mainpage.Printer1.WriteString(CRLF & mainpage.Printer1.WIDE & cursor.RowCount & " refunds" & mainpage.Printer1.SINGLE &CRLF)
		
		Do While cursor.NextRow
			Dim ref As String = cursor.GetString("rowid")
			Dim amount As Float = -1*cursor.GetDouble("amount")/100
			Dim items As Int = cursor.GetInt("items")
			Dim skus As Int = cursor.GetInt("skucount")
			Dim pfx As String = cursor.GetString("prefix")

			
			refunds = refunds + amount
			mainpage.Printer1.WriteString(mainpage.orderprefix & NumberFormat2(ref,4,0,0,False) & "," & items & " items, " & skus & " SKUs" & mainpage.Printer1.HT & NumberFormat2(amount,1,2,2,False) & CRLF)
		Loop
		
		mainpage.Printer1.WriteString(mainpage.Printer1.BOLD & mainpage.currencyname & " " & NumberFormat2(refunds,1,2,2,True) & CRLF)
		
		' print total
		
		mainpage.Printer1.WriteString(CRLF & CRLF & mainpage.Printer1.WIDE & "Gross sales" & CRLF & mainpage.currencyname & " " & NumberFormat2((sales-refunds),1,2,2,True) & mainpage.Printer1.NOBOLD & CRLF & CRLF)
		
		' now handle line items
		Dim cursor As ResultSet
		cursor = mainpage.saleslog.ExecQuery("SELECT item, sum(qty) AS sold FROM lineitems GROUP BY sku")
		
		Dim total As Int = 0
		mainpage.Printer1.WriteString(CRLF & mainpage.Printer1.WIDE & cursor.RowCount & " SKUs sold" & mainpage.Printer1.SINGLE &CRLF)

		
		Do While cursor.NextRow
			Dim item As String = cursor.Getstring("item")
			Dim sold As String = cursor.GetInt("sold")
			
			total = total + sold
			mainpage.Printer1.writestring(item & mainpage.printer1.HT & sold &CRLF)		
		Loop
		cursor.close
		mainpage.Printer1.WriteString(mainpage.Printer1.BOLD & "Total items sold: " & total & CRLF)
		
		If mainpage.vatid <> "" Then
			' calculate VAT
			mainpage.Printer1.WriteString(CRLF & mainpage.Printer1.WIDE & mainpage.vatname & " reporting" & mainpage.Printer1.SINGLE &CRLF)
		
			Dim totalvat As Float = 0
			Dim totalgoods As Float = 0
			
			
			Dim cursor As ResultSet
			cursor = mainpage.saleslog.ExecQuery("SELECT * FROM lineitems")
			Do While cursor.NextRow
				Dim l_total As Int = cursor.GetInt("total")
				Dim l_vat As Float = cursor.GetDouble("vatrate")/100
				
				Dim goods As Float = (l_total/100) / (1 +l_vat)
				Dim vatcharged As Float = l_total/100 - goods
				totalvat = totalvat + vatcharged
				totalgoods = totalgoods + goods
			Loop
			cursor.close
			
			mainpage.Printer1.WriteString(mainpage.Printer1.BOLD & "Total goods " & mainpage.currencyname & " " & NumberFormat2(totalgoods,1,2,2,True) & CRLF)
			mainpage.Printer1.WriteString(mainpage.Printer1.BOLD & "Total " & mainpage.vatname & " " & mainpage.currencyname & " " & NumberFormat2(totalvat,1,2,2,True) & CRLF)

			
		End If
		
		mainpage.Printer1.WriteString(CRLF & "End of log" & CRLF)
		mainpage.Printer1.PrintAndFeedPaper(120)
	End If
End Sub

private Sub button_ImportBusiness_Click
	Msgbox2Async("Do you want to import business settings? This will override current values", "Import settings", "Yes", "", "No", Null, False)
	Wait For Msgbox_Result (Result As Int)
	If Result = DialogResponse.POSITIVE Then
		Dim url As B4XInputTemplate
		url.Initialize
		url.lblTitle.Text = "Enter URL path to business.ini"
		
		wait for( dialog.showTemplate(url,"OK","","Cancel")) complete (Result As Int)
		If Result = xui.DialogResponse_Positive Then
			downloadBusiness(url.text)
		End If
	End If
End Sub

Private Sub Button_Import_Click
	Msgbox2Async("Do you want to import products? This will delete all products currently in the database", "Import products", "Yes", "", "No", Null, False)
	Wait For Msgbox_Result (Result As Int)
	If Result = DialogResponse.POSITIVE Then
		Dim url As B4XInputTemplate
		url.Initialize
		url.lblTitle.Text = "Enter URL path to products.csv"
		
		wait for( dialog.showTemplate(url,"OK","","Cancel")) complete (Result As Int)
		If Result = xui.DialogResponse_Positive Then
			downloadProducts(url.text)
		End If
	End If
End Sub

private Sub Button_ImportBusiness_LongClick
	Msgbox2Async("Do you want to delete all products and settings?","Delete products and settings","Yes","","No",Null,False)
	Wait For Msgbox_Result (Result As Int)
	If Result = DialogResponse.POSITIVE Then
		Msgbox2Async("Are you really, really sure? This cannot be undone","Delete products and settings","Yes","","No",Null,False)
		If Result = DialogResponse.POSITIVE Then
			If File.Exists(File.DirInternal,"logo.jpg") Then File.Delete(File.DirInternal,"logo.jpg")
			mainpage.skus.ExecNonQuery("DELETE FROM products")
			
			Dim settings As List
			settings.Initialize2(Array As String("companyname","shopname","address1","address2","vatid","orderprefix","currencyname","currencysymbol","vatname","receiptlogo","postback","postbackurl","postbacksecret","passcode","prodoductsurl","showstock"))
		
			For Each option As String In settings
				mainpage.settingsdb.Remove(option)
			Next
			
			set_companyname.Text = ""
			set_shopname.Text = ""
			set_address1.text = ""
			set_address2.text = ""
			set_vatid.Text = ""
			set_ref.Text = ""
			set_currency.Text = ""
			set_symbol.Text = ""
			Check_Showstock.Checked = False
			
		End If
	End If
End Sub

Private Sub Button_Emaillog_Click
	' email sales logs as csv files
	Dim su As StringUtils
	
	Dim email As B4XInputTemplate
	email.Initialize
	email.lblTitle.Text = "Enter email to send reports"
	
	wait for ( dialog.ShowTemplate(email,"OK","","Cancel")) complete ( result As Int )
	If result = xui.DialogResponse_Positive Then
		
		DateTime.DateFormat = "d MMM yyyy"
		DateTime.TimeFormat = "HH:mm"
		
		' sales
		Dim salesdata As List
		salesdata.Initialize
		
		salesdata.Add(Array As String("salesref","date","amount","items","skucount","prefix","discount"))
		Dim cursor As ResultSet
		cursor = mainpage.saleslog.ExecQuery("SELECT rowid, * FROM sales ORDER BY ts")
		Do While cursor.NextRow
			Dim ref As String = cursor.GetString("rowid")
			Dim ts As Long = cursor.GetLong("ts")
			Dim amount As String = cursor.GetString("amount")
			Dim items As String = cursor.GetString("items")
			Dim skus As Int = cursor.GetInt("skucount")
			Dim pfx As String = cursor.GetString("prefix")
			Dim disc As String = cursor.GetString("discount")

			
			salesdata.Add(Array As String(ref, DateTime.Date(ts) & " " & DateTime.Time(ts), amount, items, skus, pfx, disc ))
		Loop
		cursor.close
		
		su.SaveCSV(File.DirInternal,"sales.csv",",",salesdata)		
		File.Copy(File.Dirinternal, "sales.csv", provider.SharedFolder, "sales.csv")
		
		' line items
		Dim lineitems As List
		lineitems.Initialize
		lineitems.Add(Array As String("salesref","sku","quantity","item","price","vatrate","total"))
		
		Dim cursor As ResultSet
		cursor = mainpage.saleslog.ExecQuery("SELECT * FROM lineitems ORDER BY saleid")
		Do While cursor.NextRow
			Dim ref As String = cursor.Getstring("saleid")
			Dim sku As String = cursor.getstring("sku")
			Dim item As String = cursor.GetString("item")
			Dim qty As String = cursor.GetString("qty")
			Dim price As String = cursor.GetString("price")
			Dim vatrate As String = cursor.GetString("vatrate")
			Dim total As String = cursor.GetString("total")
			
			lineitems.Add(Array As String(ref, sku, qty, item, price, vatrate, total))
		Loop
		cursor.close
		
		su.SaveCSV(File.DirInternal,"lineitems.csv",",",lineitems)
		File.Copy(File.DirInternal,"lineitems.csv",provider.SharedFolder, "lineitems.csv")
		
		' now send the email
		Dim e As Email
		e.to = Array As String(email.Text)
		e.Subject = "Sales reports for " & mainpage.shopname
		
		DateTime.DateFormat = "d MMM yyyy"
		DateTime.TimeFormat = "HH:mm"
		
		
		e.Body = "Data generated at " & DateTime.Date(DateTime.now) & " " & DateTime.Time(DateTime.now) & CRLF & CRLF
		
		e.Attachments.Add(provider.GetFileUri("sales.csv"))
		e.Attachments.Add(provider.GetFileUri("lineitems.csv"))
		
		StartActivity(e.GetIntent)
	End If
	
End Sub


private Sub Button_PIN_Click
	Dim pin As B4XInputTemplate
	pin.Initialize
	pin.lblTitle.Text = "Enter a new passcode for settings"
		
	wait for( dialog.showTemplate(pin,"OK","","Cancel")) complete (Result As Int)
	If Result = xui.DialogResponse_Positive Then
		Dim pin2 As B4XInputTemplate
		pin2.Initialize
		pin2.lblTitle.Text = "Confirm passcode"
		wait for( dialog.showTemplate(pin2,"OK","","Cancel")) complete (Result As Int)
		If Result = xui.DialogResponse_Positive Then
			If pin.Text = pin2.Text Then
				mainpage.settingsdb.Put("passcode",pin.Text)
				MsgboxAsync("Passcode will be required to access settings","Passcode set")
			Else
				MsgboxAsync("Passcodes do not match","Passcode not set")
			End If
			
		End If
		
	End If
End Sub


Private Sub Button_Cancel_Click
	B4XPages.ClosePage(Me)
End Sub

private Sub downloadProducts( url As String)
	
	Dim baseurl  As String
	If Not( url.StartsWith("https://")) Then
		url = "https://" & url 
	End If
		
	If url.EndsWith("/") Then
		baseurl = url
	Else if url.EndsWith("products.csv") Then
		baseurl = url.Replace("products.csv","")
	Else 
		baseurl = url & "/"
	End If
	
	Log("Downloading products info from " & baseurl )
	
	ProgressDialogShow("Fetching product data file")
	
	Dim j As HttpJob
	
	j.Initialize("",Me)
	j.Download(baseurl & "products.csv")
	
	wait for (j) JobDone( j As HttpJob)
	If j.success Then
		ProgressDialogShow("Processing products data")
		
		Dim csvfile As OutputStream
		csvfile = File.OpenOutput(File.DirInternal,"products.csv",False)		
		File.Copy2(j.GetInputStream,csvfile)
		csvfile.Close
		Log("Downloaded " & File.Size(File.DirInternal,"products.csv") & " bytes")

		processCSV(baseurl)
	Else
		ProgressDialogHide
		MsgboxAsync("Check there is a products.csv file at the URL, and that the internet connection is working","Download failed")
	End If
		
End Sub

private Sub downloadBusiness (url As String )
	Dim targeturl  As String
	If Not( url.StartsWith("https://")) Then
		url = "https://" & url
	End If
		
	If url.EndsWith("/") Then
		targeturl = url & "business.ini"
	Else if Not( url.EndsWith("business.ini")) Then
		targeturl = url & "/business.ini"		
	End If
	
	Dim j As HttpJob
	
	j.Initialize("",Me)
	j.Download(targeturl)
	
	wait for (j) JobDone( j As HttpJob)
	If j.success Then
		ProgressDialogShow("Processing business data")
		
		Dim csvfile As OutputStream
		csvfile = File.OpenOutput(File.DirInternal,"business.ini",False)
		File.Copy2(j.GetInputStream,csvfile)
		csvfile.Close
		Log("Downloaded " & File.Size(File.DirInternal,"business.ini") & " bytes")

		' now process the file
		Dim Reader As TextReader
		Reader.Initialize(File.OpenInput(File.DirInternal, "business.ini"))
		
		Dim business As Map
		business.Initialize
		
		Dim line As String
		line = Reader.ReadLine
		Do While line <> Null
			line = Reader.ReadLine
			If line == Null Then Exit
			If line.StartsWith("#") Or line.StartsWith(";") Then 
				' do nothing
			Else If line.Contains("=") Then
				Dim key As String = line.SubString2(0,line.IndexOf("=")-1).Trim
				Dim value As String = line.substring(line.IndexOf("=")+1).Trim
				
				business.Put(key,value)
				Log("Setting " & key & " to " & value)
			End If
		Loop
		Reader.Close
		
		' see if there's a logo file to fetch
		Dim j As HttpJob
		j.Initialize("",Me)
	
		' receipt logo
		If business.ContainsKey("receiptlogo") Then
		
			Dim logourl As String = targeturl.Replace("business.ini",business.Get("receiptlogo"))
	
			j.Download(logourl)
			wait for (j) jobdone ( j As HttpJob)
		
			If j.Success Then

				Dim b As Bitmap = j.GetBitmap
				
				Dim out As OutputStream
				out = File.OpenOutput(File.DirInternal,"logo.jpg",False)
				b.WriteToStream(out,100,"JPEG")
				out.Close
				Log("Downloaded receipt logo")
			End If
		End If
	
		' products if specified
		If business.ContainsKey("productsurl") Then
			Msgbox2Async("Do you want to update products now?","Update products","Yes","","No",Null,False)
			Wait For Msgbox_Result (Result As Int)
			If Result = DialogResponse.POSITIVE Then downloadProducts(business.Get("productsurl"))
		End If
	
		' save or delete settings
		Dim settings As List
		settings.Initialize2(Array As String("companyname","shopname","address1","address2","vatid","orderprefix","currencyname","currencysymbol","vatname","discount","receiptlogo","postback","postbackurl","postbacksecret","passcode","prodoductsurl","showstock"))
		
		For Each option As String In settings
			If business.ContainsKey(option) Then
				mainpage.settingsdb.Put(option,business.Get(option))
			Else
				mainpage.settingsdb.Remove(option) 
			End If
		Next
		
		' populate the display
		set_companyname.text = mainpage.settingsdb.GetDefault("companyname","")
		set_shopname.text = mainpage.settingsdb.GetDefault("shopname","")
		set_address1.Text = mainpage.settingsdb.GetDefault("address1","")
		set_address2.Text = mainpage.settingsdb.GetDefault("address2","")
		set_vatid.Text = mainpage.settingsdb.GetDefault("vatid","")
		set_ref.Text = mainpage.settingsdb.GetDefault("orderprefix","")
		set_currency.Text = mainpage.settingsdb.GetDefault("currencyname","EUR")
		set_symbol.Text = mainpage.settingsdb.GetDefault("currencysymbol","€")
		If mainpage.settingsdb.ContainsKey("showstock") Then
			Check_Showstock.Checked = True
		Else
			Check_Showstock.Checked = False
		End If
		
		ProgressDialogHide
	
		
	Else
		ProgressDialogHide
		MsgboxAsync("Check there is a business.ini file at the URL, and that the internet connection is working","Download failed")
	End If
	
	
	
	
End Sub

private Sub processCSV( baseurl As String )
	Log("Starting to process CSV file")
	
	Dim products As List
	Dim su As StringUtils
	Try
		products = su.LoadCSV(File.DirInternal,"products.csv",",")
		ProgressDialogShow("Found " & products.Size & " products to import")
	
		If products.Size > 0 Then
			' delete the current products
		
			mainpage.skus.BeginTransaction
			mainpage.skus.ExecNonQuery("DELETE FROM products")
		
			' add each product in turn
			For Each row() As String In products
				Select row.Length
					Case 5
						' no stock or customisation
						mainpage.skus.ExecNonQuery2("INSERT INTO products VALUES ( ?, ?, ?, ?, ?, -1, '' )",row)
					Case 6
						' stock levels
						mainpage.skus.ExecNonQuery2("INSERT INTO products VALUES ( ?, ?, ?, ?, ?, ?, '')",row)
					Case Else
						' all options
						mainpage.skus.ExecNonQuery2("INSERT INTO products VALUES ( ?, ?, ?, ?, ?, ?, ? )",row)
				End Select
			Next
			mainpage.skus.TransactionSuccessful
			mainpage.skus.EndTransaction
		End If
	
		Dim c As ResultSet
		c = mainpage.skus.ExecQuery("SELECT * FROM products")
		Do While c.NextRow
			Dim name As String = c.GetString("name")
			Dim image As String = c.GetString("imagename")
		
			Dim fmt As String
			If image.EndsWith(".png") Then
				fmt = "PNG"
			Else
				fmt = "JPEG"
			End If
		
			ProgressDialogShow("Downloading product image for " & name)
			Dim j As HttpJob
			j.Initialize("",Me)
		
			j.Download(baseurl & image)
		
			wait for (j) JobDone( j As HttpJob)
			If j.success Then
				Dim b As Bitmap = j.GetBitmap
			
				Dim out As OutputStream
				out = File.OpenOutput(File.DirInternal,image,False)
				b.WriteToStream(out,100,fmt)
				out.Close
		
			End If
		Loop
		c.close
	
		ProgressDialogHide

		MsgboxAsync("Products have been imported","Import complete")
	Catch
		ProgressDialogHide
		MsgboxAsync("Error loading products. Check the CSV file is valid." &CRLF & CRLF & LastException.Message,"Import error")
	End Try
	
End Sub

private Sub button_Postlog_Click
	If mainpage.settingsdb.Getdefault("postbackurl","") = "" Or mainpage.settingsdb.GetDefault("postback","none") = "none" Then
		MsgboxAsync("Sales postback is not configured. Update the business.ini file with the required settings.","Sales cannot be posted")
	Else
		Dim cursor As ResultSet
		cursor = mainpage.saleslog.ExecQuery("SELECT rowid FROM sales WHERE posted = 0")
		Dim pending As Int = cursor.RowCount
		If pending = 0 Then
			MsgboxAsync("There are no transactions waiting to be posted","Nothing to do!")
		Else
			Do While cursor.NextRow
				ProgressDialogShow("Posting transaction " & mainpage.orderprefix & NumberFormat2(cursor.GetInt("rowid"),4,0,0,False))
			
				wait for (mainpage.postTransaction(cursor.GetInt("rowid"))) complete
			Loop
			
			ProgressDialogHide
		
			Dim waiting As Int
		
			waiting = mainpage.saleslog.ExecQuerySingleResult("SELECT count(rowid) FROM sales WHERE posted = 0")
		
			If waiting = 0 Then
				MsgboxAsync("All transactions posted to server","Communication complete")
			Else
				MsgboxAsync("Some transactions failed to post. " & waiting & " still to be posted","Communication incomplete")
			End If
		End If
		cursor.Close
		refresh_status
	End If
End Sub

private Sub refresh_status
	Dim unposted As Int
	unposted = mainpage.saleslog.ExecQuerySingleResult("SELECT count(rowid) FROM sales WHERE posted = 0")
	
	Dim sales As Int
	sales = mainpage.saleslog.ExecQuerySingleResult("SELECT count(rowid) FROM sales")
	
	If sales > 0 Then 
		Dim pennies As Int
		Dim gross As Float
		pennies = mainpage.saleslog.ExecQuerySingleResult("SELECT SUM(amount) FROM sales")
		Log(pennies)
		
		If pennies = 0 Then
			gross = 0.0
		Else
			gross = pennies / 100
		End If
		
		Label_Status.Text = "STATUS: " & sales & " sales, " & unposted & " unposted, gross " & mainpage.currencysymbol & NumberFormat2(gross,1,2,2,True)
	Else
		Label_Status.Text = "STATUS: no sales logged"
	End If
End Sub