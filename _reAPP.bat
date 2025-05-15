@echo off
rem [ SETTINGS ]==========================================================
set AppName=reAPP
set AppAuthor=Kristian Cenov
::set AppVersion=v2025.04.06
::set AppWeb=kcenow.com
set AppPrefix=re
set AppSettingsFile=_%AppName%.ini
set AppUninstallName=Uninstall

:: Task
set AppTaskFile=template.xml
set AppTaskInterval=1H
set AppTaskPermision=HighestAvailable

:: Get local date and set variables
for /F "usebackq tokens=1,2 delims==" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set ldt=%%j
set AppCurrentDateTime=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%T%ldt:~8,2%:%ldt:~10,2%:%ldt:~12,9%
set AppCurrentDate=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%
rem ======================================================================

rem [ REGISTER ]==========================================================
for /f "tokens=1 delims=_%AppPrefix%" %%i in ("%~n0") do set AppTargetName=%%i

title %AppName% [%AppTargetName%.exe]
rem ======================================================================

rem [ MAIN ]==============================================================
:: Check if target app exist
if not exist "%AppTargetName%.exe" (
	call :fn_popup "%AppName%.exe" "Please, move the program in YOUR_APP_NAME.exe directory and rename this program to _reYOUR_APP_NAME.exe!" "Warning"
	exit
)

:: Check if settings file exist
if not exist "%AppSettingsFile%" (
	(	echo # Task Settings
		echo AppTaskInterval=%AppTaskInterval%
		echo AppTaskPermision=%AppTaskPermision%
	) > "%AppSettingsFile%"
	
	call :fn_popup "%AppName%.exe" "%AppSettingsFile% is missing, generating new settings file!" "Warning"
)

:: Replace variables with ini settings
for /f "delims== tokens=1,2" %%G in (%AppSettingsFile%) do set %%G=%%H

:: Check if shortcut cotains "-uninstall" argument
if "%1" == "-uninstall" (
	:: Force kill the main program and it's tree if it is started
	taskkill /IM "%AppTargetName%.exe" /F /T

	:: Delete created task
	schtasks /Delete /TN "%AppPrefix%%AppTargetName%" /F
	
	:: Delete uninstall shortcut
	del %AppUninstallName%.lnk

	:: Show notification for uninstall
	call :fn_popup "%AppName%.exe" "Program was successfuly uninstalled!" "Info"
	
	:: Force exit
	exit
)

:: Check if scheduled task exist
schtasks /Query /TN "%AppPrefix%%AppTargetName%" >NUL 2>&1
if %errorlevel% NEQ 0 (
	:: Populate template with custom settings
	type "%MYFILES%\%AppTaskFile%" | %MYFILES%\repl "(<Date>).*(</Date>)" "$1%AppCurrentDateTime%$2" > %MYFILES%\%AppTaskFile%
	type "%MYFILES%\%AppTaskFile%" | %MYFILES%\repl "(<Author>).*(</Author>)" "$1%AppAuthor%$2" > %MYFILES%\%AppTaskFile%
	type "%MYFILES%\%AppTaskFile%" | %MYFILES%\repl "(<URI>).*(</URI>)" "$1\%AppTargetName%$2" > %MYFILES%\%AppTaskFile%
	type "%MYFILES%\%AppTaskFile%" | %MYFILES%\repl "(<Interval>).*(</Interval>)" "$1PT%AppTaskInterval%$2" > %MYFILES%\%AppTaskFile%
	type "%MYFILES%\%AppTaskFile%" | %MYFILES%\repl "(<RunLevel>).*(</RunLevel>)" "$1%AppTaskPermision%$2" > %MYFILES%\%AppTaskFile%
	type "%MYFILES%\%AppTaskFile%" | %MYFILES%\repl "(<Command>).*(</Command>)" "$1%~f0$2" > %MYFILES%\%AppTaskFile%
	::type "%MYFILES%\%AppTaskFile%" | %MYFILES%\repl "(<Arguments>).*(</Arguments>)" "$1%~f0$2" > %MYFILES%\%AppTaskFile%
	type "%MYFILES%\%AppTaskFile%" | %MYFILES%\repl "(<WorkingDirectory>).*(</WorkingDirectory>)" "$1%cd%$2" > %MYFILES%\%AppTaskFile%
	
	:: Create task from xml template with the settings above
	schtasks /Create /TN "%AppPrefix%%AppTargetName%" /XML %MYFILES%\%AppTaskFile%
	
	:: Run created task
	schtasks /Run /TN "%AppPrefix%%AppTargetName%"
	
	:: Check if uninstall shortcut exist
	if not exist "%AppUninstallName%.ink" (
		:: Create uninstall shortcut
		call :fn_create_shortcut "%cd%" "%AppUninstallName%" "%~f0" "-uninstall" "Uninstall %AppName%" "%~f0" "%cd%"
	)

	:: Show notification for install
	call :fn_popup "%AppName%.exe" "Program was successfuly installed!" "Info"
)

:: Force kill the main program and it's tree if it is started
taskkill /IM "%AppTargetName%.exe" /F /T

:: Start the main program
start %AppTargetName%

:: Force exit
exit
rem ======================================================================

rem [ FUNCTIONS ]==========================================================
:: *** Function PopUP v1.0 - Show notification popup ***
:: Usage: call :fn_popup "Title" "Message" "Icon" "Time to show in seconds (Default: 0-Unlimited[OK button needs to be pressed])"
:: Icon Types: None, Error, Question, Warning, Info
:fn_popup
:: Replace variables
if "%~1" == "" (set PopupTitle="Default Title") else (set PopupTitle=%1)
if "%~2" == "" (set PopupMessage="Default Message") else (set PopupMessage=%2)
if "%~3" == "" (set PopupIcon=0)
if "%~3" == "None" (set PopupIcon=0)
if "%~3" == "Error" (set PopupIcon=10)
if "%~3" == "Question" (set PopupIcon=20)
if "%~3" == "Warning" (set PopupIcon=30)
if "%~3" == "Info" (set PopupIcon=40)
if "%~4" == "" (set PopupTime=0) else (set PopupTime=%4)

:: Start PowerShell and create popup
powershell -Command "(New-Object -ComObject Wscript.Shell).Popup('%PopupMessage%', %PopupTime%, '%PopupTitle%', 0x%PopupIcon%)"

:: Return to callable
exit /B
:: *** END OF FUNCTION ***

:: *** Function Create Shortcut v1.0 ***
:: Usage: call :fn_create_shortcut "Location" "Title" "Target Path" "Arguments" "Description" "Icon Location" "Working Directory"
:fn_create_shortcut
:: Replace variables
if "%~1" == "" (set ShortCutLocation="%cd%") else (set ShortCutLocation=%~1)
if "%~2" == "" (set ShortCutTitle="Default Title") else (set ShortCutTitle=%~2)
if "%~3" == "" (set ShortCutTarget="Default Target") else (set ShortCutTarget=%~3)
if "%~4" == "" (set ShortCutArgs="") else (set ShortCutArgs=%~4)
if "%~5" == "" (set ShortCutDesc="") else (set ShortCutDesc=%~5)
if "%~6" == "" (set ShortCutIcon="%~f0") else (set ShortCutIcon=%~6)
if "%~7" == "" (set ShortCutWorkDir="%cd%") else (set ShortCutWorkDir=%~7)

:: Create VBS Script
(	echo Set objectWS = WScript.CreateObject("WScript.Shell"^)
	echo shortCutFile = "%ShortCutLocation%\%ShortCutTitle%.lnk"
	echo Set shortCut = objectWS.CreateShortcut(shortCutFile^)
	echo shortCut.TargetPath = "%ShortCutTarget%"
	echo shortCut.Arguments = "%ShortCutArgs%"
	echo shortCut.Description = "%ShortCutDesc%"
	echo shortCut.IconLocation = "%ShortCutIcon%"
	echo shortCut.WorkingDirectory = "%ShortCutWorkDir%"
	echo shortCut.Save
) > %TEMP%\CreateShortcut.vbs

:: Start created VBS Script
cscript %TEMP%\CreateShortcut.vbs

:: Delete created VBS Script
del %TEMP%\CreateShortcut.vbs

:: Return to callable
exit /B
:: *** END OF FUNCTION ***
rem ======================================================================