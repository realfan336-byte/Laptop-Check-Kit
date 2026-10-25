@echo off
setlocal EnableDelayedExpansion
title Windows Full Report + Crash History Collector
color 0A

REM ============================================================
REM  Windows Full Report + Past Crash / Bugcheck Collector
REM  Creates a reports folder next to this script if missing.
REM  Only adds new timestamped reports; does not delete or
REM  overwrite existing report files.
REM ============================================================

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

set "REPORT_ROOT=%SCRIPT_DIR%\Windows_Reports"

echo ============================================================
echo   WINDOWS FULL REPORT + CRASH HISTORY
echo ============================================================
echo.
echo This script collects genuine Windows system information
echo and recent crash / bugcheck related event log entries.
echo.
echo Reports folder:
echo   %REPORT_ROOT%
echo.

REM Create folder only if it does not exist
if not exist "%REPORT_ROOT%" (
    echo Creating reports folder for the first time...
    mkdir "%REPORT_ROOT%" 2>nul
    if errorlevel 1 (
        echo [ERROR] Cannot create folder: %REPORT_ROOT%
        echo Try running from a location where you have write permission.
        pause
        exit /b 1
    )
    echo Folder created.
) else (
    echo Reports folder already exists. New reports will be added inside it.
)

REM Timestamp
for /f "tokens=2 delims==" %%a in ('wmic os get localdatetime /value 2^>nul') do set "dt=%%a"
if defined dt (
    set "TS=%dt:~0,4%-%dt:~4,2%-%dt:~6,2%_%dt:~8,2%-%dt:~10,2%-%dt:~12,2%"
) else (
    set "TS=%date:~-4,4%-%date:~-10,2%-%date:~-7,2%_%time:~0,2%-%time:~3,2%-%time:~6,2%"
    set "TS=%TS: =0%"
)

set "FULL_REPORT=%REPORT_ROOT%\Full_System_Report_%TS%.txt"
set "CRASH_REPORT=%REPORT_ROOT%\Crash_Bugcheck_History_%TS%.txt"
set "SUMMARY=%REPORT_ROOT%\Summary_%TS%.txt"

echo.
echo Collecting data... please wait.
echo.

(
    echo Windows Full System Report
    echo Generated: %date% %time%
    echo Computer: %COMPUTERNAME%
    echo User: %USERNAME%
    echo ============================================================
    echo.
) > "%FULL_REPORT%"

echo [1/6] Basic system information...
echo ----- systeminfo ----- >> "%FULL_REPORT%"
systeminfo >> "%FULL_REPORT%" 2>&1
echo. >> "%FULL_REPORT%"

echo [2/6] Processor and memory...
echo ----- Processor ----- >> "%FULL_REPORT%"
wmic cpu get Name,NumberOfCores,NumberOfLogicalProcessors,MaxClockSpeed /format:list >> "%FULL_REPORT%" 2>&1
echo. >> "%FULL_REPORT%"
echo ----- Memory ----- >> "%FULL_REPORT%"
wmic OS get TotalVisibleMemorySize,FreePhysicalMemory /format:list >> "%FULL_REPORT%" 2>&1
wmic memorychip get Capacity,Speed,Manufacturer /format:list >> "%FULL_REPORT%" 2>&1
echo. >> "%FULL_REPORT%"

echo [3/6] Windows version and architecture...
echo ----- Windows Version ----- >> "%FULL_REPORT%"
ver >> "%FULL_REPORT%" 2>&1
wmic os get Caption,Version,BuildNumber,OSArchitecture,InstallDate /format:list >> "%FULL_REPORT%" 2>&1
echo. >> "%FULL_REPORT%"

echo [4/6] Disks...
echo ----- Logical Disks ----- >> "%FULL_REPORT%"
wmic logicaldisk get DeviceID,FileSystem,Size,FreeSpace,VolumeName /format:list >> "%FULL_REPORT%" 2>&1
echo. >> "%FULL_REPORT%"

echo [5/6] Graphics and network adapters (summary)...
echo ----- Graphics ----- >> "%FULL_REPORT%"
wmic path win32_VideoController get Name,DriverVersion /format:list >> "%FULL_REPORT%" 2>&1
echo. >> "%FULL_REPORT%"
echo ----- Network Adapters ----- >> "%FULL_REPORT%"
wmic path win32_NetworkAdapter where "NetEnabled=true" get Name,MACAddress /format:list >> "%FULL_REPORT%" 2>&1
echo. >> "%FULL_REPORT%"

echo [6/6] Installed hotfixes (recent)...
echo ----- Recent Hotfixes ----- >> "%FULL_REPORT%"
wmic qfe list brief >> "%FULL_REPORT%" 2>&1

echo.
echo Collecting crash / bugcheck related history...
echo.

(
    echo Windows Crash / Bugcheck / Error History
    echo Generated: %date% %time%
    echo ============================================================
    echo.
    echo This report contains recent Error and Critical events from
    echo the System log, plus specific BugCheck / WER related entries
    echo when available. It does not invent data.
    echo.
) > "%CRASH_REPORT%"

echo [A] Recent Critical and Error events (System log, last 50)...
echo ----- Critical / Error Events (last 50) ----- >> "%CRASH_REPORT%"
wevtutil qe System /q:"*[System[(Level=1 or Level=2)]]" /f:text /c:50 /rd:true >> "%CRASH_REPORT%" 2>&1
if errorlevel 1 (
    echo [WARN] Could not read some event log entries. Try running as Administrator.
    echo [WARN] wevtutil returned an error. >> "%CRASH_REPORT%"
)
echo. >> "%CRASH_REPORT%"

echo [B] BugCheck / Blue Screen related events...
echo ----- BugCheck / Stop Error related ----- >> "%CRASH_REPORT%"
wevtutil qe System /q:"*[System[Provider[@Name='Microsoft-Windows-WER-SystemErrorReporting'] or Provider[@Name='BugCheck'] or (EventID=1001) or (EventID=1003)]]" /f:text /c:30 /rd:true >> "%CRASH_REPORT%" 2>&1
echo. >> "%CRASH_REPORT%"

echo [C] Kernel-Power and unexpected shutdown events...
echo ----- Kernel-Power / Unexpected Shutdown ----- >> "%CRASH_REPORT%"
wevtutil qe System /q:"*[System[Provider[@Name='Microsoft-Windows-Kernel-Power'] and (EventID=41 or EventID=42 or EventID=109)]]" /f:text /c:20 /rd:true >> "%CRASH_REPORT%" 2>&1
echo. >> "%CRASH_REPORT%"

echo [D] Memory Diagnostic results (if any)...
echo ----- MemoryDiagnostics-Results ----- >> "%CRASH_REPORT%"
wevtutil qe System /q:"*[System[Provider[@Name='MemoryDiagnostics-Results']]]" /f:text /c:10 /rd:true >> "%CRASH_REPORT%" 2>&1
echo. >> "%CRASH_REPORT%"

echo [E] Minidump folder check (presence only)...
echo ----- Minidump files (list only) ----- >> "%CRASH_REPORT%"
if exist "%SystemRoot%\Minidump\*.dmp" (
    echo Minidump files found in %SystemRoot%\Minidump\
    dir /b "%SystemRoot%\Minidump\*.dmp" >> "%CRASH_REPORT%" 2>&1
) else (
    echo No minidump files currently present in %SystemRoot%\Minidump\
    echo (This is normal if no recent crashes occurred or dumps were cleaned.)
)
echo. >> "%CRASH_REPORT%"

echo [F] Windows Error Reporting folder presence...
echo ----- WER folders ----- >> "%CRASH_REPORT%"
if exist "%LOCALAPPDATA%\Microsoft\Windows\WER" (
    echo WER folder exists: %LOCALAPPDATA%\Microsoft\Windows\WER
) else (
    echo WER folder not found in user profile.
)
if exist "%ProgramData%\Microsoft\Windows\WER" (
    echo ProgramData WER folder exists.
) else (
    echo ProgramData WER folder not found.
)

REM Simple summary
(
    echo Summary - Windows Full Report + Crash History
    echo Generated: %date% %time%
    echo.
    echo Full system report :
    echo   %FULL_REPORT%
    echo.
    echo Crash / bugcheck history :
    echo   %CRASH_REPORT%
    echo.
    echo Reports folder :
    echo   %REPORT_ROOT%
    echo.
    echo Notes:
    echo - Event log access is more complete when run as Administrator.
    echo - Absence of BugCheck events usually means no recent BSODs
    echo   were recorded, or the log was cleared.
    echo - This tool only reads information; it does not change
    echo   Windows settings or delete any files.
) > "%SUMMARY%"

echo.
echo ============================================================
echo   DONE
echo ============================================================
echo.
echo Reports saved in:
echo   %REPORT_ROOT%
echo.
echo Files created this run:
echo   Full_System_Report_%TS%.txt
echo   Crash_Bugcheck_History_%TS%.txt
echo   Summary_%TS%.txt
echo.
echo Opening the reports folder...
start "" explorer "%REPORT_ROOT%"
timeout /t 2 >nul
start notepad "%SUMMARY%"

echo.
echo Press any key to close...
pause >nul
exit /b 0
