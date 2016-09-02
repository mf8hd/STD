;"Spot The Difference" a poor mans file integrity checker for windows
;
;Invocation:
;	SCRIPTNAME COMMAND PARAMETERS
;               /help				show help
;               /?                  show help
;
;Needs:
;	sqlite.dll
;

#cs
Changelog
1.0.0.0		integrate CONFIGFILE in DB table config (line by line as hexstring)
			help extended
			set file infos of executable with pragma compile()
			new programm name
1.1.0.0		Make TreeClimber ignore excludes Dirs
#ce

#cs
FixMe:
	  - possible sql injection through value of "Rule:" in config file
	  done - does /report "missing" realy work ???? GetAllRulenames() must return ALL rulenames from scanold AND scannew
ToDo:
	  - change name of DB field "status" to "valid"
	  - count directory entries and put the count in the DB
	  - email report via smtp
#ce


#cs
file format config.cfg

Rule:RULENAME			;name of rule
IncDirRec:PATH			;directory to include, including all subdirectories
ExcDirRec:PATH			;directory to exclude, including all subdirectories
IncDir:PATH				;directory to include, only this directory
ExcDir:PATH				;directory to exclude, only this directory
IncExt:FILEEXTENTION	;file extention to include
ExcExt:FILEEXTENTION	;file extention to exclude
IncExe					;all executable files, no matter what the extention is
IncAll					;all files, no matter what the extention is aka *.*
ExcExe					;no executable files, no matter what the extention is
ExcAll					;no files, no matter what the extention is aka *.*, only directories
End

Rule:Rule #1
IncDirRec:"d:\temp"
ExcDirRec:"d:\temp\unimportant"
IncDir:c:\windows\softwaredistribution
IncDir:"c:\windows"
ExcDir:"c:\windows\system32"
IncExt:doc
IncExt:xls
IncExt:txt
End

Rule:Documents I love
IncDirRec:"e:\Documents"
IncExt:*
ExcExt:pdf
End

Rule:All executables
IncDirRec:"c:\Program Files (x86)"
IncExe
End
#ce

#pragma compile(Console, true)
#pragma compile(UPX, False)

;Set file infos
#pragma compile(FileDescription,"file integrity checker for windows")
#pragma compile(ProductName,"Spot The Difference")
#pragma compile(ProductVersion,"1.1.0.0")
#pragma compile(LegalCopyright,"Reinhard Dittmann")
#pragma compile(InternalName,"STD")


#include <CRC32.au3>
#include <MD5.au3>
#include <array.au3>
#include <String.au3>
#include <FileConstants.au3>
#include <SQLite.au3>
#include <SQLite.dll.au3>
#include <MsgBoxConstants.au3>
#include <StringConstants.au3>

;Constants
global const $cVersion = FileGetVersion(@ScriptName,"ProductVersion")
global const $cScannameLimit = 65535	;max number of scannames resturnd from the DB


;Compile options
Opt("TrayIconHide", 1)
;Opt("MustDeclareVars", 1)

;Variables
$Path = ""				;directory to process
$Filename = ""			;File to process
$ReportFilename = ""	;report filename
$ConfigFilename = ""	;config filename (what to scan)
$sDBName = ""			;path of sqlite db file
$sScanname = ""			;name of the scan i.e. scantime
global $sScantime = ""	;date and time of the scan
global $hDBHandle = ""	;handle of db

local $sScannameOld = ""
local $sScannameNew = ""

local $aQueryResult = 0	;result of a query
local $hQuery = 0		;handle to a query

local $aCfgQueryResult = 0	;result of a query on table config
local $hCfgQuery = 0		;handle to a query on table config

$iQueryRows = 0			;returned rows of a query
$iQueryColumns = 0  	;returned colums of a query
global $aRule[1][2]		;one rule form config File
$sTempValid = ""		;"X" if scan is validated "-" if not yet validated
local $aRulenames = 0	;all rulenames in a scan
local $sTempText = ""	;
local $iTempCount = ""	;
global $aFileInfo[13]	;array with informations about the file

#cs
		 $aFileInfo[0]	;name
		 $aFileInfo[1]	;file exists 1 else 0
		 $aFileInfo[2]	;size
		 $aFileInfo[3]	;attributes
		 $aFileInfo[4]	;file modification timestamp
		 $aFileInfo[5]	;file creation timestamp
		 $aFileInfo[6]	;file accessed timestamp
		 $aFileInfo[7]	;version
		 $aFileInfo[8]	;8.3 short path+name
		 $aFileInfo[9]	;crc32
		 $aFileInfo[10]	;md5 hash
		 $aFileInfo[11]	;time it took to process the file
		 $aFileInfo[12]	;rulename
#ce

#cs
db stucture
   scantime			time the scan took place
   name				long filename incl. path
   status			1 = file exists
   size				size of file in byte
   attributes		file attributes
   mtime			file modification time
   ctime			file creation time
   atime			file access time
   version			file version information (exe or dll version)
   spath			short filename incl. path
   crc32			crc32 checksum of file content
   md5				md5	hash of file content
   ptime			time to process the file while scanning in ms
   rulename			name of the rule from config file, according to that the file was processed
#ce





;check commandline
if $CmdLine[0] < 1 then
   ShowHelp()
   exit (1)
EndIf

select
   Case $CmdLine[1] = "/importcfg"
	  if $CmdLine[0] < 3 then
 		 ShowHelp()
		 exit (1)
	  EndIf

	  $sDBName = $CmdLine[2]
	  $ConfigFilename = $CmdLine[3]

	  OpenDB($sDBName)

	  ;recreate table config
	  if FileExists($ConfigFilename) then
		 _SQLite_Exec(-1,"DROP TABLE IF EXISTS config;")
		 _SQLite_Exec(-1,"CREATE TABLE IF NOT EXISTS config (linenumber INTEGER PRIMARY KEY AUTOINCREMENT, line );")

		 ;import $ConfigFilename into table config
		 $iCfgLineNr = 1
		 While True

			$sTempCfgLine = ""
			$sTempCfgLine = FileReadLine($ConfigFilename,$iCfgLineNr)
			if @error then
			   ExitLoop
			EndIf
			_SQLite_Exec(-1,"INSERT INTO config(line) values ('" & _StringToHex($sTempCfgLine) & "');")
			$iCfgLineNr += 1
		 WEnd
	  EndIf
	  CloseDB()

   Case $CmdLine[1] = "/exportcfg"
	  if $CmdLine[0] < 3 then
 		 ShowHelp()
		 exit (1)
	  EndIf

	  $sDBName = $CmdLine[2]
	  $ConfigFilename = $CmdLine[3]

	  OpenDB($sDBName)


	  if FileExists($ConfigFilename) then
		 FileDelete($ConfigFilename)
	  EndIf

	  ;export table config into $ConfigFilename
	  $aQueryResult = 0
	  $hQuery = 0
	  _SQLite_Query(-1, "SELECT line FROM config ORDER BY linenumber ASC;",$hQuery)
	  While _SQLite_FetchData($hQuery, $aQueryResult) = $SQLITE_OK
		 FileWriteLine($ConfigFilename,_HexToString($aQueryResult[0]))
	  WEnd

	  CloseDB()

   Case $CmdLine[1] = "/validate"
	  if $CmdLine[0] < 3 then
 		 ShowHelp()
		 exit (1)
	  EndIf

	  $sDBName = $CmdLine[2]
	  $sScanname = $CmdLine[3]

	  OpenDB($sDBName)

	  $aQueryResult = 0
	  if GetScannames($sScanname,$aQueryResult) Then
		 for $i = 2 to $aQueryResult[0]
			;_ArrayDisplay($aQueryResult)
			;$aQueryResult[$i]
			_SQLite_Exec(-1,"update files set status = '1' where scantime = '" & $aQueryResult[$i] & "' and status = '0';")
		 next
	  EndIf

	  CloseDB()


   Case $CmdLine[1] = "/invalidate"
	  if $CmdLine[0] < 3 then
 		 ShowHelp()
		 exit (1)
	  EndIf

	  $sDBName = $CmdLine[2]
	  $sScanname = $CmdLine[3]

	  OpenDB($sDBName)

	  $aQueryResult = 0
	  if GetScannames($sScanname,$aQueryResult) Then
		 for $i = 2 to $aQueryResult[0]
			;_ArrayDisplay($aQueryResult)
			;$aQueryResult[$i]
			_SQLite_Exec(-1,"update files set status = '0' where scantime = '" & $aQueryResult[$i] & "' and status = '1';")
		 next
	  EndIf

	  CloseDB()


   Case $CmdLine[1] = "/delete"
	  if $CmdLine[0] < 3 then
 		 ShowHelp()
		 exit (1)
	  EndIf

	  $sDBName = $CmdLine[2]
	  $sScanname = $CmdLine[3]

	  OpenDB($sDBName)

	  $aQueryResult = 0
	  if GetScannames($sScanname,$aQueryResult) Then
		 for $i = 2 to $aQueryResult[0]
			;_ArrayDisplay($aQueryResult)
			;$aQueryResult[$i]
			_SQLite_Exec(-1,"delete from files where scantime = '" & $aQueryResult[$i] & "';")
		 next
	  EndIf

	  CloseDB()

   Case $CmdLine[1] = "/list"
	  if $CmdLine[0] < 2 then
		 ShowHelp()
		 exit (1)
	  EndIf
	  $sDBName = $CmdLine[2]
	  OpenDB($sDBName)

	  ;get all scans in db
	  $aQueryResult = 0
	  ;_SQLite_GetTable2d(-1, "select distinct scantime from files order by scantime desc;", $aQueryResult, $iQueryRows, $iQueryColumns)
	  _SQLite_GetTable2d(-1, "SELECT scantime,count(name),status from files group by scantime order by scantime desc;", $aQueryResult, $iQueryRows, $iQueryColumns)
	  if not @error Then
		 ;_ArrayDisplay($aQueryResult)
		 ConsoleWrite(StringFormat("%-5s %-14s %-10s %-8s %s","Valid","Scanname","Date","Time","Entries") & @CRLF)
		 ConsoleWrite(StringFormat("%-5s %-14s %-10s %-8s %s","-----","--------------","----------","--------","--------------"))
		 for $i = 1 to $iQueryRows
			if $aQueryResult[$i][2] = 1 Then
			   $sTempValid = "X"
			Else
			   $sTempValid = "-"
			EndIf

			ConsoleWrite(@CRLF & StringFormat("%5s %-14s %4s.%2s.%2s %2s:%2s:%2s %s",$sTempValid,$aQueryResult[$i][0],StringMid($aQueryResult[$i][0],1,4),StringMid($aQueryResult[$i][0],5,2),StringMid($aQueryResult[$i][0],7,2),StringMid($aQueryResult[$i][0],9,2),StringMid($aQueryResult[$i][0],11,2),StringMid($aQueryResult[$i][0],13,2),$aQueryResult[$i][1]))
			;ConsoleWrite(StringFormat("%-14s",$aQueryResult[$i][0]) & @CRLF)
		 next

	  EndIf

	  CloseDB()

   Case $CmdLine[1] = "/scan"
	  if $CmdLine[0] < 2 then
 		 ShowHelp()
		 exit (1)
	  EndIf

	  $sDBName = $CmdLine[2]

	  OpenDB($sDBName)

	  $sScantime = @YEAR & @MON & @MDAY & @HOUR & @MIN & @SEC

	  ;read the rules from table config
	  $iCfgLineNr = 1
	  $iLastRuleRead = False
	  $aCfgQueryResult = 0
	  $hCfgQuery = 0
	  _SQLite_Query(-1, "SELECT line FROM config ORDER BY linenumber ASC;",$hCfgQuery)
	  While True
		 ;read one rule from table config
		 dim $aRule[1][2]
		 While True
			#cs
			;read one rule form $ConfigFilename
			$sTempCfgLine = ""
			$sTempCfgLine = FileReadLine($ConfigFilename,$iCfgLineNr)
			if @error then
			   $iLastRuleRead = True
			   ExitLoop
			EndIf
			#ce

			;read one line form table config
			$sTempCfgLine = ""
			if _SQLite_FetchData($hCfgQuery, $aCfgQueryResult) = $SQLITE_OK Then
			   $sTempCfgLine = _HexToString($aCfgQueryResult[0])
			   ;_ArrayDisplay($aQueryResult[0])
			Else
			   $iLastRuleRead = True
			   ExitLoop
			EndIf

			;Output line of rule
			;ConsoleWrite($sTempCfgLine & @CRLF)
			#cs
			file format config.cfg

			Rule:RULENAME			;name of rule
			IncDirRec:PATH			;directory to include, including all subdirectories
			ExcDirRec:PATH			;directory to exclude, including all subdirectories
			IncDir:PATH				;directory to include, only this directory
			ExcDir:PATH				;directory to exclude, only this directory
			IncExt:FILEEXTENTION	;file extention to include
			ExcExt:FILEEXTENTION	;file extention to exclude
			IncExe					;all executable files, no matter what the extention is
			IncAll					;all files, no matter what the extention is aka *.*
			ExcExe					;no executable files, no matter what the extention is
			ExcAll					;no files, no matter what the extention is aka *.*, only directories
			End
			#ce

			;strip whitespaces at begin of line
			$sTempCfgLine = StringStripWS($sTempCfgLine,$STR_STRIPLEADING )

			;tranfer rule lines to $aRule
			;strip leading and trailing " from directories
			;strip trailing \ from directories
			Select
			   Case stringleft($sTempCfgLine,stringlen("Rule:")) = "Rule:"
				  redim $aRule[UBound($aRule,1)+1][2]
				  $aRule[UBound($aRule,1)-1][0] = "Rule:"
				  $aRule[UBound($aRule,1)-1][1] = StringTrimLeft($sTempCfgLine,stringlen("Rule:"))
			   Case stringleft($sTempCfgLine,stringlen("IncDirRec:")) = "IncDirRec:"
  				  redim $aRule[UBound($aRule,1)+1][2]
				  $aRule[UBound($aRule,1)-1][0] = "IncDirRec:"
				  $aRule[UBound($aRule,1)-1][1] = StringReplace(StringTrimLeft($sTempCfgLine,stringlen("IncDirRec:")),"""","")
				  if StringRight($aRule[UBound($aRule,1)-1][1],1) = "\" then $aRule[UBound($aRule,1)-1][1] = StringTrimRight($aRule[UBound($aRule,1)-1][1],1)
			   Case stringleft($sTempCfgLine,stringlen("ExcDirRec:")) = "ExcDirRec:"
  				  redim $aRule[UBound($aRule,1)+1][2]
				  $aRule[UBound($aRule,1)-1][0] = "ExcDirRec:"
				  $aRule[UBound($aRule,1)-1][1] = StringReplace(StringTrimLeft($sTempCfgLine,stringlen("ExcDirRec:")),"""","")
				  if StringRight($aRule[UBound($aRule,1)-1][1],1) = "\" then $aRule[UBound($aRule,1)-1][1] = StringTrimRight($aRule[UBound($aRule,1)-1][1],1)
			   Case stringleft($sTempCfgLine,stringlen("IncDir:")) = "IncDir:"
  				  redim $aRule[UBound($aRule,1)+1][2]
				  $aRule[UBound($aRule,1)-1][0] = "IncDir:"
				  $aRule[UBound($aRule,1)-1][1] = StringReplace(StringTrimLeft($sTempCfgLine,stringlen("IncDir:")),"""","")
				  if StringRight($aRule[UBound($aRule,1)-1][1],1) = "\" then $aRule[UBound($aRule,1)-1][1] = StringTrimRight($aRule[UBound($aRule,1)-1][1],1)
			   Case stringleft($sTempCfgLine,stringlen("ExcDir:")) = "ExcDir:"
  				  redim $aRule[UBound($aRule,1)+1][2]
				  $aRule[UBound($aRule,1)-1][0] = "ExcDir:"
				  $aRule[UBound($aRule,1)-1][1] = StringReplace(StringTrimLeft($sTempCfgLine,stringlen("ExcDir:")),"""","")
				  if StringRight($aRule[UBound($aRule,1)-1][1],1) = "\" then $aRule[UBound($aRule,1)-1][1] = StringTrimRight($aRule[UBound($aRule,1)-1][1],1)
			   Case stringleft($sTempCfgLine,stringlen("IncExt:")) = "IncExt:"
  				  redim $aRule[UBound($aRule,1)+1][2]
				  $aRule[UBound($aRule,1)-1][0] = "IncExt:"
				  $aRule[UBound($aRule,1)-1][1] = StringTrimLeft($sTempCfgLine,stringlen("IncExt:"))
			   Case stringleft($sTempCfgLine,stringlen("ExcExt:")) = "ExcExt:"
  				  redim $aRule[UBound($aRule,1)+1][2]
				  $aRule[UBound($aRule,1)-1][0] = "ExcExt:"
				  $aRule[UBound($aRule,1)-1][1] = StringTrimLeft($sTempCfgLine,stringlen("ExcExt:"))
			   Case StringStripWS($sTempCfgLine,$STR_STRIPALL ) = "IncExe"
  				  redim $aRule[UBound($aRule,1)+1][2]
				  $aRule[UBound($aRule,1)-1][0] = "IncExe"
				  $aRule[UBound($aRule,1)-1][1] = ""
			   Case StringStripWS($sTempCfgLine,$STR_STRIPALL ) = "ExcExe"
  				  redim $aRule[UBound($aRule,1)+1][2]
				  $aRule[UBound($aRule,1)-1][0] = "ExcExe"
				  $aRule[UBound($aRule,1)-1][1] = ""
			   Case StringStripWS($sTempCfgLine,$STR_STRIPALL ) = "IncAll"
  				  redim $aRule[UBound($aRule,1)+1][2]
				  $aRule[UBound($aRule,1)-1][0] = "IncAll"
				  $aRule[UBound($aRule,1)-1][1] = ""
			   Case StringStripWS($sTempCfgLine,$STR_STRIPALL ) = "ExcAll"
  				  redim $aRule[UBound($aRule,1)+1][2]
				  $aRule[UBound($aRule,1)-1][0] = "ExcAll"
				  $aRule[UBound($aRule,1)-1][1] = ""

			   case Else
			EndSelect



			$iCfgLineNr = $iCfgLineNr + 1
			if StringStripWS($sTempCfgLine,$STR_STRIPALL ) = "End" then
			   ExitLoop
			EndIf
		 WEnd
		 ;last line of config file is read
		 if $iLastRuleRead = True then ExitLoop


		 ;_ArrayDisplay($aRule)
		 ;exit(0)

		 ;process rule
		 for $i=1 to UBound($aRule,1)-1
			;MsgBox(0,"UBound",$aRule[$i][0] & @crlf & $aRule[$i][1])
			if $aRule[$i][0] = "IncDirRec:" then TreeClimber($aRule[$i][1],$aRule,True)
			if $aRule[$i][0] = "IncDir:" 	then TreeClimber($aRule[$i][1],$aRule,False)
		 ;TreeClimber($Path)
		 Next

	  WEnd
	  ;end read $ConfigFilename

	  CloseDB()

   Case $CmdLine[1] = "/report"

	  if $CmdLine[0] < 3 then
		 ShowHelp()
		 exit (1)
	  EndIf

	  $sDBName = $CmdLine[2]
	  $ReportFilename = $CmdLine[3]

	  OpenDB($sDBName)


	  FileDelete($ReportFilename)

	  ;check

	  ;drop old views
	  _SQLite_Exec(-1,"DROP VIEW IF EXISTS scanold;")
	  _SQLite_Exec(-1,"DROP VIEW IF EXISTS scannew;")




	  $sScannameNew = ""
	  $aQueryResult = 0
	  if GetScannames("last",$aQueryResult) Then
		 ;_ArrayDisplay($aQueryResult)
		 $sScannameNew = $aQueryResult[2]
	  EndIf

	  $sScannameOld = ""
	  $aQueryResult = 0
	  if GetScannames("lastvalid",$aQueryResult) Then
		 ;_ArrayDisplay($aQueryResult)
		 $sScannameOld = $aQueryResult[2]
	  EndIf


	  if $sScannameOld = "" or $sScannameNew = "" Then
	  else

		 ;build views

		 ConsoleWrite("Generating report for old:" & $sScannameOld & " <-> new:" & $sScannameNew)

		 _SQLite_Exec(-1,"create view if not exists scannew as select * from files where scantime='" & $sScannameNew & "';")
		 _SQLite_Exec(-1,"create view if not exists scanold as select * from files where scantime='" & $sScannameOld & "';")

		 ;SELECT scantime,rulename FROM files where scantime = '20160514212002' group by rulename order by rulename asc;
		 $aRulenames = 0
		 if GetAllRulenames($sScannameNew,$sScannameOld,$aRulenames) Then
			;_ArrayDisplay($aRulenames)

			FileWriteLine($ReportFilename,@CRLF & "report for old scan:" & $sScannameOld & " <-> new scan:" & $sScannameNew & @CRLF)
			FileWriteLine($ReportFilename,"generated: " & @YEAR & "." & @MON & "." & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC & @CRLF)
			FileWriteLine($ReportFilename,@CRLF & "======================================================================" & @CRLF)

			$sTempText = ""
			FileWriteLine($ReportFilename,StringFormat(@CRLF & "%-40s %7s %7s %7s","rulename","changed","new","missing"))
			FileWriteLine($ReportFilename,StringFormat("%-40s %7s %7s %7s","--------","-------","-------","-------"))

		    ;summery per rule
			for $i = 2 to $aRulenames[0]
			   $sTempText = StringFormat("%-40s",$aRulenames[$i])

			   ;return scan differences
			   $aQueryResult = 0
			   $hQuery = 0
			   $iTempCount = 0
			   _SQLite_Query(-1, "SELECT scannew.rulename,count(scannew.rulename) FROM scannew,scanold WHERE scannew.name = scanold.name and scannew.rulename = scanold.rulename and scannew.rulename = '" & $aRulenames[$i] & "' and (scannew.size <> scanold.size or scannew.attributes <> scanold.attributes or scannew.mtime <> scanold.mtime or scannew.ctime <> scanold.ctime or scannew.atime <> scanold.atime or scannew.version <> scanold.version or scannew.spath <> scanold.spath or scannew.crc32 <> scanold.crc32 or scannew.md5 <> scanold.md5);",$hQuery)
			   While _SQLite_FetchData($hQuery, $aQueryResult) = $SQLITE_OK
				  ;_ArrayDisplay($aQueryResult)
				  ;OutputLineOfQueryResultSummary($aQueryResult,$ReportFilename)
				  $iTempCount = $aQueryResult[1]
			   WEnd
			   $sTempText &= StringFormat(" %7i",$iTempCount)

			   ;return new files
			   $aQueryResult = 0
			   $hQuery = 0
			   $iTempCount = 0
			   _SQLite_Query(-1,"SELECT scannew.rulename,count(scannew.rulename) FROM scannew LEFT JOIN scanold ON scannew.name = scanold.name and scannew.rulename = scanold.rulename WHERE scannew.rulename = '" & $aRulenames[$i] & "' and scanold.name IS NULL;" ,$hQuery)
			   While _SQLite_FetchData($hQuery, $aQueryResult) = $SQLITE_OK
				  ;OutputLineOfQueryResultSummary($aQueryResult,$ReportFilename)
				  $iTempCount = $aQueryResult[1]
			   WEnd
			   $sTempText &= StringFormat(" %7i",$iTempCount)

			   ;return deleted files
			   $aQueryResult = 0
			   $hQuery = 0
			   $iTempCount = 0
			   _SQLite_Query(-1,"SELECT scanold.rulename,count(scanold.rulename) FROM scanold LEFT JOIN scannew ON scannew.name = scanold.name and scannew.rulename = scanold.rulename WHERE scanold.rulename = '" & $aRulenames[$i] & "' and scannew.name IS NULL;",$hQuery)
			   While _SQLite_FetchData($hQuery, $aQueryResult) = $SQLITE_OK
				  ;OutputLineOfQueryResultSummary($aQueryResult,$ReportFilename)
				  $iTempCount = $aQueryResult[1]
			   WEnd
			   $sTempText &= StringFormat(" %7i",$iTempCount)

			   FileWriteLine($ReportFilename,$sTempText)
			Next
			FileWriteLine($ReportFilename,@CRLF & "======================================================================" & @CRLF)


			;list per rule
			for $i = 2 to $aRulenames[0]
			   FileWriteLine($ReportFilename,@crlf & "---- rule: " & $aRulenames[$i] & " ----")

			   ;return scan differences
			   $aQueryResult = 0
			   $hQuery = 0
			   _SQLite_Query(-1, "SELECT scannew.name FROM scannew,scanold WHERE scannew.name = scanold.name and scannew.rulename = scanold.rulename and scannew.rulename = '" & $aRulenames[$i] & "' and (scannew.size <> scanold.size or scannew.attributes <> scanold.attributes or scannew.mtime <> scanold.mtime or scannew.ctime <> scanold.ctime or scannew.atime <> scanold.atime or scannew.version <> scanold.version or scannew.spath <> scanold.spath or scannew.crc32 <> scanold.crc32 or scannew.md5 <> scanold.md5);",$hQuery)
			   While _SQLite_FetchData($hQuery, $aQueryResult) = $SQLITE_OK
				  ;OutputLineOfQueryResult($aQueryResult,$ReportFilename)
				  FileWriteLine($ReportFilename,StringFormat("%-8s : %s","changed",_HexToString($aQueryResult[0])))
			   WEnd

			   ;return new files
			   $aQueryResult = 0
			   $hQuery = 0
			   _SQLite_Query(-1,"SELECT scannew.name FROM scannew LEFT JOIN scanold ON scannew.name = scanold.name and scannew.rulename = scanold.rulename WHERE scannew.rulename = '" & $aRulenames[$i] & "' and scanold.name IS NULL;" ,$hQuery)
			   While _SQLite_FetchData($hQuery, $aQueryResult) = $SQLITE_OK
				  ;OutputLineOfQueryResult($aQueryResult,$ReportFilename)
				  FileWriteLine($ReportFilename,StringFormat("%-8s : %s","new",_HexToString($aQueryResult[0])))
			   WEnd

			   ;return deleted files
			   $aQueryResult = 0
			   $hQuery = 0
			   _SQLite_Query(-1,"SELECT scanold.name FROM scanold LEFT JOIN scannew ON scannew.name = scanold.name and scannew.rulename = scanold.rulename WHERE scanold.rulename = '" & $aRulenames[$i] & "' and scannew.name IS NULL;",$hQuery)
			   While _SQLite_FetchData($hQuery, $aQueryResult) = $SQLITE_OK
				  ;OutputLineOfQueryResult($aQueryResult,$ReportFilename)
				  FileWriteLine($ReportFilename,StringFormat("%-8s : %s","missing",_HexToString($aQueryResult[0])))
			   WEnd

			Next
			FileWriteLine($ReportFilename,@CRLF & "======================================================================" & @CRLF)

			;details per rule
			for $i = 2 to $aRulenames[0]
			   FileWriteLine($ReportFilename,@crlf & "---- rule: " & $aRulenames[$i] & " ----")

			   ;return scan differences
			   $aQueryResult = 0
			   $hQuery = 0
			   _SQLite_Query(-1, "SELECT scanold.*,scannew.* FROM scannew,scanold WHERE scannew.name = scanold.name and scannew.rulename = scanold.rulename and scannew.rulename = '" & $aRulenames[$i] & "' and (scannew.size <> scanold.size or scannew.attributes <> scanold.attributes or scannew.mtime <> scanold.mtime or scannew.ctime <> scanold.ctime or scannew.atime <> scanold.atime or scannew.version <> scanold.version or scannew.spath <> scanold.spath or scannew.crc32 <> scanold.crc32 or scannew.md5 <> scanold.md5);",$hQuery)
			   While _SQLite_FetchData($hQuery, $aQueryResult) = $SQLITE_OK
				  OutputLineOfQueryResult($aQueryResult,$ReportFilename)
			   WEnd

			   ;return new files
			   $aQueryResult = 0
			   $hQuery = 0
			   _SQLite_Query(-1,"SELECT scanold.*,scannew.* FROM scannew LEFT JOIN scanold ON scannew.name = scanold.name and scannew.rulename = scanold.rulename WHERE scannew.rulename = '" & $aRulenames[$i] & "' and scanold.name IS NULL;" ,$hQuery)
			   While _SQLite_FetchData($hQuery, $aQueryResult) = $SQLITE_OK
				  OutputLineOfQueryResult($aQueryResult,$ReportFilename)
			   WEnd

			   ;return deleted files
			   $aQueryResult = 0
			   $hQuery = 0
			   _SQLite_Query(-1,"SELECT scanold.*,scannew.* FROM scanold LEFT JOIN scannew ON scannew.name = scanold.name and scannew.rulename = scanold.rulename WHERE scanold.rulename = '" & $aRulenames[$i] & "' and scannew.name IS NULL;",$hQuery)
			   While _SQLite_FetchData($hQuery, $aQueryResult) = $SQLITE_OK
				  OutputLineOfQueryResult($aQueryResult,$ReportFilename)
			   WEnd

			Next
		 EndIf

		 ;drop old views
		 _SQLite_Exec(-1,"DROP VIEW IF EXISTS scanold;")
		 _SQLite_Exec(-1,"DROP VIEW IF EXISTS scannew;")

	  EndIf

	  CloseDB()

   Case $CmdLine[1] = "/help"
	  ShowHelp()

   Case $CmdLine[1] = "/?"
	  ShowHelp()

   case Else
	  ShowHelp()

EndSelect


Exit(0)





;---------------------------------------------------
; Functions
;---------------------------------------------------

Func GetAllRulenames($sScan1,$sScan2, ByRef $aRules)

   ;return all the rules in scan $sScan
   ;----------------------------------------------------------------

   local $sSQL = ""

   local $iTempQueryRows = 0
   local $iTempQueryColumns = 0

   $sSQL = "SELECT rulename FROM files where scantime = '" & $sScan1 & "' or scantime = '" & $sScan2 & "' group by rulename order by rulename asc;"

   _SQLite_GetTable(-1, $sSQL, $aRules, $iTempQueryRows, $iTempQueryColumns)
   if not @error Then
	  if $iTempQueryRows >= 1 then
		 ;MsgBox(0,"Test",$iQueryRows & @CRLF & $iQueryColumns)
		 ;_ArrayDisplay($aScans)
		 Return True
	  EndIf
   EndIf

   Return False

EndFunc


Func GetScannames($sScan,ByRef $aScans)

   ;return the scans described by $sScan
   ;$sScan can be "all","last","invalid","valid","lastinvalid","lastvalid","oldvalid" or the name of a scan
   ;----------------------------------------------------------------

   local $sSQL = ""

   local $iTempQueryRows = 0
   local $iTempQueryColumns = 0
   Select
	  Case $sScan = "all"
		 $sSQL = "SELECT scantime from files group by scantime order by scantime desc limit " & $cScannameLimit & ";"
	  Case $sScan = "last"
		 $sSQL = "SELECT scantime from files group by scantime order by scantime desc limit 1;"
	  Case $sScan = "invalid"
		 $sSQL = "SELECT scantime from files where status = '0' group by scantime order by scantime desc limit " & $cScannameLimit & ";"
	  Case $sScan = "valid"
		 $sSQL = "SELECT scantime from files where status = '1' group by scantime order by scantime desc limit " & $cScannameLimit & ";"
	  Case $sScan = "lastinvalid"
		 $sSQL = "SELECT scantime from files where status = '0' group by scantime order by scantime desc limit 1;"
	  Case $sScan = "lastvalid"
		 $sSQL = "SELECT scantime from files where status = '1' group by scantime order by scantime desc limit 1;"
	  Case $sScan = "oldvalid"
		 $sSQL = "SELECT scantime from files where status = '1' group by scantime order by scantime desc limit " & $cScannameLimit & " offset 1;"
	  case Else
		 $sSQL = "SELECT scantime from files where scantime = '" & $sScan & "' group by scantime order by scantime desc limit 1;"
   EndSelect

   _SQLite_GetTable(-1, $sSQL, $aScans, $iTempQueryRows, $iTempQueryColumns)
   if not @error Then
	  if $iTempQueryRows >= 1 then
		 ;MsgBox(0,"Test",$iQueryRows & @CRLF & $iQueryColumns)
		 ;_ArrayDisplay($aScans)
		 Return True
	  EndIf
   EndIf

   Return False

EndFunc


Func ShowHelp()

   ;show help
   ;---------------------------------------

   local $sText = ""

   $sText &= "Spot The Difference (" & $cVersion & ")" & @CRLF
   $sText &= "A poor mans file integrity checker." & @CRLF
   $sText &= @CRLF
   $sText &= "Prerequisites:" & @CRLF
   $sText &= "sqlite.dll in searchpath or the same directory as " & @ScriptName & @CRLF
   $sText &= @CRLF
   $sText &= "Invocation:" & @CRLF
   $sText &= @ScriptName & " COMMAND PARAMETERS" & @CRLF
   $sText &= @CRLF
   $sText &= @CRLF
   $sText &= "COMMANDS and their PARAMETERS:" & @CRLF

   $sText &= @CRLF
   $sText &= @ScriptName & " /importcfg DB CONFIGFILE" & @CRLF
   $sText &= @ScriptName & " /importcfg c:\test.sqlite c:\config.cfg" & @CRLF
   $sText &= "Import CONFIGFILE into DB." & @CRLF
   $sText &= "An existing config with rules in DB will be replaced." & @CRLF
   $sText &= @CRLF
   $sText &= @ScriptName & " /exportcfg DB CONFIGFILE" & @CRLF
   $sText &= @ScriptName & " /exportcfg c:\test.sqlite c:\config.cfg" & @CRLF
   $sText &= "Export config with rules form DB into CONFIGFILE." & @CRLF
   $sText &= "An existing CONFIGFILE will be overwritten." & @CRLF

   $sText &= @CRLF
   $sText &= @ScriptName & " /scan DB" & @CRLF
   $sText &= @ScriptName & " /scan c:\test.sqlite" & @CRLF
   $sText &= "Scan directories according to the rules in a previously imported CONFIGFILE" & @CRLF
   $sText &= "and insert directory and/or file information into DB" & @CRLF

   $sText &= @CRLF
   $sText &= @ScriptName & " /report DB REPORTFILE" & @CRLF
   $sText &= @ScriptName & " /report c:\test.sqlite c:\report.txt" & @CRLF
   $sText &= "Write the differences between last and last validated scan to REPORTFILE" & @CRLF

   $sText &= @CRLF
   $sText &= @ScriptName & " /list DB" & @CRLF
   $sText &= @ScriptName & " /list c:\test.sqlite" & @CRLF
   $sText &= "List all scans in DB" & @CRLF
   $sText &= @CRLF
   $sText &= @ScriptName & " /validate DB SCANNAME" & @CRLF
   $sText &= @ScriptName & " /validate c:\test.sqlite 20160514131610" & @CRLF
   $sText &= "Set status of scan SCANNAME to valid. SCANNAME is either an existing scan" & @CRLF
   $sText &= "or a SPECIAL_NAME" & @CRLF
   $sText &= @CRLF
   $sText &= @ScriptName & " /invalidate DB SCANNAME" & @CRLF
   $sText &= @ScriptName & " /invalidate c:\test.sqlite 20160514131610" & @CRLF
   $sText &= "Set status of scan SCANNAME to invalid. SCANNAME is either an existing scan" & @CRLF
   $sText &= "or a SPECIAL_NAME" & @CRLF
   $sText &= @CRLF
   $sText &= @ScriptName & " /delete DB SCANNAME" & @CRLF
   $sText &= @ScriptName & " /delete c:\test.sqlite 20160514131610" & @CRLF
   $sText &= "Delete the scan SCANNAME. SCANNAME is either an existing scan or a SPECIAL_NAME" & @CRLF

   $sText &= @CRLF
   $sText &= @ScriptName & " /help" & @CRLF
   $sText &= "Show this help" & @CRLF
   $sText &= @CRLF
   $sText &= @ScriptName & " /?" & @CRLF
   $sText &= "Show this help" & @CRLF

   $sText &= @CRLF
   $sText &= @CRLF
   $sText &= "SPECIAL_NAME:" & @CRLF
   $sText &= @CRLF
   $sText &= "all           all the scans in DB" & @CRLF
   $sText &= "last          the most recent scan in DB" & @CRLF
   $sText &= "invalid       all not validated scans in DB" & @CRLF
   $sText &= "valid         all validated scans in DB" & @CRLF
   $sText &= "lastinvalid   the most recent not validated scan in DB" & @CRLF
   $sText &= "lastvalid     the most recent validated scan in DB" & @CRLF
   $sText &= "oldvalid      all validated scans in DB except lastvalid" & @CRLF


   $sText &= @CRLF
   $sText &= @CRLF
   $sText &= "DB:" & @CRLF
   $sText &= @CRLF
   $sText &= 'SQLite database files. It will be generated if it does not exist.' & @CRLF
   $sText &= 'It contains all data of all scans and the imported CONFIGFILE.' & @CRLF
   $sText &= 'If the file gets big, delete old scans.' & @CRLF


   $sText &= @CRLF
   $sText &= @CRLF
   $sText &= "REPORTFILE:" & @CRLF
   $sText &= @CRLF
   $sText &= 'Textfile that contains the differences of two scans in human readable form.' & @CRLF


   $sText &= @CRLF
   $sText &= @CRLF
   $sText &= "CONFIGFILE:" & @CRLF
   $sText &= @CRLF
   $sText &= 'Describes one or more scan rules. A rule is a code block that starts with a' & @CRLF
   $sText &= '"Rule" statement and ends with an "End" statement.' & @CRLF
   $sText &= "A rule block consists of statements that describe which directories and file" & @CRLF
   $sText &= "extentions should be included in or excluded from the scan." & @CRLF
   $sText &= "A line that starts with # indicates a comment line." & @CRLF
   $sText &= "" & @CRLF
   $sText &= "Rule:RULENAME          start of rule" & @CRLF
   $sText &= "IncDirRec:PATH         directory to include, including all subdirectories" & @CRLF
   $sText &= "ExcDirRec:PATH         directory to exclude, including all subdirectories" & @CRLF
   $sText &= "IncDir:PATH            directory to include, only this directory" & @CRLF
   $sText &= "ExcDir:PATH            directory to exclude, only this directory" & @CRLF
   $sText &= "IncExt:FILEEXTENTION   file extention to include" & @CRLF
   $sText &= "ExcExt:FILEEXTENTION   file extention to exclude" & @CRLF
   $sText &= "IncExe                 all executable files, no matter what the extention is." & @CRLF
   $sText &= "                       This statement is very slow, since the first two bytes of" & @CRLF
   $sText &= "                       EVERY file in the IncDir are read!" & @CRLF
   $sText &= "IncAll                 all files, no matter what the extention is aka *.*" & @CRLF
   $sText &= "ExcExe                 no executable files, no matter what the extention is" & @CRLF
   $sText &= "ExcAll                 no files, no matter what the extention is aka *.*," & @CRLF
   $sText &= "                       only directories" & @CRLF
   $sText &= "End                    end of rule" & @CRLF
   $sText &= "" & @CRLF
   $sText &= "RULENAME               name of rule" & @CRLF
   $sText &= "                       e.g.: My first Rule" & @CRLF
   $sText &= "PATH                   one directory name" & @CRLF
   $sText &= '                       e.g.: "\\pc\share\my files","c:\temp","c:\temp\",c:\temp' & @CRLF
   $sText &= "FILEEXTENTION          one file extention" & @CRLF
   $sText &= '                       e.g.: doc,xls,xlsx,txt,pdf,PDF,TxT,Doc' & @CRLF
   $sText &= "" & @CRLF
   $sText &= "Example:" & @CRLF
   $sText &= '#' & @CRLF
   $sText &= '# The rule is named "Word and Excel" and includes all *.doc,*.docx,*.xls,*.xlsx' & @CRLF
   $sText &= '# files in "c:\my msoffice files" and all subdirectories, with the exception of' & @CRLF
   $sText &= '# "c:\my msoffice files\temp" and all its subdirectories.' & @CRLF
   $sText &= '#' & @CRLF
   $sText &= 'Rule:Word and Excel' & @CRLF
   $sText &= '  IncDirRec:"c:\my msoffice files"' & @CRLF
   $sText &= '  ExcDirRec:"c:\my msoffice files\temp"' & @CRLF
   $sText &= '  IncExt:doc' & @CRLF
   $sText &= '  IncExt:docx' & @CRLF
   $sText &= '  IncExt:xls' & @CRLF
   $sText &= '  IncExt:xlsx' & @CRLF
   $sText &= 'End' & @CRLF

   $sText &= @CRLF
   $sText &= @CRLF
   $sText &= "Quick start:" & @CRLF
   $sText &= "" & @CRLF
   $sText &= " 1. Create a CONFIGFILE with an editor" & @CRLF
   $sText &= " 2. Import CONFIGFILE into DB:" & @CRLF
   $sText &= "    " & @ScriptName & " /importcfg DB CONFIGFILE" & @CRLF
   $sText &= " 3. Initial scan:" & @CRLF
   $sText &= "    " & @ScriptName & " /scan DB" & @CRLF
   $sText &= " 4. Validate initial scan:" & @CRLF
   $sText &= "    " & @ScriptName & " /validate DB last" & @CRLF
   $sText &= " 5. Delete all existing invalid scans (optional):" & @CRLF
   $sText &= "    " & @ScriptName & " /delete DB invalid" & @CRLF
   $sText &= " 6. Normal scan:" & @CRLF
   $sText &= "    " & @ScriptName & " /scan DB" & @CRLF
   $sText &= " 7. Create report:" & @CRLF
   $sText &= "    " & @ScriptName & " /report DB REPORTFILE" & @CRLF
   $sText &= " 8. Review the report with an editor." & @CRLF
   $sText &= " 9. Validate last scan:" & @CRLF
   $sText &= "    " & @ScriptName & " /validate DB last" & @CRLF
   $sText &= "10. Delete all old valid scans (optional):" & @CRLF
   $sText &= "    " & @ScriptName & " /delete DB oldvalid" & @CRLF
   $sText &= "11. Start next cycle, goto 5." & @CRLF

   ConsoleWrite($sText)

EndFunc


Func OpenDB($sDBName)

   ;open and initialize database if needed
   ;---------------------------------------

   _SQLite_Startup()
   If @error Then
	   MsgBox($MB_SYSTEMMODAL, "SQLite Error", "SQLite3.dll Can't be Loaded!")
	   Exit -1
   EndIf
   ;ConsoleWrite("_SQLite_LibVersion=" & _SQLite_LibVersion() & @CRLF)

   $hDBHandle = _SQLite_Open($sDBName)


   ;create new db structure if needed
   _SQLite_Exec(-1,"CREATE TABLE IF NOT EXISTS files (scantime,name,status,size,attributes,mtime,ctime,atime,version,spath,crc32,md5,ptime,rulename, PRIMARY KEY(scantime,name));")
   _SQLite_Exec(-1,"CREATE TABLE IF NOT EXISTS config (linenumber INTEGER PRIMARY KEY AUTOINCREMENT, line );")


   Return True
EndFunc


Func CloseDB()

   ;close database
   ;--------------------

   _SQLite_Close($hDBHandle)
   _SQLite_Shutdown()

   Return True
EndFunc


Func GetRulename(ByRef $aRule)

   ;get name of the rule
   ;--------------------

   local $sRulename = ""

   $iMax = UBound($aRule,1)-1
   for $i = 1 to $iMax
	  ;$aRule[$i][0]
	  ;$aRule[$i][1]
	  if $aRule[$i][0] = "Rule:" then $sRulename = $aRule[$i][1]
   Next

   return $sRulename
EndFunc


Func IsIncludedByRule($PathOrFile,ByRef $aRule)

   ;determin if $PathOrFile satisfy the current rule
   ;--------------------------------------------------

   ;$PathOrFile is a directory if there is a \ at the ende !
   ;$PathOrFile is a file if there is NO \ at the ende !

   #cs
	  file format config.cfg

	  Rule:RULENAME				;name of rule
	  IncDirRec:PATH			;directory to include, including all subdirectories
	  ExcDirRec:PATH			;directory to exclude, including all subdirectories
	  IncDir:PATH				;directory to include, only this directory
	  ExcDir:PATH				;directory to exclude, only this directory
	  IncExt:FILEEXTENTION		;file extention to include
	  ExcExt:FILEEXTENTION		;file extention to exclude
	  IncExe					;all executable files, no matter what the extention is
	  IncAll					;all files, no matter what the extention is aka *.*
	  ExcExe					;no executable files, no matter what the extention is
	  ExcAll					;no files, no matter what the extention is aka *.*, only directories
	  End
   #ce

   local $iIsIncluded = False
   local $i = 0
   local $iMax = 0

   ;strip leading and trailing " from directories
   $PathOrFile = StringReplace($PathOrFile,"""","")
   ;if StringRight($PathOrFile,1) = "\" then $PathOrFile = StringTrimRight($PathOrFile,1)

   ;_ArrayDisplay($aRule)

   ;include directory command
   $iMax = UBound($aRule,1)-1
   ;msgbox(0,"iMax",$iMax)
   for $i = 1 to $iMax
	  ;$aRule[$i][0]
	  ;$aRule[$i][1]
	  ;msgbox(0,"Cmd","#" & $aRule[$i][0] & "#" & @CRLF & "#" & $aRule[$i][1] & "#" & @CRLF & "#" & $PathOrFile & "#" & @CRLF & "#" & StringLeft($PathOrFile,stringlen($aRule[$i][1] & "\")) & "#" & @CRLF & "#" & $aRule[$i][1] & "\")
	  Select
		 case $aRule[$i][0] = "IncDirRec:"
			if StringLeft($PathOrFile,stringlen($aRule[$i][1] & "\")) = $aRule[$i][1] & "\" then $iIsIncluded = True
		 case $aRule[$i][0] = "IncDir:"
			if StringLeft($PathOrFile,stringlen($aRule[$i][1] & "\")) = $aRule[$i][1] & "\" And Not StringInStr(StringReplace(StringLower($PathOrFile),StringLower($aRule[$i][1] & "\"),""),"\") then $iIsIncluded = True
		 case Else
	  EndSelect
   Next

   ;ConsoleWrite("...ID..." & $iIsIncluded & " " & $PathOrFile & @crlf)

   ;msgbox(0,"Cmd","#" & $aRule[$i][0] & "#" & @CRLF & "#" & $aRule[$i][1] & "#" & @CRLF & "#" & $PathOrFile & "#" & @CRLF)

   ;include file extension command (if it is not a directory and the path is included)
   if StringRight($PathOrFile,1) <> "\" and $iIsIncluded = True then
	  $iIsIncluded = False

	  ;msgbox(0,"Cmd","#" & $aRule[$i][0] & "#" & @CRLF & "#" & $aRule[$i][1] & "#" & @CRLF & "#" & $PathOrFile & "#" & @CRLF)

	  $iMax = UBound($aRule,1)-1
	  for $i = 1 to $iMax
		 ;$aRule[$i][0]
		 ;$aRule[$i][1]

		 Select
			case $aRule[$i][0] = "IncExt:"
			   if StringRight($PathOrFile,stringlen("." & $aRule[$i][1])) = "." & $aRule[$i][1] then $iIsIncluded = True
			case $aRule[$i][0] = "IncExe"
			   if IsExecutable($PathOrFile) then $iIsIncluded = True
			case $aRule[$i][0] = "IncAll"
			   $iIsIncluded = True
			case Else
		 EndSelect
	  Next
   EndIf

   ;ConsoleWrite("...IE..." & $iIsIncluded & " " & $PathOrFile & @crlf)

   ;exclude directory command
   $iMax = UBound($aRule,1)-1
   for $i = 1 to $iMax
	  ;$aRule[$i][0]
	  ;$aRule[$i][1]
	  Select
		 case $aRule[$i][0] = "ExcDirRec:"
			if StringLeft($PathOrFile,stringlen($aRule[$i][1] & "\")) = $aRule[$i][1] & "\" then $iIsIncluded = False
		 case $aRule[$i][0] = "ExcDir:"
			if StringLeft($PathOrFile,stringlen($aRule[$i][1] & "\")) = $aRule[$i][1] & "\" And not StringInStr(StringReplace(StringLower($PathOrFile),StringLower($aRule[$i][1] & "\"),""),"\") then $iIsIncluded = False
		 case Else
	  EndSelect
   Next

   ;ConsoleWrite("...ED..." & $iIsIncluded & " " & $PathOrFile & @crlf)

   ;exclude file extension command (if it is not a directory and the path is included)
   if StringRight($PathOrFile,1) <> "\" and $iIsIncluded = True then
	  ;$iIsIncluded = False

	  $iMax = UBound($aRule,1)-1
	  for $i = 1 to $iMax
		 ;$aRule[$i][0]
		 ;$aRule[$i][1]
		 Select
			case $aRule[$i][0] = "ExcExt:"
			   if StringRight($PathOrFile,stringlen("." & $aRule[$i][1])) = "." & $aRule[$i][1] then $iIsIncluded = False
			case $aRule[$i][0] = "ExcExe"
			   if IsExecutable($PathOrFile) then $iIsIncluded = False
			case $aRule[$i][0] = "ExcAll"
			   $iIsIncluded = False
			case Else
		 EndSelect
	  Next
   EndIf

   ;ConsoleWrite("...EE..." & $iIsIncluded & " " & $PathOrFile & @crlf)
   ;if $iIsIncluded then ConsoleWrite($iIsIncluded & " " & $PathOrFile & @crlf)

   Return $iIsIncluded
EndFunc


Func OutputLineOfQueryResult(ByRef $aQueryResult,$ReportFilename)

   ;Simple report writer
   ;----------------------


   ;Output single line of a sql query result
   ;--------------------------------------------
   ;"CREATE TABLE IF NOT EXISTS files (scantime,name,status,size,attributes,mtime,ctime,atime,version,spath,crc32,md5,ptime,rulename, PRIMARY KEY(scantime,name));"
   ;     old                                 0   1      2     3       4        5     6    7      8     9      10   11  12      13
   ;     new                                 14  15     16    17      18       19    20   21     22    23     24   25  26      27

   local $aDesc[] = ["scantime","name","valid","size","attributes","mtime","ctime","atime","version","spath","crc32","md5","ptime","rulename"]
   local $i = 0

   if $aQueryResult[1] = "" Then FileWriteLine($ReportFilename,"-- new     --"  & @CRLF & _HexToString($aQueryResult[15]) & @CRLF & @CRLF)

   if $aQueryResult[15] = "" Then FileWriteLine($ReportFilename,"-- missing --"  & @CRLF & _HexToString($aQueryResult[1]) & @CRLF & @CRLF)

   if $aQueryResult[1] = $aQueryResult[15] Then FileWriteLine($ReportFilename,"-- changed --"  & @CRLF & _HexToString($aQueryResult[1]) & @CRLF & @CRLF)

   $sTempOld = $aQueryResult[0]
   $sTempNew = $aQueryResult[0 + 14]
   if $sTempOld = "" then $sTempOld = "-"
   if $sTempNew = "" then $sTempNew = "-"
   FileWriteLine($ReportFilename,StringFormat("%-15s %1s %35s %-35s","","","expected","observed"))
   FileWriteLine($ReportFilename,StringFormat("%-15s %1s %35s %-35s",$aDesc[$i] & ":"," ",$sTempOld,$sTempNew))

   for $i = 2 to 12
	  $sTempOld = $aQueryResult[$i]
	  $sTempNew = $aQueryResult[$i + 14]
	  if $sTempOld = "" then $sTempOld = "-"
	  if $sTempNew = "" then $sTempNew = "-"

	  if $i = 9 Then
	  ElseIf $i = 13 Then
	  else
		 if $sTempOld = $sTempNew or $sTempOld = "-" or $sTempNew = "-" or $i = 0 or $i = 2 or $i = 12  then
			FileWriteLine($ReportFilename,StringFormat("%-15s %1s %35s %-35s",$aDesc[$i] & ":"," ",$sTempOld,$sTempNew))
		 Else
			FileWriteLine($ReportFilename,StringFormat("%-15s %1s %35s %-35s",$aDesc[$i] & ":","*",$sTempOld,$sTempNew))
		 EndIf
	  EndIf

   Next

   $sTempOld = $aQueryResult[9]
   $sTempNew = $aQueryResult[9 + 14]
   if $sTempOld = "" then $sTempOld = "-"
   if $sTempNew = "" then $sTempNew = "-"
   FileWriteLine($ReportFilename,"")
   FileWriteLine($ReportFilename,StringFormat("%-15s %1s %s","old path:"," ",$sTempOld))
   ;FileWriteLine($ReportFilename,StringFormat("%-15s %1s %s","new path:"," ",$sTempNew))
   if $sTempOld = $sTempNew or $sTempOld = "-" or $sTempNew = "-" then
	  FileWriteLine($ReportFilename,StringFormat("%-15s %1s %s","new path:"," ",$sTempNew))
   Else
	  FileWriteLine($ReportFilename,StringFormat("%-15s %1s %s","new path:","*",$sTempNew))
   EndIf

   FileWriteLine($ReportFilename,"-------------")
   FileWriteLine($ReportFilename,"")

   Return True
EndFunc


Func TreeClimber($StartPath,ByRef $aRule,$iScanSubdirs)

   ;read any directory entry in $StartPath and its subdirectories
   ;and scan according to %aRule
   ;-------------------------------------------------------------

   Local $iScanFile = False
   Local $sTempText = ""

   ;abort if $StartPath is not valid (does not exist)
   if not FileExists($StartPath) Then Return False

   ;if StringRight($StartPath,1) = "\" then $StartPath = StringTrimRight($StartPath,1)

   ;list every directory we are reading - reading is NOT scanning !!!
   ;ConsoleWrite(GetRulename($aRule) & " : " & $StartPath & @CRLF)

   ; Assign a Local variable the search handle of all files in the current directory.
   Local $hSearch = FileFindFirstFile($StartPath & "\*.*")


   ; Check if the search was successful, if not display a message and return False.
   If $hSearch = -1 Then
	  ;MsgBox($MB_SYSTEMMODAL, "", "Error: No files/directories matched the search pattern.")
	  Return False
   EndIf

   ; Assign a Local variable the empty string which will contain the files names found.
   Local $sFileName = ""

   While 1
	  $iScanFile = False

	  $sFileName = FileFindNextFile($hSearch)
	  ; If there is no more file matching the search.
	  If @error Then ExitLoop


	  ;climb to subdirectory if directory entry is directory AND subdirectories should be scanned
	  ;MsgBox(0,"Recursiv",StringInStr(FileGetAttrib($StartPath & "\" & $sFileName),"D") & @crlf & $iScanSubdirs)
	  if 0 < StringInStr(FileGetAttrib($StartPath & "\" & $sFileName),"D") and $iScanSubdirs = True Then
		 if IsIncludedByRule($StartPath & "\" & $sFileName & "\",$aRule) then TreeClimber($StartPath & "\" & $sFileName,$aRule,True)
	  EndIf

	  ;msgbox(0,"Aktueller Pfad",$StartPath & "\" & $sFileName)
	  ;ConsoleWrite($StartPath & "\" & $sFileName & @CRLF)

	  ;if IsExecutable($StartPath & "\" & $sFileName) then $iScanFile = True
	  ;check if current directory entry should be scanned according to the current rule
	  if 0 < StringInStr(FileGetAttrib($StartPath & "\" & $sFileName),"D") Then

		 ;it is a directory
		 if IsIncludedByRule($StartPath & "\" & $sFileName & "\",$aRule) then $iScanFile = True
	  Else

		 ;it is a file
		 if IsIncludedByRule($StartPath & "\" & $sFileName,$aRule) then $iScanFile = True
	  EndIf

	  ;MsgBox(0,"Test",$sFileName & @CRLF & $iScanFile)

	  ;scan directory entry (get file information) and put it in the database
	  if $iScanFile then
		 ;list every file or directory we scan - reading is NOT scanning !!!
		 ;ConsoleWrite(GetRulename($aRule) & " : " & $StartPath & "\" & $sFileName & @CRLF)
		 $sTempText = GetRulename($aRule) & " : " & $StartPath & "\" & $sFileName
		 ;$sTempText = OEM2ANSI($sTempText) ; translate from OEM to ANSI
		 ;DllCall('user32.dll','Int','OemToChar','str',$sTempText,'str','') ; translate from OEM to ANSI
		 ConsoleWrite($sTempText & @CRLF)

		 GetFileInfo($aFileInfo,$StartPath & "\" & $sFileName)
		 _SQLite_Exec(-1,"INSERT INTO files(scantime,name,status,size,attributes,mtime,ctime,atime,version,spath,crc32,md5,ptime,rulename) values ('" & $sScantime & "','" & _StringToHex($aFileInfo[0]) & "','" & $aFileInfo[1] & "','" & $aFileInfo[2] & "','" & $aFileInfo[3] & "','" & $aFileInfo[4] & "','" & $aFileInfo[5] & "','" & $aFileInfo[6] & "','" & $aFileInfo[7] & "','" & $aFileInfo[8] & "','" & $aFileInfo[9] & "','" & $aFileInfo[10] & "','" & $aFileInfo[11] & "','" & $aRule[1][1] & "');")
	  EndIf


   WEnd

   ; Close the search handle.
   FileClose($hSearch)

EndFunc


Func OEM2ANSI($aString)

   Local $OEM[256]
   Local $var = ""
   Local $anArray = 0
   Local $i = 0

   $OEM[000]="00"
   $OEM[001]="01"
   $OEM[002]="02"
   $OEM[003]="03"
   $OEM[004]="04"
   $OEM[005]="05"
   $OEM[006]="06"
   $OEM[007]="07"
   $OEM[008]="08"
   $OEM[009]="09"
   $OEM[010]="0A"
   $OEM[011]="0B"
   $OEM[012]="0C"
   $OEM[013]="0D"
   $OEM[014]="0E"
   $OEM[015]="0F"
   $OEM[016]="10"
   $OEM[017]="11"
   $OEM[018]="12"
   $OEM[019]="13"
   $OEM[020]="14"
   $OEM[021]="15"
   $OEM[022]="16"
   $OEM[023]="17"
   $OEM[024]="18"
   $OEM[025]="19"
   $OEM[026]="1A"
   $OEM[027]="1B"
   $OEM[028]="1C"
   $OEM[029]="1D"
   $OEM[030]="1E"
   $OEM[031]="1F"
   $OEM[032]="20"
   $OEM[033]="21"
   $OEM[034]="22"
   $OEM[035]="23"
   $OEM[036]="24"
   $OEM[037]="25"
   $OEM[038]="26"
   $OEM[039]="27"
   $OEM[040]="28"
   $OEM[041]="29"
   $OEM[042]="2A"
   $OEM[043]="2B"
   $OEM[044]="2C"
   $OEM[045]="2D"
   $OEM[046]="2E"
   $OEM[047]="2F"
   $OEM[048]="30"
   $OEM[049]="31"
   $OEM[050]="32"
   $OEM[051]="33"
   $OEM[052]="34"
   $OEM[053]="35"
   $OEM[054]="36"
   $OEM[055]="37"
   $OEM[056]="38"
   $OEM[057]="39"
   $OEM[058]="3A"
   $OEM[059]="3B"
   $OEM[060]="3C"
   $OEM[061]="3D"
   $OEM[062]="3E"
   $OEM[063]="3F"
   $OEM[064]="40"
   $OEM[065]="41"
   $OEM[066]="42"
   $OEM[067]="43"
   $OEM[068]="44"
   $OEM[069]="45"
   $OEM[070]="46"
   $OEM[071]="47"
   $OEM[072]="48"
   $OEM[073]="49"
   $OEM[074]="4A"
   $OEM[075]="4B"
   $OEM[076]="4C"
   $OEM[077]="4D"
   $OEM[078]="4E"
   $OEM[079]="4F"
   $OEM[080]="50"
   $OEM[081]="51"
   $OEM[082]="52"
   $OEM[083]="53"
   $OEM[084]="54"
   $OEM[085]="55"
   $OEM[086]="56"
   $OEM[087]="57"
   $OEM[088]="58"
   $OEM[089]="59"
   $OEM[090]="5A"
   $OEM[091]="5B"
   $OEM[092]="5C"
   $OEM[093]="5D"
   $OEM[094]="5E"
   $OEM[095]="5F"
   $OEM[096]="60"
   $OEM[097]="61"
   $OEM[098]="62"
   $OEM[099]="63"
   $OEM[100]="64"
   $OEM[101]="65"
   $OEM[102]="66"
   $OEM[103]="67"
   $OEM[104]="68"
   $OEM[105]="69"
   $OEM[106]="6A"
   $OEM[107]="6B"
   $OEM[108]="6C"
   $OEM[109]="6D"
   $OEM[110]="6E"
   $OEM[111]="6F"
   $OEM[112]="70"
   $OEM[113]="71"
   $OEM[114]="72"
   $OEM[115]="73"
   $OEM[116]="74"
   $OEM[117]="75"
   $OEM[118]="76"
   $OEM[119]="77"
   $OEM[120]="78"
   $OEM[121]="79"
   $OEM[122]="7A"
   $OEM[123]="7B"
   $OEM[124]="7C"
   $OEM[125]="7D"
   $OEM[126]="7E"
   $OEM[127]="7F"
   $OEM[128]="C7"
   $OEM[129]="FC"
   $OEM[130]="E9"
   $OEM[131]="E2"
   $OEM[132]="E4"
   $OEM[133]="E0"
   $OEM[134]="E5"
   $OEM[135]="E7"
   $OEM[136]="EA"
   $OEM[137]="EB"
   $OEM[138]="E8"
   $OEM[139]="EF"
   $OEM[140]="EE"
   $OEM[141]="EC"
   $OEM[142]="C4"
   $OEM[143]="C5"
   $OEM[144]="C9"
   $OEM[145]="E6"
   $OEM[146]="C6"
   $OEM[147]="F4"
   $OEM[148]="F6"
   $OEM[149]="F2"
   $OEM[150]="FB"
   $OEM[151]="F9"
   $OEM[152]="FF"
   $OEM[153]="D6"
   $OEM[154]="DC"
   $OEM[155]="F8"
   $OEM[156]="A3"
   $OEM[157]="D8"
   $OEM[158]="D7"
   $OEM[159]="83"
   $OEM[160]="E1"
   $OEM[161]="ED"
   $OEM[162]="F3"
   $OEM[163]="FA"
   $OEM[164]="F1"
   $OEM[165]="D1"
   $OEM[166]="AA"
   $OEM[167]="BA"
   $OEM[168]="BF"
   $OEM[169]="AE"
   $OEM[170]="AC"
   $OEM[171]="BD"
   $OEM[172]="BC"
   $OEM[173]="A1"
   $OEM[174]="AB"
   $OEM[175]="BB"
   $OEM[176]="A6"
   $OEM[177]="A6"
   $OEM[178]="A6"
   $OEM[179]="A6"
   $OEM[180]="A6"
   $OEM[181]="C1"
   $OEM[182]="C2"
   $OEM[183]="C0"
   $OEM[184]="A9"
   $OEM[185]="A6"
   $OEM[186]="A6"
   $OEM[187]="2B"
   $OEM[188]="2B"
   $OEM[189]="A2"
   $OEM[190]="A5"
   $OEM[191]="2B"
   $OEM[192]="2B"
   $OEM[193]="2D"
   $OEM[194]="2D"
   $OEM[195]="2B"
   $OEM[196]="2D"
   $OEM[197]="2B"
   $OEM[198]="E3"
   $OEM[199]="C3"
   $OEM[200]="2B"
   $OEM[201]="2B"
   $OEM[202]="2D"
   $OEM[203]="2D"
   $OEM[204]="A6"
   $OEM[205]="2D"
   $OEM[206]="2B"
   $OEM[207]="A4"
   $OEM[208]="F0"
   $OEM[209]="D0"
   $OEM[210]="CA"
   $OEM[211]="CB"
   $OEM[212]="C8"
   $OEM[213]="69"
   $OEM[214]="CD"
   $OEM[215]="CE"
   $OEM[216]="CF"
   $OEM[217]="2B"
   $OEM[218]="2B"
   $OEM[219]="A6"
   $OEM[220]="5F"
   $OEM[221]="A6"
   $OEM[222]="CC"
   $OEM[223]="AF"
   $OEM[224]="D3"
   $OEM[225]="DF"
   $OEM[226]="D4"
   $OEM[227]="D2"
   $OEM[228]="F5"
   $OEM[229]="D5"
   $OEM[230]="B5"
   $OEM[231]="FE"
   $OEM[232]="DE"
   $OEM[233]="DA"
   $OEM[234]="DB"
   $OEM[235]="D9"
   $OEM[236]="FD"
   $OEM[237]="DD"
   $OEM[238]="AF"
   $OEM[239]="B4"
   $OEM[240]="AD"
   $OEM[241]="B1"
   $OEM[242]="3D"
   $OEM[243]="BE"
   $OEM[244]="B6"
   $OEM[245]="A7"
   $OEM[246]="F7"
   $OEM[247]="B8"
   $OEM[248]="B0"
   $OEM[249]="A8"
   $OEM[250]="B7"
   $OEM[251]="B9"
   $OEM[252]="B3"
   $OEM[253]="B2"
   $OEM[254]="A6"
   $OEM[255]="A0"

   $anArray = StringSplit($aString,"")
   $var = ""

   For $i = 1 to $anArray[0]
	  $var = $var & Chr(dec($OEM[Asc($anArray[$i])]))
   Next

   return $var

EndFunc


Func IsExecutable($Filename)

   ;Check if $Filename is a windows executable
   ;by looking at the magic number
   ;--------------------------------------------

   $sBuffer = ""
   $FileHandle = 0

   $FileHandle = FileOpen($Filename, 16)
   $sBuffer = FileRead($FileHandle,2)
   FileClose($FileHandle)

   if $sBuffer = "MZ" or $sBuffer = "ZM" then
	  return True
   Else
	  return False
   EndIf

EndFunc


Func GetFileInfo( ByRef $aFileInfo, $Filename )

   ;Retrieves all information about $Filename
   ;--------------------------------------------


   local const $BufferSize = 0x20000
   local $FileHandle = 0	;Handle of file to process
   local $FileSize = 0		;Size of file to process
   local $TempBuffer = ""	;File read buffer
   local $CRC32 = 0			;CRC32 value of file
   local $MD5CTX = 0		;MD5 interim value


   $aFileInfo[0] = $Filename
   $aFileInfo[1] = 0		;not validated


   $Timer = TimerInit()


   ;Start processing
   $FileHandle = 0
   $FileHandle = FileOpen($Filename, 16)

   $FileSize = 0
   $FileSize = FileGetSize($Filename)
   $aFileInfo[2] = $FileSize

   $aFileInfo[3] = FileGetAttrib($Filename)

   $aFileInfo[4] = FileGetTime($Filename,$FT_MODIFIED,1)
   $aFileInfo[5] = FileGetTime($Filename,$FT_CREATED,1)
   $aFileInfo[6] = FileGetTime($Filename,$FT_ACCESSED,1)

   $aFileInfo[7] = FileGetVersion($Filename)

   $aFileInfo[8] = FileGetShortName($Filename)

   ; ### CRC32 + MD5###
   $CRC32 = 0
   $MD5CTX = _MD5Init()

   For $i = 1 To Ceiling($FileSize / $BufferSize)
	  $TempBuffer = FileRead($FileHandle, $BufferSize)
	  $CRC32 = _CRC32($TempBuffer, BitNot($CRC32))
	  _MD5Input($MD5CTX, $TempBuffer)
   Next

   $aFileInfo[9] = $CRC32
   $aFileInfo[10] = _MD5Result($MD5CTX)

   FileClose($FileHandle)

   ;End processing

   $aFileInfo[11] = Round(TimerDiff($Timer))

   return 0
EndFunc




;Scrapbook
;-----------------------

#cs
scans in der datenbank
   SELECT distinct scantime FROM files

views erzeugen

   create view if not exists scanold as select * from files where scantime='20160428144350'

   create view if not exists scannew as select * from files where scantime='20160428144915'

unterschiede zurückgeben
   select * from  scannew join scanold where scannew.name = scanold.name and (scannew.md5 <> scanold.md5 or )

#ce

#cs
   ; ### CRC32 ###
   $CRC32 = 0

   For $i = 1 To Ceiling($FileSize / $BufferSize)
	   $CRC32 = _CRC32(FileRead($FileHandle, $BufferSize), BitNot($CRC32))
   Next

   $aFileInfo[9] = $CRC32
   ;MsgBox (0, "Result", Hex($CRC32, 8) & " in " & Round(TimerDiff($Timer)) & " ms")
   FileClose($FileHandle)

   ; ### MD5 ###

   $FileHandle = 0
   $FileHandle = FileOpen($Filename, 16)

   $MD5CTX = _MD5Init()
   For $i = 1 To Ceiling($FileSize / $BufferSize)
	   _MD5Input($MD5CTX, FileRead($FileHandle, $BufferSize))
   Next
   $aFileInfo[10] = _MD5Result($MD5CTX)
#ce
