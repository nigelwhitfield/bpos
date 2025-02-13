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
	#If B4J
	Private set_address1 As TextField
	Private set_address2 As TextField
	Private set_companyname As TextField
	Private set_ref As TextField
	Private set_shopname As TextField
	Private set_vatid As TextField
	Private set_currency As TextField
	Private set_symbol As TextField
	#Else
	Private set_address1 As EditText
	Private set_address2 As EditText
	Private set_companyname As EditText
	Private set_ref As EditText
	Private set_shopname As EditText
	Private set_vatid As EditText
	Private set_currency As EditText
	Private set_symbol As EditText
	Public provider As FileProvider
	#End If
	Private Check_Showstock As CheckBox
	Private mainpage As B4XMainPage
	Private Label_Status As Label
End Sub

'You can add more parameters here.
Public Sub Initialize As Object
	Return Me
End Sub

'This event will be called once, before the page becomes visible.
Private Sub B4XPage_Created (Root1 As B4XView)
	Root = Root1
	'load the layout to Root
	Root.LoadLayout("Settings")
	B4XPages.SetTitle(Me, "B-POS settings")
	mainpage = B4XPages.GetPage("MainPage")
	#If B4A
	provider.Initialize
	#End If
End Sub

Private Sub B4XPage_Appear
	Dim mainpage As B4XMainPage = B4XPages.GetPage("MainPage")
	
	dialog.Initialize(Root)
	
	set_companyname.text = mainpage.settingsdb.GetDefault("companyname", "")
	set_shopname.text = mainpage.settingsdb.GetDefault("shopname", "")
	set_address1.Text = mainpage.settingsdb.GetDefault("address1", "")
	set_address2.Text = mainpage.settingsdb.GetDefault("address2", "")
	set_vatid.Text = mainpage.settingsdb.GetDefault("vatid", "")
	set_ref.Text = mainpage.settingsdb.GetDefault("orderprefix", "")
	set_currency.Text = mainpage.settingsdb.GetDefault("currencyname", "EUR")
	set_symbol.Text = mainpage.settingsdb.GetDefault("currencysymbol", "€")
	'If mainpage.settingsdb.ContainsKey("showstock") Then
	'	Check_Showstock.Checked = True
	'Else
	'	Check_Showstock.Checked = False
	'End If
	Check_Showstock.Checked = mainpage.settingsdb.ContainsKey("showstock")
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
		mainpage.settingsdb.Put("showstock", True)
	Else
		mainpage.settingsdb.Remove("showstock")
	End If
	B4XPages.ClosePage(Me)
End Sub

Private Sub Button_Reset_Click
	Dim sf As Object = xui.Msgbox2Async("Do you really want to reset the logs? This will delete all records of sales. You should probably print or email the logs first.", "Reset sales logs?", "Yes", "", "No", Null)
	Wait For (sf) Msgbox_Result (Result As Int)
	If Result = xui.DialogResponse_Positive Then
		Dim sf As Object = xui.Msgbox2Async("Are you really, really sure? This cannot be undone", "Delete sales logs", "Yes", "", "No",Null)
		Wait For (sf) Msgbox_Result (Result As Int)
		If Result = xui.DialogResponse_Positive Then
			mainpage.saleslog.ExecNonQuery("DELETE FROM lineitems")
			mainpage.saleslog.ExecNonQuery("DELETE FROM sales")
		End If
	End If
End Sub

Private Sub Button_Printlog_Click
	#If B4A
	If mainpage.Printer1.IsConnected = False Then
		xui.MsgboxAsync("Printer is not connected. Return to the main screen and tap the printer icon", "Printer unavailable")
		Return
	End If
	#End If
	mainpage.Printer1.Reset
	mainpage.Printer1.codepage = 71 ' Western Europe
		
	mainpage.Printer1.leftmargin = 25
	mainpage.Printer1.WriteString(mainpage.Printer1.BOLD & mainpage.shopname & " sales log" & mainpage.Printer1.NOBOLD & CRLF & CRLF)
	
	Dim ts As Long = DateTime.Now
	Dim DF As String = DateTime.DateFormat
	DateTime.DateFormat = "d MMM yyyy HH:mm"
	Dim time As String = DateTime.Date(ts)
	DateTime.DateFormat = DF
	
	mainpage.Printer1.LeftMargin = 10
	mainpage.Printer1.WriteString(time & CRLF & CRLF)
	
	Dim tabs() As Int = Array As Int(3, 24)
	mainpage.Printer1.TabPositions = tabs

	Dim sales As Float = 0
	Dim refunds As Float = 0

	' get sales items
	Dim salesitems As List
	salesitems.Initialize
	Dim rows As Int
	Dim cursor As ResultSet = mainpage.saleslog.ExecQuery("SELECT rowid, * FROM sales WHERE amount > 0 ORDER BY ts")
	Do While cursor.NextRow
		Dim ref As String = cursor.GetString("rowid")
		Dim amount As Float = cursor.GetDouble("amount") / 100
		Dim items As Int = cursor.GetInt("items")
		Dim skus As Int = cursor.GetInt("skucount")
		Dim pfx As String = cursor.GetString("prefix")
		salesitems.Add(CreateMap( _
			"ref": ref, _
			"amount": amount, _
			"items": items, _
			"skus": skus, _
			"pfx": pfx))
		rows = rows + 1
	Loop
	cursor.Close
	'mainpage.Printer1.WriteString(CRLF & mainpage.Printer1.WIDE & cursor.RowCount & " sales" & mainpage.Printer1.SINGLE & CRLF)
	mainpage.Printer1.WriteString(CRLF & mainpage.Printer1.WIDE & rows & " sales" & mainpage.Printer1.SINGLE & CRLF)
		
	For Each s As Map In salesitems
		Dim ref As String = s.Get("ref")
		Dim amount As Float = s.Get("amount")
		Dim items As Int = s.Get("items")
		Dim skus As Int = s.Get("skus")
		Dim pfx As String = s.Get("pfx")
		sales = sales + amount
		mainpage.Printer1.WriteString(pfx & NumberFormat2(ref, 4, 0, 0, False) & ": " & items & " items " & skus & " SKUs" & mainpage.Printer1.HT & NumberFormat2(amount, 1, 2, 2, False) & CRLF)
	Next
	mainpage.Printer1.WriteString(mainpage.Printer1.BOLD & mainpage.currencyname & " " & NumberFormat2(sales, 1, 2, 2, True) & mainpage.Printer1.NOBOLD & CRLF)

	' get refund items
	Dim refunditems As List
	refunditems.Initialize
	Dim rows As Int
	Dim cursor As ResultSet = mainpage.saleslog.ExecQuery("SELECT rowid, * FROM sales WHERE amount < 0 ORDER BY ts")
	Do While cursor.NextRow
		Dim ref As String = cursor.GetString("rowid")
		Dim amount As Float = -1*cursor.GetDouble("amount")/100
		Dim items As Int = cursor.GetInt("items")
		Dim skus As Int = cursor.GetInt("skucount")
		Dim pfx As String = cursor.GetString("prefix")
		refunditems.Add(CreateMap( _
			"ref": ref, _
			"amount": amount, _
			"items": items, _
			"skus": skus, _
			"pfx": pfx))
		rows = rows + 1
	Loop
	cursor.Close
	mainpage.Printer1.WriteString(CRLF & mainpage.Printer1.WIDE & rows & " refunds" & mainpage.Printer1.SINGLE & CRLF)
		
	For Each r As Map In refunditems
		Dim ref As String = r.Get("ref")
		Dim amount As Float = r.Get("amount")
		Dim items As Int = r.Get("items")
		Dim skus As Int = r.Get("skus")
		Dim pfx As String = r.Get("pfx")
		refunds = refunds + amount
		mainpage.Printer1.WriteString(mainpage.orderprefix & NumberFormat2(ref, 4, 0, 0, False) & ", " & items & " items, " & skus & " SKUs" & mainpage.Printer1.HT & NumberFormat2(amount, 1, 2, 2, False) & CRLF)
	Next
	mainpage.Printer1.WriteString(mainpage.Printer1.BOLD & mainpage.currencyname & " " & NumberFormat2(refunds, 1, 2, 2, True) & CRLF)
		
	' print total
	mainpage.Printer1.WriteString(CRLF & CRLF & mainpage.Printer1.WIDE & "Gross sales" & CRLF & mainpage.currencyname & " " & NumberFormat2((sales-refunds), 1, 2, 2, True) & mainpage.Printer1.NOBOLD & CRLF & CRLF)
		
	' now handle line items
	Dim lineitems As List
	lineitems.Initialize
		
	Dim rows As Int
	Dim cursor As ResultSet = mainpage.saleslog.ExecQuery("SELECT item, sum(qty) AS sold FROM lineitems GROUP BY sku")
	Do While cursor.NextRow
		Dim item As String = cursor.Getstring("item")
		Dim sold As Int = cursor.GetInt("sold")
		lineitems.Add(CreateMap( _
			"item": item, _
			"sold": sold))
		rows = rows + 1
	Loop
	cursor.Close
	mainpage.Printer1.WriteString(CRLF & mainpage.Printer1.WIDE & rows & " SKUs sold" & mainpage.Printer1.SINGLE & CRLF)
		
	Dim total As Int = 0
	For Each i As Map In lineitems
		Dim item As String = i.Get("item")
		Dim sold As Int = i.Get("sold")
		total = total + sold
		mainpage.Printer1.WriteString(item & mainpage.printer1.HT & sold & CRLF)
	Next
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
			
		mainpage.Printer1.WriteString(mainpage.Printer1.BOLD & "Total goods " & mainpage.currencyname & " " & NumberFormat2(totalgoods, 1, 2, 2, True) & CRLF)
		mainpage.Printer1.WriteString(mainpage.Printer1.BOLD & "Total " & mainpage.vatname & " " & mainpage.currencyname & " " & NumberFormat2(totalvat, 1, 2, 2, True) & CRLF)
	End If
		
	mainpage.Printer1.WriteString(CRLF & "End of log" & CRLF)
	mainpage.Printer1.PrintAndFeedPaper(120)
End Sub

Private Sub button_ImportBusiness_Click
	Dim sf As Object = xui.Msgbox2Async("Do you want to import business settings? This will override current values", "Import settings", "Yes", "", "No", Null)
	Wait For (sf) Msgbox_Result (Result As Int)
	If Result = xui.DialogResponse_Positive Then
		Dim url As B4XInputTemplate
		url.Initialize
		url.lblTitle.Text = "Enter URL path to business.ini"
		
		Dim sf As Object = dialog.showTemplate(url, "OK", "", "Cancel")
		Wait For (sf) Complete (Result As Int)
		If Result = xui.DialogResponse_Positive Then
			downloadBusiness(url.text)
		End If
	End If
End Sub

Private Sub Button_Import_Click
	Dim sf As Object = xui.Msgbox2Async("Do you want to import products? This will delete all products currently in the database", "Import products", "Yes", "", "No", Null)
	Wait For (sf) Msgbox_Result (Result As Int)
	If Result = xui.DialogResponse_Positive Then
		Dim url As B4XInputTemplate
		url.Initialize
		url.lblTitle.Text = "Enter URL path to products.csv"
		
		Dim sf As Object = dialog.showTemplate(url, "OK", "", "Cancel")
		Wait For (sf) Complete (Result As Int)
		If Result = xui.DialogResponse_Positive Then
			downloadProducts(url.text)
		End If
	End If
End Sub

Private Sub Button_ImportBusiness_LongClick
	Dim sf As Object = xui.Msgbox2Async("Do you want to delete all products and settings?", "Delete products and settings", "Yes", "", "No", Null)
	Wait For (sf) Msgbox_Result (Result As Int)
	If Result = xui.DialogResponse_Positive Then
		Dim sf As Object = xui.Msgbox2Async("Are you really, really sure? This cannot be undone", "Delete products and settings", "Yes", "", "No", Null)
		Wait For (sf) Msgbox_Result (Result As Int)
		If Result = xui.DialogResponse_Positive Then
			#If B4J
			If File.Exists(File.DirApp, "logo.jpg") Then File.Delete(File.DirApp, "logo.jpg")
			#Else
			If File.Exists(File.DirInternal, "logo.jpg") Then File.Delete(File.DirInternal, "logo.jpg")
			#End If
			mainpage.skus.ExecNonQuery("DELETE FROM products")
			
			Dim settings As List
			settings.Initialize2(Array As String("companyname", "shopname", "address1", "address2", "vatid", "orderprefix", "currencyname", "currencysymbol", "vatname", "receiptlogo", "postback", "postbackurl", "postbacksecret", "passcode", "prodoductsurl", "showstock"))
		
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
	
	Dim sf As Object = dialog.ShowTemplate(email, "OK", "", "Cancel")
	Wait For (sf) Complete (result As Int)
	If result = xui.DialogResponse_Positive Then		
		' sales
		Dim salesdata As List
		salesdata.Initialize
		
		salesdata.Add(Array As String("salesref", "date", "amount", "items", "skucount", "prefix", "discount"))
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
			
			Dim DF As String = DateTime.DateFormat
			DateTime.DateFormat = "d MMM yyyy HH:mm"
			Dim time As String = DateTime.Date(ts)
			DateTime.DateFormat = DF
			salesdata.Add(Array As String(ref, time, amount, items, skus, pfx, disc ))
		Loop
		cursor.close
		
		#If B4J
		su.SaveCSV(File.DirApp, "sales.csv", ", ", salesdata)
		#Else
		su.SaveCSV(File.DirInternal, "sales.csv", ", ", salesdata)
		File.Copy(File.Dirinternal, "sales.csv", provider.SharedFolder, "sales.csv")
		#End If
		
		' line items
		Dim lineitems As List
		lineitems.Initialize
		lineitems.Add(Array As String("salesref", "sku", "quantity", "item", "price", "vatrate", "total"))
		
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
		
		#If B4J
		su.SaveCSV(File.DirApp, "lineitems.csv", ", ", lineitems)
		#Else
		su.SaveCSV(File.DirInternal,"lineitems.csv", ", ", lineitems)
		File.Copy(File.DirInternal, "lineitems.csv", provider.SharedFolder, "lineitems.csv")
		#End If
		
		#If B4A
		' now send the email
		Dim e As Email
		e.to = Array As String(email.Text)
		e.Subject = "Sales reports for " & mainpage.shopname
		
		Dim DF As String = DateTime.DateFormat
		DateTime.DateFormat = "d MMM yyyy HH:mm"
		Dim time As String = DateTime.Date(DateTime.Now)
		DateTime.DateFormat = DF
		
		e.Body = "Data generated at " & time & CRLF & CRLF
		
		e.Attachments.Add(provider.GetFileUri("sales.csv"))
		e.Attachments.Add(provider.GetFileUri("lineitems.csv"))
		
		StartActivity(e.GetIntent)
		#End If
	End If
End Sub

Private Sub Button_PIN_Click
	Dim pin As B4XInputTemplate
	pin.Initialize
	pin.lblTitle.Text = "Enter a new passcode for settings"
		
	Dim sf As Object = dialog.showTemplate(pin, "OK", "", "Cancel")
	Wait For (sf) Complete (Result As Int)
	If Result = xui.DialogResponse_Positive Then
		Dim pin2 As B4XInputTemplate
		pin2.Initialize
		pin2.lblTitle.Text = "Confirm passcode"
		Dim sf As Object = dialog.showTemplate(pin2, "OK", "", "Cancel")
		Wait For (sf) Complete (Result As Int)
		If Result = xui.DialogResponse_Positive Then
			If pin.Text = pin2.Text Then
				mainpage.settingsdb.Put("passcode",pin.Text)
				xui.MsgboxAsync("Passcode will be required to access settings", "Passcode set")
			Else
				xui.MsgboxAsync("Passcodes do not match", "Passcode not set")
			End If
		End If
	End If
End Sub

Private Sub Button_Cancel_Click
	B4XPages.ClosePage(Me)
End Sub

Private Sub downloadProducts ( url As String)
	Dim baseurl  As String
	If Not( url.StartsWith("https://")) Then
		url = "https://" & url 
	End If
		
	If url.EndsWith("/") Then
		baseurl = url
	Else if url.EndsWith("products.csv") Then
		baseurl = url.Replace("products.csv", "")
	Else 
		baseurl = url & "/"
	End If
	
	Log("Downloading products info from " & baseurl )
	
	#If B4J
	Log("Fetching product data file")
	#Else
	ProgressDialogShow("Fetching product data file")
	#End If
	
	Dim j As HttpJob
	j.Initialize("", Me)
	j.Download(baseurl & "products.csv")
	
	Wait For (j) JobDone( j As HttpJob)
	If j.success Then
		#If B4J
		Log("Processing products data")
		Dim csvfile As OutputStream
		csvfile = File.OpenOutput(File.DirApp, "products.csv", False)
		File.Copy2(j.GetInputStream, csvfile)
		csvfile.Close
		Log("Downloaded " & File.Size(File.DirApp, "products.csv") & " bytes")
		#Else
		ProgressDialogShow("Processing products data")
		Dim csvfile As OutputStream
		csvfile = File.OpenOutput(File.DirInternal,"products.csv",False)		
		File.Copy2(j.GetInputStream, csvfile)
		csvfile.Close
		Log("Downloaded " & File.Size(File.DirInternal, "products.csv") & " bytes")
		#End If
		processCSV(baseurl)
	Else
		#If B4A
		ProgressDialogHide
		#End If
		xui.MsgboxAsync("Check there is a products.csv file at the URL, and that the internet connection is working", "Download failed")
	End If		
End Sub

Private Sub downloadBusiness (url As String )
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
	
	Wait For (j) JobDone( j As HttpJob)
	If j.success Then
		#If B4J
		Log("Processing business data")
		Dim csvfile As OutputStream
		csvfile = File.OpenOutput(File.DirApp, "business.ini",False)
		File.Copy2(j.GetInputStream, csvfile)
		csvfile.Close
		Log("Downloaded " & File.Size(File.DirApp, "business.ini") & " bytes")
		#Else
		ProgressDialogShow("Processing business data")
		Dim csvfile As OutputStream
		csvfile = File.OpenOutput(File.DirInternal,"business.ini",False)
		File.Copy2(j.GetInputStream,csvfile)
		csvfile.Close
		Log("Downloaded " & File.Size(File.DirInternal,"business.ini") & " bytes")		
		#End If

		' now process the file
		Dim Reader As TextReader
		#If B4J
		Reader.Initialize(File.OpenInput(File.DirApp, "business.ini"))
		#Else
		Reader.Initialize(File.OpenInput(File.DirInternal, "business.ini"))
		#End If
		
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
		
		
		Dim job As HttpJob
		job.Initialize("", Me)
		Dim payload As Map = CreateMap("key": "value", "another key": 1000)
		Dim json As String = payload.As(JSON).ToString 'make sure that the json library is checked
		job.PostString("https://link here", json)
		job.GetRequest.SetContentType("application/json")
		Wait For (job) JobDone (job As HttpJob)
		If job.Success Then
			'assuming that the response is json:
			Dim response As Map = job.GetString.As(JSON).ToMap
			Log(response)
		End If
		job.Release
		
		' see if there's a logo file to fetch
		Dim j As HttpJob
		j.Initialize("",Me)
	
		' receipt logo
		If business.ContainsKey("receiptlogo") Then
		
			Dim logourl As String = targeturl.Replace("business.ini",business.Get("receiptlogo"))
	
			j.Download(logourl)
			Wait For (j) jobdone ( j As HttpJob)
		
			If j.Success Then
				Dim b As B4XBitmap = j.GetBitmap
				Dim out As OutputStream
				#If B4J
				out = File.OpenOutput(File.DirApp, "logo.jpg", False)
				#Else
				out = File.OpenOutput(File.DirInternal, "logo.jpg", False)
				#End If
				b.WriteToStream(out, 100, "JPEG")
				out.Close
				Log("Downloaded receipt logo")
			End If
		End If
	
		' products if specified
		If business.ContainsKey("productsurl") Then
			Dim sf As Object = xui.Msgbox2Async("Do you want to update products now?", "Update products", "Yes", "", "No", Null)
			Wait For (sf) Msgbox_Result (Result As Int)
			If Result = xui.DialogResponse_Positive Then downloadProducts(business.Get("productsurl"))
		End If
	
		' save or delete settings
		Dim settings As List
		settings.Initialize2(Array As String("companyname", "shopname", "address1", "address2", "vatid", "orderprefix", "currencyname", "currencysymbol", "vatname", "discount", "receiptlogo", "postback", "postbackurl", "postbacksecret", "passcode", "prodoductsurl", "showstock"))
		
		For Each option As String In settings
			If business.ContainsKey(option) Then
				mainpage.settingsdb.Put(option,business.Get(option))
			Else
				mainpage.settingsdb.Remove(option) 
			End If
		Next
		
		' populate the display
		set_companyname.text = mainpage.settingsdb.GetDefault("companyname", "")
		set_shopname.text = mainpage.settingsdb.GetDefault("shopname", "")
		set_address1.Text = mainpage.settingsdb.GetDefault("address1", "")
		set_address2.Text = mainpage.settingsdb.GetDefault("address2", "")
		set_vatid.Text = mainpage.settingsdb.GetDefault("vatid", "")
		set_ref.Text = mainpage.settingsdb.GetDefault("orderprefix", "")
		set_currency.Text = mainpage.settingsdb.GetDefault("currencyname", "EUR")
		set_symbol.Text = mainpage.settingsdb.GetDefault("currencysymbol", "€")
		If mainpage.settingsdb.ContainsKey("showstock") Then
			Check_Showstock.Checked = True
		Else
			Check_Showstock.Checked = False
		End If
		
		#If B4A
		ProgressDialogHide
		#End If
	Else
		#If B4A
		ProgressDialogHide
		#End If
		xui.MsgboxAsync("Check there is a business.ini file at the URL, and that the internet connection is working", "Download failed")
	End If	
End Sub

Private Sub processCSV( baseurl As String )
	Log("Starting to process CSV file")
	
	Dim products As List
	Dim su As StringUtils
	Try
		#If B4J
		products = su.LoadCSV(File.DirApp, "products.csv", ", ")
		Log("Found " & products.Size & " products to import")
		#Else
		products = su.LoadCSV(File.DirInternal, "products.csv", ", ")
		ProgressDialogShow("Found " & products.Size & " products to import")
		#End If
	
		If products.Size > 0 Then
			' delete the current products
		
			mainpage.skus.BeginTransaction
			mainpage.skus.ExecNonQuery("DELETE FROM products")
		
			' add each product in turn
			For Each row() As String In products
				Select row.Length
					Case 5
						' no stock or customisation
						mainpage.skus.ExecNonQuery2("INSERT INTO products VALUES ( ?, ?, ?, ?, ?, -1, '' )", row)
					Case 6
						' stock levels
						mainpage.skus.ExecNonQuery2("INSERT INTO products VALUES ( ?, ?, ?, ?, ?, ?, '')", row)
					Case Else
						' all options
						mainpage.skus.ExecNonQuery2("INSERT INTO products VALUES ( ?, ?, ?, ?, ?, ?, ? )", row)
				End Select
			Next
			mainpage.skus.TransactionSuccessful
			'mainpage.skus.EndTransaction
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
		
			#If B4J
			Log("Downloading product image for " & name)
			#Else
			ProgressDialogShow("Downloading product image for " & name)
			#End If
			Dim j As HttpJob
			j.Initialize("", Me)
			j.Download(baseurl & image)
			Wait For (j) JobDone(j As HttpJob)
			If j.success Then
				Dim b As B4XBitmap = j.GetBitmap
				Dim out As OutputStream
				#If B4J
				out = File.OpenOutput(File.DirApp, image, False)
				#Else
				out = File.OpenOutput(File.DirInternal, image, False)
				#End If
				b.WriteToStream(out, 100, fmt)
				out.Close
			End If
		Loop
		c.close
	
		#If B4A
		ProgressDialogHide
		#End If

		xui.MsgboxAsync("Products have been imported", "Import Complete")
	Catch
		#If B4A
		ProgressDialogHide
		#End If
		xui.MsgboxAsync("Error loading products. Check the CSV file is valid." &CRLF & CRLF & LastException.Message,"Import error")
	End Try
	
End Sub

Private Sub button_Postlog_Click
	If mainpage.settingsdb.Getdefault("postbackurl", "") = "" Or mainpage.settingsdb.GetDefault("postback", "none") = "none" Then
		xui.MsgboxAsync("Sales postback is not configured. Update the business.ini file with the required settings.", "Sales cannot be posted")
	Else
		Dim rows As Int
		Dim cursor As ResultSet = mainpage.saleslog.ExecQuery("SELECT rowid FROM sales WHERE posted = 0")
		Do While cursor.NextRow
			#If B4A
			ProgressDialogShow("Posting transaction " & mainpage.orderprefix & NumberFormat2(cursor.GetInt("rowid"), 4, 0, 0, False))
			#End If			
			Wait For (mainpage.postTransaction(cursor.GetInt("rowid"))) Complete (Posted As Boolean)
			Log(Posted)
			#If B4A
			ProgressDialogHide
			#End If
			rows = rows + 1
		Loop
		cursor.Close

		If rows = 0 Then
			xui.MsgboxAsync("There are no transactions waiting to be posted", "Nothing to do!")
		Else
			Dim waiting As Int = mainpage.saleslog.ExecQuerySingleResult("SELECT count(rowid) FROM sales WHERE posted = 0")
			If waiting = 0 Then
				xui.MsgboxAsync("All transactions posted to server", "Communication Complete")
			Else
				xui.MsgboxAsync("Some transactions failed to post. " & waiting & " still to be posted", "Communication incomplete")
			End If
		End If
		refresh_status
	End If
End Sub

Private Sub refresh_status
	Dim unposted As Int = mainpage.saleslog.ExecQuerySingleResult("SELECT count(rowid) FROM sales WHERE posted = 0")
	Dim sales As Int = mainpage.saleslog.ExecQuerySingleResult("SELECT count(rowid) FROM sales")
	
	If sales > 0 Then 
		Dim gross As Float
		Dim pennies As Int = mainpage.saleslog.ExecQuerySingleResult("SELECT SUM(amount) FROM sales")
		Log(pennies)
		
		If pennies = 0 Then
			gross = 0.0
		Else
			gross = pennies / 100
		End If
		
		Label_Status.Text = "STATUS: " & sales & " sales, " & unposted & " unposted, gross " & mainpage.currencysymbol & NumberFormat2(gross, 1, 2, 2, True)
	Else
		Label_Status.Text = "STATUS: no sales logged"
	End If
End Sub