B4A=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=9.01
@EndOfDesignText@
Sub Class_Globals
	' 1.0	Initial version
	' 2.0	Added FeedPaper, changed many WriteString(.." &  Chr(number)) instances to WriteBytes(params)
	' 		This is to avoid Unicode code page transformations on some numbers > 32
	'			Added PrintAndFeedPaper, setRelativePrintPosn,
	'			Added user defined characters, DefineCustomCharacter, DeleteCustomCharacter and setUseCustomCharacters
	'			Addedhelper methods CreateCustomCharacter, CreateLine, CreateBox and CreateCircle
	' 2.1	Update by Nigel to add ReConnect and store mac address
	' 3.0	Updated by Aeric for B4J
	
	Private Version As Double = 3.0 ' Printer class version	 'ignore

	Type AnImage (Width As Int, Height As Int, Data() As Byte)
	
	Private EventName As String 'ignore
	Private CallBack As Object 'ignore

	Private Serial1 As Serial
	Private Astream As AsyncStreams
	Private Connected As Boolean
	Private ConnectedError As String
	
	Dim ESC As String = Chr(27)
	Dim FS As String = Chr(28)	'ignore
	Dim GS As String = Chr(29)
	
	'Bold and underline don't work well in reversed text
	Dim UNREVERSE As String  = GS & "B" & Chr(0)
	Dim REVERSE As String = GS & "B" & Chr(1)	'ignore
	
	' Character orientation. Print upside down from right margin
	Dim UNINVERT As String = ESC & "{0"
	Dim INVERT As String = ESC & "{1"	'ignore
	
	' Character rotation clockwise. Not much use without also reversing the printed character sequence
	Dim UNROTATE As String = ESC & "V0"
	Dim ROTATE As String = ESC & "V1"	'ignore
	
	' Horizontal tab
	Dim HT As String = Chr(9)
	
	' Character underline
	Dim ULINE0 As String = ESC & "-0"
	Dim ULINE1 As String = ESC & "-1"	'ignore
	Dim ULINE2 As String = ESC & "-2"	'ignore
	
	' Character emphasis
	Dim BOLD As String = ESC & "E1"
	Dim NOBOLD As String = ESC & "E0"
	
	' Character height and width
	Dim SINGLE As String = GS & "!" & Chr(0x00)
	Dim HIGH As String = GS & "!" & Chr(0x01)	'ignore
	Dim WIDE As String = GS & "!" & Chr(0x10)
	Dim HIGHWIDE As String = GS & "!" & Chr(0x11)
	
	' Default settings
	Private LEFTJUSTIFY As String = ESC & "a0"
	Private LINEDEFAULT As String = ESC & "2"
	Private LINSET0 As String = ESC & "$" & Chr(0x0) & Chr(0x0)
	Private LMARGIN0 As String = GS & "L" & Chr(0x0) & Chr(0x0)
	Private WIDTH0 As String = GS & "W" & Chr(0xff) & Chr(0xff)
	Private CHARSPACING0 As String = ESC & " " & Chr(0)
	Private CHARFONT0 As String = ESC & "M" & Chr(0)
	Dim DEFAULTS As String =  CHARSPACING0 & CHARFONT0 & LMARGIN0 & WIDTH0 & LINSET0 & LINEDEFAULT & LEFTJUSTIFY _
		& UNINVERT & UNROTATE & UNREVERSE & NOBOLD & ULINE0		'ignore
	#If B4A
	Public RemoteMAC As String
	#Else If B4J
	Public ComPort As String
	#End If
End Sub

'**********
'PUBLIC API
'**********

'Initialize the object with the parent and event name
Public Sub Initialize (vCallback As Object, vEventName As String)
	EventName = vEventName
	CallBack = vCallback
	Serial1.Initialize("Serial1")
	Connected = False
	ConnectedError = ""
End Sub

#If B4A
Public Sub ConnectByName (devicename As String) As Boolean
	Dim PairedDevices As Map = GetPairedDevices
	For i = 0 To PairedDevices.Size -1
		If PairedDevices.GetKeyAt(i) = devicename Then
			Log("Attempting to reconnect to " & devicename)
			Serial1.Connect(PairedDevices.Get(devicename))
			Return True
		End If
	Next
	Return False
End Sub
#End If

' Disconnect the printer
Public Sub DisConnect
	#If B4A
	Serial1.Disconnect
	#Else If B4J
	Serial1.Close
	Astream.Close
	#End If
	Connected = False
End Sub

#If B4A
' Connect to a specific printer via MAC address
Public Sub ReConnect (mac As String) As Boolean
	Log("Connecting to printer " & mac)
	Serial1.Connect(mac)
	Return True
End Sub

' Returns whether Bluetooth is on or off
Public Sub IsBluetoothOn As Boolean
	Return Serial1.IsEnabled
End Sub

Public Sub ConnectedMAC As String
	Return Serial1.Address
End Sub

Public Sub ConnectedDevice As String
	Return Serial1.Name
End Sub
#Else If B4J
' Connect to a specific printer via COM port
Public Sub ReConnect (port As String) As Boolean
	Log("Connecting to printer port " & port)
	Serial1.Open(port)
	Return True
End Sub
#End If

' Returns whether a printer is connected or not
Public Sub IsConnected As Boolean
	Return Connected
End Sub

' Returns any error raised by the last attempt to connect a printer
Public Sub ConnectedErrorMsg As String
	Return ConnectedError
End Sub

' Ask the user to connect to a printer and return whether she tried or not
' If True then a subsequent Connected event will indicate success or failure
Public Sub Connect
	#If B4A
	Dim PairedDevices As Map = GetPairedDevices
	Dim l As List
	l.Initialize
	For Each device As String In PairedDevices.Keys
		l.Add(device)
	Next
	InputListAsync(l, "Choose a printer", -1, True)
	Wait for InputList_Result (Res As Int)
	If Res <> DialogResponse.CANCEL Then
		Serial1.Connect(PairedDevices.Get(l.Get(Res))) 'convert the name to mac address
		RemoteMAC = PairedDevices.Get(l.Get(Res))
		Log("Device MAC is " & RemoteMAC)
	'Return True
	End If
	'Return False
	#Else If B4J
	Dim PairedDevices As List = GetComPorts
	For Each port In PairedDevices
		Log(port)
	Next
	ComPort = PairedDevices.Get(6) ' paired virtual COM port (check device manager)
	Log("Connecting to COM port " & ComPort)
	Try
		Serial1.Open(ComPort)
		Astream.InitializePrefix(Serial1.GetInputStream, True, Serial1.GetOutputStream, "astream")
		Connected = True
	Catch
		Log(LastException)
		ConnectedError = LastException.Message
		DisConnect
	End Try
	#End If
End Sub

#If B4A
Public Sub GetPairedDevices As Map
	Return Serial1.GetPairedDevices
End Sub
#Else If B4J
Public Sub GetComPorts As List
	Return Serial1.ListPorts
End Sub
#End If

' Reset the printer to the power on state
Public Sub Reset
	WriteString(ESC & "@")
End Sub

'--------------
' Text Commands
'--------------

' Print any outstanding characters then feed the paper the specified number of units of 0.125mm
' This is similar to changing LineSpacing before sending CRLF but this has a one off effect
' A full character height is always fed even if units = 0. Units defines the excess over this minimum
Public Sub PrintAndFeedPaper(units As Int)
	WriteString(ESC & "J")
	Dim params(1) As Byte
	params(0) = units
	WriteBytes(params)
End Sub

' Set the distance between characters
Public Sub setCharacterSpacing(spacing As Int)
	WriteString(ESC & " ")
	Dim params(1) As Byte
	params(0) = spacing
	WriteBytes(params)
End Sub

' Set the left inset of the next line to be printed
' Automatically resets to 0 for the following line
' inset is specified in units of 0.125mm
Public Sub setLeftInset(inset As Int)
	Dim dh As Int = inset / 256
	Dim dl As Int = inset - dh
	WriteString(ESC & "$" & Chr(dl) & Chr(dh))
	Dim params(2) As Byte
	params(0) = dl
	params(1) = dh
	WriteBytes(params)
End Sub

' Set the left margin of the print area, must be the first item on a new line
' margin is specified in units of 0.125mm
' This affects barcodes as well as text
Public Sub setLeftMargin(margin As Int)
	Dim dh As Int = margin / 256
	Dim dl As Int = margin - dh
	WriteString(GS & "L")
	Dim params(2) As Byte
	params(0) = dl
	params(1) = dh
	WriteBytes(params)
End Sub

' Set the width of the print area, must be the first item on a new line
' margin is specified in units of 0.125mm
' This affects barcodes as well as text
' This appears to function more like a right margin than a print area width when used with LeftMargin
Public Sub setPrintWidth(width As Int)
	Dim dh As Int = width / 256
	Dim dl As Int = width - dh
	WriteString(GS & "W")
	Dim params(2) As Byte
	params(0) = dl
	params(1) = dh
	WriteBytes(params)
End Sub

' Set the distance between lines in increments of 0.125mm
' If spacing is < 0 then the default of 30 is set
Public Sub setLineSpacing(spacing As Int)
	If spacing < 0 Then
		WriteString(ESC & "2")
	Else
		WriteString(ESC & "3")
		Dim params(1) As Byte
		params(0) = spacing
		WriteBytes(params)
	End If
End Sub
	
' Set the line content justification, must be the first item on a new line
' 0 left, 1 centre, 2 right
Public Sub setJustify(justify As Int)
	WriteString(ESC & "a" & Chr(justify + 48))
End Sub

' Set the codepage of the printer
' You need to look at the printer documentation to establish which codepages are supported
Public Sub setCodePage(codepage As Int)	
	WriteString(ESC & "t")
	Dim params(1) As Byte
	params(0) = codepage
	WriteBytes(params)
End Sub

' Select the size of the font for printing text. 0 = Font A (12 x 24), 1 = Font B (9 x 17)
' For font B you may want to set the line spacing to a lower value than the default of 30
' This affects only the size of printed characters. The code page determines the actual character set
' On my printer setting UseCustomCharacters = while Font B is selected crashes the printer and turns it off
Public Sub setCharacterFont(font As Int)
	WriteString(ESC & "M" & Chr(Bit.And(1,font)))
End Sub

' Set the positions of the horizontal tabs
' Each tab is specified as a number of character widths from the beginning of the line
' There may be up to 32 tab positions specified each of size up to 255 characters
' The printer default is that no tabs are defined
Public Sub setTabPositions(tabs() As Int)
	WriteString(ESC & "D")
	Dim data(tabs.Length+1) As Byte
	For i = 0 To tabs.Length - 1
		data(i) = tabs(i)
	Next
	data(tabs.Length) = 0
	WriteBytes(data)
End Sub

' Set print position relative to the current position using horizontal units of 0.125mm
' relposn can be negative
' Unless I have misundertood this doesn't work as documented on my printer
' It only seems take effect at the beginning of a line as a one off effect
Public Sub setRelativePrintPosn(relposn As Int)
	Dim dh As Int = relposn / 256
	Dim dl As Int = relposn - dh
	WriteString(ESC & "\")
	Dim params(2) As Byte
	params(0) = dl
	params(1) = dh
	WriteBytes(params)	
End Sub

' Send the contents of an array of bytes to the printer
' Remember that if the printer is expecting text the bytes will be printed as characters in the current code page
Public Sub WriteBytes(data() As Byte)
	If Connected Then
		Astream.Write(data)
	End If
End Sub

' Send the string to the printer in IBM437 encoding which is the original PC DOS codepage
' This is usually the default codepage for a printer and is CodePage = 0
' Beware of using WriteString with Chr() to send numeric values as they may be affected by Unicode to codepage translations
' Most character level operations are pre-defined as UPPERCASE string variables for easy concatenation with other string data
Public Sub WriteString(data As String)
	#If B4A
	WriteString2(data, "IBM437")
	#End If
	#If B4J
	WriteString2(data, "CP437") ' added by Aeric
	#End If
End Sub

' Send the string to the printer in the specified encoding
' You also need to set the printer to a  matching encoding using the CodePage property
' Beware of using WriteString2 with Chr() to send numeric values as they may be affected by codepage substitutions
' Most character level operations are pre-defined as UPPERCASE string variables for easy concatenatipon with other string data
Public Sub WriteString2(data As String, encoding As String)
	Try
		If Connected Then
			Astream.Write(data.GetBytes(encoding))
		End If
	Catch
		Log("Printer error : " & LastException.Message)
		AStream_Error
	End Try
End Sub

'-----------------------------------------
' User defined character commands commands
'-----------------------------------------

' Delete the specified user defined character mode
' This command deletes the pattern defined for the specified code in the font selected by ESC !
' If the code is subsequently printed in custom character mode the present code page character is printed instead
Public Sub DeleteCustomCharacter(charcode As Int)
	WriteString(ESC & "?")
	Dim params(1) As Byte
	params(0) = charcode
	WriteBytes(params)	
End Sub

' Enable the user defined character mode if custom is True, revert to normal if custom is False
' If a custom character has not been defined for a given character code then the default character for the present font is printed
' FontA and FontB have separate definitions for custom characters
' On my printer setting UseCustomCharacters = while Font B is selected crashes the printer and turns it off
' Therefore the cuatom character routines have not been tested on ont B
Public Sub setUseCustomCharacters(custom As Boolean)
	If custom Then
		WriteString(ESC & "%1")
	Else
		WriteString(ESC & "%0")
	End If
End Sub

' Define  a user defined character
' The allowable character code range is the 95 characters) from ASCII code 32 (0x20) to 126 (0x7E) 
' Characters can be defined in either font A (12*24) or font B (9*17) as selected by present setting of CharacterFont
' The programmer must ensure that the correct font size definition is used for the present setting of CharacterFont
' The user-defined character definition is cleared when Reset is invoked or the printer is turned off
' The vertical and horizontal printed resolution is approximaely 180dpi
' Characters are always defined by sets of three bytes in the vertical direction and up to 9 or 12 sets horizontally
' Each byte defines a vertical line of 8 dots. The MSB of each byte is the highest image pixel, the LSB is the lowest
' Byte(0+n) defines the topmost third of the vertical line, Byte(1+n) is below and Byte(2+n) is the lowest
' Set a bit to 1 to print a dot or 0 to not print a dot
' If the lines to the right of the character are blank then there set of three bytes can be omiited from the byte array
' When the user-defined characters are defined in font B (9*17) only the most significant bit of the 3rd byte of data is used
' charcode defines the character code for the character being defined
' bitdata is a Byte array containing the character definitiopn as described above.
' If the length of bitdata is not a multiple of 3 the definition is ignored and a value of -1 returned
Public Sub DefineCustomCharacter(charcode As Int, bitdata() As Byte) As Int
	Dim excess As Int = bitdata.Length Mod 3
	If excess <> 0 Then Return -1
	Dim size As Int = bitdata.Length / 3
	WriteString(ESC & "&")
	Dim params(4) As Byte
	params(0) = 3
	params(1) = charcode
	params(2) = charcode
	params(3) = size
	WriteBytes(params)
	WriteBytes(bitdata)
	Return 0
End Sub

' The third triangle point is hacked into spare bits keeping the generated Int human readable i hex for other shapes
' The shape array contains the character shapes and characterfont is 0 for a 12*24 character andd 1 for a 9*17 character
' Returns a Byte(36) for characterfont = 0 and a Byte(27) for characterfont = 1
' The returned array can be directly passed to DefineCustomCharacter
' To define a custom character requires specifying up to 288 data points
' This is a lot of data and in most cases it is mainly white space
' This method takes a character definition that defines only the shapes in the character that are to be printed black
' It will be easier use the outputs from CreateLine, CreateTriangle, CreateBox and CreateCircle rather then building the actual Int values
' Each shape is defined by a single Int value containing four parameters in hex format plugs some single bit flags
' Taking the representation of the Int as eight hex characters numbered from the MS end as 0x01234567
' 0 contains the shape to draw. 0 = Line, 1 = Box, 2 = Circle, 3 = Triangle
' 1 contains a value between 0 and 0xF. This is either an X coordinate or for a circle the radius
' 2 and 3 contain a value between 0 and 0x1F. This is either a Y coordinate or for a circle the quadrants to draw
' 4 contains a value between 0 and 0xF. This is 0 for an empty shope or 1 for a filled shape
' 5 contains a value between 0 and 0xF. This is an X coordinate
' 5 and 6 contain a value between 0 and 0x1F. This is a Y coordinate
' The coordinate 0,0 is at the top left of the character
' Line
' One point of the vector is contained in the top part of the Int and the other in the bottom half
' To define a single point place its coordinates as both sr=start and end of a line
' Box
' The two X,Y coordinates specify the top left and bottom right corners of the box
' Circle
' The left X parameter is now the radius of the circle, the left Y is the quadrants to be drawn
' The right X and Y parameters are the centre of the circle' 
' The quadrants to draw are bit ORed together, UpperRight = 0x1, LowerRight = 0x2, LowerLeft = 0x4, Upper Left = 0x8
' Triangle
' The left X and Y parameters are now one point of the triangle, the right X and Y parameters another point
' The third triangle point is hacked into spare bits keeping the generated Int human readable in hex for the other shapes
' The bit allocations of a shape are as follows. f = fill as 0 or 1, s = shape as 0 to 7, xn as 0 to 15, yn as 0 to 31
' Shape 0 = line, 1 = box, 2 = triangle, 3 = circle, 4 to 7 = unused
'   fsss xxxx -yyy yyyy xxxx xxxx yyyy yyyy
'        0000  220 0000 2222 1111 2221 1111 
'         x0   y2  y0    x2   x1  y2   y1
' The shape array contains the character shapes and characterfont is 0 for a 12*24 character andd 1 for a 9*17 character
' Returns a Byte(36) for characterfont = 0 and a Byte(27) for characterfont = 1
' The returned array can be directly passed to DefineCustomCharacter
Public Sub CreateCustomCharacter(shapes() As Int, characterfont As Int) As Byte()
	Dim masks(8) As Byte
	masks(0) = 0x80
	masks(1) = 0x40
	masks(2) = 0x20
	masks(3) = 0x10
	masks(4) = 0x08
	masks(5) = 0x04
	masks(6) = 0x02
	masks(7) = 0x01
	' rather than try to catch errors whenever we access this array we Dim it to the maximum possible values of X and Y
	' then copy the top left of it to the final character definition array of the correct size
	Dim points(16,32) As Byte
	' initialise the character to all white
	For x = 0 To 15
		For y = 0 To 31
			points(x,y) = 0
		Next
	Next
	Dim size As Int = 12
	If characterfont = 1 Then size = 9
	Dim charbyes(size * 3) As Byte
	For c = 0 To charbyes.Length - 1
		charbyes(c) = 0
	Next
	' set the points array from the shapes provided
	For i = 0 To shapes.Length -1
		Dim fill As Int =  Bit.UnsignedShiftRight(Bit.And(0x80000000, shapes(i)), 31)
		Dim shape As Int = Bit.UnsignedShiftRight(Bit.And(0x70000000, shapes(i)), 28)
		Dim x0 As Int = Bit.UnsignedShiftRight(Bit.And(0x0f000000, shapes(i)), 24)
		Dim y0 As Int = Bit.UnsignedShiftRight(Bit.And(0x001f0000, shapes(i)), 16)
		Dim x1 As Int = Bit.UnsignedShiftRight(Bit.And(0x00000f00, shapes(i)), 8)
		Dim y1 As Int = Bit.And(0x0000001f, shapes(i))
		Dim x2 As Int = Bit.UnsignedShiftRight(Bit.And(0x0000f000, shapes(i)), 12)
		Dim y2 As Int = Bit.UnsignedShiftRight(Bit.And(0x00e00000, shapes(i)), 18) +  Bit.UnsignedShiftRight(Bit.And(0x000000e0, shapes(i)), 5)
		' The bit allocations of a shape are as follows. f = fill as 0 or 1, s = shape as 0 to 7, xn as 0 to 15, yn as 0 to 31
		' Shape 0 = line, 1 = box, 2 = triangle, 3 = circle, 4 to 7 = unused
		'   fsss xxxx -yyy yyyy xxxx xxxx yyyy yyyy
		'        0000  220 0000 2222 1111 2221 1111
		'         x0   y2  y0    x2   x1  y2   y1
		Dim logmsg As String = ": Fill=" & fill & " : Points " & x0 & "," & y0 & "  " & x1 & "," & y1 & "  " & x2 & "," & y2
		If shape = 3 Then
			Log("Triangle " & logmsg)
			PlotTriangle(x0, y0, x1, y1, x2, y2, points, fill)
		else If shape = 2 Then
			Log("Circle " & logmsg)
			PlotCircle(x0, y0, x1, y1, points, fill)
		Else If shape = 1 Then
			Log("Box " & logmsg)
			PlotBox(x0, y0, x1, y1, points, fill)
		Else
			Log("Line " & logmsg)
			PlotLine(x0, y0, x1, y1, points)
		End If
		' map the points array onto the character definition array
		For x = 0 To size -1 ' 9 or 12 horizontal bytes
			For y = 0 To 2 ' 3 vertical bytes
				Dim bits As Byte = 0
				For b = 0 To 7 ' 8 vertical bits
					If points(x, y*8+b) <> 0 Then
						bits = Bit.Or(bits, masks(b))
					End If
				Next
				charbyes(x*3+y) = bits
			Next
		Next
	Next
	Return charbyes
End Sub

' This is a higher level method that builds the Int values to pass to CreateCustomCharacter in the shapes array
' Create the value to draw a line in a custom character
' The line starts at X0,Y0 and ends at X1,Y1
Public Sub CreateLine(x0 As Int, y0 As Int, x1 As Int, y1 As Int) As Int
	Dim line As Int = 0
	line = line + Bit.ShiftLeft(Bit.And(0xf,x0), 24)
	line = line + Bit.ShiftLeft(Bit.And(0x1f,y0), 16)
	line = line + Bit.ShiftLeft(Bit.And(0xf,x1), 8)
	line = line + Bit.And(0x1f,y1)
	Return line
End Sub

' This is a higher level method that builds the Int values to pass to CreateCustomCharacter in the shapes array
' Create the value to draw a circle in a custom character
' The circle is centred on X1,Y1 and the quadrants to draw are bit ORed together
' UpperRight = 0x1, LowerRight = 0x2, LowerLeft = 0x4, Upper Left = 0x8
Public Sub CreateCircle(radius As Int, quadrants As Int, x1 As Int, y1 As Int, fill As Boolean) As Int
	Dim circle As Int = 0x20000000
	If fill Then circle = circle + 0x80000000
	circle = circle + Bit.ShiftLeft(radius, 24)
	circle = circle + Bit.ShiftLeft(quadrants, 16)
	circle = circle + Bit.ShiftLeft(x1, 8)
	circle = circle + y1
	Return circle
End Sub


' This is a higher level method that builds the Int values to pass to CreateCustomCharacter in the shapes array
' Create the value to draw a triangle in a custom character
' The triangles corners are at X0,Y0 X1,Y1 and X2,Y2
Public Sub CreateTriangle(x0 As Int, y0 As Int, x1 As Int, y1 As Int, x2 As Int, y2 As Int, fill As Boolean) As Int
	Dim triangle As Int = 0x30000000
	If fill Then triangle = triangle + 0x80000000
	triangle = triangle + Bit.ShiftLeft(Bit.And(0xf,x0), 24)
	triangle = triangle + Bit.ShiftLeft(Bit.And(0x1f,y0), 16)
	triangle = triangle + Bit.ShiftLeft(Bit.And(0xf,x1), 8)
	triangle = triangle + Bit.And(0x1f,y1)
	triangle = triangle + Bit.ShiftLeft(Bit.And(0xf,x2), 12) ' extra X
	triangle = triangle + Bit.ShiftLeft(Bit.And(0x7,y2), 5) ' extra Y lsbits * 3
	triangle = triangle + Bit.ShiftLeft(Bit.And(0x18,y2), 18) ' extra Y msbits * 2
	Return triangle
End Sub

' This is a higher level method that builds the Int values to pass to CreateCustomCharacter in the shapes array
' Create the value to draw a box in a custom character
' The box top left start is X0,Y0 and bottom right is X1,Y1
Public Sub CreateBox(x0 As Int, y0 As Int, x1 As Int, y1 As Int, fill As Boolean) As Int
	Dim box As Int = 0x10000000
	If fill Then box = box + 0x80000000
	box = box + Bit.ShiftLeft(Bit.And(0xf,x0), 24)
	box = box + Bit.ShiftLeft(Bit.And(0x1f,y0), 16)
	box = box + Bit.ShiftLeft(Bit.And(0xf,x1), 8)
	box = box + Bit.And(0x1f,y1)
	Return box
End Sub

'-----------------------------------------
' Private custom character drawing methods
'-----------------------------------------

Private Sub PlotTriangle(x0 As Int, y0 As Int, x1 As Int, y1 As Int, x2 As Int, y2 As Int, points(,) As Byte, Fill As Int)
	' This is a pretty crude algorithm, but it is simple, works and it isn't invoked often
	PlotLine(x0, y0, x1, y1, points)
	PlotLine(x1, y1, x2, y2, points)
	PlotLine(x2, y2, x0, y0, points)
	If Fill > 0 Then
		FillTriangle(x0, y0, x1, y1, x2, y2, points)
	End If
End Sub

Private Sub FillTriangle(x0 As Int, y0 As Int, x1 As Int, y1 As Int, x2 As Int, y2 As Int, points(,) As Byte)
	' first sort the three vertices by y-coordinate ascending so v0 Is the topmost vertice */
	Dim tx, ty As Int
	If y0 > y1 Then
		tx = x0 : ty = y0
		x0 = x1 : y0 = y1
		x1 = tx : y1 = ty
	End If
	If y0 > y2 Then
		tx = x0 : ty = y0
		x0 = x2 : y0 = y2
		x2 = tx : y2 = ty
	End If
	If y1 > y2 Then
		tx = x1 : ty = y1
		x1 = x2 : y1 = y2
		x2 = tx : y2 = ty
	End If
	
	Dim dx0, dx1, dx2 As Double
	Dim x3, x4, y3, y4 As Double
	Dim inc As Int
		
	If y1 - y0 > 0 Then	dx0=(x1-x0)/(y1-y0) Else	dx0=0
	If y2 - y0 > 0 Then dx1=(x2-x0)/(y2-y0) Else dx1=0
	If y2 - y1 > 0 Then dx2=(x2-x1)/(y2-y1) Else dx2=0
	x3 = x0 : x4 = x0
	y3 = y0 : y4 = y0
	If dx0 > dx1 Then
		While
		Do While y3 <= y1
			If x3 > x4 Then inc = -1 Else inc = 1
			For x = x3 To x4 Step inc
				points(x, y3) = 1
			Next
			y3 = y3 + 1 : y4 = y4 + 1 : x3 = x3 + dx1 : x4 = x4 + dx0
		Loop
		x4=x1
		y4=y1
		Do While y3 <= y2
			If x3 > x4 Then inc = -1 Else inc = 1
			For x = x3 To x4 Step inc
				points(x ,y3) = 1
			Next
			y3 = y3 + 1 : y4 = y4 + 1 : x3 = x3 + dx1 : x4 = x4 + dx2
		Loop
	Else
		While
		Do While y3 <= y1
			If x3 > x4 Then inc = -1 Else inc = 1
			For x = x3 To x4 Step inc
				points(x, y3) = 1
			Next
			y3 = y3 + 1 : y4 = y4 + 1 : x3 = x3 + dx0 : x4 = x4 +dx1
		Loop
		x3=x1
		y3=y1
		Do While y3<=y2
			If x3 > x4 Then inc = -1 Else inc = 1
			For x = x3 To x4 Step inc
				points(x, y3) = 1
			Next
			y3 = y3 + 1 : y4 = y4 + 1 : x3 = x3 + dx2 : x4 = x4 + dx1
		Loop
	End If
End Sub

Private Sub PlotBox(x0 As Int, y0 As Int, x1 As Int, y1 As Int, points(,) As Byte, Fill As Int)
	' This is a pretty crude algorithm, but it is simple, works and itsn't invoked often
	PlotLine(x0, y0, x0, y1, points)
	PlotLine(x0, y0, x1, y0, points)
	PlotLine(x1, y0, x1, y1, points)
	PlotLine(x0, y1, x1, y1, points)
	If Fill > 0 Then
		For x = x0 To x1
			PlotLine(x, y0, x, y1, points)
		Next
	End If
End Sub


Private Sub PlotCircle(radius As Int, quadrants As Int, x1 As Int, y1 As Int, points(,) As Byte, fill As Int)
	' This is a pretty crude algorithm, but it is simple, works and itsn't invoked often
	Dim mask As Int = 1
	For q = 3 To 0 Step -1
		If Bit.And(quadrants, mask) <> 0 Then
			For i = q*90 To q*90+90 Step 1
				Dim x,y As Double
				x = x1 - SinD(i)*radius
				y = y1 - CosD(i)*radius
				If fill > 0 Then
					PlotLine(x1, y1, x, y, points)
				Else
					points(Round(x), Round(y)) = 1
				End If
			Next
		End If
		mask = Bit.ShiftLeft(mask, 1)
	Next
End Sub

' Bresenham's line algorithm - see Wikipedia
Private Sub PlotLine(x0 As Int, y0 As Int, x1 As Int, y1 As Int, points(,) As Byte )
  If Abs(y1 - y0) < Abs(x1 - x0) Then
    If x0 > x1 Then
      PlotLineLow(x1, y1, x0, y0, points)
    Else
      PlotLineLow(x0, y0, x1, y1, points)
    End If
  Else
    If y0 > y1 Then
      PlotLineHigh(x1, y1, x0, y0, points)
    Else
      PlotLineHigh(x0, y0, x1, y1, points)
    End If
  End If
End Sub

Private Sub PlotLineHigh(x0 As Int, y0 As Int, x1 As Int, y1 As Int, points(,) As Byte )
  Dim dx As Int = x1 - x0
  Dim dy  As Int = y1 - y0
  Dim xi As Int = 1
  If dx < 0 Then
    xi = -1
    dx = -dx
  End If
  Dim D As Int = 2*dx - dy
  Dim x As Int = x0
  For y = y0 To y1
    	points(x,y) = 1
    If D > 0 Then
       x = x + xi
       D = D - 2*dy
    End If
    D = D + 2*dx
	Next
End Sub
	
Private Sub	PlotLineLow(x0 As Int, y0 As Int, x1 As Int,y1 As Int, points(,) As Byte )
  Dim dx As Int = x1 - x0
  Dim dy As Int = y1 - y0
  Dim yi As Int = 1
  If dy < 0 Then
    yi = -1
    dy = -dy
  End If
  Dim D As Int = 2*dy - dx
  Dim y As Int = y0
  For x = x0 To x1
    	points(x,y) = 1
    If D > 0 Then
       y = y + yi
       D = D - 2*dx
    End If
    D = D + 2*dy
	Next
End Sub


'-------------------
' Image commands
'-------------------
' There are two different image printing options with different pixel formats.
' PrintImage prints an entire image at once with a maximum size of 576x512
' PrintImage2 prints a slice of an image with a height of 8 or 24 and a maximum width of 576
' One or other may look better on your particular printer

' Printer support method for pre-processing images to print
' Convert the bitmap supplied to an array of pixel values representing the luminance value of each original pixel
Public Sub ImageToBWIMage (bmp As B4XBitmap) As AnImage
	Dim BC As BitmapCreator 'ignore
	Dim W As Int = bmp.Width
	Dim H As Int = bmp.Height
	Dim pixels(W * H) As Byte

	For y = 0 To H - 1
		For x = 0 To W - 1
			#If B4A
			Dim j As Int = bmp.As(Bitmap).GetPixel(x, y) ' Aeric: not tested
			#Else If B4i
			Dim j As Int = GetPixelColor(bmp, x, y)
			#Else
			Dim j As Int = bmp.As(Image).GetPixel(x, y)
			#End If
			' convert color to approximate luminance value
			Dim col As ARGBColor
			BC.ColorToARGB(j, col )
			Dim lum As Int = col.r * 0.2 + col.b * 0.1 + col.g * 0.7
			If lum> 255 Then lum = 255
			' save the pixel luminance
			pixels(y * W + x) = lum
		Next
	Next
	Dim ret As AnImage
	ret.Width = bmp.Width
	ret.Height = bmp.Height
	ret.Data = pixels
	Return ret
End Sub

' Printer support method for pre-processing images to print
' Convert the array of luminance values to an array of 0s and 1s according to the threshold value
Sub ThresholdImage(img As AnImage, threshold As Int) As AnImage
	Dim pixels(img.Data.Length) As Byte
	For i = 0 To pixels.Length - 1
		Dim lum As Int = Bit.And(img.Data(i), 0xff) ' bytes are signed values
		If lum < threshold Then
			lum = 1
		Else
			lum = 0
		End If
		pixels(i) = lum
	Next
	Dim ret As AnImage
	ret.Width = img.Width
	ret.Height = img.Height
	ret.Data = pixels
	Return ret
End Sub

' Printer support method for pre-processing images to print
' Convert the array of luminance values to a dithered array of 0s and 1s according to the threshold value
' The dithering algorithm is the simplest one-dimensional error diffusion algorithm
' Normally threshold should be 128 but some images may look better with a little more or less.
' This algorithm tends to produce vertical lines. DitherImage2D will probably look far better
Public Sub DitherImage1D (img As AnImage, threshold As Int) As AnImage
	Dim pixels(img.Data.Length) As Byte
	Dim error As Int
	For y = 0 To img.Height - 1
		error = 0 ' reset on each new line
		For x = 0 To img.Width - 1
			Dim lum As Int = Bit.And(img.Data(y*img.Width + x), 0xff) ' bytes are signed values
			lum = lum + error
			If lum < threshold Then
				error = lum
				lum = 1
			Else
				error = lum - 255
				lum = 0
			End If
			pixels(y*img.Width + x) = lum
		Next
	Next
	Dim ret As AnImage
	ret.Width = img.Width
	ret.Height = img.Height
	ret.Data = pixels
	Return ret
End Sub


' Printer support method for pre-processing images to print
' Convert the array of luminance values to a dithered array of 0s and 1s according to the threshold value
' The dithering algorithm is the simplest two-dimensional error diffusion algorithm
' Normally threshold should be 128 but some images may look better with a little more or less.
' Anything more sophisticated might be overkill considering the image quality of most thermal printers
Public Sub DitherImage2D (img As AnImage, threshold As Int) As AnImage
	Dim pixels(img.Data.Length) As Byte
	Dim xerror As Int
	Dim yerrors(img.Width) As Int
	For i = 0 To yerrors.Length -1
		yerrors(0) = 0		
	Next
	For y = 0 To img.Height - 1
		xerror = 0 ' reset on each new line
		For x = 0 To img.Width - 1
			Dim lum As Int = Bit.And(img.Data(y*img.Width + x), 0xff) ' bytes are signed values
			lum = lum + xerror + yerrors(x)
			If lum < threshold Then
				xerror = lum/2
				yerrors(x) = xerror
				lum = 1
			Else
				xerror = (lum - 255)/2
				yerrors(x) = xerror
				lum = 0
			End If
			pixels(y*img.Width + x) = lum
		Next
	Next
	Dim ret As AnImage
	ret.Width = img.Width
	ret.Height = img.Height
	ret.Data = pixels
	Return ret
End Sub


' GS v0 printing
'---------------

' Prints the given image at the specified height and width using the "GS v" command
' Image data is supplied as bytes each containing 8 bits of horizontal image data
' The top left of the image is Byte(0) and the bottom right is Byte(width*height-1)
' MSB of the byte is the leftmost image pixel, the LSB is the rightmost
' Maximum width is 72 bytes (576 bits), Maximum height is 512 bytes
' The printed pixels are square
' Returns status 0 : OK, -1 : too wide, -2 : too high, -3 : array too small
' The printer can take a long time to process the data and start printing
Public Sub PrintImage(img As AnImage) As Int
	' max width = 72 ' 72mm/576 bits wide
	' max height = 512 ' 64mm/512 bits high
	If img.width > 72 Then Return -1
	If img.height > 512 Then Return -2
	If img.data.Length < img.width * img.height Then Return -3
	Dim xh As Int = img.width / 256
	Dim xl As Int = img.width - xh * 256	
	Dim yh As Int = img.height / 256
	Dim yl As Int = img.height - yh * 256
	Dim params(5) As Byte
	params(0) = 0 ' 
	params(1) = xl
	params(2) = xh
	params(3) = yl
	params(4) = yh
	WriteString(GS & "v0")
	WriteBytes(params)
	WriteBytes(img.data)
	WriteString(CRLF)
	Return 0
End Sub

' Printer support method for pre-processing images to print by PrintImage
' Takes an array of image pixels and packs it for use with PrintImage
' Each byte in the imagedata array is a single pixel valued zero or non-zero for white and black
' The returned array is 8 x smaller and packs 8 horizontal black or white pixels into each byte
' If the horizontal size of the image is not a multiple of 8 it will be truncated so that it is.
Public Sub PackImage(imagedata As AnImage) As AnImage
	Dim xbytes As Int = imagedata.width/8
	Dim pixels(xbytes * imagedata.height) As Byte
	Dim masks(8) As Byte
	masks(0) = 0x80
	masks(1) = 0x40
	masks(2) = 0x20
	masks(3) = 0x10
	masks(4) = 0x08
	masks(5) = 0x04
	masks(6) = 0x02
	masks(7) = 0x01	
	Dim index As Int = 0
	For y = 0 To imagedata.Height - 1
		For x = 0 To xbytes - 1
			Dim xbyte As Byte = 0
			For b = 0 To 7
				' get a pixel
				Dim pix As Byte = imagedata.Data(index)
				If pix <> 0 Then
					xbyte = xbyte + masks(b)
				End If
				index = index + 1
			Next
			pixels(y*xbytes + x) = xbyte
		Next
	Next
	Dim ret As AnImage
	ret.Width = xbytes
	ret.Height = imagedata.Height
	ret.Data = pixels
	Return ret
End Sub


' ESC * printing
'---------------

' Prints the given image slice at the specified height and width using the "ESC *" command
' Image data is supplied as bytes each containing 8 bits of vertical image data
' Pixels are not square, the width:height ratio varies with density and line height 
' Returns status 0 = OK, -1 = too wide, -2 = too high, -3 = wrong array length
' Line spacing needs to be set to 0 if printing consecutive slices
' The printed pixels are not square, the ratio varies with the highdensity and dots24 parameter settings
' The highdensity parameter chooses high or low horizontal bit density when printed
' The dots24 parameter chooses 8 or 24 bit data slice height when printed
' Not(highdensity)
'   Maximum width is 288 bits. Horizontal dpi is approximately 90
'   MSB of each byte is the highest image pixel, the LSB is the lowest
' highdensity 
'   Maximum width is 576 bits. Horizontal dpi is approximately 180
' Not(dots24)
'   Vertical printed height is 8 bits at approximately 60dpi
'   One byte in the data Array represents one vertical line when printed
'   Array size is the same as the width
'   MSB of each byte is the highest image pixel, the LSB is the lowest
' dots24
'   Vertical printed height is 24 bits at approximately 180dpi
'   Three consecutive bytes in the data array represent one vertical 24bit line when printed
'   Array size is 3 times the width
'   Byte(n+0) is the highest, byte (n+2) us the lowest
'   MSB of each byte is the highest image pixel, the LSB is the lowest
Public Sub PrintImage2(width As Int, data() As Byte, highdensity As Boolean, dotds24 As Boolean) As Int
	Dim d As String = Chr(0)
	If Not(highdensity) And Not(dotds24 )	 Then
		d = Chr(0)
		If width > 288 Then Return -1
		If data.Length <> width Then Return -3
	Else If highdensity And Not(dotds24) 	 Then
		d = Chr(1)
		If width > 576 Then Return -1
		If data.Length <> width Then Return -3
	Else 	If Not(highdensity) And dotds24 	 Then
		d = Chr(32)
		If width > 288 Then Return -1
		If data.Length <> width*3 Then Return -3
	Else  ' highdensity And dotds24
		d = Chr(33)
		If width > 576 Then Return -1
		If data.Length <> width*3 Then Return -3
	End If
	Dim xh As Int = width / 256
	Dim xl As Int = width - xh * 256
	Dim params(2) As Byte
	params(0) = xl
	params(1) = xh
	WriteString(ESC & "*" & d)
	WriteBytes(params)	
	WriteBytes(data)
	WriteString(CRLF)
	Return 0
End Sub

' Printer support method for pre-processing images to print by PrintImage2
' Takes an array of image pixels and packs one slice of it for use with PrintImage2
' Each byte in the imagedata array is a single pixel valued zero or non-zero for white and black
' The returned array packs 8 vertical black or white pixels into each byte
' If dots24 is True then the slice is 24 pixels high otherwise it is 8 pixels high
Public Sub PackImageSlice(img As AnImage, slice As Int, dots24 As Boolean) As Byte()
	Dim bytes As Int = img.width
	If dots24 Then
		Dim pixels(bytes * 3) As Byte
		Dim slicestart As Int = slice * bytes * 8 * 3
	Else
		Dim pixels(bytes) As Byte
		Dim slicestart As Int = slice * bytes * 8
	End If

	Dim masks(8) As Byte
	masks(0) = 0x80
	masks(1) = 0x40
	masks(2) = 0x20
	masks(3) = 0x10
	masks(4) = 0x08
	masks(5) = 0x04
	masks(6) = 0x02
	masks(7) = 0x01
	' You could compress this into a single code block but I left it as two to make it more obvious what's happening
	If dots24 Then
		For x = 0 To bytes - 1
			For s = 0 To 2
				Dim xbyte As Byte = 0
				For b = 0 To 7
					' get a pixel
					Dim pix As Byte = img.Data(slicestart + ((b + s*8) * bytes) + x)
					If pix <> 0 Then
						xbyte = xbyte + masks(b)
					End If
				Next
				pixels(x*3+s) = xbyte
			Next
		Next
	Else
		For x = 0 To bytes - 1
			Dim xbyte As Byte = 0
			For b = 0 To 7
				' get a pixel
				Dim pix As Byte = img.Data(slicestart + (b * bytes) + x)
				If pix <> 0 Then
					xbyte = xbyte + masks(b)
				End If
			Next
			pixels(x) = xbyte
		Next
	End If
	Return pixels
End Sub

'----------------
'Barcode commands
'----------------

' Set the height of a 2D bar code as number of dots vertically, 1 to 255
' Automatically resets to the default after printing the barcode
Public Sub setBarCodeHeight(height As Int)
	WriteString(GS & "h")
	Dim params(1) As Byte
	params(0) = height
	WriteBytes(params)
End Sub

' Set the left inset of a 2D barcode, 0 to 255
' This does not reset on receipt of RESET
Public Sub setBarCodeLeft(left As Int)
	WriteString(GS & "x")
	Dim params(1) As Byte
	params(0) = left
	WriteBytes(params)
End Sub

' Set the width of each bar in a 2D barcode. width value is 2 to 6, default is 3
' 2 = 0.250, 3 - 0.375, 4 = 0.560, 5 = 0.625, 6 = 0.75
' Resets to default after printing the barcode
Public Sub setBarCodeWidth(width As Int)
	WriteString(GS & "w")
	Dim params(1) As Byte
	params(0) = width
	WriteBytes(params)
End Sub

'Selects the printing position of HRI (Human Readable Interpretation) characters when printing a 2D bar code.
'0 Not printed, 1 Above the bar code, 2 Below the bar code, 3 Both above And below the bar code
' Automatically resets to the default of 0 after printing the barcode
' The docs say this can be Chr(0, 1 2 or 3) or "0" "1" "2" or "3" but the numeric characters don't work
Public Sub setHriPosn(posn As Int)
	WriteString(GS & "H")
	Dim params(1) As Byte
	params(0) = posn
	WriteBytes(params)
End Sub

'Selects the font for HRI (Human Readable Interpretation) characters when printing a 2D bar code.
'0 Font A (12 x 24), 1 Font B (9 x 17)
' Automatically resets to the default of 0 after printing the barcode
' The docs say this can be Chr(0 or 1) or "0" or "1" but the numeric characters don't work
Public Sub setHriFont(font As Int)
	WriteString(GS & "f" & Chr(font))
End Sub

' If given invalid data no barcode is printed, only strange characters 
' CODABAR needs any of A,B,C or D at the start and end of the barcode. Some decoders may not like them anywhere else
' Bartype   Code     Number of characters   Permitted values
'       A | UPC-A  | 11 or 12 characters  | 0 to 9 | The 12th printed character is always the check digit
'       B | UPC-E  | 6 characters         | 0 to 9 | The 12th printed character is always the check digit
'       C | EAN13  | 12 or 13 characters  | 0 to 9 | The 12th printed character is always the check digit
'       D | EAN8   | 7 or 8 characters    | 0 to 9 | The 8th printed character is always the check digit
'       E | CODE39 | 1 or more characters | 0 to 9, A to Z, Space $ % + - . /
'       F | ITF    | 1 or more characters | 0 to 9 | even number of characters only
'       G | CODABAR| 3 to 255 characters  | 0 to 9, A to D, $ + - . / : |  needs any of A,B,C or D at the start and end
'       H | CODE93 | 1 to 255 characters  | Same as CODE39
'       I | CODE128| 2 to 255 characters  | entire 7 bit ASCII set
Public Sub WriteBarCode(bartype As String, data As String)
	Dim databytes() As Byte = data.GetBytes("ASCII")
	Dim dlow As Int = databytes.Length
	Log("Barcode " & bartype & ", Size " & dlow & ", " & data)
	WriteString(GS & "k" & bartype.ToUpperCase.CharAt(0))
	Dim params(1) As Byte
	params(0) = dlow
	WriteBytes(params)
	WriteBytes(databytes)
End Sub

' On my printer QR codes don't seem to be able to be decoded and on high ECs look obviously wrong :(
' size is 1 to 40, 0 is auto-size. Successive versions increase module size by 4 each side 
' size = 1 is 21x21, 2 = 25x25 ... size 40 = 177x177
' EC is error correction level, "L"(7%) or "M"(15%) or "Q"(25%) or "H"(30%)
' scale is 1 to 8, 1 is smallest, 8 is largest
Public Sub WriteQRCode(size As Int, EC As String, scale As Int, data As String)
	Dim databytes() As Byte = data.GetBytes("ISO-8859-1")
	Dim dhigh As Int = databytes.Length / 256
	Dim dlow As Int = databytes.Length - dhigh*256
	Log("QR Code : Size " & size & ", EC " & EC & ", Scale " & scale & ", Size " & dlow & " " & dhigh & " : Data = " & data)
	Dim params(3) As Byte
	params(0) = scale
	params(1) = dlow
	params(2) = dhigh
	WriteString(ESC & "Z" & Chr(size) & EC.ToUpperCase.CharAt(0))
	WriteBytes(params)
	WriteBytes(databytes)
End Sub


'****************
' PRIVATE METHODS
'****************

'-----------------------
' Internal Serial Events
'-----------------------
#If B4A
Private Sub Serial1_Connected (Success As Boolean)
	If Success Then
		Astream.Initialize(Serial1.InputStream, Serial1.OutputStream, "astream")
		Connected = True
		ConnectedError = ""
		Serial1.Listen
	Else
		Connected = False
		ConnectedError = LastException.Message
	End If
	If SubExists(CallBack, EventName & "_Connected") Then
		CallSub2(CallBack, EventName & "_Connected", Success)
	End If
End Sub
#End If

'----------------------------
' Internal AsyncStream Events
'----------------------------

Private Sub AStream_NewData (Buffer() As Byte)
	#If B4A
	If SubExists(CallBack, EventName & "_NewData") Then
		CallSub2(CallBack, EventName & "_NewData", Buffer)
	End If
	Log("Data " & Buffer(0))
	#Else If B4J
	Dim msg As String = BytesToString(Buffer, 0, Buffer.Length, "UTF8")
	Log("AStream_NewData = " & msg)
	#End If
End Sub

Private Sub AStream_Error
	#If B4A
	If SubExists(CallBack, EventName & "_Error") Then
		CallSub(CallBack, EventName & "_Error")
	End If
	#Else If B4J
	Log(LastException.Message)
	Astream.Close
	#End If	
End Sub

Private Sub AStream_Terminated
	#If B4A
	Connected = False
	If SubExists(CallBack, EventName & "_Terminated") Then
		CallSub(CallBack, EventName & "_Terminated")
	End If	
	#Else If B4J
	Connected = False
	Log("AStream_Terminated")
	#End If	
End Sub