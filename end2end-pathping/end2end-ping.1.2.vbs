Option Explicit
'-------------------------------------------------------------------------
' end2end-ping
'
' Description
' Runs a pin in given intervals to measure the rpundtrip time
' If time is more than 500% of the average time, it will generate an eventlog message
' Additional alle results are tracked in a CSV-File for later usage
'
' Requirements
' - target mus be PINGable (Attn windows firewalls etc
'
' Attn:  You can stop the script only with CTRL-C 
'
' Version 1.1 (11. Dez 2008)
'	complete english messages
'-------------------------------------------------------------------------

' Configuration
const conIdleTime = 1000	' Idletime between two pings
const Alarmdelta = 500	'Maximum roundtrip time in percent from the average timein percent
'const PINGTARGET = "127.0.0.1"
const PINGTARGET = "www.google.de"
const conCSVfilename = "c:\users\fcarius\end2end-ping.csv"

Const ForWriting = 2
Const ForAppending = 8

dim objDebug
set objdebug = new DebugWriter 
objDebug.target = "file:6 console:3" ' errorlogging  0=only output, 1=Error 2=Warning 3=information  5++ =debug
objDebug.outFile = "end2end-ping-" & Date() & "-" & Time() &".log"
objDebug.start
objDebug.writeln "end2end-ping: gestartet", 0

objDebug.writeln "Pause zwischen zwei Pings :" & conIdleTime,0
objDebug.writeln "Maximal tolerierte Abweichung:" & Alarmdelta ,0

objDebug.writeln "end2end-ping:Initialize Eventlog Writer",0
Dim objShell 
Set objShell = CreateObject ("WScript.Shell") 
objShell.LogEvent 0, "end2end-ping: gestartet"

objDebug.writeln "end2end-ping:Initialize Logfile",0
dim fs, file, logfile
Set fs = CreateObject("Scripting.FileSystemObject")
If (fs.FileExists(conCSVfilename)) Then
	wscript.echo "Logdatei existiert bereits"
	Set logfile = fs.OpenTextFile(conCSVfilename, ForAppending)
Else
	wscript.echo "Create Logfile " & conCSVfilename
	Set logfile = fs.CreateTextFile(conCSVfilename, ForWriting)
	logfile.writeline "timestamp;performance"
End If

dim performance, mittelwert, count, max, message, alive, PingResult, PingResults, OUTPUT
mittelwert = 0 : count  = 0 : max = 0 : message = "" : alive=0
objDebug.writeln ":Start Pinging",0
do
	if alive > 6000 then	' dump regular "alive" messages to eventlog nearly every 10+WriteTime Minutes 
		objDebug.writeln "end2end-ping: alive",0
		objShell.LogEvent 0, "end2end-ping: alive"
		alive = 0
	else
		alive = alive+1
	end if

	' ------------ PING -------------------
	Set PingResults = GetObject("winmgmts:{impersonationLevel=impersonate}//./root/cimv2"). ExecQuery("SELECT * FROM Win32_PingStatus " & _
		"WHERE Address = '" + PINGTARGET + "'")

	For Each PingResult In PingResults
		If PingResult.StatusCode = 0 Then
			If LCase(PINGTARGET) = PingResult.ProtocolAddress Then
			    OUTPUT = PINGTARGET & " is responding" & VbCrLf
			Else
			    OUTPUT = PINGTARGET & "(" & PingResult.ProtocolAddress & ") is responding" & VbCrLf
			End If
			OUTPUT = OUTPUT & "Bytes = " & PingResult.BufferSize & vbtab & "Time (ms)= " & PingResult.ResponseTime & VBTAB & "TTL (s)=" & PingResult.ResponseTimeToLive
			performance = PingResult.ResponseTime 
			wscript.stdout.write "."
		Else
			OUTPUT = OUTPUT & PINGTARGET & " is not responding. Status code is " & PingResult.StatusCode
			wscript.stdout.write "X"
			performance =10000
		End If
	Next
	objDebug.writeln "end2end-ping: " & OUTPUT,4
	
	if mittelwert = 0 then 
		mittelwert = performance  ' First run
	else
		if performance - mittelwert > Alarmdelta then
			message = "End2End PING ALARM: TTL exceeded limit" & vbcrlf &_
					vbtab & "Average value: " & vbtab & mittelwert & "ms" & vbcrlf &_
					vbtab & "Current value: " & vbtab & performance &  "ms" & vbcrlf &_
					vbtab & "Alarmdelta: " & vbtab & alarmdelta &  "ms"& vbcrlf &_
					vbtab & "Idletime: " & vbtab & conIdleTime &  "s" 
			objDebug.writeln message,1
			objShell.LogEvent 1, message 
		else
			mittelwert = round(mittelwert + (performance - mittelwert)/10)  ' verschiebe mittelwert median by 10% 
			objDebug.writeln "end2end-ping: TTL:"&performance & vbtab & "Average value=" & mittelwert ,3
		end if
	end if

	if performance > max then max = performance

	if count > 9 then 
		objDebug.writeln " Average ms:" & cint(mittelwert) & "ms  Max:" & Max & "ms ",3
		count = 0 : max = 0 
	end if 
	count = count  + 1

	logfile.writeline now & ";" & performance
	wscript.sleep(conIdleTime)
loop




class debugwriter
	' Generic Class for writing debugging information

	private objIE, file, fs, debugfilename, status, strline
	private debuglevelIE , debuglevelfile, debugleveleventlog, debuglevelConsole

	private Sub Class_Initialize
		status = "active" : strline = "" : debugfilename = ""
		debuglevelIE = -1
		debuglevelfile = -1 
		debugleveleventlog = -1
		debuglevelConsole = -1
	End Sub

	private Sub Class_Terminate()
		if isobject(OBJIE) then
			objie.document.write "</table></body></html>"
		end if
		if debugfilename <> "" then
			file.Close
		end if
	End Sub

	public sub start : status = "active": end sub
	public sub pause : status = "pause" : end sub

	public property let outfile(wert) 	
		if debugfilename <> "" then    'Close existing debug file
			file.close : file = nothing : fs = nothing 
		end if

		debugfilename = wert    ' open debug file
		Set fs = CreateObject("Scripting.FileSystemObject")
		Set file = fs.OpenTextFile(makefilename(debugfilename), 8, True)
	end property

	public property let setie (wert)  : set objIE = wert  : objie.visible = true  end property

	public property let target (wert)
		dim arrTemp, intcount
		arrTemp = split(wert," ")  ' spit by space
		for intcount = 0 to ubound(arrTemp)
			select case lcase(split(arrtemp(intcount),":")(0))
				case "ie" 		debuglevelIE = cint(right(arrtemp(intcount),1))
				case "file" 	debuglevelfile = cint(right(arrtemp(intcount),1))
				case "eventlog" debugleveleventlog = cint(right(arrtemp(intcount),1))
				case "console" 	debuglevelConsole = cint(right(arrtemp(intcount),1))
			end select
		next
	end property

	sub write(strMessage)  
		strline = strline & strMessage
	end sub

	Sub writeln(strMessage, intseverity)
	'F�gt einen Eintrag in die Log-Datei ein
		strMessage = strline & strMessage
		if (status = "active") Then
           if (debuglevelfile >= intseverity) and (debugfilename <> "") then
                file.Write(Now & ",")
                Select Case intseverity
                    Case 0  file.Write("Out0")
                    Case 1  file.Write("Err1")
                    Case 2  file.Write("Wrn2")
                    Case 3  file.Write("Inf3")
                    Case Else file.Write("Dbg"&intseverity)
                End Select
                file.WriteLine("," & Convert2Text(strMessage))
            end if

           if debugleveleventlog >=intSeverity then
                dim objWSHShell
				Set objWSHShell = Wscript.CreateObject("Wscript.Shell")
                Select Case intseverity
                    Case 0  objWSHShell.LogEvent 0, strMessage '           		Const EVENT_SUCCESS = 0
                    Case 1  objWSHShell.LogEvent 1, strMessage '           		const EVENT_ERROR = 1
                    Case 2  objWSHShell.LogEvent 2, strMessage '           		Const EVENT_WARNING = 2
                    Case else  objWSHShell.LogEvent 4, strMessage '           		Const EVENT_INFO = 4
                End Select
           end if

           if debuglevelconsole >=intSeverity then
                Select Case intseverity
                    Case 0  wscript.echo now() & ",OUT0:" & strMessage
                    Case 1  wscript.echo now() & ",ERR1:" & strMessage
                    Case 2  wscript.echo now() & ",WRN2:" & strMessage
                    Case 3  wscript.echo now() & ",INF3:" & strMessage
                    Case Else wscript.echo now() & ",DBG" & intseverity & ":" & strMessage
                End Select

           end if

           if debuglevelie >=intSeverity then
           		dim strieline
      			if  not isobject(objIE) then
      				Set objIE = CreateObject("InternetExplorer.Application")
           		    objIE.navigate("about:blank")
					objIE.visible = true
					Do While objIE.Busy
				    	WScript.Sleep 50
					Loop
					objIE.document.write "<html><head><title>DebugWriter Output</title></head><body>"
					objIE.document.write "<table  border=""1"" width=""100%""><tr><th>Time</th><th>intseverity</th><th>Description</th></tr>"
				end if
           		strieline = "<tr><td>" & now () & "</td>"
                Select Case intseverity
                    Case 0  strieline = strieLine & "<td bgcolor=""#00FF00"">Out0</td>"
                    Case 1  strieline = strieLine & "<td bgcolor=""#FF0000"">Err1</td>"
                    Case 2  strieline = strieLine & "<td bgcolor=""#FFFF00"">Wrn2</td>"
                    Case 3  strieline = strieLine & "<td>Inf3</td>"
                    Case Else strieline = strieLine & "<td>Dbg"&intseverity&"</td>"
                End Select
                strieline = strieline & "<td>" & strmessage & "</td></tr>"
				objIE.document.write cstr(strieline)
           end if

           '~ if (instr(DebugTarget,"mom") <>0) then
				'~ scriptContext.echo now() &","& intseverity &":"& strline & strMessage
           '~ end if

		end if  ' if status = active
		strline = ""
   	End Sub
	
	
	private function makefilename(wert)
		' Converts all invalid characters to valid file names
		wert = replace(wert,"\","-")
		wert = replace(wert,"/","-")
		wert = replace(wert,":","-")
		wert = replace(wert,"*","-")
		wert = replace(wert,"?","-")
		wert = replace(wert,"<","-")
		wert = replace(wert,"|","-")
		wert = replace(wert,"""","-")
		makefilename = wert
	end function
	
	private function Convert2Text(wert) 	' Converts non printable characters to "X" , so that Textfile is working
		dim loopcount, tempwert, inttest
		tempwert=""
		for loopcount = 1 to len(wert)   ' replace all unprintable characters  maybe easier and faster with RegEx
			tempwert = tempwert & chr(ascb(mid(wert,loopcount,1)))	
		next
		Convert2Text = tempwert
	end function
	
end class
