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
Versioning: "Incompatible changes to DB"."new feature"."bug fix"."minor fix"

Changelog
1.0.0.0		integrate CONFIGFILE in DB table config (line by line as hexstring)
			help extended
			set file infos of executable with pragma compile()
			new programm name
1.1.0.0		make TreeClimber ignore excludes Dirs
1.2.0.0		access time (atime) is not a difference of files, so ignore it
			/v	show versions of scirpt, sqlite.dll and autoit
1.3.0.0		new statement ExcDirs in CONFIGFILE
			new statement EmailFrom in CONFIGFILE
			new statement EmailTo in CONFIGFILE
			new statement EmailSubject in CONFIGFILE
			new statement EmailServer in CONFIGFILE
			new statement EmailPort in CONFIGFILE
			new SPECIAL_REPORTNAME email on commandline
			shrink (vacuum) DB file after /delete
			/exportscan export scan to csv
1.3.0.1		update todo list
2.0.0.0		split filedata in DB in several tables
			reorganize code in mainloop
2.0.1.0		report shows "changed" files with no difference
			error messages if report is not generated
			GetFileInfo(): no md5 and crc32 for directories
			GetFileInfo(): handle files that can not be read (status = $aFileInfo[1] = 1 )
2.0.1.1		GetFileInfo(): first get filesize then calculate md5 and crc32
2.0.1.2		OutputLineOfQueryResult(): changes in attributes not indicated by a * in report
			OutputLineOfQueryResult(): if filesize is greater 0 and the file can not be read, then set file status  = 1
2.1.0.0		OpenDB(): create db index for path and fileinfo
2.1.0.1		close all _SQLite_Query() with _SQLite_QueryFinalize()

#ce

#cs
FixMe:
	  done - !!!!!!!!!!  /report is not working anymore !!!!!!!!!!!!
	  - possible sql injection through value of "Rule:" in config file
	  done - does /report "missing" realy work ???? GetAllRulenames() must return ALL rulenames from scanold AND scannew
ToDo:
	  obsolete - change name of DB field "status" to "valid"
	  - DoDeleteScan() sanitize DB tables rules and filenames !
	  - unused field "filedata.status" in DB
	  - count directory entries and put the count in the DB
	  done - email report via smtp
	  done - redesign DB structure, so all name-strings are referenced with foreign keys etc. (DB size !)
	  - report: ignore differences of certain fileinfos (size,mtime etc.)
	  done - export scan data to csv
	  - read directories in ONE pass and check ALL the rule on each file, not the other way round
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
#pragma compile(FileDescription,"Spot The Difference")
#pragma compile(ProductName,"Spot The Difference")
#pragma compile(ProductVersion,"2.1.0.1")
;Versioning: "Incompatible changes to DB"."new feature"."bug fix"."minor fix"
#pragma compile(LegalCopyright,"Reinhard Dittmann")
#pragma compile(InternalName,"STD")


#include <CRC32.au3>
#include <MD5.au3>
#include <array.au3>
#include <File.au3>
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
global $aRule[1][2]		;one rule form config File
global $aFileInfo[13]	;array with informations about the file
#cs
		 $aFileInfo[0]	;name
		 $aFileInfo[1]	;file could not be read 1 else 0
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
global $sScantime = ""	;date and time of the scan
global $iScanId	= 0		;scanid
global $hDBHandle = ""	;handle of db

;mailer setup
Global $oMyRet[2]
Global $oMyError = ObjEvent("AutoIt.Error", "MyErrFunc")



$Path = ""				;directory to process
$Filename = ""			;File to process
$ReportFilename = ""	;report filename
$ConfigFilename = ""	;config filename (what to scan)
$sDBName = ""			;path of sqlite db file
$sScanname = ""			;name of the scan i.e. scantime

local $sCSVFilename = ""	;csv file for scan export
local $aCSVQueryResult = 0
local $hCSVQuery = 0



local $aQueryResult = 0	;result of a query
local $hQuery = 0		;handle to a query

local $aCfgQueryResult = 0	;result of a query on table config
local $hCfgQuery = 0		;handle to a query on table config


$iQueryRows = 0			;returned rows of a query
$iQueryColumns = 0  	;returned colums of a query

$sTempValid = ""		;"X" if scan is validated "-" if not yet validated
local $aRulenames = 0	;all rulenames in a scan
local $sTempText = ""	;
local $iTempCount = ""	;

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
   Case $CmdLine[1] = "/exportscan"
	  if $CmdLine[0] < 4 then
 		 ShowHelp()
		 exit (1)
	  EndIf

	  ;$sDBName = $CmdLine[2]
	  ;$sScanname = $CmdLine[3]
	  ;$sCSVFilename = $CmdLine[4]

	  OpenDB($CmdLine[2])

	  DoExportScan($CmdLine[3],$CmdLine[4])

	  CloseDB()

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
	  _SQLite_QueryFinalize($hQuery)
	  CloseDB()

   Case $CmdLine[1] = "/validate"
	  if $CmdLine[0] < 3 then
 		 ShowHelp()
		 exit (1)
	  EndIf

	  ;$sDBName = $CmdLine[2]
	  ;$sScanname = $CmdLine[3]

	  OpenDB($CmdLine[2])

	  DoValidateScan($CmdLine[3])

	  CloseDB()


   Case $CmdLine[1] = "/invalidate"
	  if $CmdLine[0] < 3 then
 		 ShowHelp()
		 exit (1)
	  EndIf

	  ;$sDBName = $CmdLine[2]
	  ;$sScanname = $CmdLine[3]

	  OpenDB($CmdLine[2])

	  DoInvalidateScan($CmdLine[3])

	  CloseDB()


   Case $CmdLine[1] = "/delete"
	  if $CmdLine[0] < 3 then
 		 ShowHelp()
		 exit (1)
	  EndIf

	  ;$sDBName = $CmdLine[2]
	  ;$sScanname = $CmdLine[3]

	  OpenDB($CmdLine[2])

	  DoDeleteScan($CmdLine[3])

	  CloseDB()

   Case $CmdLine[1] = "/list"
	  if $CmdLine[0] < 2 then
		 ShowHelp()
		 exit (1)
	  EndIf
	  ;$sDBName = $CmdLine[2]
	  OpenDB($CmdLine[2])

	  DoListScan()

	  CloseDB()

   Case $CmdLine[1] = "/scan"
	  if $CmdLine[0] < 2 then
 		 ShowHelp()
		 exit (1)
	  EndIf

	  $sDBName = $CmdLine[2]

	  OpenDB($sDBName)

	  DoScan()

	  CloseDB()

   Case $CmdLine[1] = "/report"

	  if $CmdLine[0] < 3 then
		 ShowHelp()
		 exit (1)
	  EndIf

	  ;$sDBName = $CmdLine[2]
	  ;$ReportFilename = $CmdLine[3]

	  OpenDB($CmdLine[2])

	  DoReport($CmdLine[3])

	  CloseDB()

   Case $CmdLine[1] = "/help"
	  ShowHelp()

   Case $CmdLine[1] = "/?"
	  ShowHelp()

   Case $CmdLine[1] = "/v"
	  ShowVersions()

   case Else
	  ShowHelp()

EndSelect


Exit(0)





;---------------------------------------------------
; Functions
;---------------------------------------------------
Func DoReport($ReportFilename)
   local $rc = 0				;mailer return code
   local $iEmailReport = False	;send report per email (smtp)
   local $sEMailBody = ""		;bodytext of email
   local $aEMail[5]				;array with all email infos
   $aEMail[4] = 25				;SMTP default port = 25
#cs
   $aEMail[0]		;sender email address
   $aEMail[1]		;recipient email address
   $aEMail[2]		;email subject
   $aEMail[3]		;name of smtp server (hostname or ip-address)
   $aEMail[4]		;smtp port on SMTPSERVERNAME, defaults to 25
#ce
   local $sScannameOld = ""
   local $sScannameNew = ""

   local $aQueryResult = 0	;result of a query
   local $hQuery = 0		;handle to a query

   local $aCfgQueryResult = 0	;result of a query on table config
   local $hCfgQuery = 0			;handle to a query on table config
   local $sTempCfgLine = ""

   local $aRulenames = 0	;all rulenames in a scan

   local $sTempText = ""	;
   local $iTempCount = ""	;

   local $i = 0

   local $sTempSQL = ""


   $sTempSQL = "SELECT "
   $sTempSQL &= "scans.scantime,"
   $sTempSQL &= "filenames.path,"
   $sTempSQL &= "scans.valid,"
   $sTempSQL &= "filedata.size,"
   $sTempSQL &= "filedata.attributes,"
   $sTempSQL &= "filedata.mtime,"
   $sTempSQL &= "filedata.ctime,"
   $sTempSQL &= "filedata.atime,"
   $sTempSQL &= "filedata.version,"
   $sTempSQL &= "filenames.spath,"
   $sTempSQL &= "filedata.crc32,"
   $sTempSQL &= "filedata.md5,"
   $sTempSQL &= "filedata.ptime,"
   $sTempSQL &= "rules.rulename "
   $sTempSQL &= "FROM filedata,filenames,rules,scans "
   $sTempSQL &= "WHERE "
   $sTempSQL &= "filedata.filenameid = filenames.filenameid AND "
   $sTempSQL &= "filedata.scanid = scans.scanid AND "
   $sTempSQL &= "filedata.ruleid = rules.ruleid"
   ;$sTempSQL &= ";"

   ;$sTempSQL = "create view if not exists scannew as SELECT scans.scantime,filenames.path,scans.valid,filedata.size,filedata.attributes,filedata.mtime,filedata.ctime,filedata.atime,filedata.version,filenames.spath,filedata.crc32,filedata.md5,filedata.ptime,rules.rulename FROM filedata,filenames,rules,scans WHERE filedata.filenameid = filenames.filenameid AND filedata.scanid = scans.scanid AND filedata.ruleid = rules.ruleid;"
   ;$sTempSQL = "SELECT scans.scantime,filenames.path,scans.valid,filedata.size,filedata.attributes,filedata.mtime,filedata.ctime,filedata.atime,filedata.version,filenames.spath,filedata.crc32,filedata.md5,filedata.ptime,rules.rulename FROM filedata,filenames,rules,scans WHERE filedata.filenameid = filenames.filenameid AND filedata.scanid = scans.scanid AND filedata.ruleid = rules.ruleid"


   if $ReportFilename = "email" then
	  ;email report and create tempfile
	  $iEmailReport = True
	  $ReportFilename = _TempFile(@TempDir,"std-report-","txt" )
   EndIf


   FileDelete($ReportFilename)
   ;MsgBox(0,"",$ReportFilename)
   ;check

   ;drop old views
   _SQLite_Exec(-1,"DROP VIEW IF EXISTS scanold;")
   _SQLite_Exec(-1,"DROP VIEW IF EXISTS scannew;")




   $sScannameNew = ""
   $aQueryResult = 0
   if GetScannamesFromDB("last",$aQueryResult) Then
	  ;_ArrayDisplay($aQueryResult)
	  $sScannameNew = $aQueryResult[2]
   EndIf

   $sScannameOld = ""
   $aQueryResult = 0
   if GetScannamesFromDB("lastvalid",$aQueryResult) Then
	  ;_ArrayDisplay($aQueryResult)
	  $sScannameOld = $aQueryResult[2]
   EndIf


   if $sScannameOld = "" Then
	  ConsoleWrite("Error:" & @CRLF & "Old scan does not exist" & @CRLF & "Scan name: " & $sScannameOld)
   ElseIf $sScannameNew = "" Then
	  ConsoleWrite("Error:" & @CRLF & "New scan does not exist" & @CRLF & "Scan name: " & $sScannameNew)
   else

	  ;build views

	  ConsoleWrite("Generating report for old:" & $sScannameOld & " <-> new:" & $sScannameNew)

	  ;_SQLite_Exec(-1,"create view if not exists scannew as select * from files where scantime='" & $sScannameNew & "';")
	  ;_SQLite_Exec(-1,"create view if not exists scanold as select * from files where scantime='" & $sScannameOld & "';")

	  _SQLite_Exec(-1,"create view if not exists scannew as " & $sTempSQL & " AND scans.scantime = '" & $sScannameNew & "';")
	  _SQLite_Exec(-1,"create view if not exists scanold as " & $sTempSQL & " AND scans.scantime = '" & $sScannameOld & "';")


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
			;_SQLite_Query(-1, "SELECT scannew.rulename,count(scannew.rulename) FROM scannew,scanold WHERE scannew.path = scanold.path and scannew.rulename = scanold.rulename and scannew.rulename = '" & $aRulenames[$i] & "' and (scannew.size <> scanold.size or scannew.attributes <> scanold.attributes or scannew.mtime <> scanold.mtime or scannew.ctime <> scanold.ctime or scannew.atime <> scanold.atime or scannew.version <> scanold.version or scannew.spath <> scanold.spath or scannew.crc32 <> scanold.crc32 or scannew.md5 <> scanold.md5);",$hQuery)
			_SQLite_Query(-1, "SELECT scannew.rulename,count(scannew.rulename) FROM scannew,scanold WHERE scannew.path = scanold.path and scannew.rulename = scanold.rulename and scannew.rulename = '" & $aRulenames[$i] & "' and (scannew.size <> scanold.size or scannew.attributes <> scanold.attributes or scannew.mtime <> scanold.mtime or scannew.ctime <> scanold.ctime or scannew.version <> scanold.version or scannew.spath <> scanold.spath or scannew.crc32 <> scanold.crc32 or scannew.md5 <> scanold.md5);",$hQuery)
			While _SQLite_FetchData($hQuery, $aQueryResult) = $SQLITE_OK
			   ;_ArrayDisplay($aQueryResult)
			   ;OutputLineOfQueryResultSummary($aQueryResult,$ReportFilename)
			   $iTempCount = $aQueryResult[1]
			WEnd
			$sTempText &= StringFormat(" %7i",$iTempCount)
			_SQLite_QueryFinalize($hQuery)


			;return new files
			$aQueryResult = 0
			$hQuery = 0
			$iTempCount = 0
			_SQLite_Query(-1,"SELECT scannew.rulename,count(scannew.rulename) FROM scannew LEFT JOIN scanold ON scannew.path = scanold.path and scannew.rulename = scanold.rulename WHERE scannew.rulename = '" & $aRulenames[$i] & "' and scanold.path IS NULL;" ,$hQuery)
			While _SQLite_FetchData($hQuery, $aQueryResult) = $SQLITE_OK
			   ;OutputLineOfQueryResultSummary($aQueryResult,$ReportFilename)
			   $iTempCount = $aQueryResult[1]
			WEnd
			$sTempText &= StringFormat(" %7i",$iTempCount)
			_SQLite_QueryFinalize($hQuery)


			;return deleted files
			$aQueryResult = 0
			$hQuery = 0
			$iTempCount = 0
			_SQLite_Query(-1,"SELECT scanold.rulename,count(scanold.rulename) FROM scanold LEFT JOIN scannew ON scannew.path = scanold.path and scannew.rulename = scanold.rulename WHERE scanold.rulename = '" & $aRulenames[$i] & "' and scannew.path IS NULL;",$hQuery)
			While _SQLite_FetchData($hQuery, $aQueryResult) = $SQLITE_OK
			   ;OutputLineOfQueryResultSummary($aQueryResult,$ReportFilename)
			   $iTempCount = $aQueryResult[1]
			WEnd
			$sTempText &= StringFormat(" %7i",$iTempCount)
			_SQLite_QueryFinalize($hQuery)


			FileWriteLine($ReportFilename,$sTempText)
		 Next
		 FileWriteLine($ReportFilename,@CRLF & "======================================================================" & @CRLF)


		 ;list per rule
		 for $i = 2 to $aRulenames[0]
			FileWriteLine($ReportFilename,@crlf & "---- rule: " & $aRulenames[$i] & " ----")

			;return scan differences
			$aQueryResult = 0
			$hQuery = 0
			_SQLite_Query(-1, "SELECT scannew.path FROM scannew,scanold WHERE scannew.path = scanold.path and scannew.rulename = scanold.rulename and scannew.rulename = '" & $aRulenames[$i] & "' and (scannew.size <> scanold.size or scannew.attributes <> scanold.attributes or scannew.mtime <> scanold.mtime or scannew.ctime <> scanold.ctime or scannew.atime <> scanold.atime or scannew.version <> scanold.version or scannew.spath <> scanold.spath or scannew.crc32 <> scanold.crc32 or scannew.md5 <> scanold.md5);",$hQuery)
			While _SQLite_FetchData($hQuery, $aQueryResult) = $SQLITE_OK
			   ;OutputLineOfQueryResult($aQueryResult,$ReportFilename)
			   FileWriteLine($ReportFilename,StringFormat("%-8s : %s","changed",_HexToString($aQueryResult[0])))
			WEnd
			_SQLite_QueryFinalize($hQuery)

			;return new files
			$aQueryResult = 0
			$hQuery = 0
			_SQLite_Query(-1,"SELECT scannew.path FROM scannew LEFT JOIN scanold ON scannew.path = scanold.path and scannew.rulename = scanold.rulename WHERE scannew.rulename = '" & $aRulenames[$i] & "' and scanold.path IS NULL;" ,$hQuery)
			While _SQLite_FetchData($hQuery, $aQueryResult) = $SQLITE_OK
			   ;OutputLineOfQueryResult($aQueryResult,$ReportFilename)
			   FileWriteLine($ReportFilename,StringFormat("%-8s : %s","new",_HexToString($aQueryResult[0])))
			WEnd
			_SQLite_QueryFinalize($hQuery)

			;return deleted files
			$aQueryResult = 0
			$hQuery = 0
			_SQLite_Query(-1,"SELECT scanold.path FROM scanold LEFT JOIN scannew ON scannew.path = scanold.path and scannew.rulename = scanold.rulename WHERE scanold.rulename = '" & $aRulenames[$i] & "' and scannew.path IS NULL;",$hQuery)
			While _SQLite_FetchData($hQuery, $aQueryResult) = $SQLITE_OK
			   ;OutputLineOfQueryResult($aQueryResult,$ReportFilename)
			   FileWriteLine($ReportFilename,StringFormat("%-8s : %s","missing",_HexToString($aQueryResult[0])))
			WEnd
			_SQLite_QueryFinalize($hQuery)

		 Next
		 FileWriteLine($ReportFilename,@CRLF & "======================================================================" & @CRLF)

		 ;details per rule
		 for $i = 2 to $aRulenames[0]
			FileWriteLine($ReportFilename,@crlf & "---- rule: " & $aRulenames[$i] & " ----")

			;return scan differences
			$aQueryResult = 0
			$hQuery = 0
			_SQLite_Query(-1, "SELECT scanold.*,scannew.* FROM scannew,scanold WHERE scannew.path = scanold.path and scannew.rulename = scanold.rulename and scannew.rulename = '" & $aRulenames[$i] & "' and (scannew.size <> scanold.size or scannew.attributes <> scanold.attributes or scannew.mtime <> scanold.mtime or scannew.ctime <> scanold.ctime or scannew.atime <> scanold.atime or scannew.version <> scanold.version or scannew.spath <> scanold.spath or scannew.crc32 <> scanold.crc32 or scannew.md5 <> scanold.md5);",$hQuery)
			While _SQLite_FetchData($hQuery, $aQueryResult) = $SQLITE_OK
			   OutputLineOfQueryResult($aQueryResult,$ReportFilename)
			WEnd
			_SQLite_QueryFinalize($hQuery)

			;return new files
			$aQueryResult = 0
			$hQuery = 0
			_SQLite_Query(-1,"SELECT scanold.*,scannew.* FROM scannew LEFT JOIN scanold ON scannew.path = scanold.path and scannew.rulename = scanold.rulename WHERE scannew.rulename = '" & $aRulenames[$i] & "' and scanold.path IS NULL;" ,$hQuery)
			While _SQLite_FetchData($hQuery, $aQueryResult) = $SQLITE_OK
			   OutputLineOfQueryResult($aQueryResult,$ReportFilename)
			WEnd
			_SQLite_QueryFinalize($hQuery)

			;return deleted files
			$aQueryResult = 0
			$hQuery = 0
			_SQLite_Query(-1,"SELECT scanold.*,scannew.* FROM scanold LEFT JOIN scannew ON scannew.path = scanold.path and scannew.rulename = scanold.rulename WHERE scanold.rulename = '" & $aRulenames[$i] & "' and scannew.path IS NULL;",$hQuery)
			While _SQLite_FetchData($hQuery, $aQueryResult) = $SQLITE_OK
			   OutputLineOfQueryResult($aQueryResult,$ReportFilename)
			WEnd
			_SQLite_QueryFinalize($hQuery)
		 Next
	  EndIf

	  ;drop old views
	  _SQLite_Exec(-1,"DROP VIEW IF EXISTS scanold;")
	  _SQLite_Exec(-1,"DROP VIEW IF EXISTS scannew;")

   EndIf

   if $iEmailReport = True then
	  ;email report and delete temp file




	  ;read email parameters from table config
	  $aCfgQueryResult = 0
	  $hCfgQuery = 0
	  _SQLite_Query(-1, "SELECT line FROM config ORDER BY linenumber ASC;",$hCfgQuery)
	  While True

		 ;read one line form table config
		 $sTempCfgLine = ""
		 if _SQLite_FetchData($hCfgQuery, $aCfgQueryResult) = $SQLITE_OK Then
			$sTempCfgLine = _HexToString($aCfgQueryResult[0])
			;_ArrayDisplay($aQueryResult[0])
		 Else
			ExitLoop
		 EndIf

		 ;Output line of rule
		 ;ConsoleWrite($sTempCfgLine & @CRLF)
		 #cs
		 file format config.cfg

		 EmailFrom:EMAILADDRESS			;sender email address
		 EmailTo:EMAILADDRESS			;recipient email address
		 EmailSubject:SUBJECT			;email subject
		 EmailServer:SMTPSERVERNAME		;name of smtp server (hostname or ip-address)
		 EmailPort:SMTPPORT				;smtp port on SMTPSERVERNAME, defaults to 25
		 #ce

		 ;strip whitespaces at begin of line
		 $sTempCfgLine = StringStripWS($sTempCfgLine,$STR_STRIPLEADING )

		 ;tranfer rule lines to $aRule
		 ;strip leading and trailing " from directories
		 ;strip trailing \ from directories
		 Select
			Case stringleft($sTempCfgLine,stringlen("EmailFrom:")) = "EmailFrom:"
			   $aEMail[0] = StringTrimLeft($sTempCfgLine,stringlen("EmailFrom:"))
			Case stringleft($sTempCfgLine,stringlen("EmailTo:")) = "EmailTo:"
			   $aEMail[1] = StringTrimLeft($sTempCfgLine,stringlen("EmailTo:"))
			Case stringleft($sTempCfgLine,stringlen("EmailSubject:")) = "EmailSubject:"
			   $aEMail[2] = StringTrimLeft($sTempCfgLine,stringlen("EmailSubject:"))
			Case stringleft($sTempCfgLine,stringlen("EmailServer:")) = "EmailServer:"
			   $aEMail[3] = StringTrimLeft($sTempCfgLine,stringlen("EmailServer:"))
			Case stringleft($sTempCfgLine,stringlen("EmailPort:")) = "EmailPort:"
			   $aEMail[4] = StringTrimLeft($sTempCfgLine,stringlen("EmailPort:"))

			case Else
		 EndSelect

	  WEnd
	  _SQLite_QueryFinalize($hCfgQuery)

	  ;send email
	  $sEMailBody = "STD Report"
	  $sTempText = $ReportFilename
	  if $sScannameOld = "" Then
		 $sEMailBody = "STD Report" & @CRLF	 & @CRLF & "Error: old scan does not exist"
		 $sTempText = ""
	  ElseIf $sScannameNew = "" Then
		 $sEMailBody = "STD Report" & @CRLF	 & @CRLF & "Error: new scan does not exist"
		 $sTempText = ""
	  ElseIf not FileExists($ReportFilename) Then
		 $sEMailBody = "STD Report" & @CRLF	 & @CRLF & "Error: report file does not exist"
		 $sTempText = ""
	  Else
	  EndIf


	  $rc = 0
	  $rc = _INetSmtpMailCom($aEMail[3], $aEMail[0], $aEMail[0], $aEMail[1], $aEMail[2], $sEMailBody, $sTempText, "", "", "Normal", "", "", $aEMail[4], 0)
	  If @error Then
		  ConsoleWrite("Error sending message:" & @CRLF & "Error code:" & @error & "  Description:" & $rc)
	  EndIf






	  FileDelete($ReportFilename)
   EndIf


EndFunc


Func DoDeleteScan($sScanname)
   local $aQueryResult = 0	;result of a query
   local $i = 0

   $aQueryResult = 0
   if GetScannamesFromDB($sScanname,$aQueryResult) Then
	  for $i = 2 to $aQueryResult[0]
		 ;_ArrayDisplay($aQueryResult)
		 ;$aQueryResult[$i]
#cs
   _SQLite_Exec(-1,"CREATE TABLE IF NOT EXISTS scans (scanid INTEGER PRIMARY KEY AUTOINCREMENT, scantime, valid );")
   _SQLite_Exec(-1,"CREATE TABLE IF NOT EXISTS rules (ruleid INTEGER PRIMARY KEY AUTOINCREMENT, rulename );")
   _SQLite_Exec(-1,"CREATE TABLE IF NOT EXISTS filenames (filenameid INTEGER PRIMARY KEY AUTOINCREMENT, path, spath );")
   _SQLite_Exec(-1,"CREATE TABLE IF NOT EXISTS filedata (scanid not null,ruleid not null,filenameid not null, status,size,attributes,mtime,ctime,atime,version,crc32,md5,ptime, PRIMARY KEY(scanid,ruleid,filenameid) );")
#ce

		 _SQLite_Exec(-1,"delete from filedata where scanid = '" & GetScanIDFromDB($aQueryResult[$i]) & "';")
		 _SQLite_Exec(-1,"delete from scans where scantime = '" & $aQueryResult[$i] & "';")
	  next
   EndIf

   ;shrink DB file
   _SQLite_Exec(-1,"vacuum;")

EndFunc


Func DoInvalidateScan($sScanname)
   local $aQueryResult = 0	;result of a query
   local $i = 0

   $aQueryResult = 0
   if GetScannamesFromDB($sScanname,$aQueryResult) Then
	  for $i = 2 to $aQueryResult[0]
		 ;_ArrayDisplay($aQueryResult)
		 ;$aQueryResult[$i]
		 _SQLite_Exec(-1,"update scans set valid = 0 where scantime = '" & $aQueryResult[$i] & "' and valid = 1;")
	  next
   EndIf

EndFunc


Func DoValidateScan($sScanname)
   local $aQueryResult = 0	;result of a query
   local $i = 0

   $aQueryResult = 0
   if GetScannamesFromDB($sScanname,$aQueryResult) Then
	  for $i = 2 to $aQueryResult[0]
		 ;_ArrayDisplay($aQueryResult)
		 ;$aQueryResult[$i]
		 _SQLite_Exec(-1,"update scans set valid = 1 where scantime = '" & $aQueryResult[$i] & "' and valid = 0;")
	  next
   EndIf

EndFunc


Func DoListScan()
   local $aQueryResult = 0	;result of a query
   local $iQueryRows = 0
   local $iQueryColumns = 0
   local $sTempValid = ""	;"X" if scan is validated "-" if not yet validated
   local $sTempSQL	= ''		;sql statement

   $sTempSQL =  "SELECT "
   $sTempSQL &= "scans.scantime,"
   $sTempSQL &= "count(filedata.filenameid),"
   $sTempSQL &= "scans.valid "
   $sTempSQL &= "FROM filedata,rules,scans "
   $sTempSQL &= "WHERE "
   $sTempSQL &= "filedata.scanid = scans.scanid AND "
   $sTempSQL &= "filedata.ruleid = rules.ruleid "
   $sTempSQL &= "GROUP BY scans.scantime ORDER BY scans.scantime DESC;"


   ;get all scans in db
   $aQueryResult = 0
   ;_SQLite_GetTable2d(-1, "SELECT scantime,count(name),status from files group by scantime order by scantime desc;", $aQueryResult, $iQueryRows, $iQueryColumns)
   _SQLite_GetTable2d(-1, $sTempSQL, $aQueryResult, $iQueryRows, $iQueryColumns)
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

EndFunc


Func DoExportScan($sScanname,$sCSVFilename)
   ;$sScanname = $CmdLine[3]
   ;$sCSVFilename = $CmdLine[4]

   local $aCSVDesc[] = ["scantime","name","valid","size","attributes","mtime","ctime","atime","version","spath","crc32","md5","ptime","rulename"]
   local $sTempText = ''
   local $sTempSQL	= ''		;sql statement
   local $j = 0
   local $i = 0

   local $aQueryResult = 0		;result of a query

   local $aCfgQueryResult = 0	;result of a query on table config
   local $hCfgQuery = 0			;handle to a query on table config


   #cs
   select * from filedata,filenames,rules,scans where
   filedata.filenameid = filenames.filenameid AND
   filedata.scanid = scans.scanid AND
   filedata.ruleid = rules.ruleid
   scans.scantime,filenames.path,scans.valid,filedata.size,filedata.attributes,filedata.mtime,filedata.ctime,filedata.atime,filedata.version,filenames.spath,filedata.crc32,filedata.md5,filedata.ptime,rules.rulename
   #ce

   $sTempSQL = "SELECT "
   $sTempSQL &= "scans.scantime,"
   $sTempSQL &= "filenames.path,"
   $sTempSQL &= "scans.valid,"
   $sTempSQL &= "filedata.size,"
   $sTempSQL &= "filedata.attributes,"
   $sTempSQL &= "filedata.mtime,"
   $sTempSQL &= "filedata.ctime,"
   $sTempSQL &= "filedata.atime,"
   $sTempSQL &= "filedata.version,"
   $sTempSQL &= "filenames.spath,"
   $sTempSQL &= "filedata.crc32,"
   $sTempSQL &= "filedata.md5,"
   $sTempSQL &= "filedata.ptime,"
   $sTempSQL &= "rules.rulename "
   $sTempSQL &= "FROM filedata,filenames,rules,scans "
   $sTempSQL &= "WHERE "
   $sTempSQL &= "filedata.filenameid = filenames.filenameid AND "
   $sTempSQL &= "filedata.scanid = scans.scanid AND "
   $sTempSQL &= "filedata.ruleid = rules.ruleid"



   FileDelete($sCSVFilename)

   ;write fileheader
   $sTempText = ''
   for $j = 0 to 13
	  if $j = 0 then
		 $sTempText &= '"' & $aCSVDesc[$j] & '"'
	  Else
		 $sTempText &= ',"' & $aCSVDesc[$j] & '"'
	  EndIf
   Next
   ;$sTempText &= '"'
   FileWriteLine($sCSVFilename,$sTempText)





   $aQueryResult = 0
   if GetScannamesFromDB($sScanname,$aQueryResult) Then
	  for $i = 2 to $aQueryResult[0]
		 ;_ArrayDisplay($aQueryResult)
		 ;$aQueryResult[$i]
		 ;_SQLite_Exec(-1,"update files set status = '1' where scantime = '" & $aQueryResult[$i] & "' and status = '0';")

		 ;export selected scans from table files into $sCSVFilename
		 $aCSVQueryResult = 0
		 $hCSVQuery = 0

		 ;_SQLite_Query(-1, "SELECT * FROM files WHERE scantime = '" & $aQueryResult[$i] & "';",$hCSVQuery)
		 _SQLite_Query(-1, $sTempSQL & " AND scantime = '" & $aQueryResult[$i] & "';",$hCSVQuery)

		 While _SQLite_FetchData($hCSVQuery, $aCSVQueryResult) = $SQLITE_OK
			$sTempText = ''
			for $j = 0 to 13
			   ;if $j = 1 or $j = 9  or $j = 13 then
			   if $j = 0 then
				  $sTempText &= '"' & $aCSVQueryResult[$j] & '"'
			   Elseif $j = 1 then
				  $sTempText &= ',"' & _HexToString($aCSVQueryResult[$j]) & '"'
			   Else
				  $sTempText &= ',"' & $aCSVQueryResult[$j] & '"'
			   EndIf
			Next
			;$sTempText &= '"'
			;ConsoleWrite($sTempText)
			FileWriteLine($sCSVFilename,$sTempText)
		 WEnd
		 _SQLite_QueryFinalize($hCSVQuery)
	  next
   EndIf


EndFunc


Func DoScan()

	  local $iLastRuleRead = False

	  local $aQueryResult = 0		;result of a query
	  local $hQuery = 0				;handle to a query

	  local $iCfgLineNr = 0
	  local $sTempCfgLine = ""
	  local $aCfgQueryResult = 0	;result of a query on table config
	  local $hCfgQuery = 0			;handle to a query on table config



	  $sScantime = @YEAR & @MON & @MDAY & @HOUR & @MIN & @SEC
	  $iScanId = GetScanIDFromDB($sScantime)

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
				  redim $aRule[UBound($aRule,1)+1][2]
				  $aRule[UBound($aRule,1)-1][0] = "RuleId:"
				  $aRule[UBound($aRule,1)-1][1] = GetRuleIDFromDB($aRule[UBound($aRule,1)-2][1])
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
			   Case StringStripWS($sTempCfgLine,$STR_STRIPALL ) = "ExcDirs"
  				  redim $aRule[UBound($aRule,1)+1][2]
				  $aRule[UBound($aRule,1)-1][0] = "ExcDirs"
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

	  _SQLite_QueryFinalize($hCfgQuery)

EndFunc


Func GetFilenameIDFromDB($sPath,$sSPath)

   ;get filenameid from DB for $sPath and $sSPath and
   ;insert new filename in DB table filenames if not exists
   ;------------------------------------------------

   $aRow = 0	;Returned data row


   if _SQLite_QuerySingleRow(-1,'SELECT filenameid FROM filenames where path="' & $sPath & '" and spath="' & $sSPath & '"',$aRow) = $SQLITE_OK Then
	  ;get filenameid
	  return $aRow[0]
   Else
	  ;filename does not exist in DB so create it
	  _SQLite_Exec(-1,'INSERT INTO filenames VALUES(NULL,"' & $sPath & '","' & $sSPath & '")')
	  if _SQLite_QuerySingleRow(-1,'SELECT filenameid FROM filenames where path="' & $sPath & '" and spath="' & $sSPath & '"',$aRow) = $SQLITE_OK Then
		 ;get filenameid
		 return $aRow[0]
	  EndIf

   EndIf

   Return 0
EndFunc


Func GetScanIDFromDB($sScanname)

   ;get scanid from DB for $sScanname And
   ;insert new scan in DB table scans if not exists
   ;------------------------------------------------

   $aRow = 0	;Returned data row


   if _SQLite_QuerySingleRow(-1,'SELECT scanid FROM scans where scantime="' & $sScanname & '"',$aRow) = $SQLITE_OK Then
	  ;get scanid
	  ;_ArrayDisplay($aRow)
	  return $aRow[0]
   Else
	  ;scan does not exist in DB so create it
	  _SQLite_Exec(-1,'INSERT INTO scans VALUES(NULL,"' & $sScanname & '",0)')
	  if _SQLite_QuerySingleRow(-1,'SELECT scanid FROM scans where scantime="' & $sScanname & '"',$aRow) = $SQLITE_OK Then
		 ;get scanid
		 ;_ArrayDisplay($aRow)
		 return $aRow[0]
	  EndIf

   EndIf

   Return 0
EndFunc


Func GetRuleIDFromDB($sRulename)

   ;get ruleid from DB for $sRulename And
   ;insert new rule in DB table rules if not exists
   ;------------------------------------------------

   $aRow = 0	;Returned data row


   if _SQLite_QuerySingleRow(-1,'SELECT ruleid FROM rules where rulename="' & $sRulename & '"',$aRow) = $SQLITE_OK Then
	  ;get ruleid
	  return $aRow[0]
   Else
	  ;Rule does not exist in DB so create it
	  _SQLite_Exec(-1,'INSERT INTO rules VALUES(NULL,"' & $sRulename & '")')
	  if _SQLite_QuerySingleRow(-1,'SELECT ruleid FROM rules where rulename="' & $sRulename & '"',$aRow) = $SQLITE_OK Then
		 ;get ruleid
		 return $aRow[0]
	  EndIf

   EndIf

   Return 0
EndFunc


Func IncludeDirDataInDBByRule(ByRef $aRule)

   ;Returns True, if the rule demands to put directory information in the DB
   ;------------------------------------------------------------------------

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
	  ExcDirs					;no directory information (attribs,name etc.)
	  End
   #ce

   local $iIsIncluded = True
   local $i = 0
   local $iMax = 0


   $iMax = UBound($aRule,1)-1
   ;msgbox(0,"iMax",$iMax)
   for $i = 1 to $iMax
	  ;$aRule[$i][0]
	  ;$aRule[$i][1]
	  ;msgbox(0,"Cmd","#" & $aRule[$i][0] & "#" & @CRLF & "#" & $aRule[$i][1] & "#" & @CRLF & "#" & $PathOrFile & "#" & @CRLF & "#" & StringLeft($PathOrFile,stringlen($aRule[$i][1] & "\")) & "#" & @CRLF & "#" & $aRule[$i][1] & "\")
	  Select
		 case $aRule[$i][0] = "ExcDirs"
			$iIsIncluded = False

		 case Else
	  EndSelect
   Next

   Return $iIsIncluded
EndFunc


Func ShowVersions()

   ;show version information
   ;---------------------------------------

   local $sText = ""
   local $sSQliteVersion = ""
   Local $sSQliteDll

   $sSQliteDll = _SQLite_Startup()
   if @error Then
	  $sSQliteVersion = "*** sqlite.dll not found ***"
   Else
	  $sSQliteVersion = _SQLite_LibVersion()
   EndIf

   $sText &= "Spot The Difference (" & $cVersion & ")" & @CRLF
   $sText &= "A poor mans file integrity checker." & @CRLF
   $sText &= @CRLF
   $sText &= "AutoIT version:     " & @AutoItVersion & @CRLF
   $sText &= @CRLF
   $sText &= "SQLite.dll version: " & $sSQliteVersion & @CRLF
   $sText &= "SQLite.dll path:    " & $sSQliteDll & @CRLF
   $sText &= @CRLF

   ConsoleWrite($sText)

   _SQLite_Shutdown()

EndFunc


#cs
   ;Start Mailer Setup

   $SmtpServer = "ntmail.za-netz.lokal"
   $FromName = "Freier Platz auf C:"
   $FromAddress = "freespace@za-netz.lokal"
   $ToAddress = "admin@zieglersche.de"
   $Subject = ""
   $Body = ""
   $AttachFiles = ""
   $CcAddress = ""
   $BccAddress = ""
   $Importance = "Normal"
   $Username = ""
   $Password = ""
   $IPPort = 25             ; bleibt so
   $ssl = 0

   Global $oMyRet[2]
   Global $oMyError = ObjEvent("AutoIt.Error", "MyErrFunc")

   ;Ende MAiler Setup

#ce


Func _INetSmtpMailCom($s_SmtpServer, $s_FromName, $s_FromAddress, $s_ToAddress, $s_Subject = "", $as_Body = "", $s_AttachFiles = "", $s_CcAddress = "", $s_BccAddress = "", $s_Importance="Normal", $s_Username = "", $s_Password = "", $IPPort = 25, $ssl = 0)
;###################################################################################################################
; Mailer
;###################################################################################################################

#cs
#Include<file.au3>

$SmtpServer = "MailServer"
$FromName = "Name"
$FromAddress = "your@Email.Address.com"
$ToAddress = "your@Email.Address.com"
$Subject = "Userinfo"
$Body = ""
$AttachFiles = ""
$CcAddress = "CCadress1@test.com"
$BccAddress = "BCCadress1@test.com"
$Importance = "Normal"
$Username = "******"
$Password = "********"
$IPPort = 25             ; bleibt so
$ssl = 0




Global $oMyRet[2]
Global $oMyError = ObjEvent("AutoIt.Error", "MyErrFunc")
$rc = _INetSmtpMailCom($SmtpServer, $FromName, $FromAddress, $ToAddress, $Subject, $Body, $AttachFiles, $CcAddress, $BccAddress, $Importance, $Username, $Password, $IPPort, $ssl)
If @error Then
    MsgBox(0, "Error sending message", "Error code:" & @error & "  Description:" & $rc)
EndIf

#ce

    Local $objEmail = ObjCreate("CDO.Message")
    $objEmail.From = '"' & $s_FromName & '" <' & $s_FromAddress & '>'
    $objEmail.To = $s_ToAddress
    Local $i_Error = 0
    Local $i_Error_desciption = ""
    If $s_CcAddress <> "" Then $objEmail.Cc = $s_CcAddress
    If $s_BccAddress <> "" Then $objEmail.Bcc = $s_BccAddress
    $objEmail.Subject = $s_Subject
    If StringInStr($as_Body, "<") And StringInStr($as_Body, ">") Then
        $objEmail.HTMLBody = $as_Body
    Else
        $objEmail.Textbody = $as_Body & @CRLF
    EndIf
    If $s_AttachFiles <> "" Then
        Local $S_Files2Attach = StringSplit($s_AttachFiles, ";")
        For $x = 1 To $S_Files2Attach[0]
            $S_Files2Attach[$x] = _PathFull($S_Files2Attach[$x])
            ;ConsoleWrite('@@ Debug(62) : $S_Files2Attach = ' & $S_Files2Attach & @LF & '>Error code: ' & @error & @LF)
            If FileExists($S_Files2Attach[$x]) Then
                $objEmail.AddAttachment ($S_Files2Attach[$x])
            Else
                ConsoleWrite('!> File not found to attach: ' & $S_Files2Attach[$x] & @LF)
                SetError(1)
                Return 0
            EndIf
        Next
    EndIf
    $objEmail.Configuration.Fields.Item ("http://schemas.microsoft.com/cdo/configuration/sendusing") = 2
    $objEmail.Configuration.Fields.Item ("http://schemas.microsoft.com/cdo/configuration/smtpserver") = $s_SmtpServer
    If Number($IPPort) = 0 then $IPPort = 25
    $objEmail.Configuration.Fields.Item ("http://schemas.microsoft.com/cdo/configuration/smtpserverport") = $IPPort

    If $s_Username <> "" Then
        $objEmail.Configuration.Fields.Item ("http://schemas.microsoft.com/cdo/configuration/smtpauthenticate") = 1
        $objEmail.Configuration.Fields.Item ("http://schemas.microsoft.com/cdo/configuration/sendusername") = $s_Username
        $objEmail.Configuration.Fields.Item ("http://schemas.microsoft.com/cdo/configuration/sendpassword") = $s_Password
    EndIf
    If $ssl Then
        $objEmail.Configuration.Fields.Item ("http://schemas.microsoft.com/cdo/configuration/smtpusessl") = True
    EndIf

    $objEmail.Configuration.Fields.Update

    Switch $s_Importance
        Case "High"
            $objEmail.Fields.Item ("urn:schemas:mailheader:Importance") = "High"
        Case "Normal"
            $objEmail.Fields.Item ("urn:schemas:mailheader:Importance") = "Normal"
        Case "Low"
            $objEmail.Fields.Item ("urn:schemas:mailheader:Importance") = "Low"
    EndSwitch
    $objEmail.Fields.Update

    $objEmail.Send
    If @error Then
        SetError(2)
        Return $oMyRet[1]
    EndIf
    $objEmail=""
EndFunc


Func MyErrFunc()
    $HexNumber = Hex($oMyError.number, 8)
    $oMyRet[0] = $HexNumber
    $oMyRet[1] = StringStripWS($oMyError.description, 3)
    ConsoleWrite("### COM Error !  Number: " & $HexNumber & "   ScriptLine: " & $oMyError.scriptline & "   Description:" & $oMyRet[1] & @LF)
    SetError(1)
    Return
EndFunc


Func GetAllRulenames($sScan1,$sScan2, ByRef $aRules)

   ;return all the rules in scan $sScan
   ;----------------------------------------------------------------

   local $sSQL = ""

   local $iTempQueryRows = 0
   local $iTempQueryColumns = 0

   ;$sSQL = "SELECT rulename FROM files where scantime = '" & $sScan1 & "' or scantime = '" & $sScan2 & "' group by rulename order by rulename asc;"
   $sSQL = "SELECT rulename FROM rules order by rulename asc;"

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


Func GetScannamesFromDB($sScan,ByRef $aScans)

   ;return the scans described by $sScan
   ;$sScan can be "all","last","invalid","valid","lastinvalid","lastvalid","oldvalid" or the name of a scan
   ;----------------------------------------------------------------

   local $sSQL = ""

   local $iTempQueryRows = 0
   local $iTempQueryColumns = 0
   Select
	  Case $sScan = "all"
		 $sSQL = "SELECT scantime from scans group by scantime order by scantime desc limit " & $cScannameLimit & ";"
	  Case $sScan = "last"
		 $sSQL = "SELECT scantime from scans group by scantime order by scantime desc limit 1;"
	  Case $sScan = "invalid"
		 $sSQL = "SELECT scantime from scans where valid = 0 group by scantime order by scantime desc limit " & $cScannameLimit & ";"
	  Case $sScan = "valid"
		 $sSQL = "SELECT scantime from scans where valid = 1 group by scantime order by scantime desc limit " & $cScannameLimit & ";"
	  Case $sScan = "lastinvalid"
		 $sSQL = "SELECT scantime from scans where valid = 0 group by scantime order by scantime desc limit 1;"
	  Case $sScan = "lastvalid"
		 $sSQL = "SELECT scantime from scans where valid = 1 group by scantime order by scantime desc limit 1;"
	  Case $sScan = "oldvalid"
		 $sSQL = "SELECT scantime from scans where valid = 1 group by scantime order by scantime desc limit " & $cScannameLimit & " offset 1;"
	  case Else
		 $sSQL = "SELECT scantime from scans where scantime = '" & $sScan & "' group by scantime order by scantime desc limit 1;"
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
   $sText &= "REPORTFILE is either a regular filename or a SPECIAL_REPORTNAME" & @CRLF


   $sText &= @CRLF
   $sText &= @ScriptName & " /list DB" & @CRLF
   $sText &= @ScriptName & " /list c:\test.sqlite" & @CRLF
   $sText &= "List all scans in DB" & @CRLF
   $sText &= @CRLF
   $sText &= @ScriptName & " /validate DB SCANNAME" & @CRLF
   $sText &= @ScriptName & " /validate c:\test.sqlite 20160514131610" & @CRLF
   $sText &= "Set status of scan SCANNAME to valid. SCANNAME is either an existing scan" & @CRLF
   $sText &= "or a SPECIAL_SCANNAME" & @CRLF
   $sText &= @CRLF
   $sText &= @ScriptName & " /invalidate DB SCANNAME" & @CRLF
   $sText &= @ScriptName & " /invalidate c:\test.sqlite 20160514131610" & @CRLF
   $sText &= "Set status of scan SCANNAME to invalid. SCANNAME is either an existing scan" & @CRLF
   $sText &= "or a SPECIAL_SCANNAME" & @CRLF
   $sText &= @CRLF
   $sText &= @ScriptName & " /delete DB SCANNAME" & @CRLF
   $sText &= @ScriptName & " /delete c:\test.sqlite 20160514131610" & @CRLF
   $sText &= "Delete the scan SCANNAME. SCANNAME is either an existing scan or a SPECIAL_SCANNAME" & @CRLF
   $sText &= @CRLF
   $sText &= @ScriptName & " /exportscan DB SCANNAME CSVFILENAME" & @CRLF
   $sText &= @ScriptName & " /exportscan c:\test.sqlite 20160514131610 c:\test.csv" & @CRLF
   $sText &= "Export scan SCANNAME to CSVFILENAME. SCANNAME is either an existing scan" & @CRLF
   $sText &= "or a SPECIAL_SCANNAME" & @CRLF

   $sText &= @CRLF
   $sText &= @ScriptName & " /help" & @CRLF
   $sText &= "Show this help" & @CRLF
   $sText &= @CRLF
   $sText &= @ScriptName & " /?" & @CRLF
   $sText &= "Show this help" & @CRLF
   $sText &= @CRLF
   $sText &= @ScriptName & " /v" & @CRLF
   $sText &= "Show version information" & @CRLF


   $sText &= @CRLF
   $sText &= @CRLF
   $sText &= "SPECIAL_SCANNAME:" & @CRLF
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
   $sText &= "SPECIAL_REPORTNAME:" & @CRLF
   $sText &= @CRLF
   $sText &= "email         create report as temporary file and send the report as email" & @CRLF
   $sText &= "              according to the config in DB." & @CRLF



   $sText &= @CRLF
   $sText &= @CRLF
   $sText &= "CSVFILENAME:" & @CRLF
   $sText &= @CRLF
   $sText &= 'Textfile that contains all data from one or more scans as comma separated values.' & @CRLF


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
   $sText &= "ExcDirs                no directory information, only file information." & @CRLF
   $sText &= "                       The default is to gather information on all scaned directories." & @CRLF
   $sText &= "End                    end of rule" & @CRLF
   $sText &= "" & @CRLF

   $sText &= "EmailFrom:EMAILADDRESS       sender email address" & @CRLF
   $sText &= "EmailTo:EMAILADDRESS         recipient email address" & @CRLF
   $sText &= "EmailSubject:SUBJECT         email subject" & @CRLF
   $sText &= "EmailServer:SMTPSERVERNAME   name of smtp server (hostname or ip-address)" & @CRLF
   $sText &= "EmailPort:SMTPPORT           smtp port on SMTPSERVERNAME, defaults to 25" & @CRLF
   $sText &= "" & @CRLF

   $sText &= "EMAILADDRESS           email adress" & @CRLF
   $sText &= "                       e.g.: peter.miller@example.com" & @CRLF
   $sText &= "FILEEXTENTION          one file extention" & @CRLF
   $sText &= '                       e.g.: doc,xls,xlsx,txt,pdf,PDF,TxT,Doc' & @CRLF
   $sText &= "RULENAME               name of rule" & @CRLF
   $sText &= "                       e.g.: My first Rule" & @CRLF
   $sText &= "SMTPPORT               smtp portnumber" & @CRLF
   $sText &= "                       e.g.: 25" & @CRLF
   $sText &= "SMTPSERVERNAME         name of a smtp server" & @CRLF
   $sText &= "                       e.g.: mail.excample.com, 127.0.0.1" & @CRLF
   $sText &= "SUBJECT                subject line of an email" & @CRLF
   $sText &= "                       e.g.: std report" & @CRLF
   $sText &= "PATH                   one directory name" & @CRLF
   $sText &= '                       e.g.: "\\pc\share\my files","c:\temp","c:\temp\",c:\temp' & @CRLF


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
   _SQLite_Exec(-1,"CREATE TABLE IF NOT EXISTS config (linenumber INTEGER PRIMARY KEY AUTOINCREMENT, line );")

   ;_SQLite_Exec(-1,"CREATE TABLE IF NOT EXISTS files (scantime,name,status,size,attributes,mtime,ctime,atime,version,spath,crc32,md5,ptime,rulename, PRIMARY KEY(scantime,name));")
   ;_SQLite_Exec(-1,"CREATE TABLE IF NOT EXISTS files (scanid not null,ruleid not null,filenameid not null );")
   _SQLite_Exec(-1,"CREATE TABLE IF NOT EXISTS scans (scanid INTEGER PRIMARY KEY AUTOINCREMENT, scantime, valid );")
   _SQLite_Exec(-1,"CREATE TABLE IF NOT EXISTS rules (ruleid INTEGER PRIMARY KEY AUTOINCREMENT, rulename );")
   _SQLite_Exec(-1,"CREATE TABLE IF NOT EXISTS filenames (filenameid INTEGER PRIMARY KEY AUTOINCREMENT, path, spath );")
   _SQLite_Exec(-1,"CREATE TABLE IF NOT EXISTS filedata (scanid not null,ruleid not null,filenameid not null, status,size,attributes,mtime,ctime,atime,version,crc32,md5,ptime, PRIMARY KEY(scanid,ruleid,filenameid) );")

   ;_SQLite_Exec(-1,"CREATE INDEX IF NOT EXISTS config_index ON config (linenumber);")
   _SQLite_Exec(-1,"CREATE INDEX IF NOT EXISTS filenames_path ON filenames (path);")
   _SQLite_Exec(-1,"CREATE INDEX IF NOT EXISTS filedata_pk ON filedata (scanid,ruleid,filenameid);")

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


Func GetRuleId(ByRef $aRule)

   ;get id of the rule
   ;--------------------

   local $sRuleId = ""

   $iMax = UBound($aRule,1)-1
   for $i = 1 to $iMax
	  ;$aRule[$i][0]
	  ;$aRule[$i][1]
	  if $aRule[$i][0] = "RuleId:" then $sRuleId = $aRule[$i][1]
   Next

   return $sRuleId
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
   local $sTempOld = ""
   local $sTempNew = ""


   if $aQueryResult[1] = "" Then FileWriteLine($ReportFilename,"-- new     --"  & @CRLF & _HexToString($aQueryResult[15]) & @CRLF & @CRLF)

   if $aQueryResult[15] = "" Then FileWriteLine($ReportFilename,"-- missing --"  & @CRLF & _HexToString($aQueryResult[1]) & @CRLF & @CRLF)

   if $aQueryResult[1] = $aQueryResult[15] Then FileWriteLine($ReportFilename,"-- changed --"  & @CRLF & _HexToString($aQueryResult[1]) & @CRLF & @CRLF)

   $sTempOld = ""
   $sTempNew = ""
   $sTempOld = $aQueryResult[0]
   $sTempNew = $aQueryResult[0 + 14]
   if $sTempOld = "" then $sTempOld = "-"
   if $sTempNew = "" then $sTempNew = "-"
   FileWriteLine($ReportFilename,StringFormat("%-15s %1s %35s %-35s","","","expected","observed"))
   FileWriteLine($ReportFilename,StringFormat("%-15s %1s %35s %-35s",$aDesc[$i] & ":"," ",$sTempOld,$sTempNew))

   for $i = 2 to 12
	  $sTempOld = ""
	  $sTempNew = ""
	  $sTempOld = $aQueryResult[$i]
	  $sTempNew = $aQueryResult[$i + 14]
	  if $sTempOld = "" then $sTempOld = "-"
	  if $sTempNew = "" then $sTempNew = "-"

	  if $i = 9 Then
	  ElseIf $i = 13 Then
	  ElseIf $i = 4 Then
		 if $sTempOld = $sTempNew  then
			FileWriteLine($ReportFilename,StringFormat("%-15s %1s %35s %-35s",$aDesc[$i] & ":"," ",$sTempOld,$sTempNew))
		 Else
			FileWriteLine($ReportFilename,StringFormat("%-15s %1s %35s %-35s",$aDesc[$i] & ":","*",$sTempOld,$sTempNew))
		 EndIf
	  ElseIf $i = 7 Then
		 FileWriteLine($ReportFilename,StringFormat("%-15s %1s %35s %-35s",$aDesc[$i] & ":"," ",$sTempOld,$sTempNew))
	  else
		 if $sTempOld = $sTempNew or $sTempOld = "-" or $sTempNew = "-" or $i = 0 or $i = 2 or $i = 12  then
			FileWriteLine($ReportFilename,StringFormat("%-15s %1s %35s %-35s",$aDesc[$i] & ":"," ",$sTempOld,$sTempNew))
		 Else
			FileWriteLine($ReportFilename,StringFormat("%-15s %1s %35s %-35s",$aDesc[$i] & ":","*",$sTempOld,$sTempNew))
		 EndIf
	  EndIf

   Next

   $sTempOld = ""
   $sTempNew = ""
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
   Local $iFilenameId = 0

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
		 if 0 < StringInStr($aFileInfo[3],"D") and not IncludeDirDataInDBByRule($aRule) Then
			;its a directory and the rule doesn�t want directory infos in the DB
		 Else
			#cs
			$iScanId  GetRuleId($aRule)   $iFilenameId GetFilenameIDFromDB()


			_SQLite_Exec(-1,"CREATE TABLE IF NOT EXISTS scans (scanid INTEGER PRIMARY KEY AUTOINCREMENT, scantime, valid );")
			_SQLite_Exec(-1,"CREATE TABLE IF NOT EXISTS rules (ruleid INTEGER PRIMARY KEY AUTOINCREMENT, rulename );")
			_SQLite_Exec(-1,"CREATE TABLE IF NOT EXISTS filenames (filenameid INTEGER PRIMARY KEY AUTOINCREMENT, path, spath );")
			_SQLite_Exec(-1,"CREATE TABLE IF NOT EXISTS filedata (scanid not null,ruleid not null,filenameid not null, status,size,attributes,mtime,ctime,atime,version,crc32,md5,ptime, PRIMARY KEY(scanid,ruleid,filenameid) );")
			#ce

			_SQLite_Exec(-1,"INSERT INTO filedata (scanid,ruleid,filenameid,status,size,attributes,mtime,ctime,atime,version,crc32,md5,ptime)  values ('" & $iScanId & "', '" & GetRuleId($aRule) & "', '" & GetFilenameIDFromDB(_StringToHex($aFileInfo[0]),$aFileInfo[8]) & "','" & $aFileInfo[1] & "','" & $aFileInfo[2] & "','" & $aFileInfo[3] & "','" & $aFileInfo[4] & "','" & $aFileInfo[5] & "','" & $aFileInfo[6] & "','" & $aFileInfo[7] & "','" & $aFileInfo[9] & "','" & $aFileInfo[10] & "','" & $aFileInfo[11] & "');")
			;_SQLite_Exec(-1,"INSERT INTO files(scantime,name,status,size,attributes,mtime,ctime,atime,version,spath,crc32,md5,ptime,rulename) values ('" & $sScantime & "','" & _StringToHex($aFileInfo[0]) & "','" & $aFileInfo[1] & "','" & $aFileInfo[2] & "','" & $aFileInfo[3] & "','" & $aFileInfo[4] & "','" & $aFileInfo[5] & "','" & $aFileInfo[6] & "','" & $aFileInfo[7] & "','" & $aFileInfo[8] & "','" & $aFileInfo[9] & "','" & $aFileInfo[10] & "','" & $aFileInfo[11] & "','" & $aRule[1][1] & "');")

		 EndIf
	  EndIf


   WEnd

   ; Close the search handle.
   FileClose($hSearch)

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
   ;$aFileInfo[1] = 0	;not validated
   $aFileInfo[1] = 0	;file could not be read 1 else 0


   $Timer = TimerInit()


   ;Start processing
   $aFileInfo[3] = FileGetAttrib($Filename)

   $FileSize = 0
   if 0 < StringInStr($aFileInfo[3],"D") Then
	  ;it�s a directory, so FileGetSize(),md5 and crc32 does not work !

	  $aFileInfo[9] = 0
	  $aFileInfo[10] = 0

   Else
	  ;it�s a file !


	  ;get size of file in bytes
	  $FileSize = FileGetSize($Filename)

	  ;read file and calculate md5 and crc32
	  $FileHandle = 0
	  $FileHandle = FileOpen($Filename, 16)
	  if @error or $FileSize = 0 Then
		 ;unable to open file or filesize is 0

		 ;if filesize not 0 and we can not open the file something is fishy
		 if $FileSize > 0 then $aFileInfo[1] = 1

		 $aFileInfo[9] = 0
		 $aFileInfo[10] = 0
	  Else
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

		 ;close file
		 FileClose($FileHandle)
	  EndIf
   EndIf
   $aFileInfo[2] = $FileSize


   $aFileInfo[4] = FileGetTime($Filename,$FT_MODIFIED,1)
   $aFileInfo[5] = FileGetTime($Filename,$FT_CREATED,1)
   $aFileInfo[6] = FileGetTime($Filename,$FT_ACCESSED,1)

   $aFileInfo[7] = FileGetVersion($Filename)

   $aFileInfo[8] = FileGetShortName($Filename)



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

unterschiede zur�ckgeben
   select * from  scannew join scanold where scannew.path = scanold.path and (scannew.md5 <> scanold.md5 or )

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


