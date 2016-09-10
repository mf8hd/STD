;-----------------------------------------------------------------------------
; STD - Spot The Difference
; A poor mans file integrity checker for windows
;
; By Reinhard Dittmann
;-----------------------------------------------------------------------------
;
;Invocation:
;	SCRIPTNAME COMMAND PARAMETERS
;               /help				show help
;               /?                  show help
;
;Needs:
;	sqlite.dll
;	CRC32 and MD5 UDF form Dan Nagel https://dannagle.com/2012/10/autoit-md5-sha1-base64-crc32
;	_SQL UDF for MS SQL form ChrisL https://www.autoitscript.com/forum/topic/51952-_sqlau3-adodbconnection/

;Changelog
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
			GetFileInfo(): handle files that can not be read (status = $gaFileInfo[1] = 1 )
2.0.1.1		GetFileInfo(): first get filesize then calculate md5 and crc32
2.0.1.2		OutputLineOfQueryResult(): changes in attributes not indicated by a * in report
			OutputLineOfQueryResult(): if filesize is greater 0 and the file can not be read, then set file status  = 1
2.1.0.0		OpenDB(): create db index for path and fileinfo
2.1.0.1		close all _SQLite_Query() with _SQLite_QueryFinalize()
2.1.0.2		DoReport(): replace views with temporary tables for performance reasons
			DoReport(), OutputLineOfQueryResult(): replace "valid" from scan.valid with "status" from filedata.status in report
			OpenDB(): remove unnecessary db index on table filedata
			TreeClimber(): remove 2x FileGetAttrib() in inner loop and use @extended of FileFindNextFile() instead
			TreeClimber(): code cleanup
			GetFileInfo(): increase buffersize for CRC and md5
3.0.0.0		split filedata.attributes in DB into rattrib,aattrib,sattrib,hattrib,nattrib,dattrib,oattrib,cattrib,tattrib
3.1.0.0		help extended
			reorganize code in mainloop
			clean up variable declarations
			GetRuleSetFromDB()
			GetRuleFromRuleSet()
			sourcecode cleanup
			InsertStatementInRuleSet()
			IsFilepropertyIgnoredByRule()
			Ignore file properties in report with the "Ign:"  statement
			performance: sqlite in WAL mode and sync to normal
			DoScan(), DoReport(): use GetRuleSetFromDB()
3.1.1.0		GetFileInfo(): new version that uses _WinAPI_GetFileAttributes() for performance (kind of)
			Old_GetFileInfo(): obsolete old version of GetFileInfo() that uses FileGetAttrib()
3.2.0.0		DoScan(): iterate over directories not rules !
			TreeClimber(): iterate over directories not rules !
			IsClimbTargetByRule()
			DoScanWithSecondProcess(), TreeClimberSecondProcess(), DoSecondProcess(): /scan now uses two processes
			   1. gets the filenames
			   2. gets the fileinformation and puts it in the db
			   better performance, but higher cpu usage
			   second process is started with: @ScriptName /secondprocess DBNAME
			   /scan-obsolete is the obsolete single process version of /scan
			IsIncludedByRule(): ExcDirs moved from IncludeDirDataInDBByRule()
			IncludeDirDataInDBByRule(): function is now obsolete because of IsClimbTargetByRule() and a fixed IsIncludedByRule()
			OutputLineOfQueryResult(): all file attributes printed on one line
3.3.0.0		/history: file history (search is case sensitiv !)
			/scan: added error message, script must be compiled !
			help extended
			OpenDB(): write errors to console not to MsgBox()
			/duplicates: list files with identical size,crc32 and md5 in a scan
3.3.0.1		DoSecondProcess(): calculate scantime better
3.3.0.2		/history
			/duplicates: has 3 commandline parameter, not only 2
3.3.1.0		new debug option $cDEBUGShowVisitedDirectories
			IsExecutable(): remember result of last use, so the file is tested just once while itterating over all rules (performance !)
3.3.1.1		GetFileInfo(): sanitized variable names
			profiler options: $gcDEBUGTimeGetFileInfo, $cDEBUGTimeGetRuleFromRuleSet, $cDEBUGTimeIsExecutable, $cDEBUGTimeIsIncludedByRule, $cDEBUGTimeIsClimbTargetByRule
3.3.1.2		GetRuleSetFromDB(),GetRuleFromRuleSet(): Write begin of all rules in $aRuleSet[] to $aRuleStart[] (performance !)
			IsClimbTargetByRule($PathOrFile,$iRuleNumber),IsIncludedByRule($PathOrFile,$iRuleNumber),GetRulename($iRuleNumber): use $aRuleSet[] not $aRule[] , so GetRuleFromRuleSet() is obsolete (performance !)
3.3.1.3		GetRuleSetFromDB(),IsIncludedByRule(): use $aRuleExtensions (performance !)
			Remove GetRuleFromRuleSet() and old calls to GetRulename($aRule)
			Replace GetRuleId($aRule) with GetRuleIdFromRuleSet($iRuleNumber)
			OutputLineOfQueryResult(): fix changed marker for attributes
3.3.1.4		IsIncludedByRule(): Search for "ExcDir:" and "ExcDirRec:" only if "IncDir:" or "IncDirRec:" returned $iIsIncluded = True
3.3.1.5		TreeClimberSecondProcess(), TreeClimber(), GetRuleSetFromDB(), IsIncludedByRule():
			Replace StringReplace() with "bufferd" count of "\" for "IncDir:","ExcDir:"
			($aRuleSetLineBackslashCount[],$iCurrentDirBackslashCount)
			GetRuleSetFromDB(), IsIncludedByRule():
			replace stringlen($aRuleSet[$i][1] & "\") with "buffered" StringLen() for "IncDir:","ExcDir:","IncDirRec:","ExcDirRec:"
			($aRuleSetLineDirStringLenPlusOne[])
			DoReport(),IsFilepropertyIgnoredByRule($sFileproperty,$iRuleNumber): use $aRuleSet[] not $aRule[]
3.3.1.6		remove all OLD_ functions
			rename ShowHelp() to DoShowHelp()
			rename ShowVersions() to DoShowVersions()
			DoShowUsage(): show short help
			remove IncludeDirDataInDBByRule()
			remove GetAllRulenamesFromDB()
			rename all global variables to $gTypeVariablename
3.3.1.7		DoReport(): delete comments with $gaRulenames
3.3.1.8		DoScanWithSecondProcess(),TreeClimberSecondProcess(): Only check relevant rules on the current file or directory (performance !)
			   Initially all rules are relevant -> fixme this is not true but IsClimbTarget() works only with $aRuleSet !!!
			$gcDEBUG: Main switch for debug output.
3.3.1.9		DoScanWithSecondProcess(): $aRelevantRulesForClimbTarget is set corrently for the initial directories too.
			$gcDEBUGDoNotStartSecondProcess: Debug - run only the list process and do not start the scan process
			$gcDEBUGRunWithoutCompilation: Debug - force the program to run, without beeing compiled
			GetRulename(): reimplemented (performance !)
			DoSecondProcess(),TreeClimberSecondProcess(): rulenumber and filename are sent from list process to scan process via stdout,stdin
3.4.0.0		remove obsolete GetRuleFromRuleSet()
			remove obsolete $gaRule[]
			remove obsolete DoScan() and /scan-obsolete
			remove obsolete TreeClimber()
			rename $gaRuleExtensions[] to $gaRuleData[] and add $gcNoHashes,$gcExcDirs,$gcHasExcDir
			IsIncludedByRule(),IsClimbTargetByRule(): search for "ExcDir:" or "ExcDirRec:" only if the rule has these statements
			new statement NoHashes in CONFIGFILE
3.5.0.0		show debug settings in DoShowVersion()
			DoReport(): read email options from $aRuleSet and not from table "config"
			DoReport(): compare any two scans, given as parameters
			help extended
			DoReport(),OutputLineOfQueryResultHeadline(): beautify report
			allways check if DB file exists
3.6.0.0		DoReport(),OutputLineOfQueryResultHeadline(): beautify report again
			DoReport(): create report for just one given scan aka dump all the data from the scan in a report
			help extended
3.6.1.0		DoReport(): fixed handling of special scan "none"
3.7.0.0		OpenDB(),CloseDB(), GetRuleIDFromDB(), GetRuleSetFromDB(), GetFilenameIDFromDB(),
			GetScanIDFromDB(), GetScannamesFromDB(),DoImportCfg(), DoExportCfg(),DoSecondProcess():
			MS SQL support (/importcfg,/exportcfg,/scan). db-filename is ini-file with connection definition


#ce

;ToDo List
#cs
FixMe:
	  done - /report is not working anymore
	  - possible sql injection through value of "Rule:" in config file
	  done - does /report "missing" realy work ???? GetAllRulenamesFromDB() must return ALL rulenames from scanold AND scannew
ToDo:
	  obsolete - change name of DB field "status" to "valid"
	  - DoDeleteScan() sanitize DB tables rules and filenames !
	  done - unused field "filedata.status" in DB
	  - unused field "filedata.attributes" in DB
	  - count directory entries and put the count in the DB
	  done - email report via smtp
	  done - redesign DB structure, so all name-strings are referenced with foreign keys etc. (DB size !)
	  done - report: ignore differences of certain fileinfos (size,mtime etc.)
	  done - export scan data to csv
	  done - read directories in ONE pass and check ALL the rule on each file, not the other way round
	  - record total scan time and save it in DB
	  done - /scan2 use
	  done - help for /history is missing
	  done - allways check if DB-file exists !
	  done - mail report: email options should be read from $aRuleSet and not from table "config"
	  - use a spellchecker on source code
	  done - /scan : eliminate IsExecutable() in second process (performance !)
	  - /delete : sqlite "vacuum" copies DB content to a new file. Check for diskspace !
	  done - /report : compare any two scans, given as parameters
	  - rename statements "IncDirRec:" and "ExcDirRec:" to "IncDirSub:" and "ExcDirSub:" (?)
	  done - /duplicates : show duplicate files in DB based on status = 0, size, crc32 and md5
	  - redesign DB : there is a row of data in table 'filedata' for every rule ! (redundant !)
	  done - rename global variables
	  - per default nothing is scanned into the database (CONFIG) or vice versa. but stick to it !
	  - use RuleID for rule identification. Export RuleID with /exportcfg
	  - is the csv format ok ? /doublicates /history ...
	  - use _SQLite_Escape() not _StringToHex() for text in DB

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
#pragma compile(ProductVersion,"3.6.1.0")
#pragma compile(FileVersion,"3.6.1.0")
;Versioning: "Incompatible changes to DB"."new feature"."bug fix"."minor fix"

#pragma compile(FileDescription,"Spot The Difference")
#pragma compile(ProductName,"Spot The Difference")
#pragma compile(InternalName,"STD")


;3rd party UDFs from Dan Nagel https://dannagle.com/2012/10/autoit-md5-sha1-base64-crc32
#include <CRC32.au3>
#include <MD5.au3>
;3rd party UDF from ChrisL https://www.autoitscript.com/forum/topic/51952-_sqlau3-adodbconnection/
#include <_SQL.au3>
;AutiIt UDFs
#include <array.au3>
#include <File.au3>
#include <String.au3>
#include <FileConstants.au3>
#include <SQLite.au3>
#include <SQLite.dll.au3>
#include <MsgBoxConstants.au3>
#include <StringConstants.au3>
#include <WinAPIFiles.au3>
#include <Date.au3>
#include <Constants.au3>



;Constants
global const $gcVersion = FileGetVersion(@ScriptName,"ProductVersion")
global const $gcScannameLimit = 65535				;max number of scannames resturnd from the DB
;Debug
global const $gcDEBUG = False						;master switch for debug output

global $gcDEBUGOnlyShowScanBuffer = True		;show only "searching" and buffersize during scan !
global $gcDEBUGShowVisitedDirectories = False	;show visited directories during scan !
global $gcDEBUGDoNotStartSecondProcess = False	;run only the list process and do not start the scan process
global $gcDEBUGRunWithoutCompilation = False		;force the program to run, without beeing compiled
Global $gcDEBUGShowEmptyScanBuffer = False		;show "*** searching ***" if the scan process is waiting for the list process


;Profiler
global $gcDEBUGTimeGetFileInfo = True
global $gcDEBUGTimeGetRuleFromRuleSet = True
global $gcDEBUGTimeIsExecutable = True
global $gcDEBUGTimeIsIncludedByRule = True
global $gcDEBUGTimeIsClimbTargetByRule = True

global $giDEBUGTimerGetFileInfo = 0
global $giDEBUGTimerGetRuleFromRuleSet = 0
global $giDEBUGTimerIsExecutable = 0
global $giDEBUGTimerIsIncludedByRule = 0
global $giDEBUGTimerIsClimbTargetByRule = 0

if $gcDEBUG = False Then
   $gcDEBUGOnlyShowScanBuffer = False
   $gcDEBUGShowVisitedDirectories = False
   $gcDEBUGDoNotStartSecondProcess = False
   $gcDEBUGRunWithoutCompilation = False
   $gcDEBUGShowEmptyScanBuffer = False

   $gcDEBUGTimeGetFileInfo = False
   $gcDEBUGTimeGetRuleFromRuleSet = False
   $gcDEBUGTimeIsExecutable = False
   $gcDEBUGTimeIsIncludedByRule = False
   $gcDEBUGTimeIsClimbTargetByRule = False
EndIf




;Compile options
Opt("TrayIconHide", 1)
;Opt("MustDeclareVars", 1)



;Variables
global $gaRuleSet[1][3]	;all rules form config db table
						;$gaRuleSet
						;.....................................
						;command    | parameter | rulenumber
						;-------------------------------------
                        ;EmailFrom: | i@y.com   | 0
			            ;EmailTo:   | y@i.com   | 0
						;Rule:      | Test      | 1
						;IncDir:    | "c:\test" | 1
						;IncExt:    | txt       | 1
						;Rule:      | Logfiles  | 2
						;IncDir:    | "c:\tst1" | 2
						;IncExt:    | log       | 2
						;.....................................
global $gaRuleStart[1]   	    ;Index of start of all rules in $gaRuleSet[]
global const $gcIncExt = 0 	    ;column index for IncExt parameters in $gaRuleData[]
global const $gcExcExt = 1	    ;column index for ExcExt parameters in $gaRuleData[]
global const $gcIncExe = 2	    ;column index for IncExe parameters in $gaRuleData[]
global const $gcExcExe = 3	    ;column index for ExcExe parameters in $gaRuleData[]
global const $gcIncAll = 4	    ;column index for IncAll parameters in $gaRuleData[]
global const $gcExcAll = 5	    ;column index for ExcAll parameters in $gaRuleData[]
global const $gcNoHashes  = 6	;column index for NoHashes parameters in $gaRuleData[]
global const $gcExcDirs   = 7	;column index for ExcDirs parameters in $gaRuleData[]
global const $gcHasExcDir = 8   ;column index for the existence of "ExcDir:" or "ExcDirRec:" parameters in $gaRuleData[]
global $gaRuleData[1][9]	;all infos of extension statements of a rule
		;........................................................................................................................................
		;IncExt           | ExcExt           | IncExe    | ExcExe    | IncAll    | ExcAll    | NoHashes    | ExcDirs    | are there "ExcDir:" or "ExcDirRec:"
		;                 |                  |           |           |           |           |             |            | statements in the rule ?
		;$gcIncExt        | $gcExcExt        | $gcIncExe | $gcExcExe | $gcIncAll | $gcExcAll | $gcNoHashes | $gcExcDirs | $gcHasExcDir
		;----------------------------------------------------------------------------------------------------------------------------------------
		;".txt.dll.docx." | ".txt.dll.xlsx." | True      | False     | True      | False     | True        | True
		;........................................................................................................................................
global $gaRuleSetLineDirStringLenPlusOne[1]		;stringlen($gaRuleSet[$i][1] & "\") for every "IncDir:","ExcDir:","IncDirRec:","ExcDirRec:" line in $gaRuleSet[]
global $gaRuleSetLineBackslashCount[1] 			;number of backslashes for every "IncDir:" and "ExcDir:" line in $gaRuleSet[]
global $giCurrentDirBackslashCount 				;number of backslashes in the currently scanned path
global $gaFileInfo[22]		;array with informations about the file
#cs
		 $gaFileInfo[0]		;name
		 $gaFileInfo[1]		;file could not be read 1 else 0
		 $gaFileInfo[2]		;size
		 $gaFileInfo[3]		;attributes (obsolete)
		 $gaFileInfo[4]		;file modification timestamp
		 $gaFileInfo[5]		;file creation timestamp
		 $gaFileInfo[6]		;file accessed timestamp
		 $gaFileInfo[7]		;version
		 $gaFileInfo[8]		;8.3 short path+name
		 $gaFileInfo[9]		;crc32
		 $gaFileInfo[10]	;md5 hash
		 $gaFileInfo[11]	;time it took to process the file
		 $gaFileInfo[12]	;rulename
		 $gaFileInfo[13]	;1 if the "R" = READONLY attribute is set
		 $gaFileInfo[14]	;1 if the "A" = ARCHIVE attribute is set
		 $gaFileInfo[15]	;1 if the "S" = SYSTEM attribute is set
		 $gaFileInfo[16]	;1 if the "H" = HIDDEN attribute is set
		 $gaFileInfo[17]	;1 if the "N" = NORMAL attribute is set
		 $gaFileInfo[18]	;1 if the "D" = DIRECTORY attribute is set
		 $gaFileInfo[19]	;1 if the "O" = OFFLINE attribute is set
		 $gaFileInfo[20]	;1 if the "C" = COMPRESSED (NTFS compression, not ZIP compression) attribute is set
		 $gaFileInfo[21]	;1 if the "T" = TEMPORARY attribute is set
#ce
global $gsScantime = ""		;date and time of the scan
global $giScanId	= 0		;scanid
global $ghDBHandle = ""		;handle of db
global $gbMSSQL = False		;True if DB is an INI-file with the connection parameter for an MSSQL-server !

;mailer setup
Global $goMyRet[2]
Global $goMyError = ObjEvent("AutoIt.Error", "MyErrFunc")

;IsExecutable() global lookup
global $giIsExecutableLastResult = False	;result of last call to IsExecutable()
global $gsIsExecutableLastFilename = ""		;filname used for last call to IsExecutable()

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
   DoShowUsage()
   exit (1)
EndIf

select
   Case $CmdLine[1] = "/duplicates"
	  if $CmdLine[0] < 3 then
 		 DoShowUsage()
		 exit (1)
	  EndIf

	  ;$sDBName = $CmdLine[2]
	  ;$sScanname = $CmdLine[3]

	  if FileExists($CmdLine[2]) then
		 OpenDB($CmdLine[2])

		 DoDuplicates($CmdLine[3])

		 CloseDB()
	  Else
		 ConsoleWriteError("Error:" & @CRLF & "Database file not found !" & @CRLF & "Filename:" & $CmdLine[2])
	  EndIf

   Case $CmdLine[1] = "/exportscan"
	  if $CmdLine[0] < 4 then
 		 DoShowUsage()
		 exit (1)
	  EndIf

	  ;$sDBName = $CmdLine[2]
	  ;$sScanname = $CmdLine[3]
	  ;$sCSVFilename = $CmdLine[4]

	  if FileExists($CmdLine[2]) then
		 OpenDB($CmdLine[2])

		 DoExportScan($CmdLine[3],$CmdLine[4])

		 CloseDB()
	  Else
		 ConsoleWriteError("Error:" & @CRLF & "Database file not found !" & @CRLF & "Filename:" & $CmdLine[2])
	  EndIf

   Case $CmdLine[1] = "/importcfg"
	  if $CmdLine[0] < 3 then
 		 DoShowUsage()
		 exit (1)
	  EndIf

	  ;$sDBName = $CmdLine[2]
	  ;$ConfigFilename = $CmdLine[3]

	  OpenDB($CmdLine[2])

	  DoImportCfg($CmdLine[3])

	  CloseDB()

   Case $CmdLine[1] = "/exportcfg"
	  if $CmdLine[0] < 3 then
 		 DoShowUsage()
		 exit (1)
	  EndIf

	  ;$sDBName = $CmdLine[2]
	  ;$ConfigFilename = $CmdLine[3]

	  if FileExists($CmdLine[2]) then
		 OpenDB($CmdLine[2])

		 DoExportCfg($CmdLine[3])

		 CloseDB()
	  Else
		 ConsoleWriteError("Error:" & @CRLF & "Database file not found !" & @CRLF & "Filename:" & $CmdLine[2])
	  EndIf

   Case $CmdLine[1] = "/validate"
	  if $CmdLine[0] < 3 then
 		 DoShowUsage()
		 exit (1)
	  EndIf

	  ;$sDBName = $CmdLine[2]
	  ;$sScanname = $CmdLine[3]

	  if FileExists($CmdLine[2]) then
		 OpenDB($CmdLine[2])

		 DoValidateScan($CmdLine[3])

		 CloseDB()
	  Else
		 ConsoleWriteError("Error:" & @CRLF & "Database file not found !" & @CRLF & "Filename:" & $CmdLine[2])
	  EndIf


   Case $CmdLine[1] = "/invalidate"
	  if $CmdLine[0] < 3 then
 		 DoShowUsage()
		 exit (1)
	  EndIf

	  ;$sDBName = $CmdLine[2]
	  ;$sScanname = $CmdLine[3]

	  if FileExists($CmdLine[2]) then
		 OpenDB($CmdLine[2])

		 DoInvalidateScan($CmdLine[3])

		 CloseDB()
	  Else
		 ConsoleWriteError("Error:" & @CRLF & "Database file not found !" & @CRLF & "Filename:" & $CmdLine[2])
	  EndIf


   Case $CmdLine[1] = "/delete"
	  if $CmdLine[0] < 3 then
 		 DoShowUsage()
		 exit (1)
	  EndIf

	  ;$sDBName = $CmdLine[2]
	  ;$sScanname = $CmdLine[3]

	  if FileExists($CmdLine[2]) then
		 OpenDB($CmdLine[2])

		 DoDeleteScan($CmdLine[3])

		 CloseDB()
	  Else
		 ConsoleWriteError("Error:" & @CRLF & "Database file not found !" & @CRLF & "Filename:" & $CmdLine[2])
	  EndIf


   Case $CmdLine[1] = "/history"

	  if $CmdLine[0] < 3 then
		 DoShowUsage()
		 exit (1)
	  EndIf

	  ;$sDBName = $CmdLine[2]
	  ;SEARCHSTRING = $CmdLine[3]

	  if FileExists($CmdLine[2]) then
		 OpenDB($CmdLine[2])

		 DoHistory($CmdLine[3])

		 CloseDB()
	  Else
		 ConsoleWriteError("Error:" & @CRLF & "Database file not found !" & @CRLF & "Filename:" & $CmdLine[2])
	  EndIf


   Case $CmdLine[1] = "/list"
	  if $CmdLine[0] < 2 then
		 DoShowUsage()
		 exit (1)
	  EndIf
	  ;$sDBName = $CmdLine[2]

	  if FileExists($CmdLine[2]) then
		 OpenDB($CmdLine[2])

		 DoListScan()

		 CloseDB()
	  Else
		 ConsoleWriteError("Error:" & @CRLF & "Database file not found !" & @CRLF & "Filename:" & $CmdLine[2])
	  EndIf


   Case $CmdLine[1] = "/secondprocess"
	  if $CmdLine[0] < 2 then
 		 DoShowUsage()
		 exit (1)
	  EndIf

	  ;$sDBName = $CmdLine[2]

	  if FileExists($CmdLine[2]) then
		 OpenDB($CmdLine[2])

		 DoSecondProcess()

		 CloseDB()
	  Else
		 ConsoleWriteError("Error:" & @CRLF & "Database file not found !" & @CRLF & "Filename:" & $CmdLine[2])
	  EndIf


   Case $CmdLine[1] = "/scan"
	  ;scan with two processes
	  if $CmdLine[0] < 2 then
 		 DoShowUsage()
		 exit (1)
	  EndIf

	  if @Compiled or $gcDEBUGRunWithoutCompilation Then
		 ;$sDBName = $CmdLine[2]

		 if FileExists($CmdLine[2]) then
			OpenDB($CmdLine[2])

			DoScanWithSecondProcess($CmdLine[2])

			CloseDB()
		 Else
			ConsoleWriteError("Error:" & @CRLF & "Database file not found !" & @CRLF & "Filename:" & $CmdLine[2])
		 EndIf
	  Else
		 ConsoleWriteError("For the " & $CmdLine[1] & " command to work " & @ScriptName & " must be compiled !")
	  EndIf

   Case $CmdLine[1] = "/report"

	  if $CmdLine[0] = 3 then
		 ;@ScriptName /report DB report.txt

		 if FileExists($CmdLine[2]) then
			OpenDB($CmdLine[2])

			DoReport($CmdLine[3])

			CloseDB()
		 Else
			ConsoleWriteError("Error:" & @CRLF & "Database file not found !" & @CRLF & "Filename:" & $CmdLine[2])
		 EndIf

	  elseif $CmdLine[0] = 4 then
		 ;@ScriptName /report DB SCANNAME report.txt

		 if FileExists($CmdLine[2]) then
			OpenDB($CmdLine[2])

			DoReport($CmdLine[4],"none",$CmdLine[3])

			CloseDB()
		 Else
			ConsoleWriteError("Error:" & @CRLF & "Database file not found !" & @CRLF & "Filename:" & $CmdLine[2])
		 EndIf


	  elseif $CmdLine[0] = 5 then
		 ;@ScriptName /report DB OLDSCANNAME NEWSCANNAME report.txt

		 if FileExists($CmdLine[2]) then
			OpenDB($CmdLine[2])

			DoReport($CmdLine[5],$CmdLine[3],$CmdLine[4])

			CloseDB()
		 Else
			ConsoleWriteError("Error:" & @CRLF & "Database file not found !" & @CRLF & "Filename:" & $CmdLine[2])
		 EndIf

	  Else
		 DoShowUsage()
		 exit (1)
	  EndIf

	  ;$sDBName = $CmdLine[2]
	  ;$ReportFilename = $CmdLine[3]


   Case $CmdLine[1] = "/help"
	  DoShowHelp()

   Case $CmdLine[1] = "/?"
	  DoShowHelp()

   Case $CmdLine[1] = "/v"
	  DoShowVersions()

   case Else
	  DoShowUsage()

EndSelect


Exit(0)





;---------------------------------------------------
; Functions
;---------------------------------------------------

;----- core functions -----

Func DoImportCfg($ConfigFilename)

   local $iCfgLineNr = 0
   local $sTempCfgLine = ""

   ;recreate table config
   if FileExists($ConfigFilename) then
	  if $gbMSSQL Then
		 _SQL_Execute(-1,"DROP TABLE config;")
		 _SQL_Execute(-1,"CREATE TABLE [config] ([linenumber] INTEGER IDENTITY(1,1)  ,[line] NTEXT NULL  ,CONSTRAINT [config_PRIMARY]  PRIMARY KEY  NONCLUSTERED  ([linenumber])); ")
	  Else
		 _SQLite_Exec(-1,"DROP TABLE IF EXISTS config;")
		 _SQLite_Exec(-1,"CREATE TABLE IF NOT EXISTS config (linenumber INTEGER PRIMARY KEY AUTOINCREMENT, line );")
	  EndIf
	  ;import $ConfigFilename into table config
	  $iCfgLineNr = 1
	  While True

		 $sTempCfgLine = ""
		 $sTempCfgLine = FileReadLine($ConfigFilename,$iCfgLineNr)
		 if @error then
			ExitLoop
		 EndIf
		 if $gbMSSQL Then
			_SQL_Execute(-1,"INSERT INTO [config] ([line]) VALUES (N'" & _StringToHex($sTempCfgLine) & "');")
		 Else
			_SQLite_Exec(-1,"INSERT INTO config(line) values ('" & _StringToHex($sTempCfgLine) & "');")
		 EndIf
		 $iCfgLineNr += 1
	  WEnd
   EndIf

EndFunc


Func DoExportCfg($ConfigFilename)

   local $aQueryResult = 0	;result of a query
   local $hQuery = 0		;handle to a query

   if FileExists($ConfigFilename) then
	  FileDelete($ConfigFilename)
   EndIf

   ;export table config into $ConfigFilename
   $aQueryResult = 0
   $hQuery = 0
   if $gbMSSQL Then
	  $hQuery = _SQL_Execute(-1, "SELECT line FROM config ORDER BY linenumber ASC;")
	  While _SQL_FetchData($hQuery, $aQueryResult) = $SQL_OK
		 FileWriteLine($ConfigFilename,_HexToString($aQueryResult[0]))
	  WEnd

   Else
	  _SQLite_Query(-1, "SELECT line FROM config ORDER BY linenumber ASC;",$hQuery)
	  While _SQLite_FetchData($hQuery, $aQueryResult) = $SQLITE_OK
		 FileWriteLine($ConfigFilename,_HexToString($aQueryResult[0]))
	  WEnd
	  _SQLite_QueryFinalize($hQuery)
   EndIf
EndFunc


Func DoDuplicates($sScanname)

   ;list duplicate files in a scan
   ;based on size,crc32,md5
   ;------------------------------------------------

   local $aQueryResult = 0	;result of a query
   local $hQuery = 0		;handle to a query
   local $sLastCrit = ""
   local $sLastFilename = ""
   local $sTempSQL = ""
   local $iLastLinePrinted = False


   $aQueryResult = 0
   if GetScannamesFromDB($sScanname,$aQueryResult) Then
	  ;for $i = 2 to $aQueryResult[0]

	  $sTempSQL = "SELECT "
	  $sTempSQL &= "scans.scantime as scantime,"
	  $sTempSQL &= "filenames.path as path,"
	  $sTempSQL &= "filedata.status as status,"
	  $sTempSQL &= "filedata.size as size,"
	  $sTempSQL &= "filedata.crc32 as crc32,"
	  $sTempSQL &= "filedata.md5 as md5 "
	  ;$sTempSQL &= "count(filedata.md5) "
	  $sTempSQL &= "FROM scans,filedata,filenames "
	  $sTempSQL &= "WHERE "
	  $sTempSQL &= "scans.scantime = '" & $aQueryResult[2] & "' AND "
	  $sTempSQL &= "filedata.scanid = scans.scanid AND "
	  $sTempSQL &= "filedata.filenameid = filenames.filenameid AND "
	  $sTempSQL &= "filedata.status = '0' AND "
	  $sTempSQL &= "filedata.size <> '0' AND "
	  $sTempSQL &= "filedata.crc32 <> '0' AND "
	  $sTempSQL &= "filedata.md5 <> '0' "
	  $sTempSQL &= "GROUP BY filedata.size,filedata.crc32,filedata.md5,filenames.path "
	  $sTempSQL &= "ORDER BY filedata.size,filedata.crc32,filedata.md5,filenames.path ASC;"

	  ConsoleWrite("scantime,size,crc32,md5,filename" & @CRLF)

	  $aQueryResult = 0
	  _SQLite_Query(-1, $sTempSQL,$hQuery)
	  While _SQLite_FetchData($hQuery, $aQueryResult) = $SQLITE_OK
		 if $aQueryResult[0] & "," & $aQueryResult[3] & "," & $aQueryResult[4] & "," & $aQueryResult[5] = $sLastCrit then
			ConsoleWrite($sLastCrit & ",""" & $sLastFilename & """" & @CRLF)
			$sLastFilename = _HexToString($aQueryResult[1])
			$iLastLinePrinted = True
		 Else
			if $iLastLinePrinted = True then ConsoleWrite($sLastCrit & ",""" & $sLastFilename & """" & @CRLF)
			$sLastCrit = $aQueryResult[0] & "," & $aQueryResult[3] & "," & $aQueryResult[4] & "," & $aQueryResult[5]
			$sLastFilename = _HexToString($aQueryResult[1])
			$iLastLinePrinted = False
		 EndIf
	  WEnd
	  _SQLite_QueryFinalize($hQuery)


   EndIf





EndFunc


Func DoHistory($sFilename)

   ;list the history of a filename and how it has
   ;changed from scan to scan
   ;------------------------------------------------

   local $aQueryResult = 0	;result of a query
   local $hQuery = 0		;handle to a query
   local $sLastFilename = ""
   local $sTempSQL = ""


   $sTempSQL = "SELECT "
   $sTempSQL &= "scans.scantime,"
   $sTempSQL &= "filenames.path,"

   $sTempSQL &= "scans.valid,"
   $sTempSQL &= "filedata.status,"

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
   $sTempSQL &= "rules.rulename,"
   $sTempSQL &= "filedata.rattrib,"
   $sTempSQL &= "filedata.aattrib,"
   $sTempSQL &= "filedata.sattrib,"
   $sTempSQL &= "filedata.hattrib,"
   $sTempSQL &= "filedata.nattrib,"
   $sTempSQL &= "filedata.dattrib,"
   $sTempSQL &= "filedata.oattrib,"
   $sTempSQL &= "filedata.cattrib,"
   $sTempSQL &= "filedata.tattrib "
   $sTempSQL &= "FROM filedata,filenames,rules,scans "
   $sTempSQL &= "WHERE "
   $sTempSQL &= "filedata.filenameid = filenames.filenameid AND "
   $sTempSQL &= "filedata.scanid = scans.scanid AND "
   $sTempSQL &= "filedata.ruleid = rules.ruleid"
   ;$sTempSQL &= ";"


   $sTempSQL &= " AND filenames.path like '%" & _StringToHex($sFilename) & "%' "
   $sTempSQL &= "ORDER BY filenames.path ASC,scans.scantime ASC;"

   OutputLineOfFileHistory($aQueryResult,True)
   _SQLite_Query(-1, $sTempSQL,$hQuery)
   While _SQLite_FetchData($hQuery, $aQueryResult) = $SQLITE_OK
	  ;_ArrayDisplay($aQueryResult)
	  if $sLastFilename <> _HexToString($aQueryResult[1]) then
		 if $sLastFilename <> "" then ConsoleWrite(@CRLF)
		 $sLastFilename = _HexToString($aQueryResult[1])
		 ConsoleWrite($sLastFilename & @CRLF)
	  EndIf
	  OutputLineOfFileHistory($aQueryResult,False)
   WEnd
   _SQLite_QueryFinalize($hQuery)



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


Func DoReport($ReportFilename,$sScannameOld = "lastvalid",$sScannameNew = "last")
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
   ;local $sScannameOld = ""
   ;local $sScannameNew = ""

   local $aQueryResult = 0	;result of a query
   local $hQuery = 0		;handle to a query

   local $aCfgQueryResult = 0	;result of a query on table config
   local $hCfgQuery = 0			;handle to a query on table config
   local $sTempCfgLine = ""

   local $sTempText = ""	;
   local $iTempCount = ""	;

   local $i = 0
   local $iCountMax = 0
   local $iCountMin = 0

   local $sTempSQL = ""
   local $iRuleNumber = 0

   local $iHasRuleHeader = False	;headline for each rule ist already printed

   GetRuleSetFromDB()


   $sTempSQL = "SELECT "
   $sTempSQL &= "scans.scantime,"
   $sTempSQL &= "filenames.path,"

   ;$sTempSQL &= "scans.valid,"
   $sTempSQL &= "filedata.status,"

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
   $sTempSQL &= "rules.rulename,"
   $sTempSQL &= "filedata.rattrib,"
   $sTempSQL &= "filedata.aattrib,"
   $sTempSQL &= "filedata.sattrib,"
   $sTempSQL &= "filedata.hattrib,"
   $sTempSQL &= "filedata.nattrib,"
   $sTempSQL &= "filedata.dattrib,"
   $sTempSQL &= "filedata.oattrib,"
   $sTempSQL &= "filedata.cattrib,"
   $sTempSQL &= "filedata.tattrib "
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
   ;_SQLite_Exec(-1,"DROP VIEW IF EXISTS scanold;")
   ;_SQLite_Exec(-1,"DROP VIEW IF EXISTS scannew;")




   ;$sScannameNew = ""
   $aQueryResult = 0
   if GetScannamesFromDB($sScannameNew,$aQueryResult) Then
	  ;_ArrayDisplay($aQueryResult)
	  $sScannameNew = $aQueryResult[2]
   Else
	  ConsoleWrite("Error:" & @CRLF & "New scan does not exist" & @CRLF & "Scan name: " & $sScannameNew)
	  $sScannameNew = ""
   EndIf

   if $sScannameOld <> "none" then
	  ;$sScannameOld = ""
	  $aQueryResult = 0
	  if GetScannamesFromDB($sScannameOld,$aQueryResult) Then
		 ;_ArrayDisplay($aQueryResult)
		 $sScannameOld = $aQueryResult[2]
	  Else
		 ConsoleWrite("Error:" & @CRLF & "Old scan does not exist" & @CRLF & "Scan name: " & $sScannameOld)
		 $sScannameOld = ""
	  EndIf
   EndIf

   if $sScannameOld = "" Then
	  ;ConsoleWrite("Error:" & @CRLF & "Old scan does not exist" & @CRLF & "Scan name: " & $sScannameOld)
   ElseIf $sScannameNew = "" Then
	  ;ConsoleWrite("Error:" & @CRLF & "New scan does not exist" & @CRLF & "Scan name: " & $sScannameNew)
   else

	  ;build temp tables (they are much faster than views in sqlite)

	  ConsoleWrite("report for old scan """ & $sScannameOld & """ and new scan """ & $sScannameNew & """")

	  _SQLite_Exec(-1,"CREATE TEMPORARY TABLE scannew as " & $sTempSQL & " AND scans.scantime = '" & $sScannameNew & "';")
	  _SQLite_Exec(-1,"CREATE TEMPORARY TABLE scanold as " & $sTempSQL & " AND scans.scantime = '" & $sScannameOld & "';")

	  ;SELECT scantime,rulename FROM files where scantime = '20160514212002' group by rulename order by rulename asc;

	  if GetNumberOfRulesFromRuleSet() > 0 Then

		 FileWriteLine($ReportFilename,@CRLF & "STD - Spot The Difference - v" & $gcVersion & @CRLF)
		 FileWriteLine($ReportFilename,"report for old scan """ & $sScannameOld & """ and new scan """ & $sScannameNew & """" & @CRLF)
		 FileWriteLine($ReportFilename,"generated: " & @YEAR & "." & @MON & "." & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC & @CRLF)
		 FileWriteLine($ReportFilename,@CRLF & "======================================================================" & @CRLF)

		 $sTempText = ""
		 FileWriteLine($ReportFilename,StringFormat(@CRLF & "%-40s %7s %7s %7s","rulename","changed","new","missing"))
		 FileWriteLine($ReportFilename,StringFormat("%-40s %7s %7s %7s","----------------------------------------","-------","-------","-------"))

		 ;summery per rule
		 for $i = 1 to GetNumberOfRulesFromRuleSet()

			$sTempText = StringFormat("%-40s",GetRulename($i))

			;return scan differences
			$aQueryResult = 0
			$hQuery = 0
			$iTempCount = 0

			$sTempSQL =  "SELECT "
			$sTempSQL &= "scannew.rulename,"
			$sTempSQL &= "count(scannew.rulename) "
			$sTempSQL &= "FROM scannew,scanold "
			$sTempSQL &= "WHERE "
			$sTempSQL &= "scannew.path = scanold.path and "
			$sTempSQL &= "scannew.rulename = scanold.rulename and "
			$sTempSQL &= "scannew.rulename = '" & GetRulename($i) & "' and "
			$sTempSQL &= "("
			if not IsFilepropertyIgnoredByRule("status",$i)       then $sTempSQL &= "scannew.status <> scanold.status or "
			if not IsFilepropertyIgnoredByRule("size",$i)         then $sTempSQL &= "scannew.size <> scanold.size or "
			;$sTempSQL &= "scannew.attributes <> scanold.attributes or "
			if not IsFilepropertyIgnoredByRule("atime",$i)        then $sTempSQL &= "scannew.atime <> scanold.atime or "
			if not IsFilepropertyIgnoredByRule("mtime",$i)        then $sTempSQL &= "scannew.mtime <> scanold.mtime or "
			if not IsFilepropertyIgnoredByRule("ctime",$i)        then $sTempSQL &= "scannew.ctime <> scanold.ctime or "
			if not IsFilepropertyIgnoredByRule("version",$i)      then $sTempSQL &= "scannew.version <> scanold.version or "
			if not IsFilepropertyIgnoredByRule("spath",$i)        then $sTempSQL &= "scannew.spath <> scanold.spath or "
			if not IsFilepropertyIgnoredByRule("crc32",$i)        then $sTempSQL &= "scannew.crc32 <> scanold.crc32 or "
			if not IsFilepropertyIgnoredByRule("md5",$i)          then $sTempSQL &= "scannew.md5 <> scanold.md5 or "
			if not IsFilepropertyIgnoredByRule("rattrib",$i)      then $sTempSQL &= "scannew.rattrib <> scanold.rattrib or "
			if not IsFilepropertyIgnoredByRule("aattrib",$i)      then $sTempSQL &= "scannew.aattrib <> scanold.aattrib or "
			if not IsFilepropertyIgnoredByRule("sattrib",$i)      then $sTempSQL &= "scannew.sattrib <> scanold.sattrib or "
			if not IsFilepropertyIgnoredByRule("hattrib",$i)      then $sTempSQL &= "scannew.hattrib <> scanold.hattrib or "
			if not IsFilepropertyIgnoredByRule("nattrib",$i)      then $sTempSQL &= "scannew.nattrib <> scanold.nattrib or "
			if not IsFilepropertyIgnoredByRule("dattrib",$i)      then $sTempSQL &= "scannew.dattrib <> scanold.dattrib or "
			if not IsFilepropertyIgnoredByRule("oattrib",$i)      then $sTempSQL &= "scannew.oattrib <> scanold.oattrib or "
			if not IsFilepropertyIgnoredByRule("cattrib",$i)      then $sTempSQL &= "scannew.cattrib <> scanold.cattrib or "
			if not IsFilepropertyIgnoredByRule("tattrib",$i)      then $sTempSQL &= "scannew.tattrib <> scanold.tattrib or "
			$sTempSQL &= ");"

			;fix sql statement
			$sTempSQL = StringReplace($sTempSQL," and ();",";")
			$sTempSQL = StringReplace($sTempSQL," or );",");")


			_SQLite_Query(-1, $sTempSQL,$hQuery)
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
			_SQLite_Query(-1,"SELECT scannew.rulename,count(scannew.rulename) FROM scannew LEFT JOIN scanold ON scannew.path = scanold.path and scannew.rulename = scanold.rulename WHERE scannew.rulename = '" & GetRulename($i) & "' and scanold.path IS NULL;" ,$hQuery)
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
			_SQLite_Query(-1,"SELECT scanold.rulename,count(scanold.rulename) FROM scanold LEFT JOIN scannew ON scannew.path = scanold.path and scannew.rulename = scanold.rulename WHERE scanold.rulename = '" & GetRulename($i) & "' and scannew.path IS NULL;",$hQuery)
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
		 for $i = 1 to GetNumberOfRulesFromRuleSet()

			$iHasRuleHeader = False
			;FileWriteLine($ReportFilename,@crlf & "----------------------------------------------------------------------")
			;FileWriteLine($ReportFilename,"rule     : " & GetRulename($i))
			;FileWriteLine($ReportFilename,"----------------------------------------------------------------------" & @CRLF)

			;return scan differences
			$aQueryResult = 0
			$hQuery = 0

			$sTempSQL =  "SELECT "
			$sTempSQL &= "scannew.path "
			$sTempSQL &= "FROM scannew,scanold "
			$sTempSQL &= "WHERE "
			$sTempSQL &= "scannew.path = scanold.path and "
			$sTempSQL &= "scannew.rulename = scanold.rulename and "
			$sTempSQL &= "scannew.rulename = '" & GetRulename($i) & "' and "
			$sTempSQL &= "("
			if not IsFilepropertyIgnoredByRule("status",$i)       then $sTempSQL &= "scannew.status <> scanold.status or "
			if not IsFilepropertyIgnoredByRule("size",$i)         then $sTempSQL &= "scannew.size <> scanold.size or "
			;$sTempSQL &= "scannew.attributes <> scanold.attributes or "
			if not IsFilepropertyIgnoredByRule("atime",$i)        then $sTempSQL &= "scannew.atime <> scanold.atime or "
			if not IsFilepropertyIgnoredByRule("mtime",$i)        then $sTempSQL &= "scannew.mtime <> scanold.mtime or "
			if not IsFilepropertyIgnoredByRule("ctime",$i)        then $sTempSQL &= "scannew.ctime <> scanold.ctime or "
			if not IsFilepropertyIgnoredByRule("version",$i)      then $sTempSQL &= "scannew.version <> scanold.version or "
			if not IsFilepropertyIgnoredByRule("spath",$i)        then $sTempSQL &= "scannew.spath <> scanold.spath or "
			if not IsFilepropertyIgnoredByRule("crc32",$i)        then $sTempSQL &= "scannew.crc32 <> scanold.crc32 or "
			if not IsFilepropertyIgnoredByRule("md5",$i)          then $sTempSQL &= "scannew.md5 <> scanold.md5 or "
			if not IsFilepropertyIgnoredByRule("rattrib",$i)      then $sTempSQL &= "scannew.rattrib <> scanold.rattrib or "
			if not IsFilepropertyIgnoredByRule("aattrib",$i)      then $sTempSQL &= "scannew.aattrib <> scanold.aattrib or "
			if not IsFilepropertyIgnoredByRule("sattrib",$i)      then $sTempSQL &= "scannew.sattrib <> scanold.sattrib or "
			if not IsFilepropertyIgnoredByRule("hattrib",$i)      then $sTempSQL &= "scannew.hattrib <> scanold.hattrib or "
			if not IsFilepropertyIgnoredByRule("nattrib",$i)      then $sTempSQL &= "scannew.nattrib <> scanold.nattrib or "
			if not IsFilepropertyIgnoredByRule("dattrib",$i)      then $sTempSQL &= "scannew.dattrib <> scanold.dattrib or "
			if not IsFilepropertyIgnoredByRule("oattrib",$i)      then $sTempSQL &= "scannew.oattrib <> scanold.oattrib or "
			if not IsFilepropertyIgnoredByRule("cattrib",$i)      then $sTempSQL &= "scannew.cattrib <> scanold.cattrib or "
			if not IsFilepropertyIgnoredByRule("tattrib",$i)      then $sTempSQL &= "scannew.tattrib <> scanold.tattrib or "
			$sTempSQL &= ");"

			;fix sql statement
			$sTempSQL = StringReplace($sTempSQL," and ();",";")
			$sTempSQL = StringReplace($sTempSQL," or );",");")

			if $sScannameOld <> "none" then
			   _SQLite_Query(-1, $sTempSQL,$hQuery)
			   While _SQLite_FetchData($hQuery, $aQueryResult) = $SQLITE_OK
				  ;OutputLineOfQueryResult($aQueryResult,$ReportFilename)
				  if not $iHasRuleHeader then
					 OutputLineOfQueryResultHeadline($i,$ReportFilename)
					 $iHasRuleHeader = True
				  EndIf
				  FileWriteLine($ReportFilename,StringFormat("%-8s : %s","changed",_HexToString($aQueryResult[0])))
			   WEnd
			   _SQLite_QueryFinalize($hQuery)
			EndIf

			;return new files
			$aQueryResult = 0
			$hQuery = 0
			_SQLite_Query(-1,"SELECT scannew.path FROM scannew LEFT JOIN scanold ON scannew.path = scanold.path and scannew.rulename = scanold.rulename WHERE scannew.rulename = '" & GetRulename($i) & "' and scanold.path IS NULL;" ,$hQuery)
			While _SQLite_FetchData($hQuery, $aQueryResult) = $SQLITE_OK
			   ;OutputLineOfQueryResult($aQueryResult,$ReportFilename)
			   if not $iHasRuleHeader then
				  OutputLineOfQueryResultHeadline($i,$ReportFilename)
				  $iHasRuleHeader = True
			   EndIf
			   FileWriteLine($ReportFilename,StringFormat("%-8s : %s","new",_HexToString($aQueryResult[0])))
			WEnd
			_SQLite_QueryFinalize($hQuery)

			if $sScannameOld <> "none" then
			   ;return deleted files
			   $aQueryResult = 0
			   $hQuery = 0
			   _SQLite_Query(-1,"SELECT scanold.path FROM scanold LEFT JOIN scannew ON scannew.path = scanold.path and scannew.rulename = scanold.rulename WHERE scanold.rulename = '" & GetRulename($i) & "' and scannew.path IS NULL;",$hQuery)
			   While _SQLite_FetchData($hQuery, $aQueryResult) = $SQLITE_OK
				  ;OutputLineOfQueryResult($aQueryResult,$ReportFilename)
				  if not $iHasRuleHeader then
					 OutputLineOfQueryResultHeadline($i,$ReportFilename)
					 $iHasRuleHeader = True
				  EndIf
				  FileWriteLine($ReportFilename,StringFormat("%-8s : %s","missing",_HexToString($aQueryResult[0])))
			   WEnd
			   _SQLite_QueryFinalize($hQuery)
			EndIf
		 Next
		 FileWriteLine($ReportFilename,@CRLF & "======================================================================" & @CRLF)

		 ;details per rule
		 for $i = 1 to GetNumberOfRulesFromRuleSet()

			$iHasRuleHeader = False
			;FileWriteLine($ReportFilename,@crlf & "----------------------------------------------------------------------")
			;FileWriteLine($ReportFilename,"rule     : " & GetRulename($i))
			;FileWriteLine($ReportFilename,"----------------------------------------------------------------------" & @CRLF)

			;return scan differences
			$aQueryResult = 0
			$hQuery = 0

			$sTempSQL =  "SELECT "
			$sTempSQL &= "scanold.*,scannew.* "
			$sTempSQL &= "FROM scannew,scanold "
			$sTempSQL &= "WHERE "
			$sTempSQL &= "scannew.path = scanold.path and "
			$sTempSQL &= "scannew.rulename = scanold.rulename and "
			$sTempSQL &= "scannew.rulename = '" & GetRulename($i) & "' and "
			$sTempSQL &= "("
			if not IsFilepropertyIgnoredByRule("status",$i)       then $sTempSQL &= "scannew.status <> scanold.status or "
			if not IsFilepropertyIgnoredByRule("size",$i)         then $sTempSQL &= "scannew.size <> scanold.size or "
			;$sTempSQL &= "scannew.attributes <> scanold.attributes or "
			if not IsFilepropertyIgnoredByRule("atime",$i)        then $sTempSQL &= "scannew.atime <> scanold.atime or "
			if not IsFilepropertyIgnoredByRule("mtime",$i)        then $sTempSQL &= "scannew.mtime <> scanold.mtime or "
			if not IsFilepropertyIgnoredByRule("ctime",$i)        then $sTempSQL &= "scannew.ctime <> scanold.ctime or "
			if not IsFilepropertyIgnoredByRule("version",$i)      then $sTempSQL &= "scannew.version <> scanold.version or "
			if not IsFilepropertyIgnoredByRule("spath",$i)        then $sTempSQL &= "scannew.spath <> scanold.spath or "
			if not IsFilepropertyIgnoredByRule("crc32",$i)        then $sTempSQL &= "scannew.crc32 <> scanold.crc32 or "
			if not IsFilepropertyIgnoredByRule("md5",$i)          then $sTempSQL &= "scannew.md5 <> scanold.md5 or "
			if not IsFilepropertyIgnoredByRule("rattrib",$i)      then $sTempSQL &= "scannew.rattrib <> scanold.rattrib or "
			if not IsFilepropertyIgnoredByRule("aattrib",$i)      then $sTempSQL &= "scannew.aattrib <> scanold.aattrib or "
			if not IsFilepropertyIgnoredByRule("sattrib",$i)      then $sTempSQL &= "scannew.sattrib <> scanold.sattrib or "
			if not IsFilepropertyIgnoredByRule("hattrib",$i)      then $sTempSQL &= "scannew.hattrib <> scanold.hattrib or "
			if not IsFilepropertyIgnoredByRule("nattrib",$i)      then $sTempSQL &= "scannew.nattrib <> scanold.nattrib or "
			if not IsFilepropertyIgnoredByRule("dattrib",$i)      then $sTempSQL &= "scannew.dattrib <> scanold.dattrib or "
			if not IsFilepropertyIgnoredByRule("oattrib",$i)      then $sTempSQL &= "scannew.oattrib <> scanold.oattrib or "
			if not IsFilepropertyIgnoredByRule("cattrib",$i)      then $sTempSQL &= "scannew.cattrib <> scanold.cattrib or "
			if not IsFilepropertyIgnoredByRule("tattrib",$i)      then $sTempSQL &= "scannew.tattrib <> scanold.tattrib or "
			$sTempSQL &= ");"

			;fix sql statement
			$sTempSQL = StringReplace($sTempSQL," and ();",";")
			$sTempSQL = StringReplace($sTempSQL," or );",");")

			if $sScannameOld <> "none" then
			   _SQLite_Query(-1, $sTempSQL,$hQuery)
			   While _SQLite_FetchData($hQuery, $aQueryResult) = $SQLITE_OK
				  if not $iHasRuleHeader then
					 OutputLineOfQueryResultHeadline($i,$ReportFilename)
					 $iHasRuleHeader = True
				  EndIf
				  OutputLineOfQueryResult($aQueryResult,$ReportFilename)
			   WEnd
			   _SQLite_QueryFinalize($hQuery)
			EndIf

			;return new files
			$aQueryResult = 0
			$hQuery = 0
			_SQLite_Query(-1,"SELECT scanold.*,scannew.* FROM scannew LEFT JOIN scanold ON scannew.path = scanold.path and scannew.rulename = scanold.rulename WHERE scannew.rulename = '" & GetRulename($i) & "' and scanold.path IS NULL;" ,$hQuery)
			While _SQLite_FetchData($hQuery, $aQueryResult) = $SQLITE_OK
			   if not $iHasRuleHeader then
				  OutputLineOfQueryResultHeadline($i,$ReportFilename)
				  $iHasRuleHeader = True
			   EndIf
			   OutputLineOfQueryResult($aQueryResult,$ReportFilename)
			WEnd
			_SQLite_QueryFinalize($hQuery)

			if $sScannameOld <> "none" then
			   ;return deleted files
			   $aQueryResult = 0
			   $hQuery = 0
			   _SQLite_Query(-1,"SELECT scanold.*,scannew.* FROM scanold LEFT JOIN scannew ON scannew.path = scanold.path and scannew.rulename = scanold.rulename WHERE scanold.rulename = '" & GetRulename($i) & "' and scannew.path IS NULL;",$hQuery)
			   While _SQLite_FetchData($hQuery, $aQueryResult) = $SQLITE_OK
				  if not $iHasRuleHeader then
					 OutputLineOfQueryResultHeadline($i,$ReportFilename)
					 $iHasRuleHeader = True
				  EndIf
				  OutputLineOfQueryResult($aQueryResult,$ReportFilename)
			   WEnd
			   _SQLite_QueryFinalize($hQuery)
			EndIf
		 Next

	  EndIf

	  ;drop old views
	  ;_SQLite_Exec(-1,"DROP VIEW IF EXISTS scanold;")
	  ;_SQLite_Exec(-1,"DROP VIEW IF EXISTS scannew;")

   EndIf

   if $iEmailReport = True then
	  ;email report and delete temp file

	  ;read email parameters from $gaRuleSet
	  $iRuleNumber = 0
	  $iCountMax = UBound($gaRuleSet,1)-1
	  $iCountMin = 1

	  for $i = $iCountMin to $iCountMax
		 if $gaRuleSet[$i][2] = $iRuleNumber then
;			if $gaRuleSet[$i][0] = "RuleId:" then $sRuleId = $gaRuleSet[$i][1]
			Select
			   Case $gaRuleSet[$i][0] = "EmailFrom:"
				  $aEMail[0] = $gaRuleSet[$i][1]
			   Case $gaRuleSet[$i][0] = "EmailTo:"
				  $aEMail[1] = $gaRuleSet[$i][1]
			   Case $gaRuleSet[$i][0] = "EmailSubject:"
				  $aEMail[2] = $gaRuleSet[$i][1]
			   Case $gaRuleSet[$i][0] = "EmailServer:"
				  $aEMail[3] = $gaRuleSet[$i][1]
			   Case $gaRuleSet[$i][0] = "EmailPort:"
				  $aEMail[4] = $gaRuleSet[$i][1]
			   case Else
			EndSelect

		 Else
			ExitLoop
		 EndIf
	  Next


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

   ;local $aCfgQueryResult = 0	;result of a query on table config
   ;local $hCfgQuery = 0		;handle to a query on table config

   local $aCSVQueryResult = 0	;result of a query on table config
   local $hCSVQuery = 0			;handle to a query on table config


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


Func DoScanWithSecondProcess($sDBName)

   ;generate a list with all the files and directories
   ;we need to scan and sends them to the "Second Process"
   ;that retrieves the file information and writes them
   ;into database
   ;------------------------------------------------

   local $iRuleNr = 0					;rule number
   local $i = 0							;counter
   local $j = 0							;counter
   local $iFound = False
   Local $iPID = 0						;process id of second process
   local $ScanTimer = TimerInit()
   local $iRuleCounter = 0
   local $aAllIncDirs[1]				;all the root directries we have to include

   GetRuleSetFromDB()

   ;only these rules must be checkt on the climbtarget (subdirectory)
   dim $aRelevantRulesForClimbTarget[UBound($gaRuleStart,1)]

   ;make a unique list ($aAllIncDirs) of only the top most dirs from the "IncDirRec:" and "IncDir:" statements in the ruleset

   ;read every line in the ruleset
   for $i=1 to UBound($gaRuleSet,1)-1

	  if $gaRuleSet[$i][0] = "IncDirRec:" or $gaRuleSet[$i][0] = "IncDir:" then
		 $iFound = False

		 for $j=1 To UBound($aAllIncDirs,1)-1
			;ConsoleWrite(StringLeft($aAllIncDirs[$j],StringLen($gaRuleSet[$i][1])) & @crlf & StringLeft($gaRuleSet[$i][1],StringLen($gaRuleSet[$i][1])) & @CRLF)
			if StringLen($aAllIncDirs[$j]) >= StringLen($gaRuleSet[$i][1]) and StringLeft($aAllIncDirs[$j],StringLen($gaRuleSet[$i][1])) = StringLeft($gaRuleSet[$i][1],StringLen($gaRuleSet[$i][1])) then
			   ;replace existing dir in $aAllIncDirs with a shorter, higher level dir in the same path
			   ;here doublicate entries get into $aAllIncDirs
			   $aAllIncDirs[$j] = $gaRuleSet[$i][1]
			   $iFound = True
			ElseIf StringLen($aAllIncDirs[$j]) < StringLen($gaRuleSet[$i][1]) and StringLeft($aAllIncDirs[$j],StringLen($aAllIncDirs[$j])) = StringLeft($gaRuleSet[$i][1],StringLen($aAllIncDirs[$j])) then
			   ;the dir in $aAllIncDirs is already a shorter and higher level dir in the same path as $gaRuleSet[$i][1]
			   $iFound = True
			EndIf
		 Next

		 ;append new dir entry to $aAllIncDirs
		 if $iFound = False then
			redim $aAllIncDirs[UBound($aAllIncDirs,1)+1]
			$aAllIncDirs[UBound($aAllIncDirs,1)-1] = $gaRuleSet[$i][1]
		 EndIf
	  EndIf

   Next
   ;remove doublicates in $aAllIncDirs
   $aAllIncDirs = _ArrayUnique($aAllIncDirs,1,0,0,0)

   ;_ArrayDisplay($aAllIncDirs)




   ;start the second process we send the filelist to
   ;$iPID = Run( @scriptname & " /secondprocess " & $sDBName, @WorkingDir, @SW_MINIMIZE, $STDIN_CHILD + $RUN_CREATE_NEW_CONSOLE)

   if Not $gcDEBUGDoNotStartSecondProcess then
	  $iPID = Run( @scriptname & " /secondprocess " & $sDBName, @WorkingDir, @SW_MINIMIZE, $STDIN_CHILD)
	  if @error then Exit
   EndIf

   ;_ArrayDisplay($aAllIncDirs)

   ;process all dirs in $aAllIncDirs
   for $i=1 to UBound($aAllIncDirs,1)-1
	  ;ConsoleWrite($aAllIncDirs[$i] & "\" & @CRLF)
	  for $iRuleCounter = 1 to UBound($gaRuleStart,1)-1
		 ;ConsoleWrite($iRuleCounter & @CRLF)
		 ;_ArrayDisplay($gaRuleStart)
		 ;_ArrayDisplay($gaRuleSet)

		 if IsClimbTargetByRule($aAllIncDirs[$i] & "\",$iRuleCounter) then
			$aRelevantRulesForClimbTarget[$iRuleCounter] = True
		 Else
			$aRelevantRulesForClimbTarget[$iRuleCounter] = False
		 EndIf
	  Next
	  ;_ArrayDisplay($aRelevantRulesForClimbTarget)
	  ;_ArrayDisplay($aAllIncDirs)
	  if Not $gcDEBUGDoNotStartSecondProcess then

		 TreeClimberSecondProcess($aAllIncDirs[$i],$iPID,$aRelevantRulesForClimbTarget)
	  EndIf
   Next

   if Not $gcDEBUGDoNotStartSecondProcess then
	  StdioClose($iPID)
   EndIf
   ;ConsoleWrite("Duration: " & Round(TimerDiff($ScanTimer)) & @CRLF)

   $ScanTimer = Round(TimerDiff($ScanTimer))

   if Not $gcDEBUGDoNotStartSecondProcess then
	  ;wait for "second process" to end
	  ProcessWaitClose($iPID)
   EndIf
   ConsoleWrite("List: " & $ScanTimer & @CRLF)

   if $gcDEBUGTimeGetFileInfo = True 			then ConsoleWrite("List-GetFileInfo:         " & Round($giDEBUGTimerGetFileInfo) & @CRLF)
   if $gcDEBUGTimeGetRuleFromRuleSet = True 	then ConsoleWrite("List-GetRuleFromRuleSet:  " & Round($giDEBUGTimerGetRuleFromRuleSet) & @CRLF)
   if $gcDEBUGTimeIsExecutable = True 			then ConsoleWrite("List-IsExecutable:        " & Round($giDEBUGTimerIsExecutable) & @CRLF)
   if $gcDEBUGTimeIsIncludedByRule = True 		then ConsoleWrite("List-IsIncludedByRule:    " & Round($giDEBUGTimerIsIncludedByRule) & @CRLF)
   if $gcDEBUGTimeIsClimbTargetByRule = True 	then ConsoleWrite("List-IsClimbTargetByRule: " & Round($giDEBUGTimerIsClimbTargetByRule) & @CRLF)


EndFunc


Func DoSecondProcess()

   ;read a list with all the files and directories
   ;we need to scan from stdin and
   ;retrieves the file information and writes them
   ;into database
   ;------------------------------------------------


   local $sFullPath = ""				;directory or filename read from stdin
   local $sInputBuffer = ""				;buffer for stdin
   local $iRuleCounter = 0
   local $iRuleCounterMax = 0
   local $sTempText = ""
   local $ScanTimer = TimerInit()
   local $iIdleCounter = 0				;times we had to wait for the list process (first process)

   GetRuleSetFromDB()

   ; how many rules are there in the ruleset
   $iRuleCounterMax = GetNumberOfRulesFromRuleSet()


   $gsScantime = @YEAR & @MON & @MDAY & @HOUR & @MIN & @SEC
   $giScanId = GetScanIDFromDB($gsScantime)

   while 1
	  ;read every file or directory we have to put in the db form stdin
	  ;a directory ends with \

	  ;read a bunch of caracters from stdin into a buffer
	  $sInputBuffer = $sInputBuffer & ConsoleRead()
	  If @error and StringLen($sInputBuffer) = 0 Then ; Exit the loop if the process closes or StdoutRead returns an error and the buffer is empty
		 ExitLoop
	  EndIf
	  if @extended then
		 if $gcDEBUGOnlyShowScanBuffer then
			StringReplace($sInputBuffer,@CRLF,"")
			ConsoleWrite( StringFormat("** %9i **",@extended) & $sTempText & @CRLF)
		 EndIf
		 While StringInStr($sInputBuffer,@CRLF) > 0

			;read and empty the buffer line by line
			$sFullPath = StringLeft($sInputBuffer,StringInStr($sInputBuffer,@CRLF)-1)

			$sInputBuffer = StringTrimLeft($sInputBuffer,Stringlen($sFullPath)+2)

			$iRuleCounter = Number(StringLeft($sFullPath,5))

			$sFullPath = StringTrimLeft($sFullPath,5)

			;get the file information
		    GetFileInfo($gaFileInfo,$sFullPath,Not $gaRuleData[$iRuleCounter][$gcNoHashes])

			;list every file or directory we scan - reading is NOT scanning !!!
			$sTempText = GetRulename($iRuleCounter) & " : " & $sFullPath
			;$sTempText = OEM2ANSI($sTempText) ; translate from OEM to ANSI
			;DllCall('user32.dll','Int','OemToChar','str',$sTempText,'str','') ; translate from OEM to ANSI
			if not $gcDEBUGOnlyShowScanBuffer then ConsoleWrite($sTempText & @CRLF)

			if $gbMSSQL then
			   _SQL_Execute(-1,"INSERT INTO [filedata] ([scanid],[ruleid],[filenameid],[status],[size],[attributes],[mtime],[ctime],[atime],[version],[crc32],[md5],[ptime],[rattrib],[aattrib],[sattrib],[hattrib],[nattrib],[dattrib],[oattrib],[cattrib],[tattrib])  values ('" & $giScanId & "','" & GetRuleIdFromRuleSet($iRuleCounter) & "','" & GetFilenameIDFromDB(_StringToHex($gaFileInfo[0]),$gaFileInfo[8]) & "','" & $gaFileInfo[1] & "','" & $gaFileInfo[2] & "','" & $gaFileInfo[3] & "','" & $gaFileInfo[4] & "','" & $gaFileInfo[5] & "','" & $gaFileInfo[6] & "','" & $gaFileInfo[7] & "','" & $gaFileInfo[9] & "','" & $gaFileInfo[10] & "','" & $gaFileInfo[11] & "','" & $gaFileInfo[13] & "','" & $gaFileInfo[14] & "','" & $gaFileInfo[15] & "','" & $gaFileInfo[16] & "','" & $gaFileInfo[17] & "','" & $gaFileInfo[18] & "','" & $gaFileInfo[19] & "','" & $gaFileInfo[20] & "','" & $gaFileInfo[21] & "');")
			Else
			   _SQLite_Exec(-1,"INSERT INTO filedata (scanid,ruleid,filenameid,status,size,attributes,mtime,ctime,atime,version,crc32,md5,ptime,rattrib,aattrib,sattrib,hattrib,nattrib,dattrib,oattrib,cattrib,tattrib)  values ('" & $giScanId & "', '" & GetRuleIdFromRuleSet($iRuleCounter) & "', '" & GetFilenameIDFromDB(_StringToHex($gaFileInfo[0]),$gaFileInfo[8]) & "','" & $gaFileInfo[1] & "','" & $gaFileInfo[2] & "','" & $gaFileInfo[3] & "','" & $gaFileInfo[4] & "','" & $gaFileInfo[5] & "','" & $gaFileInfo[6] & "','" & $gaFileInfo[7] & "','" & $gaFileInfo[9] & "','" & $gaFileInfo[10] & "','" & $gaFileInfo[11] & "','" & $gaFileInfo[13] & "','" & $gaFileInfo[14] & "','" & $gaFileInfo[15] & "','" & $gaFileInfo[16] & "','" & $gaFileInfo[17] & "','" & $gaFileInfo[18] & "','" & $gaFileInfo[19] & "','" & $gaFileInfo[20] & "','" & $gaFileInfo[21] & "');")
			EndIf

		 WEnd
	  Else
		 ;no data in stdin, so let큦 wait a bid
		 if $gcDEBUGOnlyShowScanBuffer or $gcDEBUGShowEmptyScanBuffer then ConsoleWrite("** searching **" & @CRLF)
		 sleep(1000)
		 $iIdleCounter += 1
	  EndIf
   WEnd

   ConsoleWrite("Scan: " & Round(TimerDiff($ScanTimer) - $iIdleCounter*1000) & @CRLF)

   if $gcDEBUGTimeGetFileInfo = True 			then ConsoleWrite("Scan-GetFileInfo:         " & Round($giDEBUGTimerGetFileInfo) & @CRLF)
   if $gcDEBUGTimeGetRuleFromRuleSet = True 	then ConsoleWrite("Scan-GetRuleFromRuleSet:  " & Round($giDEBUGTimerGetRuleFromRuleSet) & @CRLF)
   if $gcDEBUGTimeIsExecutable = True 			then ConsoleWrite("Scan-IsExecutable:        " & Round($giDEBUGTimerIsExecutable) & @CRLF)
   if $gcDEBUGTimeIsIncludedByRule = True 		then ConsoleWrite("Scan-IsIncludedByRule:    " & Round($giDEBUGTimerIsIncludedByRule) & @CRLF)
   if $gcDEBUGTimeIsClimbTargetByRule = True 	then ConsoleWrite("Scan-IsClimbTargetByRule: " & Round($giDEBUGTimerIsClimbTargetByRule) & @CRLF)




EndFunc


Func DoShowHelp()

   ;show help
   ;---------------------------------------

   local $sText = ""

   $sText &= "STD - Spot The Difference (" & $gcVersion & ")" & @CRLF
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
   $sText &= @ScriptName & " /report DB [[OLDSCANNAME] NEWSCANNAME] REPORTFILE" & @CRLF
   $sText &= @ScriptName & " /report c:\test.sqlite c:\report.txt" & @CRLF
   $sText &= @ScriptName & " /report c:\test.sqlite 20160514131610 c:\report.txt" & @CRLF
   $sText &= @ScriptName & " /report c:\test.sqlite 20160514131610 last c:\report.txt" & @CRLF
   $sText &= "Write the differences between NEWSCANNAME and OLDSCANNAME to REPORTFILE." & @CRLF
   $sText &= "If NEWSCANNAME and OLDSCANNAME are omitted then NEWSCANNAME defaults to last" & @CRLF
   $sText &= "and OLDSCANNAME to lastvalid." & @CRLF
   $sText &= "If only NEWSCANNAME is given then all the information from NEWSCANNAME" & @CRLF
   $sText &= "is written to REPORTFILE. This is useful if you like to know what is in a scan." & @CRLF

   $sText &= "REPORTFILE is either a regular filename or a SPECIAL_REPORTNAME." & @CRLF
   $sText &= "OLDSCANNAME and NEWSCANNAME are either existing scans" & @CRLF
   $sText &= "or SPECIAL_SCANNAMEs." & @CRLF


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
   $sText &= @ScriptName & " /duplicates DB SCANNAME" & @CRLF
   $sText &= @ScriptName & " /duplicates c:\test.sqlite last" & @CRLF
   $sText &= "Write a list with duplicate files based on size, crc32 and md5 in scan SCANNAME to stdout." & @CRLF
   $sText &= "SCANNAME is either an existing scan or a SPECIAL_SCANNAME. If scan is a SPECIAL_SCANNAME" & @CRLF
   $sText &= "only the first scan of the selected scans is used." & @CRLF
   $sText &= @CRLF
   $sText &= @ScriptName & " /history DB SEARCHTEXT" & @CRLF
   $sText &= @ScriptName & " /history c:\test.sqlite ""\temp\example.dll""" & @CRLF
   $sText &= "Write the change history of one or more files to stdout." & @CRLF
   $sText &= "SEARCHTEXT is a part of the full path or filename. SEARCHTEXT is case sensitiv !" & @CRLF
   $sText &= "Wildcards are not supported." & @CRLF

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
   $sText &= "email         create report as temporary file and send the report as email" & @CRLF
   $sText &= "              according to the config in DB." & @CRLF



   $sText &= @CRLF
   $sText &= @CRLF
   $sText &= "CSVFILENAME:" & @CRLF
   $sText &= 'Textfile that contains all data from one or more scans as comma separated values.' & @CRLF


   $sText &= @CRLF
   $sText &= @CRLF
   $sText &= "DB:" & @CRLF
   $sText &= 'SQLite database files. It will be generated if it does not exist.' & @CRLF
   $sText &= 'It contains all data of all scans and the imported CONFIGFILE.' & @CRLF
   $sText &= 'If the file gets big, delete old scans.' & @CRLF


   $sText &= @CRLF
   $sText &= @CRLF
   $sText &= "REPORTFILE:" & @CRLF
   $sText &= 'Textfile that contains the differences of two scans in human readable form.' & @CRLF


   $sText &= @CRLF
   $sText &= @CRLF
   $sText &= "CONFIGFILE:" & @CRLF
   $sText &= 'Describes a ruleset of one or more scan rules. A rule is a code block that starts with a' & @CRLF
   $sText &= '"Rule:" statement and ends with an "End" statement.' & @CRLF
   $sText &= "A rule block consists of statements that describe which directories and" & @CRLF
   $sText &= "file extentions should be included in or excluded from the scan." & @CRLF
   $sText &= @CRLF
   $sText &= 'The "Email*" statements are global for the entire ruleset and therefore NOT enclosed by' & @CRLF
   $sText &= '"Rule:" and "End" statements.' & @CRLF
   $sText &= @CRLF
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
   $sText &= "ExcExe                 no executable files, no matter what the extention is" & @CRLF
   $sText &= "                       This statement is very slow, since the first two bytes of" & @CRLF
   $sText &= "                       EVERY file in the IncDir are read!" & @CRLF
   $sText &= "IncAll                 all files, no matter what the extention is aka *.*" & @CRLF
   $sText &= "ExcAll                 no files, no matter what the extention is aka *.*," & @CRLF
   $sText &= "                       only directories" & @CRLF
   $sText &= "ExcDirs                no directory information, only file information." & @CRLF
   $sText &= "                       The default is to gather information on all scaned directories." & @CRLF
   $sText &= "NoHashes				 no CRC32 and MD5 hashes are calculated. This is faster," & @CRLF
   $sText &= "                       but changes in a file can not be detected." & @CRLF
   $sText &= "Ign:FILEPROPERTIY      ignore changes to this file property." & @CRLF
   $sText &= "End                    end of rule" & @CRLF
   $sText &= "" & @CRLF
   $sText &= "EmailFrom:EMAILADDRESS       sender email address" & @CRLF
   $sText &= "EmailTo:EMAILADDRESS         recipient email address" & @CRLF
   $sText &= "EmailSubject:SUBJECT         email subject" & @CRLF
   $sText &= "EmailServer:SMTPSERVERNAME   name of smtp server (hostname or ip-address)" & @CRLF
   $sText &= "EmailPort:SMTPPORT           smtp port on SMTPSERVERNAME, defaults to 25" & @CRLF
   $sText &= "" & @CRLF
   $sText &= "" & @CRLF

   $sText &= "EMAILADDRESS           email adress" & @CRLF
   $sText &= "                       e.g.: peter.miller@example.com" & @CRLF
   $sText &= "FILEEXTENTION          one file extention" & @CRLF
   $sText &= '                       e.g.: doc,xls,xlsx,txt,pdf,PDF,TxT,Doc' & @CRLF

   $sText &= "FILEPROPERTIY          one file property" & @CRLF
   $sText &= '                       status    was the file accessible' & @CRLF
   $sText &= '                       size      size of the file' & @CRLF
   $sText &= '                       mtime     modification time' & @CRLF
   $sText &= '                       ctime     creation time' & @CRLF
   $sText &= '                       atime     access time' & @CRLF
   $sText &= '                       version   file version' & @CRLF
   $sText &= '                       crc32     crc32 checksum' & @CRLF
   $sText &= '                       md5       md5 checksum' & @CRLF
   $sText &= '                       rattrib   read only attribute' & @CRLF
   $sText &= '                       aattrib   archive attribute' & @CRLF
   $sText &= '                       sattrib   system attribute' & @CRLF
   $sText &= '                       hattrib   hidden attribute' & @CRLF
   $sText &= '                       nattrib   normal attribute' & @CRLF
   $sText &= '                       dattrib   directory attribute' & @CRLF
   $sText &= '                       oattrib   offline attribute' & @CRLF
   $sText &= '                       cattrib   compressed attribute' & @CRLF
   $sText &= '                       tattrib   temporary attribute' & @CRLF
   $sText &= '                       e.g.: mtime,size,aattrib,nATTRIB,aAttrib' & @CRLF


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
   $sText &= "CONFIGFILE Example:" & @CRLF
   $sText &= "" & @CRLF
   $sText &= '# The rule is named "Word and Excel" and includes all *.doc,*.docx,*.xls,*.xlsx' & @CRLF
   $sText &= '# files in "c:\my msoffice files" and all subdirectories, with the exception of' & @CRLF
   $sText &= '# "c:\my msoffice files\temp" and all its subdirectories.' & @CRLF
   $sText &= '#' & @CRLF
   $sText &= '# Changes of file size and the attributes "archive" and "normal" get ignored in reports.' & @CRLF
   $sText &= '#' & @CRLF
   $sText &= '# Email reports are send from "std@example.com" to "admin@example.com" with' & @CRLF
   $sText &= '# the subject line "modified files" via the smtp mailserver at "192.168.1.1".' & @CRLF
   $sText &= '# ' & @CRLF
   $sText &= '#' & @CRLF
   $sText &= "EmailFrom:std@example.com" & @CRLF
   $sText &= "EmailTo:admin@example.com" & @CRLF
   $sText &= "EmailSubject:modified files" & @CRLF
   $sText &= "EmailServer:192.168.1.1" & @CRLF
   $sText &= '#' & @CRLF
   $sText &= 'Rule:Word and Excel' & @CRLF
   $sText &= '  IncDirRec:"c:\my msoffice files"' & @CRLF
   $sText &= '  ExcDirRec:"c:\my msoffice files\temp"' & @CRLF
   $sText &= '  IncExt:doc' & @CRLF
   $sText &= '  IncExt:docx' & @CRLF
   $sText &= '  IncExt:xls' & @CRLF
   $sText &= '  IncExt:xlsx' & @CRLF
   $sText &= '  Ign:size' & @CRLF
   $sText &= '  Ign:aattrib' & @CRLF
   $sText &= '  Ign:nattrib' & @CRLF
   $sText &= 'End' & @CRLF

   $sText &= @CRLF
   $sText &= @CRLF
   $sText &= "Quick Start:" & @CRLF
   $sText &= "" & @CRLF
   $sText &= " 1. Create a CONFIGFILE with an editor" & @CRLF
   $sText &= " 2. Import CONFIGFILE into (not yet existing) DB:" & @CRLF
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


Func DoShowVersions()

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

   $sText &= "STD - Spot The Difference (" & $gcVersion & ")" & @CRLF
   $sText &= "A poor mans file integrity checker." & @CRLF
   $sText &= @CRLF
   $sText &= "AutoIT version:     " & @AutoItVersion & @CRLF
   $sText &= @CRLF
   $sText &= "SQLite.dll version: " & $sSQliteVersion & @CRLF
   $sText &= "SQLite.dll path:    " & $sSQliteDll & @CRLF
   $sText &= @CRLF

   if $gcDEBUG = True Then
	  $sText &= @CRLF
	  $sText &= @CRLF
	  $sText &= "Debug Settings" & @CRLF
	  $sText &= @CRLF
	  $sText &= "OnlyShowScanBuffer:      " & $gcDEBUGOnlyShowScanBuffer & @CRLF
	  $sText &= "ShowVisitedDirectories:  " & $gcDEBUGShowVisitedDirectories  & @CRLF
	  $sText &= "DoNotStartSecondProcess: " & $gcDEBUGDoNotStartSecondProcess & @CRLF
	  $sText &= "RunWithoutCompilation:   " & $gcDEBUGRunWithoutCompilation  & @CRLF
	  $sText &= "ShowEmptyScanBuffer:     " & $gcDEBUGShowEmptyScanBuffer & @CRLF
	  $sText &= @CRLF
	  $sText &= "TimeGetFileInfo:         " & $gcDEBUGTimeGetFileInfo & @CRLF
	  $sText &= "TimeGetRuleFromRuleSet:  " & $gcDEBUGTimeGetRuleFromRuleSet & @CRLF
	  $sText &= "TimeIsExecutable:        " & $gcDEBUGTimeIsExecutable & @CRLF
	  $sText &= "TimeIsIncludedByRule:    " & $gcDEBUGTimeIsIncludedByRule & @CRLF
	  $sText &= "TimeIsClimbTargetByRule: " & $gcDEBUGTimeIsClimbTargetByRule & @CRLF
   EndIf


   ConsoleWrite($sText)

   _SQLite_Shutdown()

EndFunc


Func DoShowUsage()

   ;show usage
   ;---------------------------------------

   local $sText = ""

   $sText &= "STD - Spot The Difference (" & $gcVersion & ")" & @CRLF
   $sText &= "A poor mans file integrity checker." & @CRLF
   $sText &= @CRLF
   $sText &= @ScriptName & " /importcfg DB CONFIGFILE" & @CRLF
   $sText &= "Import CONFIGFILE into DB." & @CRLF
   $sText &= @CRLF
   $sText &= @ScriptName & " /exportcfg DB CONFIGFILE" & @CRLF
   $sText &= "Export config form DB into CONFIGFILE." & @CRLF
   $sText &= @CRLF
   $sText &= @ScriptName & " /scan DB" & @CRLF
   $sText &= "Scan directories" & @CRLF
   $sText &= @CRLF
   $sText &= @ScriptName & " /report DB REPORTFILE" & @CRLF
   $sText &= @ScriptName & " /report DB [[OLDSCANNAME] NEWSCANNAME] REPORTFILE" & @CRLF
   $sText &= "Write the differences between last and last validated scan to REPORTFILE" & @CRLF
   $sText &= @CRLF
   $sText &= @ScriptName & " /list DB" & @CRLF
   $sText &= "List all scans in DB" & @CRLF
   $sText &= @CRLF
   $sText &= @ScriptName & " /validate DB SCANNAME" & @CRLF
   $sText &= "Set status of scan SCANNAME to valid." & @CRLF
   $sText &= @CRLF
   $sText &= @ScriptName & " /invalidate DB SCANNAME" & @CRLF
   $sText &= "Set status of scan SCANNAME to invalid." & @CRLF
   $sText &= @CRLF
   $sText &= @ScriptName & " /delete DB SCANNAME" & @CRLF
   $sText &= "Delete the scan SCANNAME from DB." & @CRLF
   $sText &= @CRLF
   $sText &= @ScriptName & " /exportscan DB SCANNAME CSVFILENAME" & @CRLF
   $sText &= "Export scan SCANNAME to CSVFILENAME." & @CRLF
   $sText &= @CRLF
   $sText &= @ScriptName & " /duplicates DB SCANNAME" & @CRLF
   $sText &= "Write a list with duplicate files in scan SCANNAME to stdout." & @CRLF
   $sText &= @CRLF
   $sText &= @ScriptName & " /history DB SEARCHTEXT" & @CRLF
   $sText &= "Write the change history of one or more files to stdout." & @CRLF
   $sText &= @CRLF
   $sText &= @ScriptName & " /help" & @CRLF
   $sText &= "Show help" & @CRLF
   $sText &= @CRLF
   $sText &= @ScriptName & " /?" & @CRLF
   $sText &= "Show help" & @CRLF
   $sText &= @CRLF
   $sText &= @ScriptName & " /v" & @CRLF
   $sText &= "Show version information" & @CRLF


   ConsoleWrite($sText)

EndFunc


;----- get stuff from DB functions -----

Func GetRuleIDFromDB($sRulename)

   ;get ruleid from DB for $sRulename And
   ;insert new rule in DB table "rules" if not exists
   ;------------------------------------------------

   local $aRow = 0	;Returned data row

   if $gbMSSQL Then
	  if _SQL_QuerySingleRow(-1,"SELECT ruleid FROM rules where rulename='" & $sRulename & "'",$aRow) = $SQL_OK and $aRow[0]<>"" Then
		 ;get ruleid
		 return $aRow[0]
	  Else
		 ;Rule does not exist in DB so create it
		 _SQL_Execute(-1,"INSERT INTO rules ([rulename]) VALUES('" & $sRulename & "')")
		 ;_SQL_Execute(-1,"INSERT INTO rules (ruleid,rulename) VALUES(null,'TEST')")
		 if _SQL_QuerySingleRow(-1,"SELECT ruleid FROM rules where rulename='" & $sRulename & "'",$aRow) = $SQL_OK and $aRow[0]<>"" Then
			;get ruleid
			return $aRow[0]
		 EndIf
	  EndIf
   Else
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
   EndIf

   Return 0
EndFunc


Func GetRuleSetFromDB()

   ;parse all rules from table config in DB into $gaRuleSet
   ;------------------------------------------------


   ;global $gaRuleSet[1][3]	  ;all rules form config db table
							  ;$gaRuleSet
							  ;.....................................
							  ;command    | parameter | rulenumber
							  ;-------------------------------------
							  ;EmailFrom: | i@y.com   | 0
							  ;EmailTo:   | y@i.com   | 0
							  ;Rule:      | Test      | 1
							  ;IncDir:    | "c:\test" | 1
							  ;IncExt:    | txt       | 1
							  ;Rule:      | Logfiles  | 2
							  ;IncDir:    | "c:\tst1" | 2
							  ;IncExt:    | log       | 2
							  ;.....................................


   local $iLastRuleRead = False

   local $iCfgLineNr = 0
   local $sTempCfgLine = ""
   local $aCfgQueryResult = 0	;result of a query on table config
   local $hCfgQuery = 0			;handle to a query on table config

   local $iRuleCurrent = 0		;current rule number (rule 0 is global setting)
   local $iRuleCount = 0		;number of rules so far (rule 0 is global setting)

   dim $gaRuleSet[1][3]			;reset/clear $gaRuleSet
   dim $gaRuleStart[1]   		;reset/clear
   dim $gaRuleData[1][9]	    ;reset/clear



   ;read the rules from table config
   $iCfgLineNr = 1
   $iLastRuleRead = False
   $aCfgQueryResult = 0
   $hCfgQuery = 0
   if $gbMSSQL then
	  $hCfgQuery = _SQL_Execute(-1, "SELECT line FROM config ORDER BY linenumber ASC;")
   Else
	  _SQLite_Query(-1, "SELECT line FROM config ORDER BY linenumber ASC;",$hCfgQuery)
   EndIf
   While True
	  ;read one rule from table config
	  ;dim $gaRuleSet[1][3]
	  While True

		 ;read one line form table config
		 $sTempCfgLine = ""
		 if $gbMSSQL and _SQL_FetchData($hCfgQuery, $aCfgQueryResult) = $SQL_OK Then
			$sTempCfgLine = _HexToString($aCfgQueryResult[0])
			;_ArrayDisplay($aQueryResult[0])
		 Elseif not $gbMSSQL and _SQLite_FetchData($hCfgQuery, $aCfgQueryResult) = $SQLITE_OK Then
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
		 IncDir:PATH			;directory to include, only this directory
		 ExcDir:PATH			;directory to exclude, only this directory
		 IncExt:FILEEXTENTION	;file extention to include
		 ExcExt:FILEEXTENTION	;file extention to exclude
		 IncExe					;all executable files, no matter what the extention is
		 IncAll					;all files, no matter what the extention is aka *.*
		 ExcExe					;no executable files, no matter what the extention is
		 ExcAll					;no files, no matter what the extention is aka *.*, only directories
		 End

		 EmailFrom:EMAILADDRESS			;sender email address
		 EmailTo:EMAILADDRESS			;recipient email address
		 EmailSubject:SUBJECT			;email subject
		 EmailServer:SMTPSERVERNAME		;name of smtp server (hostname or ip-address)
		 EmailPort:SMTPPORT				;smtp port on SMTPSERVERNAME, defaults to 25

		 #ce



		 ;strip whitespaces at begin of line
		 $sTempCfgLine = StringStripWS($sTempCfgLine,$STR_STRIPLEADING )

		 ;tranfer rule lines to $gaRuleSet
		 ;strip leading and trailing " from directories
		 ;strip trailing \ from directories
		 Select

		 ;---------------------------------------- global ----------------------------------------------------
			Case stringleft($sTempCfgLine,stringlen("EmailFrom:")) = "EmailFrom:"
			   InsertStatementInRuleSet(1,"EmailFrom:",$sTempCfgLine,$iRuleCurrent)
			Case stringleft($sTempCfgLine,stringlen("EmailTo:")) = "EmailTo:"
			   InsertStatementInRuleSet(1,"EmailTo:",$sTempCfgLine,$iRuleCurrent)
			Case stringleft($sTempCfgLine,stringlen("EmailSubject:")) = "EmailSubject:"
			   InsertStatementInRuleSet(1,"EmailSubject:",$sTempCfgLine,$iRuleCurrent)
			Case stringleft($sTempCfgLine,stringlen("EmailServer:")) = "EmailServer:"
			   InsertStatementInRuleSet(1,"EmailServer:",$sTempCfgLine,$iRuleCurrent)
			Case stringleft($sTempCfgLine,stringlen("EmailPort:")) = "EmailPort:"
			   InsertStatementInRuleSet(1,"EmailPort:",$sTempCfgLine,$iRuleCurrent)
		 ;----------------------------------------------------------------------------------------------------

		 ;---------------------------------------- rules ----------------------------------------------------
			Case stringleft($sTempCfgLine,stringlen("Rule:")) = "Rule:"
			   $iRuleCount += 1
			   $iRuleCurrent = $iRuleCount

			   redim $gaRuleStart[UBound($gaRuleStart)+1]
			   $gaRuleStart[$iRuleCount] = UBound($gaRuleSet,1)

			   redim $gaRuleData[UBound($gaRuleData,1)+1][9]
			   $gaRuleData[$iRuleCount][$gcIncExt] = "."
			   $gaRuleData[$iRuleCount][$gcExcExt] = "."
			   $gaRuleData[$iRuleCount][$gcIncExe] = False
			   $gaRuleData[$iRuleCount][$gcExcExe] = False
			   $gaRuleData[$iRuleCount][$gcIncAll] = False
			   $gaRuleData[$iRuleCount][$gcExcAll] = False
			   $gaRuleData[$iRuleCount][$gcNoHashes] = False
			   $gaRuleData[$iRuleCount][$gcExcDirs] = False
			   $gaRuleData[$iRuleCount][$gcHasExcDir] = False

			   InsertStatementInRuleSet(1,"Rule:",$sTempCfgLine,$iRuleCurrent)

			   redim $gaRuleSet[UBound($gaRuleSet,1)+1][3]
			   $gaRuleSet[UBound($gaRuleSet,1)-1][0] = "RuleId:"
			   $gaRuleSet[UBound($gaRuleSet,1)-1][1] = GetRuleIDFromDB($gaRuleSet[UBound($gaRuleSet,1)-2][1])
			   $gaRuleSet[UBound($gaRuleSet,1)-1][2] = $iRuleCurrent

			   ;_ArrayDisplay($gaRuleStart)
			   ;_ArrayDisplay($gaRuleSet)


			;----- scan statements -----
			Case stringleft($sTempCfgLine,stringlen("IncDirRec:")) = "IncDirRec:"
			   InsertStatementInRuleSet(2,"IncDirRec:",$sTempCfgLine,$iRuleCurrent)

			   ;caclulate StringLen()+1 of given path
			   redim $gaRuleSetLineDirStringLenPlusOne[UBound($gaRuleSet,1)]
			   $gaRuleSetLineDirStringLenPlusOne[UBound($gaRuleSet,1)-1]=StringLen($gaRuleSet[UBound($gaRuleSet,1)-1][1])+1
			Case stringleft($sTempCfgLine,stringlen("ExcDirRec:")) = "ExcDirRec:"
			   InsertStatementInRuleSet(2,"ExcDirRec:",$sTempCfgLine,$iRuleCurrent)

			   ;caclulate StringLen()+1 of given path
			   redim $gaRuleSetLineDirStringLenPlusOne[UBound($gaRuleSet,1)]
			   $gaRuleSetLineDirStringLenPlusOne[UBound($gaRuleSet,1)-1]=StringLen($gaRuleSet[UBound($gaRuleSet,1)-1][1])+1

			   ;there is a "ExcDirRec:" statement in the rule
			   $gaRuleData[$iRuleCurrent][$gcHasExcDir]=True
			Case stringleft($sTempCfgLine,stringlen("IncDir:")) = "IncDir:"
			   InsertStatementInRuleSet(2,"IncDir:",$sTempCfgLine,$iRuleCurrent)

			   ;caclulate StringLen()+1 of given path
			   redim $gaRuleSetLineDirStringLenPlusOne[UBound($gaRuleSet,1)]
			   $gaRuleSetLineDirStringLenPlusOne[UBound($gaRuleSet,1)-1]=StringLen($gaRuleSet[UBound($gaRuleSet,1)-1][1])+1

			   ;count number of backslashes in given directory
			   redim $gaRuleSetLineBackslashCount[UBound($gaRuleSet,1)]
			   StringReplace($gaRuleSet[UBound($gaRuleSet,1)-1][1],"\","")
			   $gaRuleSetLineBackslashCount[UBound($gaRuleSet,1)-1]=@extended
			Case stringleft($sTempCfgLine,stringlen("ExcDir:")) = "ExcDir:"
			   InsertStatementInRuleSet(2,"ExcDir:",$sTempCfgLine,$iRuleCurrent)

			   ;caclulate StringLen()+1 of given path
			   redim $gaRuleSetLineDirStringLenPlusOne[UBound($gaRuleSet,1)]
			   $gaRuleSetLineDirStringLenPlusOne[UBound($gaRuleSet,1)-1]=StringLen($gaRuleSet[UBound($gaRuleSet,1)-1][1])+1

			   ;count number of backslashes in given directory
			   redim $gaRuleSetLineBackslashCount[UBound($gaRuleSet,1)]
			   StringReplace($gaRuleSet[UBound($gaRuleSet,1)-1][1],"\","")
			   $gaRuleSetLineBackslashCount[UBound($gaRuleSet,1)-1]=@extended

			   ;there is a "ExcDir:" statement in the rule
			   $gaRuleData[$iRuleCurrent][$gcHasExcDir]=True
			Case stringleft($sTempCfgLine,stringlen("IncExt:")) = "IncExt:"
			   $gaRuleData[$iRuleCurrent][$gcIncExt] &= StringTrimLeft($sTempCfgLine,stringlen("IncExt:")) & "."
			Case stringleft($sTempCfgLine,stringlen("ExcExt:")) = "ExcExt:"
			   $gaRuleData[$iRuleCurrent][$gcExcExt] &= StringTrimLeft($sTempCfgLine,stringlen("ExcExt:")) & "."
			Case StringStripWS($sTempCfgLine,$STR_STRIPALL ) = "IncExe"
			   $gaRuleData[$iRuleCurrent][$gcIncExe]=True
			Case StringStripWS($sTempCfgLine,$STR_STRIPALL ) = "ExcExe"
			   $gaRuleData[$iRuleCurrent][$gcExcExe]=True
			Case StringStripWS($sTempCfgLine,$STR_STRIPALL ) = "IncAll"
			   $gaRuleData[$iRuleCurrent][$gcIncAll]=True
			Case StringStripWS($sTempCfgLine,$STR_STRIPALL ) = "ExcAll"
			   $gaRuleData[$iRuleCurrent][$gcExcAll]=True
			Case StringStripWS($sTempCfgLine,$STR_STRIPALL ) = "ExcDirs"
			   $gaRuleData[$iRuleCurrent][$gcExcDirs]=True

			Case StringStripWS($sTempCfgLine,$STR_STRIPALL ) = "NoHashes"
			   $gaRuleData[$iRuleCurrent][$gcNoHashes]=True



			;----- report statements -----
			Case stringleft($sTempCfgLine,stringlen("Ign:")) = "Ign:"
			   InsertStatementInRuleSet(1,"Ign:",$sTempCfgLine,$iRuleCurrent)

			case Else
		 EndSelect

		 $iCfgLineNr = $iCfgLineNr + 1
		 if StringStripWS($sTempCfgLine,$STR_STRIPALL ) = "End" then
			;outside of a rule block we are in the global settings rule

			$iRuleCurrent = 0
			ExitLoop
		 EndIf
		 ;----------------------------------------------------------------------------------------------------

	  WEnd
	  ;last line of config file is read
	  if $iLastRuleRead = True then ExitLoop


	  ;_ArrayDisplay($gaRuleSet)
	  ;exit(0)


   WEnd
   ;end read $ConfigFilename

   if not $gbMSSQL then _SQLite_QueryFinalize($hCfgQuery)

EndFunc


Func GetFilenameIDFromDB($sPath,$sSPath)

   ;get filenameid from DB for $sPath and $sSPath and
   ;insert new filename in DB table "filenames" if not exists
   ;------------------------------------------------

   local $aRow = 0	;Returned data row

   if $gbMSSQL then
	  if _SQL_QuerySingleRow(-1,"SELECT filenameid FROM filenames where path='" & $sPath & "' and spath='" & $sSPath & "'",$aRow) = $SQL_OK and $aRow[0]<>"" Then
		 ;get filenameid
		 return $aRow[0]
	  Else
		 ;filename does not exist in DB so create it
		 _SQL_Execute(-1,"INSERT INTO [filenames] ([path],[spath]) VALUES(N'" & $sPath & "',N'" & $sSPath & "')")
		 if _SQL_QuerySingleRow(-1,"SELECT filenameid FROM filenames where path='" & $sPath & "' and spath='" & $sSPath & "'",$aRow) = $SQL_OK and $aRow[0]<>"" Then
			;get filenameid
			return $aRow[0]
		 EndIf

	  EndIf

   Else
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
   EndIf
   Return 0
EndFunc


Func GetScanIDFromDB($sScanname)

   ;get scanid from DB for $sScanname And
   ;insert new scan in DB table "scans" if not exists
   ;------------------------------------------------

   local $aRow = 0	;Returned data row

   if $gbMSSQL then

	  if _SQL_QuerySingleRow(-1,"SELECT scanid FROM scans where scantime='" & $sScanname & "'",$aRow) = $SQL_OK and $aRow[0]<>"" Then
		 ;get scanid
		 ;_ArrayDisplay($aRow)
		 return $aRow[0]
	  Else
		 ;scan does not exist in DB so create it
		 _SQL_Execute(-1,"INSERT INTO [scans] ([scantime],[valid])  VALUES('" & $sScanname & "',0)")
		 if _SQL_QuerySingleRow(-1,"SELECT scanid FROM scans where scantime='" & $sScanname & "'",$aRow) = $SQL_OK and $aRow[0]<>"" Then
			;get scanid
			;_ArrayDisplay($aRow)
			return $aRow[0]
		 EndIf

	  EndIf

   Else
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
   EndIf

   Return 0
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
		 $sSQL = "SELECT scantime from scans group by scantime order by scantime desc limit " & $gcScannameLimit & ";"
	  Case $sScan = "last"
		 $sSQL = "SELECT scantime from scans group by scantime order by scantime desc limit 1;"
	  Case $sScan = "invalid"
		 $sSQL = "SELECT scantime from scans where valid = 0 group by scantime order by scantime desc limit " & $gcScannameLimit & ";"
	  Case $sScan = "valid"
		 $sSQL = "SELECT scantime from scans where valid = 1 group by scantime order by scantime desc limit " & $gcScannameLimit & ";"
	  Case $sScan = "lastinvalid"
		 $sSQL = "SELECT scantime from scans where valid = 0 group by scantime order by scantime desc limit 1;"
	  Case $sScan = "lastvalid"
		 $sSQL = "SELECT scantime from scans where valid = 1 group by scantime order by scantime desc limit 1;"
	  Case $sScan = "oldvalid"
		 $sSQL = "SELECT scantime from scans where valid = 1 group by scantime order by scantime desc limit " & $gcScannameLimit & " offset 1;"
	  case Else
		 $sSQL = "SELECT scantime from scans where scantime = '" & $sScan & "' group by scantime order by scantime desc limit 1;"
   EndSelect

   if $gbMSSQL then
	  _SQL_GetTable(-1, $sSQL, $aScans, $iTempQueryRows, $iTempQueryColumns)
   Else
	  _SQLite_GetTable(-1, $sSQL, $aScans, $iTempQueryRows, $iTempQueryColumns)
   EndIf
   if not @error Then
	  if $iTempQueryRows >= 1 then
		 ;MsgBox(0,"Test",$iQueryRows & @CRLF & $iQueryColumns)
		 ;_ArrayDisplay($aScans)
		 Return True
	  EndIf
   EndIf

   Return False

EndFunc


;----- other DB functions

Func OpenDB($sDBName)

   ;open and initialize sqlite or mssql database if needed
   ;---------------------------------------

   if StringRight($sDBName,4) = ".INI" Then
	  ;$sDBName is *.INI, so it큦 MSSQL
	  $gbMSSQL = True
	  OpenDBMSSQL($sDBName)
   Else
	  ;$sDBName is not *.INI, so it큦 SQLite
	  $gbMSSQL = False
	  OpenDBSQLite($sDBName)
   EndIf


   Return True
EndFunc


Func OpenDBMSSQL($sDBINIFilename)

   ;open and initialize database if needed
   ;---------------------------------------

   local $aQueryResult = 0		;result of a query
   local $bTableExists = False
   local $sTablename = ""

   If not $SQL_OK = _SQL_Startup() Then
	   ConsoleWrite("MS SQL Error: " & _SQL_GetErrMsg())
	   Exit -1
   EndIf
   ;ConsoleWrite("_SQLite_LibVersion=" & _SQLite_LibVersion() & @CRLF)

   ;$ghDBHandle = _SQL_Open($sDBINIFilename)


   ;If not $SQL_OK = _SQL_Connect(-1, "MAINFRAME\SQLEXPRESS", "STD", "sa", "Pa$$w0rd") Then
   If not $SQL_OK = _SQL_Connect(-1, IniRead($sDBINIFilename,"MSSQL","server",""), IniRead($sDBINIFilename,"MSSQL","db",""), IniRead($sDBINIFilename,"MSSQL","user",""), IniRead($sDBINIFilename,"MSSQL","password","")) Then
	   ConsoleWrite("MS SQL Error: " & _SQL_GetErrMsg())
	   Exit -1
   EndIf

   ;read all tablenames form database
   $aQueryResult = 0
   $aQueryResult = _SQL_GetTableName(-1,"TABLE")

   #cs
	  FileGetAttrib()
	  "R" = READONLY
	  "A" = ARCHIVE
	  "S" = SYSTEM
	  "H" = HIDDEN
	  "N" = NORMAL
	  "D" = DIRECTORY
	  "O" = OFFLINE
	  "C" = COMPRESSED (NTFS compression, not ZIP compression)
	  "T" = TEMPORARY
   #ce



   ;create new db structure if needed

   $bTableExists = False
   for $sTablename in $aQueryResult
	  if $sTablename = "config" then
		 $bTableExists = True
		 ExitLoop
	  EndIf
   Next
   if not $bTableExists then _SQL_Execute(-1,"CREATE TABLE [config] ([linenumber] INTEGER IDENTITY(1,1)  ,[line] VARCHAR NULL  ,CONSTRAINT [config_PRIMARY]  PRIMARY KEY  NONCLUSTERED  ([linenumber])); ")

   $bTableExists = False
   for $sTablename in $aQueryResult
	  if $sTablename = "scans" then
		 $bTableExists = True
		 ExitLoop
	  EndIf
   Next
   if not $bTableExists then _SQL_Execute(-1,"CREATE TABLE [scans] ([scanid] INTEGER IDENTITY(1,1)  ,[scantime] char(14) NULL  ,[valid] INTEGER NULL  DEFAULT 0 ,CONSTRAINT [scans_PRIMARY]  PRIMARY KEY  NONCLUSTERED  ([scanid]));")

   $bTableExists = False
   for $sTablename in $aQueryResult
	  if $sTablename = "rules" then
		 $bTableExists = True
		 ExitLoop
	  EndIf
   Next
   if not $bTableExists then _SQL_Execute(-1,"CREATE TABLE [rules] ([ruleid] INTEGER IDENTITY(1,1)  ,[rulename] varchar(255)  ,CONSTRAINT [rules_PRIMARY]  PRIMARY KEY  NONCLUSTERED  ([ruleid]));")

   $bTableExists = False
   for $sTablename in $aQueryResult
	  if $sTablename = "filenames" then
		 $bTableExists = True
		 ExitLoop
	  EndIf
   Next
   if not $bTableExists then _SQL_Execute(-1,"CREATE TABLE [filenames] ([filenameid] INTEGER IDENTITY(1,1)  ,[path] varchar(512) NULL  ,[spath] varchar(512) NULL  );")

   $bTableExists = False
   for $sTablename in $aQueryResult
	  if $sTablename = "filedata" then
		 $bTableExists = True
		 ExitLoop
	  EndIf
   Next
   if not $bTableExists then _SQL_Execute(-1,"CREATE TABLE [filedata] ([scanid] INTEGER NOT NULL  DEFAULT 0 ,[ruleid] INTEGER NOT NULL  DEFAULT 0 ,[filenameid] INTEGER NOT NULL  DEFAULT 0 ,[status] INTEGER NULL  DEFAULT 0 ,[size] INTEGER NULL  DEFAULT 0 ,[attributes] CHAR(1) NULL  ,[mtime] CHAR(14) NULL  ,[ctime] CHAR(14) NULL  ,[atime] CHAR(14) NULL  ,[version] VARCHAR(80) NULL  ,[crc32] char(35) NULL  ,[md5] char(35) NULL  ,[ptime] INTEGER NULL  ,[rattrib] INTEGER NULL  DEFAULT 0 ,[aattrib] INTEGER NULL  DEFAULT 0 ,[sattrib] INTEGER NULL  DEFAULT 0 ,[hattrib] INTEGER NULL  DEFAULT 0 ,[nattrib] INTEGER NULL  DEFAULT 0 ,[dattrib] INTEGER NULL  DEFAULT 0 ,[oattrib] INTEGER NULL  DEFAULT 0 ,[cattrib] INTEGER NULL  DEFAULT 0 ,[tattrib] INTEGER NULL  DEFAULT 0 ,CONSTRAINT [filedata_PRIMARY]  PRIMARY KEY  NONCLUSTERED  ([scanid],[ruleid],[filenameid]));")


   Return True
EndFunc


Func OpenDBSQLite($sDBName)

   ;open and initialize database if needed
   ;---------------------------------------

   _SQLite_Startup()
   If @error Then
	   ;MsgBox($MB_SYSTEMMODAL, "SQLite Error", "SQLite3.dll can't be loaded!")
	   ConsoleWrite("SQLite Error: SQLite3.dll can't be loaded!")
	   Exit -1
   EndIf
   ;ConsoleWrite("_SQLite_LibVersion=" & _SQLite_LibVersion() & @CRLF)

   $ghDBHandle = _SQLite_Open($sDBName)


   #cs
	  FileGetAttrib()
	  "R" = READONLY
	  "A" = ARCHIVE
	  "S" = SYSTEM
	  "H" = HIDDEN
	  "N" = NORMAL
	  "D" = DIRECTORY
	  "O" = OFFLINE
	  "C" = COMPRESSED (NTFS compression, not ZIP compression)
	  "T" = TEMPORARY
   #ce

   ;performance tuning ...
    _SQLite_Exec(-1,"PRAGMA journal_mode=WAL;")
    _SQLite_Exec(-1,"PRAGMA synchronous = NORMAL;")


   ;create new db structure if needed
   _SQLite_Exec(-1,"CREATE TABLE IF NOT EXISTS config (linenumber INTEGER PRIMARY KEY AUTOINCREMENT, line );")

   ;_SQLite_Exec(-1,"CREATE TABLE IF NOT EXISTS files (scantime,name,status,size,attributes,mtime,ctime,atime,version,spath,crc32,md5,ptime,rulename, PRIMARY KEY(scantime,name));")
   ;_SQLite_Exec(-1,"CREATE TABLE IF NOT EXISTS files (scanid not null,ruleid not null,filenameid not null );")
   _SQLite_Exec(-1,"CREATE TABLE IF NOT EXISTS scans (scanid INTEGER PRIMARY KEY AUTOINCREMENT, scantime, valid INTEGER);")
   _SQLite_Exec(-1,"CREATE TABLE IF NOT EXISTS rules (ruleid INTEGER PRIMARY KEY AUTOINCREMENT, rulename );")
   ;_SQLite_Exec(-1,"CREATE TABLE IF NOT EXISTS filenames (filenameid INTEGER PRIMARY KEY AUTOINCREMENT, path, spath, filename );")
   _SQLite_Exec(-1,"CREATE TABLE IF NOT EXISTS filenames (filenameid INTEGER PRIMARY KEY AUTOINCREMENT, path, spath );")
   _SQLite_Exec(-1,"CREATE TABLE IF NOT EXISTS filedata (scanid INTEGER NOT NULL,ruleid INTEGER NOT NULL,filenameid INTEGER NOT NULL, status INTEGER,size INTEGER,attributes,mtime,ctime,atime,version,crc32,md5,ptime,rattrib INTEGER,aattrib INTEGER,sattrib INTEGER,hattrib INTEGER,nattrib INTEGER,dattrib INTEGER,oattrib INTEGER,cattrib INTEGER,tattrib INTEGER, PRIMARY KEY(scanid,ruleid,filenameid) );")

   ;_SQLite_Exec(-1,"CREATE INDEX IF NOT EXISTS config_index ON config (linenumber);")
   _SQLite_Exec(-1,"CREATE INDEX IF NOT EXISTS filenames_path ON filenames (path);")
   ;_SQLite_Exec(-1,"CREATE INDEX IF NOT EXISTS filedata_pk ON filedata (scanid,ruleid,filenameid);")

   Return True
EndFunc


Func CloseDB()

   ;close database
   ;--------------------

   if $gbMSSQL Then
	  CloseDBMSSQL()
   Else
	  CloseDBSQLite()
   EndIf


   Return True
EndFunc


Func CloseDBMSSQL()

   ;close MSSQL database
   ;--------------------

   _SQL_Close()

   Return True
EndFunc


Func CloseDBSQLite()

   ;close SQLite database
   ;--------------------

   _SQLite_Close($ghDBHandle)
   _SQLite_Shutdown()

   Return True
EndFunc


;----- rule related functions -----

Func GetRulename($iRuleNumber)

   ;get name of the rule
   ;--------------------

   local $sRulename = ""

   $sRulename = $gaRuleSet[$gaRuleStart[$iRuleNumber]][1]
   return $sRulename
EndFunc


Func GetNumberOfRulesFromRuleSet()

   ;return the number of rules in $gaRuleSet
   ;------------------------------------------------


   local $iCount = 0		;counter
   local $iCountMax = UBound($gaRuleSet,1)-1
   local $iRuleNumber = 0

   for $iCount = 1 to $iCountMax
	  if $gaRuleSet[$iCount][2] > $iRuleNumber then
		 $iRuleNumber = $gaRuleSet[$iCount][2]
	  EndIf
   Next

   return $iRuleNumber
EndFunc


Func GetRuleIdFromRuleSet($iRuleNumber)

   ;get id of the rule
   ;!!! rule id is not the rule number !!!
   ;--------------------

   local $sRuleId = ""
   local $iCountMax = UBound($gaRuleSet,1)-1
   local $iCountMin = $gaRuleStart[$iRuleNumber]

   for $i = $iCountMin to $iCountMax
	  if $gaRuleSet[$i][2] = $iRuleNumber then
		 if $gaRuleSet[$i][0] = "RuleId:" then $sRuleId = $gaRuleSet[$i][1]
	  Else
		 ExitLoop
	  EndIf
   Next

   return $sRuleId
EndFunc


Func InsertStatementInRuleSet($iMode,$sStatement,$sCfgLine,$iRuleNr)

   ;Transfer a statement from a line in the configuration table
   ;into the gobal $gaRuleSet
   ;
   ;$iMode = 0			statement has no parameter
   ;$iMode = 1			statement has one parameter
   ;$iMode = 2			statement has one parameter, paramenter is a directory name
   ;------------------------------------------------

   select
   case $iMode = 0
	  redim $gaRuleSet[UBound($gaRuleSet,1)+1][3]
	  $gaRuleSet[UBound($gaRuleSet,1)-1][0] = $sStatement
	  $gaRuleSet[UBound($gaRuleSet,1)-1][1] = ""
	  $gaRuleSet[UBound($gaRuleSet,1)-1][2] = $iRuleNr

   case $iMode = 1
	  redim $gaRuleSet[UBound($gaRuleSet,1)+1][3]
	  $gaRuleSet[UBound($gaRuleSet,1)-1][0] = $sStatement
	  $gaRuleSet[UBound($gaRuleSet,1)-1][1] = StringTrimLeft($sCfgLine,stringlen($sStatement))
	  $gaRuleSet[UBound($gaRuleSet,1)-1][2] = $iRuleNr

   case $iMode = 2
	  redim $gaRuleSet[UBound($gaRuleSet,1)+1][3]
	  $gaRuleSet[UBound($gaRuleSet,1)-1][0] = $sStatement
	  $gaRuleSet[UBound($gaRuleSet,1)-1][1] = StringReplace(StringTrimLeft($sCfgLine,stringlen($sStatement)),"""","")
	  if StringRight($gaRuleSet[UBound($gaRuleSet,1)-1][1],1) = "\" then $gaRuleSet[UBound($gaRuleSet,1)-1][1] = StringTrimRight($gaRuleSet[UBound($gaRuleSet,1)-1][1],1)
	  $gaRuleSet[UBound($gaRuleSet,1)-1][2] = $iRuleNr

   case Else
   EndSelect

   Return 0
EndFunc


Func IsFilepropertyIgnoredByRule($sFileproperty,$iRuleNumber)

   ;determin if $sFileproperty is ignored by the current rule
   ;--------------------------------------------------


   local $iIsIgnored = False
   local $i = 0
   ;local $iMax = 0
   local $iMax = UBound($gaRuleSet,1)-1


   for $i = $gaRuleStart[$iRuleNumber] to $iMax
	  if $gaRuleSet[$i][2] <> $iRuleNumber then ExitLoop

		 Select
			case $gaRuleSet[$i][0] = "Ign:"
			   if StringStripWS($sFileproperty,$STR_STRIPALL) = StringStripWS($gaRuleSet[$i][1],$STR_STRIPALL) then $iIsIgnored = True
			case Else
		 EndSelect
	  Next

   Return $iIsIgnored
EndFunc


Func IsIncludedByRule($PathOrFile,$iRuleNumber)

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
	  ExcDirs
	  End
   #ce

   if $gcDEBUGTimeIsIncludedByRule = True then local $iTimer = TimerInit()
   local $iIsIncluded = False
   local $iIsFile = False
   local $i = 0
   ;local $iMax = 0
   local $iMax = UBound($gaRuleSet,1)-1
   local $sExtension = ""

   ;strip leading and trailing " from directories
   $PathOrFile = StringReplace($PathOrFile,"""","")
   ;if StringRight($PathOrFile,1) = "\" then $PathOrFile = StringTrimRight($PathOrFile,1)

   if StringRight($PathOrFile,1) <> "\" then $iIsFile = True

   ;include directory command

   for $i = $gaRuleStart[$iRuleNumber] to $iMax
	  if $gaRuleSet[$i][2] <> $iRuleNumber then ExitLoop
	  ;$gaRuleSet[$i][0]
	  ;$gaRuleSet[$i][1]
	  ;msgbox(0,"Cmd","#" & $gaRuleSet[$i][0] & "#" & @CRLF & "#" & $gaRuleSet[$i][1] & "#" & @CRLF & "#" & $PathOrFile & "#" & @CRLF & "#" & StringLeft($PathOrFile,stringlen($gaRuleSet[$i][1] & "\")) & "#" & @CRLF & "#" & $gaRuleSet[$i][1] & "\")
	  Select
		 case $gaRuleSet[$i][0] = "IncDirRec:"
		 	if StringLeft($PathOrFile,$gaRuleSetLineDirStringLenPlusOne[$i]) = $gaRuleSet[$i][1] & "\" then
			   $iIsIncluded = True
			   ExitLoop
			EndIf
		 case $gaRuleSet[$i][0] = "IncDir:"
			if StringLeft($PathOrFile,$gaRuleSetLineDirStringLenPlusOne[$i]) = $gaRuleSet[$i][1] & "\" And $giCurrentDirBackslashCount = $gaRuleSetLineBackslashCount[$i] then
			   $iIsIncluded = True
			   ExitLoop
			EndIf
		 case Else
	  EndSelect

   Next

   ;ConsoleWrite("...ID..." & $iIsIncluded & " " & $PathOrFile & @crlf)

   ;exclude directory command
   if $iIsIncluded then
	  if not $iIsFile and $gaRuleData[$iRuleNumber][$gcExcDirs] then
		 ;"ExcDirs"
		 $iIsIncluded = False
	  Else
		 if $gaRuleData[$iRuleNumber][$gcHasExcDir] Then
			;there are "ExcDirRec:" or "ExcDir:" statements in this rule
			for $i = $gaRuleStart[$iRuleNumber] to $iMax
			   if $gaRuleSet[$i][2] <> $iRuleNumber then ExitLoop
			   ;$gaRuleSet[$i][0]
			   ;$gaRuleSet[$i][0]
			   ;$gaRuleSet[$i][1]
			   Select
				  case $gaRuleSet[$i][0] = "ExcDirRec:"
					 if StringLeft($PathOrFile,$gaRuleSetLineDirStringLenPlusOne[$i]) = $gaRuleSet[$i][1] & "\" then
						$iIsIncluded = False
						ExitLoop
					 EndIf
				  case $gaRuleSet[$i][0] = "ExcDir:"
					 if StringLeft($PathOrFile,$gaRuleSetLineDirStringLenPlusOne[$i]) = $gaRuleSet[$i][1] & "\" And $giCurrentDirBackslashCount = $gaRuleSetLineBackslashCount[$i] then
						$iIsIncluded = False
						ExitLoop
					 EndIf
				  case Else
			   EndSelect
			Next
		 EndIf
	  EndIf
	  ;ConsoleWrite("...ED..." & $iIsIncluded & " " & $PathOrFile & @crlf)


	  ;msgbox(0,"Cmd","#" & $gaRuleSet[$i][0] & "#" & @CRLF & "#" & $gaRuleSet[$i][1] & "#" & @CRLF & "#" & $PathOrFile & "#" & @CRLF)

	  ;include file extension command (if it is not a directory and the path is included)
	  if $iIsFile and $iIsIncluded then
		 $iIsIncluded = False

		 ;msgbox(0,"Cmd","#" & $gaRuleSet[$i][0] & "#" & @CRLF & "#" & $gaRuleSet[$i][1] & "#" & @CRLF & "#" & $PathOrFile & "#" & @CRLF)

		 ;"IncExt:"
		 $sExtension = StringRight($PathOrFile,StringLen($PathOrFile)-StringInStr($PathOrFile,".",1,-1))
		 if StringInStr($gaRuleData[$iRuleNumber][$gcIncExt],"." & $sExtension & ".") > 0 then
			$iIsIncluded = True
		 EndIf

		 ;"IncExe"
		 if $gaRuleData[$iRuleNumber][$gcIncExe] = True Then
			if IsExecutable($PathOrFile) then $iIsIncluded = True
		 EndIf

		 ; "IncAll"
		 if $gaRuleData[$iRuleNumber][$gcIncAll] = True Then
			$iIsIncluded = True
		 EndIf


		 ;ConsoleWrite("...IE..." & $iIsIncluded & " " & $PathOrFile & @crlf)

		 ;exclude file extension command (if it is not a directory and the path is included)
		 if $iIsIncluded then
			;$iIsIncluded = False


			;"ExcExt:"
			;Use $sExtension form "IncExt:" above
			;$sExtension = StringRight($PathOrFile,StringInStr($PathOrFile,".",1,-1))
			if StringInStr($gaRuleData[$iRuleNumber][$gcExcExt],"." & $sExtension & ".") > 0 then
			   $iIsIncluded = False
			EndIf

			;"ExcExe"
			if $gaRuleData[$iRuleNumber][$gcExcExe] = True Then
			   if IsExecutable($PathOrFile) then $iIsIncluded = False
			EndIf

			; "ExcAll"
			if $gaRuleData[$iRuleNumber][$gcExcAll] = True Then
			   $iIsIncluded = False
			EndIf
		 EndIf

	  EndIf
   EndIf
   ;ConsoleWrite("...EE..." & $iIsIncluded & " " & $PathOrFile & @crlf)
   ;if $iIsIncluded then ConsoleWrite($iIsIncluded & " " & $PathOrFile & @crlf)
   if $gcDEBUGTimeIsIncludedByRule then $giDEBUGTimerIsIncludedByRule += TimerDiff($iTimer)
   Return $iIsIncluded
EndFunc


Func IsClimbTargetByRule($sPath,$iRuleNumber)

   ;determin if $sPath satisfy the current rule as a climb target
   ;--------------------------------------------------

   ;$sPath is a directory with a \ at the ende !

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

   if $gcDEBUGTimeIsClimbTargetByRule = True then local $iTimer = TimerInit()
   local $iIsClimbTarget = False
   local $i = 0
   ;local $iMax = 0
   local $iMax = UBound($gaRuleSet,1)-1

   ;strip leading and trailing " from directories
   $sPath = StringReplace($sPath,"""","")

   ;include directory command
   for $i = $gaRuleStart[$iRuleNumber] to $iMax
	  if $gaRuleSet[$i][2] <> $iRuleNumber then ExitLoop
	  Select
		 case $gaRuleSet[$i][0] = "IncDirRec:"
			if StringLeft($sPath,stringlen($gaRuleSet[$i][1] & "\")) = $gaRuleSet[$i][1] & "\" then
			   $iIsClimbTarget = True
			   ExitLoop
			EndIf
		 case $gaRuleSet[$i][0] = "IncDir:"
			if StringLeft($sPath,stringlen($gaRuleSet[$i][1] & "\")) = $gaRuleSet[$i][1] & "\" And Not StringInStr(StringReplace(StringLower($sPath),StringLower($gaRuleSet[$i][1] & "\"),""),"\") then
			   $iIsClimbTarget = True
			   ExitLoop
			EndIf
		 case Else
	  EndSelect
   Next

   if $gaRuleData[$iRuleNumber][$gcHasExcDir] Then
	  ;there are "ExcDirRec:" or "ExcDir:" statements in this rule

	  ;exclude directory command
	  for $i = $gaRuleStart[$iRuleNumber] to $iMax
		 if $gaRuleSet[$i][2] <> $iRuleNumber then ExitLoop
		 ;$gaRuleSet[$i][0]
		 ;$gaRuleSet[$i][1]
		 Select
			case $gaRuleSet[$i][0] = "ExcDirRec:"
			   if StringLeft($sPath,stringlen($gaRuleSet[$i][1] & "\")) = $gaRuleSet[$i][1] & "\" then
				  $iIsClimbTarget = False
				  ExitLoop
			   EndIf
			case $gaRuleSet[$i][0] = "ExcDir:"
			   if StringLeft($sPath,stringlen($gaRuleSet[$i][1] & "\")) = $gaRuleSet[$i][1] & "\" And not StringInStr(StringReplace(StringLower($sPath),StringLower($gaRuleSet[$i][1] & "\"),""),"\") then
				  $iIsClimbTarget = False
				  ExitLoop
			   EndIf
			case Else
		 EndSelect
	  Next
   EndIf

   if $gcDEBUGTimeIsClimbTargetByRule = True then $giDEBUGTimerIsClimbTargetByRule += TimerDiff($iTimer)
   Return $iIsClimbTarget
EndFunc


Func IsExecutable($Filename)

   ;Check if $Filename is a windows executable
   ;by looking at the magic number
   ;--------------------------------------------

;	global $giIsExecutableLastResult = False	;result of last call to IsExecutable()
;	global $gsIsExecutableLastFilename = ""	;filname used for last call to IsExecutable()

   local $sBuffer = ""
   local $FileHandle = 0
   if $gcDEBUGTimeIsExecutable = True then local $iTimer = TimerInit()

   if $Filename = $gsIsExecutableLastFilename Then
	  ;no need to access and check the file, we know the result already
	  return $giIsExecutableLastResult
   Else

	  $FileHandle = FileOpen($Filename, 16)
	  $sBuffer = FileRead($FileHandle,2)
	  FileClose($FileHandle)

	  $gsIsExecutableLastFilename = $Filename

	  if $sBuffer = "MZ" or $sBuffer = "ZM" then
		 $giIsExecutableLastResult = True
		 if $gcDEBUGTimeIsExecutable = True then $giDEBUGTimerIsExecutable += TimerDiff($iTimer)
		 return True
	  Else
		 $giIsExecutableLastResult = False
		 if $gcDEBUGTimeIsExecutable = True then $giDEBUGTimerIsExecutable += TimerDiff($iTimer)
		 return False
	  EndIf
   EndIf
EndFunc


Func OutputLineOfFileHistory(ByRef $aQueryResult, $iPrintHeadline)

   ;Simple report writer
   ;----------------------


   ;Output single line of a sql query result
   ;--------------------------------------------
   ;"           scantime,name,valid,status,size,attributes,mtime,ctime,atime,version,spath,crc32,md5,ptime,rulename,rattrib,aattrib,sattrib,hattrib,nattrib,dattrib,oattrib,cattrib,tattrib"
   ;                 0    1      2     3     4        5      6     7     8     9      10    11   12    13       14      15      16      17      18      19     20      21       22      23



   local $aDesc[] = ["scantime","name","valid","status","size","attributes","mtime","ctime","atime","version","spath","crc32","md5","ptime","rulename","rattrib","aattrib","sattrib","hattrib","nattrib","dattrib","oattrib","cattrib","tattrib"]
   local $aAttribDesc[] = ["r","a","s","h","n","d","o","c","t"]
   local $i = 0
   local $sTemp = ""
   local $sTempAttrib = ""

   ;$sTemp = _HexToString($aQueryResult[1])
   ;ConsoleWrite($sTemp & @CRLF)

   if $iPrintHeadline then
	  $sTemp = StringFormat("%-15s %5s %6s %13s %14s %14s %14s %20s %10s %35s %10s %10s",$aDesc[0],$aDesc[2],$aDesc[3],$aDesc[4],$aDesc[6],$aDesc[7],$aDesc[8],$aDesc[9],$aDesc[11],$aDesc[12],$aDesc[13],"attributes")
   Else
	  ;attributes
	  $sTempAttrib = ""
	  for $i = 15 to 23
		 if $aQueryResult[$i] = 1 then $sTempAttrib &= StringUpper($aAttribDesc[$i - 15])
	  Next
	  if $sTempAttrib = "" then $sTempAttrib = "-"
	  ;ConsoleWrite($sTempAttrib & @CRLF)

	  ;$sTemp = StringFormat("%-15s %1s %1s %13s %14s %14s %14s %20s %10s %35s %10s %9s",$aQueryResult[0],$aQueryResult[2],$aQueryResult[3],$aQueryResult[4],$aQueryResult[6],$aQueryResult[7],$aQueryResult[8],$aQueryResult[9],$aQueryResult[11],$aQueryResult[12],$aQueryResult[13],$sTempAttrib)
	  $sTemp = StringFormat("%-15s %5s %6s %13s %14s %14s %14s %20s %10s %35s %10s %10s",$aQueryResult[0],$aQueryResult[2],$aQueryResult[3],$aQueryResult[4],$aQueryResult[6],$aQueryResult[7],$aQueryResult[8],$aQueryResult[9],$aQueryResult[11],$aQueryResult[12],$aQueryResult[13],$sTempAttrib)
   EndIf
   ConsoleWrite($sTemp & @CRLF)

   Return True
EndFunc


Func OutputLineOfQueryResult(ByRef $aQueryResult,$ReportFilename)

   ;Simple report writer
   ;----------------------


   ;Output single line of a sql query result
   ;--------------------------------------------
   ;"           scantime,name,status,size,attributes,mtime,ctime,atime,version,spath,crc32,md5,ptime,rulename,rattrib,aattrib,sattrib,hattrib,nattrib,dattrib,oattrib,cattrib,tattrib"
   ;     old         0    1      2     3       4        5     6    7      8     9      10   11  12      13        14      15      16      17      18      19     20      21       22
   ;     new        23   24     25    26      27       28    29   30     31    32      33   34  35      36        37      38      39      40      41      42     43      44       45


   local $aDesc[] = ["scantime","name","status","size","attributes","mtime","ctime","atime","version","spath","crc32","md5","ptime","rulename","rattrib","aattrib","sattrib","hattrib","nattrib","dattrib","oattrib","cattrib","tattrib"]
   local $aAttribDesc[] = ["r","a","s","h","n","d","o","c","t"]
   local $i = 0
   local $sTempOld = ""
   local $sTempNew = ""
   local $iIsNewOrMissing = False

   ;FileWriteLine($ReportFilename,". . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . " )
   ;FileWriteLine($ReportFilename, "......................................................................" )
   ;FileWriteLine($ReportFilename, "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -" )
   ;FileWriteLine($ReportFilename, "-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --" )
   FileWriteLine($ReportFilename, "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" )
   if $aQueryResult[1] = "" Then FileWriteLine($ReportFilename, "new          : "  & _HexToString($aQueryResult[24]) )

   if $aQueryResult[24] = "" Then FileWriteLine($ReportFilename,"missing      : "  & _HexToString($aQueryResult[1]) )

   if $aQueryResult[1] = $aQueryResult[24] Then FileWriteLine($ReportFilename,"changed      : "  & _HexToString($aQueryResult[1]) )
   ;FileWriteLine($ReportFilename,". . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . " & @CRLF)
   FileWriteLine($ReportFilename,"-  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -" & @CRLF)

#cs
   $sTempOld = ""
   $sTempNew = ""
   $sTempOld = $aQueryResult[0]
   $sTempNew = $aQueryResult[0 + 23]
   if $sTempOld = "" then
	  $sTempOld = "-"
	  $iIsNewOrMissing = True
   EndIf
   if $sTempNew = "" then
	  $sTempNew = "-"
	  $iIsNewOrMissing = True
   EndIf
   FileWriteLine($ReportFilename,StringFormat("%-10s %1s %1s %35s %-35s","","","","expected","observed"))
   FileWriteLine($ReportFilename,StringFormat("%-10s %1s %1s %35s %-35s",$aDesc[$i]," "," ",$sTempOld,$sTempNew))
#ce

   for $i = 0 to 13
	  $sTempOld = ""
	  $sTempNew = ""
	  $sTempOld = $aQueryResult[$i]
	  $sTempNew = $aQueryResult[$i + 23]
	  if $sTempOld = "" then $sTempOld = "-"
	  if $sTempNew = "" then $sTempNew = "-"

	  if $i = 0 Then
		 if $sTempOld = "-" then $iIsNewOrMissing = True
		 if $sTempNew = "-" then $iIsNewOrMissing = True

		 if $sTempOld <> "-" then $sTempOld = StringFormat("%4s.%2s.%2s %2s:%2s:%2s",StringMid($sTempOld,1,4),StringMid($sTempOld,5,2),StringMid($sTempOld,7,2),StringMid($sTempOld,9,2),StringMid($sTempOld,11,2),StringMid($sTempOld,13,2))
		 if $sTempNew <> "-" then $sTempNew = StringFormat("%4s.%2s.%2s %2s:%2s:%2s",StringMid($sTempNew,1,4),StringMid($sTempNew,5,2),StringMid($sTempNew,7,2),StringMid($sTempNew,9,2),StringMid($sTempNew,11,2),StringMid($sTempNew,13,2))

		 FileWriteLine($ReportFilename,StringFormat("%-10s %1s %1s %35s %-35s","","","","expected","observed"))
		 FileWriteLine($ReportFilename,StringFormat("%-10s %1s %1s %35s %-35s",$aDesc[$i]," "," ",$sTempOld,$sTempNew))

	  ElseIf $i = 1 Then
	  ElseIf $i = 4 Then
	  ElseIf $i >= 5 and $i <= 7 Then
		 if $sTempOld <> "-" then $sTempOld = StringFormat("%4s.%2s.%2s %2s:%2s:%2s",StringMid($sTempOld,1,4),StringMid($sTempOld,5,2),StringMid($sTempOld,7,2),StringMid($sTempOld,9,2),StringMid($sTempOld,11,2),StringMid($sTempOld,13,2))
		 if $sTempNew <> "-" then $sTempNew = StringFormat("%4s.%2s.%2s %2s:%2s:%2s",StringMid($sTempNew,1,4),StringMid($sTempNew,5,2),StringMid($sTempNew,7,2),StringMid($sTempNew,9,2),StringMid($sTempNew,11,2),StringMid($sTempNew,13,2))

		 if $sTempOld = $sTempNew or $iIsNewOrMissing then
			FileWriteLine($ReportFilename,StringFormat("%-10s %1s %1s %35s %-35s",$aDesc[$i]," "," ",$sTempOld,$sTempNew))
		 Else
			FileWriteLine($ReportFilename,StringFormat("%-10s %1s %1s %35s %-35s",$aDesc[$i]," ","*",$sTempOld,$sTempNew))
		 EndIf

	  ElseIf $i = 9 Then
	  ElseIf $i = 13 Then
	  else
		 if $sTempOld = $sTempNew or $iIsNewOrMissing or $i = 12  then
			FileWriteLine($ReportFilename,StringFormat("%-10s %1s %1s %35s %-35s",$aDesc[$i]," "," ",$sTempOld,$sTempNew))
		 Else
			FileWriteLine($ReportFilename,StringFormat("%-10s %1s %1s %35s %-35s",$aDesc[$i]," ","*",$sTempOld,$sTempNew))
		 EndIf
	  EndIf

   Next


   ;attributes
   $sTempOld = ""
   $sTempNew = ""
   for $i = 14 to 22
	  if $aQueryResult[$i] = 1 then $sTempOld &= StringUpper($aAttribDesc[$i - 14])
	  if $aQueryResult[$i + 23] = 1 then $sTempNew &= StringUpper($aAttribDesc[$i - 14])
   Next
   if $sTempOld = "" then $sTempOld = "-"
   if $sTempNew = "" then $sTempNew = "-"

   if $sTempOld = $sTempNew or $iIsNewOrMissing Then
	  FileWriteLine($ReportFilename,StringFormat("%-10s %1s %1s %35s %-35s","attributes"," "," ",$sTempOld,$sTempNew))
   Else
	  FileWriteLine($ReportFilename,StringFormat("%-10s %1s %1s %35s %-35s","attributes"," ","*",$sTempOld,$sTempNew))
   EndIf


   $sTempOld = ""
   $sTempNew = ""
   $sTempOld = $aQueryResult[9]
   $sTempNew = $aQueryResult[9 + 23]
   if $sTempOld = "" then $sTempOld = "-"
   if $sTempNew = "" then $sTempNew = "-"
   FileWriteLine($ReportFilename,"")
   FileWriteLine($ReportFilename,StringFormat("%-10s %1s %1s %s","old path"," "," ",$sTempOld))
   ;FileWriteLine($ReportFilename,StringFormat("%-15s %1s %s","new path:"," ",$sTempNew))
   if $sTempOld = $sTempNew or $iIsNewOrMissing then
	  FileWriteLine($ReportFilename,StringFormat("%-10s %1s %1s %s","new path"," "," ",$sTempNew))
   Else
	  FileWriteLine($ReportFilename,StringFormat("%-10s %1s %1s %s","new path"," ","*",$sTempNew))
   EndIf

   ;FileWriteLine($ReportFilename,"-------------")
   FileWriteLine($ReportFilename,"")

   Return True
EndFunc


Func OutputLineOfQueryResultHeadline($iRuleNumber,$ReportFilename)

   ;Print rule headline for reports
   ;-------------------------------

   FileWriteLine($ReportFilename,@crlf & "----------------------------------------------------------------------")
   FileWriteLine($ReportFilename,"rule     : " & GetRulename($iRuleNumber))
   FileWriteLine($ReportFilename,"----------------------------------------------------------------------" & @CRLF)


   Return True
EndFunc


Func TreeClimberSecondProcess($sStartPath,$iPID,$aRelevantRules)

   ;read any directory entry in $sStartPath and its subdirectories
   ;and scan according to %aRule
   ;-------------------------------------------------------------

   Local $iScanFile = False
   Local $iIsDirectory = False
   Local $iIsClimbTarget = False
   Local $sTempText = ""
   Local $iFilenameId = 0
   Local $sFullPath = ""

   local $iRuleCounter = 0
   local $iRuleCounterMax = 0

   ;abort if $sStartPath is not valid (does not exist)
   if not FileExists($sStartPath) Then Return False

   ;list every directory we are reading - reading is NOT scanning !!!
   ;ConsoleWrite("TreeClimber: " & $sStartPath & @CRLF)

   ; Assign a Local variable the search handle of all files in the current directory.
   Local $hSearch = FileFindFirstFile($sStartPath & "\*.*")


   ; Check if the search was successful, if not display a message and return False.
   If $hSearch = -1 Then
	  ;MsgBox($MB_SYSTEMMODAL, "", "Error: No files/directories matched the search pattern.")
	  Return False
   EndIf

   ; how many rules are there in the ruleset
   $iRuleCounterMax = GetNumberOfRulesFromRuleSet()
   ;ConsoleWrite("TreeClimber: " & $iRuleCounterMax & @CRLF)

   ;only these rules must be checkt on the climbtarget (subdirectory)
   dim $aRelevantRulesForClimbTarget[$iRuleCounterMax+1]

   ; Assign a Local variable the empty string which will contain the files names found.
   Local $sFileName = ""

   While 1
	  $iScanFile = False
	  $iIsDirectory = False

	  $sFileName = FileFindNextFile($hSearch)
	  ; If there is no more file matching the search.
	  If @error Then ExitLoop
	  if @extended then $iIsDirectory = True

	  $sFullPath = $sStartPath & "\" & $sFileName


	  ;climb the directory tree downward if needed
	  if $iIsDirectory Then
		 $iIsClimbTarget = False
		 ; check all the rules on this directory
		 for $iRuleCounter = 1 to $iRuleCounterMax
			;ConsoleWrite("TreeClimber: " & $sFullPath & "\" & " : " & $iIsClimbTarget & @CRLF)
			if IsClimbTargetByRule($sFullPath & "\",$iRuleCounter) then
			   $aRelevantRulesForClimbTarget[$iRuleCounter] = True
			   $iIsClimbTarget = True
			EndIf
		 Next

		 if $iIsClimbTarget Then
			if $gcDEBUGShowVisitedDirectories = True then ConsoleWrite("** visited **" & $sFullPath & @CRLF)

			;count number of "\" in current path
			StringReplace($sFullPath,"\","")
			$giCurrentDirBackslashCount = @extended
			TreeClimberSecondProcess($sFullPath,$iPID,$aRelevantRulesForClimbTarget)
		 EndIf
	  EndIf

	  ; check all the rules on this file / directory
	  for $iRuleCounter = 1 to $iRuleCounterMax

		 ;check only relevant rules for this directory
		 if $aRelevantRules[$iRuleCounter] = False then ContinueLoop

		 ;check if current directory entry should be scanned according to the current rule
		 if $iIsDirectory Then
			;it is a directory
			if IsIncludedByRule($sFullPath & "\",$iRuleCounter) then
			   ;$iScanFile = True
			   ;ExitLoop
			   StdinWrite($iPID,StringFormat("%5i%s",$iRuleCounter,$sFullPath & "\") & @CRLF)
			   if @error then Exit
			EndIf
		 Else
			;it is a file
			if IsIncludedByRule($sFullPath,$iRuleCounter) then
			   ;$iScanFile = True
			   ;ExitLoop
			   StdinWrite($iPID,StringFormat("%5i%s",$iRuleCounter,$sFullPath) & @CRLF)
			   if @error then Exit
			EndIf
		 EndIf
	  Next


#cs
	  ;write $sFullPath to stdin of second process
	  if $iScanFile then

		 ;ConsoleWrite($sFullPath & @CRLF)
		 if $iIsDirectory Then
			StdinWrite($iPID,$sFullPath & "\" & @CRLF)
			if @error then Exit
		 Else
			StdinWrite($iPID,$sFullPath & @CRLF)
			if @error then Exit
		 EndIf
	  EndIf
#ce
   WEnd

   ; Close the search handle.
   FileClose($hSearch)

EndFunc


Func GetFileInfo( ByRef $gaFileInfo, $sFilename, $iHashes )

   ;Retrieves all information about $sFilename
   ;--------------------------------------------

#cs
   Global Const $FILE_ATTRIBUTE_READONLY = 0x00000001
   Global Const $FILE_ATTRIBUTE_HIDDEN = 0x00000002
   Global Const $FILE_ATTRIBUTE_SYSTEM = 0x00000004
   Global Const $FILE_ATTRIBUTE_DIRECTORY = 0x00000010
   Global Const $FILE_ATTRIBUTE_ARCHIVE = 0x00000020
   Global Const $FILE_ATTRIBUTE_DEVICE = 0x00000040
   Global Const $FILE_ATTRIBUTE_NORMAL = 0x00000080
   Global Const $FILE_ATTRIBUTE_TEMPORARY = 0x00000100
   Global Const $FILE_ATTRIBUTE_SPARSE_FILE = 0x00000200
   Global Const $FILE_ATTRIBUTE_REPARSE_POINT = 0x00000400
   Global Const $FILE_ATTRIBUTE_COMPRESSED = 0x00000800
   Global Const $FILE_ATTRIBUTE_OFFLINE = 0x00001000
   Global Const $FILE_ATTRIBUTE_NOT_CONTENT_INDEXED = 0x00002000
   Global Const $FILE_ATTRIBUTE_ENCRYPTED = 0x00004000
#ce


#cs
   File Attribute Constants

   FILE_ATTRIBUTE_ARCHIVE:	32 (0x20)
   A file or directory that is an archive file or directory. Applications typically use this attribute to mark files for backup or removal .

   FILE_ATTRIBUTE_COMPRESSED:	2048 (0x800)
   A file or directory that is compressed. For a file, all of the data in the file is compressed. For a directory, compression is the default for newly created files and subdirectories.

   FILE_ATTRIBUTE_DEVICE:	64 (0x40)
   This value is reserved for system use.

   FILE_ATTRIBUTE_DIRECTORY:	16 (0x10)
   The handle that identifies a directory.

   FILE_ATTRIBUTE_ENCRYPTED:	16384 (0x4000)
   A file or directory that is encrypted. For a file, all data streams in the file are encrypted. For a directory, encryption is the default for newly created files and subdirectories.

   FILE_ATTRIBUTE_HIDDEN:	2 (0x2)
   The file or directory is hidden. It is not included in an ordinary directory listing.

   FILE_ATTRIBUTE_INTEGRITY_STREAM:	32768 (0x8000)
   The directory or user data stream is configured with integrity (only supported on ReFS volumes). It is not included in an ordinary directory listing. The integrity setting persists with the file if it's renamed. If a file is copied the destination file will have integrity set if either the source file or destination directory have integrity set.

   Windows Server 2008 R2, Windows 7, Windows Server 2008, Windows Vista, Windows Server 2003 and Windows XP:  This flag is not supported until Windows Server 2012.

   FILE_ATTRIBUTE_NORMAL:	128 (0x80)
   A file that does not have other attributes set. This attribute is valid only when used alone.

   FILE_ATTRIBUTE_NOT_CONTENT_INDEXED:	8192 (0x2000)
   The file or directory is not to be indexed by the content indexing service.

   FILE_ATTRIBUTE_NO_SCRUB_DATA:	131072 (0x20000)
   The user data stream not to be read by the background data integrity scanner (AKA scrubber). When set on a directory it only provides inheritance. This flag is only supported on Storage Spaces and ReFS volumes. It is not included in an ordinary directory listing.

   Windows Server 2008 R2, Windows 7, Windows Server 2008, Windows Vista, Windows Server 2003 and Windows XP:  This flag is not supported until Windows 8 and Windows Server 2012.

   FILE_ATTRIBUTE_OFFLINE:	4096 (0x1000)
   The data of a file is not available immediately. This attribute indicates that the file data is physically moved to offline storage. This attribute is used by Remote Storage, which is the hierarchical storage management software. Applications should not arbitrarily change this attribute.

   FILE_ATTRIBUTE_READONLY:	1 (0x1)
   A file that is read-only. Applications can read the file, but cannot write to it or delete it. This attribute is not honored on directories. For more information, see You cannot view or change the Read-only or the System attributes of folders in Windows Server 2003, in Windows XP, in Windows Vista or in Windows 7.

   FILE_ATTRIBUTE_REPARSE_POINT:	1024 (0x400)
   A file or directory that has an associated reparse point, or a file that is a symbolic link.

   FILE_ATTRIBUTE_SPARSE_FILE:	512 (0x200)
   A file that is a sparse file.

   FILE_ATTRIBUTE_SYSTEM:	4 (0x4)
   A file or directory that the operating system uses a part of, or uses exclusively.

   FILE_ATTRIBUTE_TEMPORARY:	256 (0x100)
   A file that is being used for temporary storage. File systems avoid writing data back to mass storage if sufficient cache memory is available, because typically, an application deletes a temporary file after the handle is closed. In that scenario, the system can entirely avoid writing the data. Otherwise, the data is written after the handle is closed.

   FILE_ATTRIBUTE_VIRTUAL:	65536 (0x10000)
   This value is reserved for system use.

#ce


   ;local const $iBufferSize = 0x20000
   local const $iBufferSize = 0x100000
   local $iFileHandle = 0	;Handle of file to process
   local $iFileSize = 0		;Size of file to process
   local $sTempBuffer = ""	;File read buffer
   local $iCRC32 = 0		;CRC32 value of file
   local $iMD5CTX = 0		;MD5 interim value
   local $iTimer = 0		;Timer


   $gaFileInfo[0]  = $sFilename	;name
   $gaFileInfo[1]  = 0			;file could not be read 1 else 0
   $gaFileInfo[2]  = 0			;size
   $gaFileInfo[3]  = ""			;attributes (obsolete)
   $gaFileInfo[4]  = ""			;file modification timestamp
   $gaFileInfo[5]  = ""			;file creation timestamp
   $gaFileInfo[6]  = ""			;file accessed timestamp
   $gaFileInfo[7]  = ""			;version
   $gaFileInfo[8]  = ""			;8.3 short path+name
   $gaFileInfo[9]  = 0			;crc32
   $gaFileInfo[10] = 0			;md5 hash
   $gaFileInfo[11] = 0			;time it took to process the file
   ;$gaFileInfo[12] =	""		;rulename
   $gaFileInfo[13] = 0			;1 if the "R" = READONLY attribute is set
   $gaFileInfo[14] = 0			;1 if the "A" = ARCHIVE attribute is set
   $gaFileInfo[15] = 0			;1 if the "S" = SYSTEM attribute is set
   $gaFileInfo[16] = 0			;1 if the "H" = HIDDEN attribute is set
   $gaFileInfo[17] = 0			;1 if the "N" = NORMAL attribute is set
   $gaFileInfo[18] = 0			;1 if the "D" = DIRECTORY attribute is set
   $gaFileInfo[19] = 0			;1 if the "O" = OFFLINE attribute is set
   $gaFileInfo[20] = 0			;1 if the "C" = COMPRESSED (NTFS compression, not ZIP compression) attribute is set
   $gaFileInfo[21] = 0			;1 if the "T" = TEMPORARY attribute is set


   $iTimer = TimerInit()


   Local $hFile = _WinAPI_CreateFile($sFilename, 2, 2, 2)
   Local $aInfo = _WinAPI_GetFileInformationByHandle($hFile)
   If IsArray($aInfo) Then

	  ;Manage file attributes
	  If BitAND ( $aInfo[0], $FILE_ATTRIBUTE_READONLY ) 	Then $gaFileInfo[13] = 1
	  If BitAND ( $aInfo[0], $FILE_ATTRIBUTE_ARCHIVE ) 		Then $gaFileInfo[14] = 1
	  If BitAND ( $aInfo[0], $FILE_ATTRIBUTE_SYSTEM ) 		Then $gaFileInfo[15] = 1
	  If BitAND ( $aInfo[0], $FILE_ATTRIBUTE_HIDDEN ) 		Then $gaFileInfo[16] = 1
	  If BitAND ( $aInfo[0], $FILE_ATTRIBUTE_NORMAL ) 		Then $gaFileInfo[17] = 1
	  If BitAND ( $aInfo[0], $FILE_ATTRIBUTE_DIRECTORY ) 	Then $gaFileInfo[18] = 1
	  If BitAND ( $aInfo[0], $FILE_ATTRIBUTE_OFFLINE ) 		Then $gaFileInfo[19] = 1
	  If BitAND ( $aInfo[0], $FILE_ATTRIBUTE_COMPRESSED ) 	Then $gaFileInfo[20] = 1
	  If BitAND ( $aInfo[0], $FILE_ATTRIBUTE_TEMPORARY ) 	Then $gaFileInfo[21] = 1


	  ;Manage file times
	  For $i = 1 To 3
		 If IsDllStruct($aInfo[$i]) Then
			Local $tFILETIME = _Date_Time_FileTimeToLocalFileTime(DllStructGetPtr($aInfo[$i]))
			$aInfo[$i] = _Date_Time_FileTimeToSystemTime(DllStructGetPtr($tFILETIME))
			$aInfo[$i] = _Date_Time_SystemTimeToDateTimeStr($aInfo[$i],1)
			$aInfo[$i] = StringReplace($aInfo[$i],"/","")
			$aInfo[$i] = StringReplace($aInfo[$i]," ","")
			$aInfo[$i] = StringReplace($aInfo[$i],":","")
		 Else
			$aInfo[$i] = ""
		 EndIf
	  Next
	  $gaFileInfo[5] = $aInfo[1]
	  ;ConsoleWrite('Created:       ' & $aInfo[1] & @CRLF)
	  $gaFileInfo[6] = $aInfo[2]
	  ;ConsoleWrite('Accessed:      ' & $aInfo[2] & @CRLF)
	  $gaFileInfo[4] = $aInfo[3]
	  ;ConsoleWrite('Modified:      ' & $aInfo[3] & @CRLF)


	  ;ConsoleWrite('Volume serial: ' & $aInfo[4] & @CRLF)
	  ;ConsoleWrite('Size:          ' & $aInfo[5] & @CRLF)
	  $iFileSize = $aInfo[5]
	  $gaFileInfo[2] = $iFileSize
	  ;ConsoleWrite('Links:         ' & $aInfo[6] & @CRLF)
	  ;ConsoleWrite('ID:            ' & $aInfo[7] & @CRLF)
   Else
	  ;unable to read file
	  $gaFileInfo[1] = 1
   EndIf
   _WinAPI_CloseHandle($hFile)



   ; calculate checksums
   if not $gaFileInfo[18] Then
	  ;it큦 not a directory it큦 a file, so md5 and crc32 DO work !

	  if $iHashes then
		 ;calculate hashes (CRC32, MD5)

		 ;read file and calculate md5 and crc32
		 $iFileHandle = 0
		 $iFileHandle = FileOpen($sFilename, 16)
		 if @error or $iFileSize = 0 Then
			;unable to open file or filesize is 0

			;if filesize not 0 and we can not open the file something is fishy
			if $iFileSize > 0 then $gaFileInfo[1] = 1

		 Else
			; ### CRC32 + MD5###
			$iCRC32 = 0
			$iMD5CTX = _MD5Init()

			For $i = 1 To Ceiling($iFileSize / $iBufferSize)
			   $sTempBuffer = FileRead($iFileHandle, $iBufferSize)
			   $iCRC32 = _CRC32($sTempBuffer, BitNot($iCRC32))
			   _MD5Input($iMD5CTX, $sTempBuffer)
			Next

			$gaFileInfo[9] = $iCRC32
			$gaFileInfo[10] = _MD5Result($iMD5CTX)

			;close file
			FileClose($iFileHandle)
		 EndIf

	  EndIf
   EndIf

   $gaFileInfo[7] = FileGetVersion($sFilename)

   $gaFileInfo[8] = FileGetShortName($sFilename)


   ;End processing
   $gaFileInfo[11] = Round(TimerDiff($iTimer))


   if $gcDEBUGTimeGetFileInfo = True then $giDEBUGTimerGetFileInfo += $gaFileInfo[11]

   return 0
EndFunc


;----- mailer functions -----

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

   Global $goMyRet[2]
   Global $goMyError = ObjEvent("AutoIt.Error", "MyErrFunc")

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




Global $goMyRet[2]
Global $goMyError = ObjEvent("AutoIt.Error", "MyErrFunc")
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
        Return $goMyRet[1]
    EndIf
    $objEmail=""
EndFunc


Func MyErrFunc()
    local $HexNumber = Hex($goMyError.number, 8)
    $goMyRet[0] = $HexNumber
    $goMyRet[1] = StringStripWS($goMyError.description, 3)
    ConsoleWrite("### COM Error !  Number: " & $HexNumber & "   ScriptLine: " & $goMyError.scriptline & "   Description:" & $goMyRet[1] & @LF)
    SetError(1)
    Return
EndFunc




