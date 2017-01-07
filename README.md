# STD
Spot the Difference (STD) is a poor mans file integrity checker written in autoit

Prerequisites:
sqlite.dll in searchpath or the same directory as STD.exe

Invocation:
STD.exe COMMAND PARAMETERS


COMMANDS and their PARAMETERS:

STD.exe /importcfg DB CONFIGFILE
STD.exe /importcfg c:\test.sqlite c:\config.cfg
Import CONFIGFILE into DB.
An existing config with rules in DB will be replaced.

STD.exe /exportcfg DB CONFIGFILE
STD.exe /exportcfg c:\test.sqlite c:\config.cfg
Export config with rules form DB into CONFIGFILE.
An existing CONFIGFILE will be overwritten.

STD.exe /scan DB
STD.exe /scan c:\test.sqlite
Scan directories according to the rules in a previously imported CONFIGFILE
and insert directory and/or file information into DB

STD.exe /report[s|m|l] DB [[OLDSCANNAME] NEWSCANNAME] REPORTFILE
STD.exe /reports c:\test.sqlite c:\report.txt
STD.exe /reportm c:\test.sqlite 20160514131610 c:\report.txt
STD.exe /report c:\test.sqlite 20160514131610 last c:\report.txt
Write the differences between NEWSCANNAME and OLDSCANNAME to REPORTFILE.
If NEWSCANNAME and OLDSCANNAME are omitted then NEWSCANNAME defaults to last
and OLDSCANNAME to lastvalid.
If only NEWSCANNAME is given then all the information from NEWSCANNAME
is written to REPORTFILE. This is useful if you like to know what is in a scan.
There are three levels of detail in a report: small (/reports), medium (/reportm) and large (/report or /reportl)
REPORTFILE is either a regular filename or a SPECIAL_REPORTNAME.
OLDSCANNAME and NEWSCANNAME are either existing scans
or SPECIAL_SCANNAMEs.

STD.exe /list DB
STD.exe /list c:\test.sqlite
List all scans in DB

STD.exe /validate DB SCANNAME
STD.exe /validate c:\test.sqlite 20160514131610
Set status of scan SCANNAME to valid. SCANNAME is either an existing scan
or a SPECIAL_SCANNAME

STD.exe /invalidate DB SCANNAME
STD.exe /invalidate c:\test.sqlite 20160514131610
Set status of scan SCANNAME to invalid. SCANNAME is either an existing scan
or a SPECIAL_SCANNAME

STD.exe /delete DB SCANNAME
STD.exe /delete c:\test.sqlite 20160514131610
Delete the scan SCANNAME. SCANNAME is either an existing scan or a SPECIAL_SCANNAME

STD.exe /exportscan DB SCANNAME CSVFILENAME
STD.exe /exportscan c:\test.sqlite 20160514131610 c:\test.csv
Export scan SCANNAME to CSVFILENAME. SCANNAME is either an existing scan
or a SPECIAL_SCANNAME

STD.exe /duplicates DB SCANNAME
STD.exe /duplicates c:\test.sqlite last
Write a list with duplicate files based on size, crc32 and md5 in scan SCANNAME to stdout.
SCANNAME is either an existing scan or a SPECIAL_SCANNAME. If scan is a SPECIAL_SCANNAME
only the first scan of the selected scans is used.

STD.exe /history DB SEARCHTEXT
STD.exe /history c:\test.sqlite "\temp\example.dll"
Write the change history of one or more files to stdout.
SEARCHTEXT is a part of the full path or filename. SEARCHTEXT is case sensitiv !
Wildcards are not supported.

STD.exe /help
Show this help

STD.exe /?
Show this help

STD.exe /v
Show version information


SPECIAL_SCANNAME:
all           all the scans in DB
last          the most recent scan in DB
invalid       all not validated scans in DB
valid         all validated scans in DB
lastinvalid   the most recent not validated scan in DB
lastvalid     the most recent validated scan in DB
oldvalid      all validated scans in DB except lastvalid


SPECIAL_REPORTNAME:
email         create report as temporary file and send the report as email
              according to the config in DB.


CSVFILENAME:
Textfile that contains all data from one or more scans as comma separated values.


DB:
SQLite database files. It will be generated if it does not exist.
It contains all data of all scans and the imported CONFIGFILE.
If the file gets big, delete old scans.


REPORTFILE:
Textfile that contains the differences of two scans in human readable form.


CONFIGFILE:
Describes a ruleset of one or more scan rules. A rule is a code block that starts with a
"Rule:" statement and ends with an "End" statement.
A rule block consists of statements that describe which directories and
file extentions should be included in or excluded from the scan.

The "Email*" statements are global for the entire ruleset and therefore NOT enclosed by
"Rule:" and "End" statements.

A line that starts with # indicates a comment line.

Rule:RULENAME          start of rule
IncDirRec:PATH         directory to include, including all subdirectories
ExcDirRec:PATH         directory to exclude, including all subdirectories
IncDir:PATH            directory to include, only this directory
ExcDir:PATH            directory to exclude, only this directory
IncExt:FILEEXTENTION   file extention to include
ExcExt:FILEEXTENTION   file extention to exclude
IncExe                 all executable files, no matter what the extention is.
                       This statement is very slow, since the first two bytes of
                       EVERY file in the IncDir are read!
ExcExe                 no executable files, no matter what the extention is
                       This statement is very slow, since the first two bytes of
                       EVERY file in the IncDir are read!
IncAll                 all files, no matter what the extention is aka *.*
ExcAll                 no files, no matter what the extention is aka *.*,
                       only directories
IncDirs                include information on directories.
                       By default no information on directories is included.
NoHashes				 no CRC32 and MD5 hashes are calculated. This is faster,
                       but changes in a file can not be detected.
Ign:FILEPROPERTIY      ignore changes to this file property.
End                    end of rule

EmailFrom:EMAILADDRESS       sender email address
EmailTo:EMAILADDRESS         recipient email address
EmailSubject:SUBJECT         email subject
EmailServer:SMTPSERVERNAME   name of smtp server (hostname or ip-address)
EmailPort:SMTPPORT           smtp port on SMTPSERVERNAME, defaults to 25


EMAILADDRESS           email adress
                       e.g.: peter.miller@example.com
FILEEXTENTION          one file extention
                       e.g.: doc,xls,xlsx,txt,pdf,PDF,TxT,Doc
FILEPROPERTIY          one file property
                       status    was the file accessible
                       size      size of the file
                       mtime     modification time
                       ctime     creation time
                       atime     access time
                       version   file version
                       crc32     crc32 checksum
                       md5       md5 checksum
                       rattrib   read only attribute
                       aattrib   archive attribute
                       sattrib   system attribute
                       hattrib   hidden attribute
                       nattrib   normal attribute
                       dattrib   directory attribute
                       oattrib   offline attribute
                       cattrib   compressed attribute
                       tattrib   temporary attribute
                       e.g.: mtime,size,aattrib,nATTRIB,aAttrib
RULENAME               name of rule
                       e.g.: My first Rule
SMTPPORT               smtp portnumber
                       e.g.: 25
SMTPSERVERNAME         name of a smtp server
                       e.g.: mail.excample.com, 127.0.0.1
SUBJECT                subject line of an email
                       e.g.: std report
PATH                   one directory name
                       e.g.: "\\pc\share\my files","c:\temp","c:\temp\",c:\temp

CONFIGFILE Example:

# The rule is named "Word and Excel" and includes all *.doc,*.docx,*.xls,*.xlsx
# files in "c:\my msoffice files" and all subdirectories, with the exception of
# "c:\my msoffice files\temp" and all its subdirectories.
#
# Changes of file size and the attributes "archive" and "normal" get ignored in reports.
#
# Email reports are send from "std@example.com" to "admin@example.com" with
# the subject line "modified files" via the smtp mailserver at "192.168.1.1".
#
#
EmailFrom:std@example.com
EmailTo:admin@example.com
EmailSubject:modified files
EmailServer:192.168.1.1
#
Rule:Word and Excel
  IncDirRec:"c:\my msoffice files"
  ExcDirRec:"c:\my msoffice files\temp"
  IncExt:doc
  IncExt:docx
  IncExt:xls
  IncExt:xlsx
  Ign:size
  Ign:aattrib
  Ign:nattrib
End


Quick Start:

 1. Create a CONFIGFILE with an editor
 2. Import CONFIGFILE into (not yet existing) DB:
    STD.exe /importcfg DB CONFIGFILE
 3. Initial scan:
    STD.exe /scan DB
 4. Validate initial scan:
    STD.exe /validate DB last
 5. Delete all existing invalid scans (optional):
    STD.exe /delete DB invalid
 6. Normal scan:
    STD.exe /scan DB
 7. Create report:
    STD.exe /report DB REPORTFILE
 8. Review the report with an editor.
 9. Validate last scan:
    STD.exe /validate DB last
10. Delete all old valid scans (optional):
    STD.exe /delete DB oldvalid
11. Start next cycle, goto 5.
