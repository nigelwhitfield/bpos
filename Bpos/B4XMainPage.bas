B4A=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=9.85
@EndOfDesignText@
#Region Shared Files
'#CustomBuildAction: folders ready, %WINDIR%\System32\Robocopy.exe,"..\..\Shared Files" "..\Files"
'Ctrl + click to sync files: ide://run?file=%WINDIR%\System32\Robocopy.exe&args=..\..\Shared+Files&args=..\Files&FilesSync=True
#End Region

'Ctrl + click to export as zip: ide://run?File=%B4X%\Zipper.jar&Args=%PROJECT_NAME%.zip

Sub Class_Globals
	
	Private Root As B4XView
	Private xui As XUI
	
	Private dialog As B4XDialog
	
	Private Button_Cancel As B4XView
	Private Button_Confirm As B4XView
	Private CLV_Products As CustomListView
	Private CLV_Sale As CustomListView
	Private Label_Printer As B4XView
	Private Label_Settings As B4XView
	Private Label_Store As B4XView
	Private Label_Discount As B4XView
	Private Label_Ref As B4XView
	Private Total As B4XView
	
	Private Settings As SettingsPage
	Public Printer1 As EscPosPrinter
	
	Public settingsdb As KeyValueStore
	
	Private sale_amount As Int = 0
	Private discount_amount As Int = 0
	Private discount_percent As Float = 0
	
	' company information
	Dim shopname, companyname, address1, address2, vatid, orderprefix, currencyname, currencysymbol, vatrate, vatname As String

	' product info and logs	
	Dim saleslog, skus As SQL
	Private stockcontrol As Boolean = False 
	
	' for sku panel
	Private SKU_Image As B4XView
	Private SKU_Name As B4XView
	Private SKU_Price As B4XView
	Private SKU_Stock As B4XView
	
	' for line items
	Private Label_Cost As B4XView
	Private Label_Item As B4XView
	Private Label_Quantity As B4XView
	Private Label_Remove As B4XView
	
	Private salesref As Int = 0
	#If B4A
	' for bluetooth admin
	Private rp As RuntimePermissions
	Public BluetoothState, ConnectionState As Boolean
	Private admin As BluetoothAdmin
	Private ion As Object
	#End If
End Sub

Public Sub Initialize
	'currentSale.Initialize
	#If B4A
	saleslog.Initialize(File.DirInternal, "saleslog.db", True)
	#End If
	#If B4J
	saleslog.InitializeSQLite(File.DirApp, "saleslog.db", True)
	#End If
	
	'Dim schema As ResultSet = saleslog.ExecQuery("PRAGMA table_info(sales)")
	Dim qry As String = $"SELECT count(name) FROM sqlite_master WHERE type = 'table' AND name = ? COLLATE NOCASE"$
	Dim count As Int = saleslog.ExecQuerySingleResult2(qry, Array As String("sales"))
	If count > 0 Then
		Dim schema As ResultSet = saleslog.ExecQuery("SELECT * FROM sales LIMIT 1")
		Dim colcount As Int = schema.ColumnCount
		schema.Close
		Log("Columns in sales = " & colcount)
		If colcount = 4 Then
			' upgrade the sales table from version 1.0, to store sku count, discount rate and sales prefix
		#If B4A
		ProgressDialogShow("Upgrading database")
		#End If
		saleslog.ExecNonQuery("ALTER TABLE sales ADD COLUMN skucount INTEGER DEFAULT 0")
		saleslog.ExecNonQuery("ALTER TABLE sales ADD COLUMN prefix TEXT DEFAULT ''")
		saleslog.ExecNonQuery("ALTER TABLE sales ADD COLUMN discount TEXT DEFAULT ''")
		#If B4A
		ProgressDialogHide
		#End If	
		End If
	Else
		saleslog.ExecNonQuery("CREATE TABLE IF NOT EXISTS sales ( ts INTEGER, amount INTEGER, items INTEGER, posted INTEGER, skucount INTEGER, prefix TEXT, discount TEXT)")
	End If
	saleslog.ExecNonQuery("CREATE TABLE IF NOT EXISTS lineitems ( saleid INTEGER, sku INTEGER, qty INTEGER, item TEXT, price INTEGER, vatrate TEXT, total INTEGER)")
	
	#If B4A
	skus.initialize(File.DirInternal, "skus.db", True)
	#End If
	#If B4J
	skus.InitializeSQLite(File.DirApp, "skus.db", True)
	#End If
	skus.ExecNonQuery("CREATE TABLE IF NOT EXISTS products ( sku INTEGER, name TEXT, imagename TEXT, vatrate TEXT, price INTEGER, stock integer, custom TEXT)")
	#if B4A
	admin.Initialize("admin")
	#End If
	
	#If B4A
	settingsdb.Initialize(File.DirInternal,"settings.dat")
	#End If
	#If B4J
	settingsdb.Initialize(File.DirApp, "settings.dat")
	#End If
	If settingsdb.GetDefault("shopname", "") = "" Or settingsdb.GetDefault("companyname", "") = "" Then
		xui.MsgboxAsync("Open settings to configure company information or import products", "B-POS setup")
	End If
End Sub

'This event will be called once, before the page becomes visible.
Private Sub B4XPage_Created (Root1 As B4XView)
	Root = Root1
	Root.LoadLayout("Pos")
	B4XPages.SetTitle(Me, "B-POS Checkout")
	
	Settings.Initialize
	B4XPages.AddPage("Settings",Settings)
	Printer1.Initialize(Me, "Printer1")
End Sub

Private Sub loadData
	' load store config
	shopname = settingsdb.GetDefault("shopname", "My B-POS Shop")
	companyname = settingsdb.GetDefault("companyname", "My Company")
	address1 = settingsdb.GetDefault("address1", "123 Acacia Avenue")
	address2 = settingsdb.GetDefault("address2", "London, United Kingdom")
	orderprefix = settingsdb.GetDefault("orderprefix", "")
	vatid = settingsdb.GetDefault("vatid", "")
	currencyname = settingsdb.GetDefault("currencyname", "EUR")
	currencysymbol = settingsdb.GetDefault("currencysymbol", "€")
	vatname = settingsdb.GetDefault("vatname", "VAT")

	Label_Store.Text = shopname
	Total.Text = currencysymbol & "0.00"
	
	' find out the next sale ref
	Dim nextref As Int = saleslog.ExecQuerySingleResult("SELECT IFNULL(MAX(rowid), 0) FROM sales").As(Int) + 1
	
	Label_Ref.Text = orderprefix & NumberFormat2(nextref, 4, 0, 0, False)
	
	' now do products
	Dim productcount As Int
	productcount = skus.ExecQuerySingleResult("SELECT count(*) FROM products")
	CLV_Products.Clear
	
	If productcount = 0 Then
		xui.MsgboxAsync("Creating dummy product list", "B-POS setup")
		createDummyProducts
	End If
	

	
	Dim prodwidth As Int = CLV_Products.sv.Width -10dip
	
	Dim pwidth As Int = prodwidth/5 
	
	Dim c As Int = 0
	
	' panel for a line of items
	'Dim p As Panel
	'p.Initialize("")
	Dim p As B4XView = xui.CreatePanel("")
	
	Dim rs As ResultSet
	rs = skus.ExecQuery("SELECT * FROM products")
	Do While rs.NextRow
		Dim thisproduct As Map
		thisproduct.Initialize
		thisproduct.Put("sku", rs.GetInt("sku"))
		thisproduct.Put("name", rs.GetString("name"))
		thisproduct.Put("imagename", rs.GetString("imagename"))
		thisproduct.Put("vatrate", rs.GetDouble("vatrate"))
		thisproduct.Put("price", rs.GetInt("price"))
		thisproduct.Put("stock", rs.GetInt("stock"))
		If rs.getstring("custom") <> "" Then
			thisproduct.Put("custom", rs.GetString("custom"))
		End If

		Log("Adding product " & thisproduct)
		
		
		' individual item panel
		#If B4J
		Dim ppanel As Pane
		#Else
		Dim ppanel As Panel
		#End If
		ppanel.Initialize("")
		'Dim p As B4XView = xui.CreatePanel("")
		p.AddView(ppanel, c * pwidth, 0, pwidth, 160dip * pwidth / 120)
		ppanel.LoadLayout("Sku")
		
		SKU_Image.Tag = thisproduct
		
		SKU_Image.SetBitmap(xui.LoadBitmapResize(File.DirAssets, "noimage.png", pwidth-10dip, pwidth-10dip, True))
		
		#If B4A
		If thisproduct.Get("imagename") <> "" And File.Exists(File.DirInternal, thisproduct.Get("imagename")) Then
			SKU_Image.SetBitmap(xui.LoadBitmapResize(File.DirInternal, thisproduct.Get("imagename"), pwidth-10dip, pwidth-10dip, True))
		Else
			If thisproduct.Get("imagename") <> "" And File.Exists(File.DirAssets, thisproduct.Get("imagename")) Then
				SKU_Image.SetBitmap(xui.LoadBitmapResize(File.DirAssets, thisproduct.Get("imagename"), pwidth-10dip, pwidth-10dip, True))
			Else
				SKU_Image.SetBitmap(xui.LoadBitmapResize(File.DirAssets, "noimage.png", pwidth-10dip, pwidth-10dip, True))
			End If
		End If
		#End If
		#If B4J
		Dim imagename As String = thisproduct.Get("imagename")
		If imagename <> "" And File.Exists(File.DirApp, thisproduct.Get("imagename")) Then
			SKU_Image.SetBitmap(xui.LoadBitmapResize(File.DirApp, imagename, pwidth-10dip, pwidth-10dip, True))
		Else
			'If imagename <> "" And File.Exists(File.DirAssets, imagename) Then
			If imagename <> "" Then
				SKU_Image.SetBitmap(xui.LoadBitmapResize(File.DirAssets, imagename, pwidth-10dip, pwidth-10dip, True))
			Else
				SKU_Image.SetBitmap(xui.LoadBitmapResize(File.DirAssets, "noimage.png", pwidth-10dip, pwidth-10dip, True))
			End If
		End If
		#End If

		'SKU_Image.SetBitmap(LoadBitmapResize(File.DirAssets,thisproduct.Get("imagename"),pwidth-10dip,pwidth-10dip,True))
		SKU_Name.text = thisproduct.Get("name")
		SKU_Price.Text = NumberFormat2(thisproduct.Get("price")/100, 1, 2, 2, False)
		
		' Show stock levels
		If settingsdb.ContainsKey("showstock") Then
			Dim level As Int = thisproduct.Get("stock")
			If level > -1 Then
				SKU_Stock.Visible = True
				If level > 0 Then
					SKU_Stock.Text = thisproduct.Get("stock")
				Else
					SKU_Stock.Text = ""
				End If
			Else
				SKU_Stock.Visible = False
			End If
		Else
				SKU_Stock.Visible = False
		End If
		c = c + 1 
		
		If c = 5 Then 
			Log("Adding line to prodcuts")
			p.Height = 160dip * pwidth / 120
			CLV_Products.Add(p,CreateMap("product":True))
			c = 0 
			'p.Initialize("")
			Dim p As B4XView = xui.CreatePanel("")
		End If
	Loop
	rs.close
	
	If c > 0  Then
		' add the last line of products
		p.Height = 160dip*pwidth/120
		CLV_Products.Add(p,CreateMap("product":True))
	End If
	
	' check implicit rowid
	Dim rows As Int
	rows = skus.ExecQuerySingleResult("SELECT max(rowid) FROM products")
	Log("Max row id " & rows)
	
	' how many VAT rates are there
	Dim v As Int
	Dim rs As ResultSet = skus.ExecQuery("SELECT DISTINCT vatrate FROM products")
	Do While rs.NextRow
		vatrate = rs.GetString("vatrate")
		v = v + 1
	Loop
	rs.Close

	If v = 1 Then	
		Log("Only one VAT rate found: " & vatrate & "%")
	Else
		vatrate = "multi"
	End If
	
	' are there products with stock control?
	Dim rows As Int = skus.ExecQuerySingleResult("SELECT count(sku) FROM products WHERE stock > -1")
	If rows > 0 Then
		stockcontrol = True
	End If
End Sub

Private Sub createDummyProducts
	For i = 1 To 10
		Dim price As Int = 200 + Rnd(1,20)*100 + i*50
		skus.ExecNonQuery2("INSERT INTO products VALUES (?,?,?,?,?,?,?)", Array As Object(i, "Product " & Chr(64+i), "product"  & NumberFormat(i,2,0) & ".png",20,price,Rnd(3,23),"")) 
	Next	
End Sub

Private Sub B4XPage_Foreground
	'loadData
End Sub

Private Sub B4XPage_Appear
	dialog.Initialize(Root)
	If Printer1.IsInitialized And Printer1.IsConnected Then
		Label_Printer.TextColor = xui.Color_Green
	Else
		Label_Printer.TextColor = xui.Color_Black
	End If
	loadData
End Sub

'Private Sub B4XPage_CloseRequest As ResumableSub
'	Log("Close")
'	Return True
'End Sub

Sub Printer1_Connected (Success As Boolean)
	Log("Connected: " & Success)
	If Success Then
		#If B4J
		Log("Connected successfully")
		xui.MsgboxAsync("Printer", "Connected successfully")
		#Else
		Log("Printer MAC is " & Printer1.RemoteMAC)
		settingsdb.Put("printerid", Printer1.RemoteMAC)
		ToastMessageShow("Connected successfully", False)
		#End If
		Label_Printer.TextColor = xui.Color_Green
		
		If salesref > 0 Then 
			PrintReceipt(salesref)
		End If
	Else
		xui.MsgboxAsync(Printer1.ConnectedErrorMsg, "Error connecting")
		Label_Printer.TextColor = xui.Color_Black
	End If
End Sub

Private Sub Printer1_NewData (Buffer() As Byte)
	Log("New data")
End Sub

Private Sub Printer1_Error
	'ToastMessageShow(LastException.Message, True)
	Log("Error: " & LastException.Message)
	If Printer1.IsConnected = False Then Label_Printer.TextColor = xui.Color_Black
End Sub

Private Sub Printer_Terminated
	#If B4J
	xui.MsgboxAsync("Connection is terminated.", "Printer")
	#Else
	ToastMessageShow("Connection is terminated.", True)
	#End If
	Label_Printer.TextColor = xui.Color_Black
End Sub

Sub PrintReceipt (saleid As Int)
	Dim refund As Boolean = False
	If saleid < 0 Then
		refund = True
		saleid = -1*saleid
	End If

	If Printer1.IsConnected = False Then
		If settingsdb.GetDefault("printerid", "") <> "" Then
			Printer1.ReConnect(settingsdb.Get("printerid"))
		Else
			Printer1.Connect
		End If
	End If

'	If Printer1.IsConnected Then
'		Return
'	End If
	
	Printer1.Reset
	Printer1.codepage = 71 ' western europe
   	#If B4A or B4i
   	Dim bmp As Bitmap
	If File.Exists(File.DirInternal, "logo.jpg") Then
		bmp.Initialize(File.DirInternal, "logo.jpg")
	Else
		bmp.Initialize(File.DirAssets, "logo.jpg")
	End If		
   	#Else If B4J
	Dim img As Image
	If File.Exists(File.DirApp, "logo.jpg") Then
		img.Initialize(File.DirApp, "logo.jpg")
	Else
		img.Initialize(File.DirAssets, "logo.jpg")
	End If
	Dim bmp As B4XBitmap = img
	#End If

	' Convert the RGB image to one with luminance values
	Dim myimage As AnImage = Printer1.ImageToBWIMage(bmp)
		
	' Choose thresholding the image or dithering it to get a black and white bit image
	myimage = Printer1.ThresholdImage(myimage, 128)
		
	' Send the black and white bit image to the printer
	myimage = Printer1.PackImage(myimage)
		
	Printer1.WriteString(CRLF) ' nudge the printer to show the user something is happening
	Printer1.PrintImage(myimage)
	Printer1.leftmargin = 75
	Printer1.WriteString(Printer1.BOLD & shopname & Printer1.NOBOLD & CRLF & CRLF)
		
	Printer1.LeftMargin = 25
	If refund Then
		Printer1.WriteString(Printer1.HIGHWIDE & "Refund " & orderprefix & NumberFormat2(saleid, 4, 0, 0, False) & Printer1.SINGLE & CRLF)
	Else
		Printer1.WriteString(Printer1.HIGHWIDE & "Order " & orderprefix & NumberFormat2(saleid, 4, 0, 0, False) & Printer1.SINGLE & CRLF)
	End If
		
	Dim ts As Long = saleslog.ExecQuerySingleResult2("SELECT ts FROM sales WHERE rowid = ?", Array As String(saleid))
	Dim DF As String = DateTime.DateFormat
	DateTime.DateFormat = "d MMM yyyy HH:mm"
	Dim time As String = DateTime.Date(ts)
	DateTime.DateFormat = DF
	
	Printer1.WriteString(time & CRLF)
	'receipt.Put("timestamp",DateTime.Now) ' so it matches the timestamp exactly
		
	Printer1.LeftMargin = 0
	Printer1.WriteString(CRLF & CRLF)
	
	'Printer1.TabPositions = Array As Int()
	Dim tabs() As Int = Array As Int(3, 24)
	'Dim tabs() As Int = Array As Int(3, 6, 9, 12)
	Printer1.TabPositions = tabs
	
	Dim totalvat As Float = 0

	Dim rs As ResultSet = saleslog.ExecQuery2("SELECT * FROM lineitems WHERE saleid = ?", Array As String(saleid))
	Do While rs.NextRow
		Dim l_name As String = rs.GetString("item")
		Dim l_qty As Int = rs.GetInt("qty")
		Dim l_price As Int = rs.GetInt("price")
			
		If discount_percent > 0 Then
			l_price = l_price * ( 1 - discount_percent)
		End If
			
		Dim l_total As Int = rs.GetInt("total")
		Dim l_vat As Float = rs.GetDouble("vatrate") / 100
			
		If refund Then
			' swap negative numbers
			l_qty = -1 * l_qty
			l_price = -1 * l_price
			l_total = -1 * l_total
		End If
			
		Printer1.CharacterFont = 0
			
		' If a product name contains a semicolon, we put a line break in
		If l_name.Contains(";") Then
			Printer1.WriteString(l_name.SubString2(0, l_name.IndexOf(";")) & Printer1.HT & Printer1.HT & NumberFormat2(l_total / 100, 1, 2, 2, False) & CRLF)
			Printer1.CharacterFont = 1
			Printer1.WriteString(Printer1.HT & l_name.SubString(l_name.IndexOf(";")+2) & CRLF)
			Printer1.CharacterFont = 0
		Else
			Printer1.WriteString(l_name & Printer1.HT & Printer1.HT & NumberFormat2(l_total / 100, 1, 2, 2, False) & CRLF)
		End If
			
		Dim indent As String = Printer1.HT
		If l_qty > 1 Then
			Printer1.CharacterFont = 1
			Printer1.WriteString(Printer1.HT & l_qty & " @ " & NumberFormat2(l_price/100, 1, 2, 2, False))
			indent = ", "
		End If
		If vatid <> ""  Then
			Dim goods As Float = l_total / (1 +l_vat)
			Dim vatcharged As Float = l_total - goods
			totalvat = totalvat + vatcharged
			If vatrate = "multi" Then
				' list VAT on each item
				Printer1.CharacterFont = 1
				Printer1.WriteString(indent & "inc " & rs.getstring("vatrate") & "% "& vatname)
			End If
		End If
		If  l_qty > 1 Or ( vatid <> "" And vatrate = "multi") Then
			Printer1.WriteString(CRLF)
		End If
	Loop
	rs.close
		
	If discount_percent > 0 Then
		Printer1.WriteString(CRLF & "Discount: " & NumberFormat2(discount_percent * 100, 1, 2, 0, False) & "%, " & currencyname & " " & NumberFormat2(discount_amount / 100, 1, 2, 2, False) & CRLF)
	End If
		
	If vatid <> "" Then
		Printer1.CharacterFont = 1
		' if all vat rates are the same, just list aggregate
		Dim vatinfo As String = ""
		If vatrate <> "multi" Then vatinfo = "@ " & vatrate & "%"
		Printer1.WriteString(CRLF & vatname & " " & vatinfo & Printer1.HT & Printer1.HT & NumberFormat2(totalvat / 100, 1, 2, 2, False))
		Printer1.WriteString(CRLF & "Total goods" & Printer1.HT & Printer1.HT & NumberFormat2((sale_amount-totalvat)/100,1,2,2,False) & CRLF)
		Printer1.CharacterFont = 0
		Printer1.WriteString(CRLF & CRLF & Printer1.BOLD & "Total " & currencyname & " inc " & vatname & ":" & Printer1.HT & NumberFormat2(sale_amount / 100, 1, 2, 2, True) & Printer1.NOBOLD & CRLF)
	Else
		Printer1.CharacterFont = 0
		Printer1.WriteString(CRLF& CRLF & Printer1.BOLD & "Total "& currencyname & " :" & Printer1.HT & NumberFormat2(sale_amount / 100, 1, 2, 2, True) & Printer1.NOBOLD & CRLF)
	End If
		
	Printer1.CharacterFont = 1
	Printer1.WriteString(companyname & CRLF & address1 & CRLF & address2 & CRLF)
	If vatid <> "" Then
		Printer1.WriteString(vatname & " id: " & vatid & CRLF)
	End If
	'Printer1.PrintAndFeedPaper(120)
		
	' allow the printer to be shared
	'Printer1.DisConnect
	salesref = 0
End Sub

Public Sub printLog
	' print out a log of transactions
	If saleslog.IsInitialized And Printer1.IsConnected Then
		
		Printer1.Reset
		Printer1.CharacterFont = 1
		Printer1.WriteString(Printer1.HIGHWIDE & "Sales log" & Printer1.SINGLE & CRLF)
		
		Dim cash As Int= 0
		Dim card As Int = 0
		
		Dim tabs() As Int = Array As Int(18, 25)
		
		Printer1.TabPositions = tabs
		
		Dim rs As ResultSet = saleslog.execquery("SELECT ts, ref, amount FROM logfile ORDER BY ts")
		Do While rs.NextRow
			Dim ts As Long = rs.GetLong("ts")
			Dim ref As String = rs.GetString("ref")
			Dim amount As Int = rs.GetString("amount")
			
			Dim DF As String = DateTime.DateFormat
			DateTime.DateFormat = "yyyy-MM-dd HH:mm"
			Dim time As String = DateTime.Date(ts)
			DateTime.DateFormat = DF

			If ref.StartsWith("cash") Then
				cash = cash + amount
				ref = "cash"
			Else
				card = card + amount
			End If
			Printer1.WriteString(time & Printer1.HT & NumberFormat2(amount / 100, 1, 2, 2, False) & Printer1.HT & ref & CRLF)
		Loop
		rs.close
		
'		Printer1.WriteString(Printer1.BOLD & "Total card = " & NumberFormat2(card/100,1,2,2,False) & " inc VAT @ " & vatrate &"%"   & Printer1.NOBOLD & CRLF)
		'Printer1.WriteString(Printer1.BOLD & "Total cash = " & NumberFormat2(cash/100,1,2,2,False) & Printer1.NOBOLD & CRLF)
		
		Printer1.PrintAndFeedPaper(40)
		
		Printer1.TabPositions = Array As Int(8, 15)
		Printer1.WriteString(Printer1.BOLD & "SKU" & Printer1.HT & "QTY" & Printer1.NOBOLD & CRLF)
		
		Dim rs As ResultSet =  saleslog.execquery("SELECT sku, qty, item FROM quantities ORDER BY sku")
		Do While rs.NextRow
			Dim sku As Int = rs.GetInt("sku")
			Dim qty As Int = rs.GetInt("qty")
			Dim item As String = rs.GetString("item")
			Printer1.WriteString(sku & Printer1.HT & qty & Printer1.HT & item  & CRLF)
		Loop
		rs.close
		'Printer1.PrintAndFeedPaper(120)
	Else
		#If B4J
		xui.MsgboxAsync("Check printer is connected", "Printer")
		#Else
		ToastMessageShow("Check printer is connected", False)
		#End If
	End If
End Sub

#If B4J
Private Sub Label_Settings_MouseClicked (EventData As MouseEvent)
#Else
Private Sub Label_Settings_Click
#End If
	If settingsdb.ContainsKey("passcode") Then
		Dim pin As B4XInputTemplate
		pin.Initialize
		pin.lblTitle.Text = "Enter settings passcode"
		
		Wait For( dialog.showTemplate(pin, "OK", "", "Cancel")) Complete (Result As Int)
		If Result = xui.DialogResponse_Positive And pin.Text = settingsdb.Get("passcode") Then 
			B4XPages.ShowPage("settings")
		Else
			xui.MsgboxAsync("You must enter the passcode to access settings", "Passcode required")
		End If
	Else
		B4XPages.ShowPage("settings")
	End If
	
End Sub

#If B4A
Private Sub StartBluetooth
	If admin.IsEnabled = False Then
		Wait For (EnableBluetooth) Complete (Success As Boolean)
		If Success = False Then
			ToastMessageShow("Failed to enable bluetooth", True)
		End If
	End If
	BluetoothState = admin.IsEnabled
End Sub

Private Sub EnableBluetooth As ResumableSub
	ToastMessageShow("Enabling Bluetooth adapter...", False)
	Dim p As Phone
	If p.SdkVersion >= 31 Then
		rp.CheckAndRequest("android.permission.BLUETOOTH_CONNECT")
		Wait For B4XPage_PermissionResult (Permission As String, Result As Boolean)
		If Result = False Then Return False
		If p.SdkVersion >= 33 Then
			Dim in As Intent
			in.Initialize("android.bluetooth.adapter.action.REQUEST_ENABLE", "")
			StartActivityForResult(in)
			Wait For ion_Event (MethodName As String, Args() As Object)
			Return admin.IsEnabled
		End If
	End If
	Return admin.Enable
End Sub

Private Sub Label_Printer_Click
	StartBluetooth
	Dim phone As Phone
	rp.CheckAndRequest(rp.PERMISSION_ACCESS_FINE_LOCATION)
	Wait For B4XPage_PermissionResult (Permission As String, Result As Boolean)
	If Result = False And rp.Check(rp.PERMISSION_ACCESS_COARSE_LOCATION) = False Then
		ToastMessageShow("No permission...", False)
		Return
	End If
	If phone.SdkVersion >= 31 Then
		For Each Permission As String In Array("android.permission.BLUETOOTH_SCAN", "android.permission.BLUETOOTH_CONNECT")
			rp.CheckAndRequest(Permission)
			Wait For B4XPage_PermissionResult (Permission As String, Result As Boolean)
			If Result = False Then
				ToastMessageShow("No permission...", False)
				Return
			End If
		Next
	End If
End Sub

Private Sub label_Printer_LongClick
	handlePrinter
End Sub

Private Sub handlePrinter	
	If Printer1.IsBluetoothOn = False Then
		xui.MsgboxAsync("Please enable Bluetooth and connect a Bluetooth printer", "Bluetooth error")
	Else If Printer1.IsConnected = False Then
		Log("Trying to connect")
		If settingsdb.GetDefault("printerid", "") <> "" Then
			Log("Reusing printer id")
			Printer1.ReConnect(settingsdb.Get("printerid"))
		Else
			Log("Calling Connect")
			Printer1.Connect
		End If
	Else
		Printer1.DisConnect
		Label_Printer.TextColor = xui.Color_Green
	End If
End Sub
#End If

#If B4J
Private Sub Label_Printer_MouseClicked (EventData As MouseEvent)
	'If EventData.SecondaryButtonPressed Then
		handlePrinter
	'	'Return
	'Else
	'	Log("Init Printer")
	'End If
End Sub

Private Sub handlePrinter
	If Printer1.IsConnected = False Then
		Log("Trying to connect")
		If settingsdb.GetDefault("printerid", "") <> "" Then
			Log("Reusing printer id")
			Printer1.ReConnect(settingsdb.Get("printerid"))
		Else
			Log("Calling Connect")
			Printer1.Connect
			If Printer1.IsConnected Then
				Label_Printer.TextColor = xui.Color_Green
			End If
		End If
	Else
		Printer1.DisConnect
		Label_Printer.TextColor = xui.Color_Black
	End If
End Sub
#End If

Private Sub Button_Confirm_Click
	If CLV_Sale.Size > 0 Then
		Dim sf As Object = xui.Msgbox2Async("Does the customer want a printed receipt? If the card transaction failed, press Cancel", "Print receipt", "Yes", "Cancel", "No", Null)
		Wait For (sf) Msgbox_Result (Result As Int)
		If Result <> xui.DialogResponse_Cancel Then
			' log the sale to the database
			Dim ts As Long = DateTime.now
			Dim skucount As Int
			If discount_percent > 0 Then
				skucount = CLV_Sale.Size-1
			Else
				skucount = CLV_Sale.Size
			End If
			saleslog.ExecNonQuery2("INSERT INTO sales VALUES ( ?, ?, 0, 0, ?, ?, ?)", _
			Array As Object(ts, sale_amount, skucount, orderprefix, NumberFormat2(discount_percent*100, 1, 2, 0, False)))
			
			salesref = saleslog.ExecQuerySingleResult("SELECT MAX(rowid) FROM sales")
			Log("Sales ref is " & salesref)
			
			' log the line items
			Dim itemcount As Int = 0
			For i = 0 To CLV_Sale.Size -1
				Dim item As Map = CLV_Sale.GetValue(i)
				
				If item.Get("sku") <> "discount" Then
					Dim price As Int = item.Get("price")
					If discount_percent > 0 Then
						price = price * ( 1-discount_percent)
					End If
					Dim vat As String
					vat = skus.ExecQuerySingleResult2("SELECT vatrate FROM products WHERE sku = ?",Array As String(item.Get("sku")))
					saleslog.ExecNonQuery2("INSERT INTO lineitems VALUES ( ?, ?, ?, ?, ?, ?, ?)",Array As Object(salesref,item.Get("sku"),item.Get("qty"),item.Get("name"),price,vat,item.Get("qty")*price))
					
					If stockcontrol Then
						' update levels for items with stock control
						Dim level As Int
						level = skus.ExecQuerySingleResult2("SELECT stock FROM products WHERE sku = ?",Array As String(item.Get("sku")))
						If level > -1 Then
							level = Max(0,level - item.Get("qty"))
							skus.ExecNonQuery2("UPDATE products SET stock = ? WHERE sku = ?",Array As Object(level,item.Get("sku")))
						End If
					End If
					
					itemcount = itemcount + item.Get("qty")
				End If
			Next
			
			' update the sales log with the itemcount
			saleslog.ExecNonQuery2("UPDATE sales SET items = ? WHERE rowid = ?",Array As Object(itemcount,salesref))
			' reset the display
			CLV_Sale.Clear
			
			' this ensures custom info etc is reset
			loadData
			
			' postback data
			If settingsdb.Getdefault("postback", "") = "transaction" Then postTransaction(salesref)
			If Result = xui.DialogResponse_Positive Then
				PrintReceipt(salesref)
			End If
		End If
	End If
End Sub

Private Sub Button_Cancel_Click
	If CLV_Sale.Size > 0 Then
		Dim sf As Object = xui.Msgbox2Async("Do you want to clear the current sale?", "Clear sale", "Yes", "", "No",  Null)
		Wait For (sf) Msgbox_Result (Result As Int)
		If Result = xui.DialogResponse_Positive Then
			CLV_Sale.Clear
			Total.Text = currencysymbol & "0.00"
		End If
	End If
End Sub

Private Sub Button_Cancel_LongClick
	If CLV_Sale.Size > 0 Then
		Dim sf As Object = xui.Msgbox2Async("Register refund. Have the products been returned?", "Issue Refund", "Yes", "Cancel", "No", Null)
		Wait For (sf) Msgbox_Result (Result As Int)
		If Result = xui.DialogResponse_Positive Then
			Log("Deleted!!!")
		End If
		
		If Result = xui.DialogResponse_Positive Then
			processRefund(True)
		Else if Result = xui.DialogResponse_Negative Then
			processRefund(False)
		End If
	End If
End Sub

Private Sub SKU_Image_LongClick
	' allow a long click on an item to reset stock level
	Dim s As B4XView = Sender
	Dim product As Map = s.Tag
		
	If settingsdb.ContainsKey("passcode") Then
		Dim pin As B4XInputTemplate
		pin.Initialize
		pin.lblTitle.Text = "Enter passcode to update stock"
		
		Wait For( dialog.showTemplate(pin,"OK", "", "Cancel")) Complete (Result As Int)
		If Result = xui.DialogResponse_Positive And pin.Text = settingsdb.Get("passcode") Then
			setStockLevel(product)
		Else
			xui.MsgboxAsync("You must enter the passcode to update stock", "Passcode required")
		End If
	Else
		setStockLevel(product)
	End If
End Sub

#If B4J
Private Sub SKU_Image_MouseClicked (EventData As MouseEvent)
	If EventData.SecondaryButtonPressed Then
		SKU_Image_LongClick
		Return
	End If
#Else
Private Sub SKU_Image_Click
#End If
	Dim s As B4XView = Sender
	Dim product As Map = s.Tag
	Dim stock As Int = product.Get("stock")
	
	If stock = 0 Then
		xui.MsgboxAsync(product.Get("name") & " may be out of stock. Check before completing sale.", "Stock level warning")
	End If

	' This code updates the bullets on stock items, but is not used at present
	' Because the varying refund cases, eg refund/keep item, refund/replace item
	' are not yet supported

'		If stock > -1 Then 
'			stock = stock -1
'			product.Put("stock",NumberFormat2(stock,1,0,0,False))
'			s.Tag = product
'			
'			Dim p As Panel = s.Parent
'			For Each v As B4XView In p.GetAllViewsRecursive
'				If v.Tag <> Null And v.Tag = "stock" Then
'					v.text = stock
'					Exit
'				End If
'			Next
'		End If
	
	
	Log("Selected " & product.Get("name"))
	
	' Allow custom information for some items
	If product.ContainsKey("custom") And product.Get("custom") <> "" Then
		Dim custom As B4XInputTemplate
		custom.Initialize
		custom.lblTitle.Text = "Enter " & product.Get("custom") & " for " & product.Get("name")
		
		Wait For( dialog.showTemplate(custom,"OK", "", "Cancel")) Complete (Result As Int)
		If Result = xui.DialogResponse_Positive Then
			product.Put("name", product.Get("name") & "; " & product.Get("custom") & " = " & custom.Text)
		End If
	End If
	
	Dim found As Boolean = False
	
	Dim lwidth As Int = CLV_Sale.sv.Width -10dip
	
	' add this sku to the list of products, or update the quantity
	For i = 0 To CLV_Sale.Size -1
		Dim item As Map = CLV_Sale.GetValue(i)
		
		If item.Get("sku") = product.Get("sku") Then
			found = True
			Log("Updating item " & i)
			item.Put("qty", item.Get("qty")+1)

			Dim np As B4XView = xui.CreatePanel("")
			np.Width = lwidth
			np.Height = 35dip
			
			np.LoadLayout("Lineitem")
			
			Label_Item.text = product.Get("name")
			Label_Quantity.text = NumberFormat( item.Get("qty"), 1, 0)
			Label_Cost.text = NumberFormat2(product.Get("price") / 100, 1, 2, 2, False)
			Label_Remove.Tag = item			
			CLV_Sale.ReplaceAt(i, np, 35dip, item)			
		End If
	Next
	
	If Not(found) Then
		' add a new line item
		Dim np As B4XView = xui.CreatePanel("")
		np.Width = lwidth
		np.Height = 35dip
		np.LoadLayout("Lineitem")
		
		Dim item As Map = CreateMap( _
		"sku": product.Get("sku"), _
		"name": product.Get("name"), _
		"qty": 1, _
		"price": product.Get("price"))
			
		Label_Item.text = product.Get("name")
		Label_Quantity.text = NumberFormat(item.Get("qty"), 1, 0)
		Label_Cost.text = NumberFormat2(product.Get("price") / 100, 1, 2, 2, False)
		Label_Remove.Tag = item
		
		CLV_Sale.Add(np, item)
	End If
	
	' now update the total amount
	calculate_total
End Sub

#If B4J
Private Sub Label_Remove_MouseClicked (EventData As MouseEvent)
#Else
Private Sub Label_Remove_Click
#End If
	Dim s As B4XView = Sender
	
	Dim item As Map = s.tag
	
	If item.Get("sku") = "discount" Then
		Dim sf As Object = xui.Msgbox2Async("Do you want to remove this discount?", "Cancel discount", "Yes", "", "No", Null)
		Wait For (sf) Msgbox_Result (Result As Int)
		If Result = xui.DialogResponse_Positive Then
			For i = 0 To CLV_Sale.size -1
				Dim p As Map = CLV_Sale.GetValue(i)
				Log(p)
				If p.Get("sku") = "discount" Then
					CLV_Sale.RemoveAt(i)
					Exit
				End If
			Next
		End If
	Else
		Dim sf As Object = xui.Msgbox2Async("Do you want to remove this item from the basket entirely, or just one?", "Remove " & item.Get("name"), "All", "Cancel", "Just One", Null)
		Wait For (sf) Msgbox_Result (Result As Int)
		If Result = xui.DialogResponse_Positive Then
			For i = 0 To CLV_Sale.size -1
				Dim p As Map = CLV_Sale.GetValue(i)
				If p.Get("sku") = item.Get("sku") Then
					CLV_Sale.RemoveAt(i)
					Exit
				End If
			Next
		Else If Result = xui.DialogResponse_Negative Then
			For i = 0 To CLV_Sale.Size -1
				Dim p As Map = CLV_Sale.GetValue(i)
				If p.Get("sku") = item.Get("sku") Then
				
					If 1 = p.Get("qty") Then 
						CLV_Sale.RemoveAt(i)
						Exit
					Else
						Dim lwidth As Int = CLV_Sale.sv.Width -10dip
						
						item.Put("qty", item.Get("qty")-1)

						Dim np As B4XView = xui.CreatePanel("")
						np.Width = lwidth
						np.Height = 30dip
					
						np.LoadLayout("Lineitem")
					
						Label_Item.text = item.Get("name")
						Label_Quantity.text = NumberFormat( item.Get("qty"),1,0)
						Label_Cost.text = NumberFormat2(item.Get("price")/100,1,2,2,False)
						Label_Remove.Tag = item
					
						CLV_Sale.ReplaceAt(i,np,30dip,item)
						Exit
					End If
				End If
			Next
		End If
	End If
	
	calculate_total
End Sub

Private Sub calculate_total
	Dim sale_total As Int = 0
	discount_amount = 0
	discount_percent = 0
	For i = 0 To CLV_Sale.Size -1
		Dim item As Map = CLV_Sale.GetValue(i)
		If item.Get("sku") = "discount" Then
			' handle a discount
			discount_percent = item.Get("percent")/100
		Else
			sale_total = sale_total+ (item.Get("qty")*item.Get("price"))
		End If
	Next
	
	sale_amount = sale_total
	
	If discount_percent > 0 Then
		discount_amount = discount_percent*sale_amount
		sale_amount = sale_amount - discount_amount
	End If
	
	Total.Text = currencysymbol & NumberFormat2(sale_amount/100,1,2,2,True)
End Sub

Private Sub processRefund (returns As Boolean)
	' mark items as refunded, issue a receipt if necessary
	
	Dim ts As Long = DateTime.now
	Dim skucount As Int
	If discount_percent > 0 Then
		skucount = CLV_Sale.Size-1
	Else
		skucount = CLV_Sale.Size
	End If
	
	Dim refundref As Int  =	saleslog.ExecQuerySingleResult("SELECT MAX(rowid) FROM sales")
	Log("Refund ref is " & refundref)
			
	' log the line items
	Dim itemcount As Int = 0 
	For i = 0 To CLV_Sale.Size -1
		Dim item As Map = CLV_Sale.GetValue(i)
		
		If item.Get("sku") <> "discount" Then 
			Dim price As Int = item.Get("price")
			If discount_percent > 0 Then
				price = price*(1-discount_percent)
			End If
				
			Dim vat As String
			vat = skus.ExecQuerySingleResult2("SELECT vatrate FROM products WHERE sku = ?",Array As String(item.Get("sku")))
			saleslog.ExecNonQuery2("INSERT INTO lineitems VALUES ( ?, ?, ?, ?, ?, ?, ?)",Array As Object(refundref,item.Get("sku"),-1*item.Get("qty"),item.Get("name"),-1*price,vat,-1*item.Get("qty")*price))
			
			If returns And stockcontrol Then
				Dim level As Int
				level = skus.ExecQuerySingleResult2("SELECT stock FROM products WHERE sku = ?",Array As String(item.Get("sku")))
				
				If level > -1 Then
					skus.ExecNonQuery2("UPDATE products SET stock = ? WHERE sku = ?",Array As Object(level+item.Get("qty"),item.Get("sku")))
				End If
						
			End If
			itemcount = itemcount + item.Get("qty")
		End If
	Next
	
	saleslog.ExecNonQuery2("INSERT INTO sales VALUES ( ?, ?, ?, 0, ?, ?, ?)",Array As Object(ts,-1*sale_amount,itemcount,skucount,orderprefix,NumberFormat2(discount_percent*100,1,2,0,False)))
	
	Dim sf As Object = xui.Msgbox2Async("Do you want to print a receipt for this refund?", "Print receipt", "Yes", "", "No", Null)
	Wait For (sf) Msgbox_Result (Result As Int)
	If Result = xui.DialogResponse_Positive Then
		PrintReceipt(-1 * refundref)
	End If
	
	' postback data
	If settingsdb.Getdefault("postback", "") = "transaction" Then postTransaction(refundref)
	
	' reset the display
	CLV_Sale.Clear
	
	If returns And stockcontrol Then 
		loadData
	Else
		Total.Text = currencysymbol & "0.00"
	End If
End Sub

#If B4A
Private Sub StartActivityForResult(i As Intent)
	Dim jo As JavaObject = GetBA
	ion = jo.CreateEvent("anywheresoftware.b4a.IOnActivityResult", "ion", Null)
	jo.RunMethod("startActivityForResult", Array As Object(ion, i))
End Sub

Sub GetBA As Object
	Dim jo As JavaObject = Me
	Return jo.RunMethod("getBA", Null)
End Sub

Private Sub Admin_StateChanged (NewState As Int, OldState As Int)
	Log("state changed: " & NewState)
	BluetoothState = NewState = admin.STATE_ON
End Sub
#End If

Public Sub postTransaction ( saleid As Int ) As ResumableSub
	 Dim target As String = settingsdb.Getdefault("postbackurl", "")
	 Dim posted As Boolean
	 If target <> "" Then 
		If Not(target.StartsWith("https://")) Then target = "https://" & target
			
		Dim rows As Int
		Dim rs As ResultSet = saleslog.ExecQuery2("SELECT * FROM sales WHERE rowid = ? AND posted = 0", Array As String(saleid))
		Do While rs.NextRow
			Dim report As Map
			report.Initialize
			report.Put("salesref", rs.GetString("prefix") & NumberFormat2(saleid, 4, 0, 0, False))
		
			Dim timestamp As Long = rs.GetLong("ts")
			report.Put("timestamp", NumberFormat2(timestamp / 1000, 1, 0, 0, False)) ' convert from milliseconds to seconds

			Dim DF As String = DateTime.DateFormat
			DateTime.DateFormat = "d MMM yyyy HH:mm"
			report.Put("date", DateTime.Date(timestamp))
			DateTime.DateFormat = DF
			report.Put("currency",settingsdb.GetDefault("currencyname", "EUR"))
			report.Put("total", NumberFormat2(rs.GetInt("amount") / 100, 1, 2, 2, False))
			report.Put("items", rs.GetInt("items"))
			report.Put("skus", rs.GetInt("skucount"))
			report.Put("discount", rs.GetString("discount"))
			
			Dim lineitems As List
			lineitems.Initialize

			' now make the lineitems
			Dim line As ResultSet = saleslog.ExecQuery2("SELECT * FROM lineitems WHERE saleid = ?", Array As String(saleid))
			Do While line.NextRow
				lineitems.Add(CreateMap( _
				"sku": line.GetInt("sku"), _
				"quantity": line.GetInt("qty"), _
				"description": line.GetString("item"), _
				"price": NumberFormat2(line.GetInt("price") / 100, 1, 2, 2, False), _
				"vatrate": line.GetString("vatrate"), _
				"goods": NumberFormat2(line.GetInt("total") / 100 / (1 + line.GetString("vatrate") / 100), 1, 2, 2, False), _
				"total": NumberFormat2(line.GetInt("total") / 100, 1, 2, 2, False)))				
			Loop
			line.Close
			
			report.Put("lineitems", lineitems)
			
			If settingsdb.GetDefault("postbacksecret", "") <> "" Then
				report.Put("secret", settingsdb.Get("postbacksecret"))
			End If
						
			Dim j As HttpJob
			j.Initialize("", Me)
			Dim json As JSONGenerator
			json.Initialize(report)
			j.PostString(target, json.ToString)
			j.GetRequest.SetContentType("application/json")
			Wait For (j) JobDone(j As HttpJob)
			If j.Success Then
				' mark as posted
				posted = True
				Log("JSON posted to callback URL")
				saleslog.ExecNonQuery2("UPDATE sales SET posted = ? WHERE rowid = ?", Array As Object(DateTime.Now, saleid))
			Else
				Log(j.ErrorMessage)
				xui.MsgboxAsync("Unable to post transaction to remote server. WIll try later", "Communication error")
			End If
			j.Release
			rows = rows + 1
		Loop
		rs.Close
		
		If rows <> 1 Then
			Log("Sales with id " & salesref & " does not exist or has already been posted")
		End If
	End If
	Return posted
End Sub

#If B4J
Private Sub Label_Discount_MouseClicked (EventData As MouseEvent)
#Else
Private Sub label_Discount_Click
#End If
	If settingsdb.ContainsKey("discount") Then 
		applyDiscount(settingsdb.Get("discount"))
	Else
		label_Discount_LongClick
	End If
End Sub

Private Sub label_Discount_LongClick
	Dim discount As B4XInputTemplate
	discount.Initialize
	
	discount.lblTitle.Text = "Enter discount percentage to apply"
	discount.ConfigureForNumbers(True,False)
	
	Wait For( dialog.showTemplate(discount,"OK", "", "Cancel")) Complete (Result As Int)
	If Result = xui.DialogResponse_Positive Then	
		applyDiscount(discount.Text)
	End If
End Sub

Private Sub applyDiscount ( percent As String )
	Dim lwidth As Int = CLV_Sale.sv.Width -10dip

	Dim np As B4XView = xui.CreatePanel("")
	np.Width = lwidth
	np.Height = 35dip
	np.LoadLayout("Lineitem")
			
	Dim item As Map = CreateMap("sku":"discount", "name":"Discount", "percent":percent)
				
	Label_Item.text = "Discount"
	Label_Quantity.text = ""
	Label_Cost.text =percent & "%"
	Label_Remove.Tag = item
	Dim found As Boolean = False
		
	For i = 0 To CLV_Sale.Size -1
		Dim p As Map = CLV_Sale.GetValue(i)
			
		If p.Get("sku") = "discount" Then
			found = True
			Log("Updating item " & i)
				
			CLV_Sale.ReplaceAt(i,np,35dip,item)
				
		End If
	Next
	If Not(found) Then
		CLV_Sale.Add(np,item)
	End If
	
	calculate_total
End Sub

Private Sub setStockLevel (product As Map)
	Dim stock As B4XInputTemplate
	stock.Initialize
	stock.lblTitle.Text = "Enter new stock level (-1 to disable)"
	stock.ConfigureForNumbers(False, True)
	Wait For( dialog.showTemplate(stock, "OK", "", "Cancel")) Complete (Result As Int)
	If Result = xui.DialogResponse_Positive Then
		Dim newstock As Int = stock.Text
		skus.ExecNonQuery2("UPDATE products SET stock = ? WHERE sku = ?", Array As Object(newstock, product.Get("sku")))
		loadData
	End If
End Sub