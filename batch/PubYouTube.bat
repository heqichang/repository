@if (1 == 2) @end /*
REM @echo off
REM Above line makes this section transparent to JScript
REM Put this file to local view of //depot/SearchGold/deploy/builds/data/latest/MMCB and run
REM You must install Visual Studio 2012 and map $/Bing/STC-A/Multimedia/DA to any local disk folder
REM No command argument is needed for this batch file, it can conclude by itself

@echo off
echo "------------------------------------------------------------------------------------------------"
echo %DATE:~4,10%
echo "------------------------------------------------------------------------------------------------"
set SG_MMCB=%~dp0
set BATCH_FILE=%~f0

set inetroot=d:\code\searchgold
set corextbranch=searchgold
call d:\code\searchgold\tools\path1st\myenv.cmd

REM ==== Set parameter defaults ====
set DIFF=7200

REM ==== Find Visual Studio 2012 (11.0) installation dir ====
set TF_EXE=
for /f "tokens=1,2,*" %%a in ('reg.exe QUERY HKLM\SOFTWARE\Microsoft\VisualStudio\11.0 /v InstallDir') do set TF_EXE=%%c
if not defined TF_EXE for /f "tokens=1,2,*" %%a in ('reg.exe QUERY HKLM\SOFTWARE\Wow6432Node\Microsoft\VisualStudio\11.0 /v InstallDir') do set TF_EXE=%%c
if not defined TF_EXE goto :err_novs
set TF_EXE=%TF_EXE%\
set TF_EXE=%TF_EXE:\\=\%
if not exist "%TF_EXE%tf.exe" goto :err_notf

REM ==== Retrieve local mapping folder of DA template ====
set DA_PATH=
pushd "%TF_EXE%"
for /f "tokens=2" %%a in ('tf.exe workfold ^| find ^"$/Bing/STC-A/Multimedia/DA^"') do set DA_PATH=%%a
popd
if not defined DA_PATH goto :err_noda
set DA_PATH=%DA_PATH%\
set DA_PATH=%DA_PATH:\\=\%

REM ==== Sync with TFS to get latest DA template ====
"%TF_EXE%tf.exe" get "%DA_PATH%" /noprompt /overwrite /recursive
REM if errorlevel 1 goto :err_tfget

REM ==== Check youtube model is latest ====
set YOUTUBE_MODEL_PATH=%DA_PATH%ProdModels\youtube.com\watch\MMVideo_youtube.com_youtube-watch(template).xml
echo %YOUTUBE_MODEL_PATH%
set %LAST_MODIFIY_TIME%=
pushd %TF_EXE%
for /f "tokens=1,* delims=:" %%a in ('tf.exe info "%YOUTUBE_MODEL_PATH%" ^| findstr "Last modified"') do set LAST_MODIFIY_TIME=%%b
popd
if not defined %LAST_MODIFIY_TIME% goto :error_notime

set ACTUAL_DIFF=
for /f %%a in ('cscript /e:JScript /nologo %BATCH_FILE% datetimediff second "%LAST_MODIFIY_TIME%" now') do set ACTUAL_DIFF=%%a
if not defined %ACTUAL_DIFF% goto :error_difftime

if %ACTUAL_DIFF% LEQ %DIFF% goto :check_in

goto :EOF


:check_in
REM ==== Reset SG client state ====
 call :sd revert "%SG_MMCB%..."
 call :sd sync "%SG_MMCB%..."

REM ==== Create a change list for use ====
 call :sd opened -c default | find "#" > nul
 if %errorlevel% == 0 goto :error_changelist2
 set SG_CHANGELIST=
 for /f "tokens=2" %%a in ('sd.exe change -C ^"VLAD tests passed: Publish templates/INIs from TFS to SG^"') do set SG_CHANGELIST=%%a
 if "%SG_CHANGELIST%" == "" goto :error_changelist

REM ==== Special MediaPlayableConfig.ini is not manged by AutoTemplate yet ====
 del "%DA_PATH%working\MediaPlayableConfig.ini"
 
REM ==== Compiler all models in ProdModels ====
 pushd "%DA_PATH%"
 IF exist WrapStarModels.bin del WrapStarModels.bin /F
 WrapStarModelCompiler.exe /m:ProdModels /d:WrapStarModels.bin
 IF not exist WrapStarModels.bin goto :error_compiler
 
 IF exist WrapStarModels-test.bin del WrapStarModels-test.bin /F
 WrapStarModelCompiler.exe /m:PPEModels /d:WrapStarModels-test.bin
 IF not exist WrapStarModels-test.bin goto :error_compiler
 popd
 
 call :update_SG %SG_MMCB%WrapStarModels.bin %DA_PATH%WrapStarModels.bin
 call :update_SG %SG_MMCB%WrapStarModels-test.bin %DA_PATH%WrapStarModels-test.bin
 
REM ==== Submit changelist ====
call :sd submit -c %SG_CHANGELIST%
goto :EOF
 

REM ==== Error message ====
 :err_novs
echo Cannot find Visual Studio 2012 installation
goto :EOF

:err_notf
echo tf.exe is not found in Visual Studio 2012 installation: %TF_EXE%
goto :EOF

:err_noda
echo Cannot find local mapped DA template folder, please map $/Bing/STC-A/Multimedia/DA
goto :EOF

:error_changelist
echo Failed to create a changelist
goto :EOF

:error_changelist2
echo You have at least one file in default changelist, this batch file need an empty default change list to work.
goto :EOF

:error_compiler
echo WrapStarModelCompiler.exe occur error
goto :EOF

:error_notime
echo tf.exe can't extract youtube watch model last modified time
goto :EOF

:error_difftime
echo Failed to get diff time 

REM Routine to update Search Gold
REM call :update_SG sg_file source_file
:update_SG
 if not exist %1 goto :add_SG
REM --- Seems file exists in SG, get its newest version and verify it really exists in depot ---
:force_sync
 call :sd sync -f %1
 if %errorlevel% == 0 goto :edit_SG
REM --- Failed to sync the file, check if it's because the file not exist in depot, if so, add it ---
 find "- no such file(s)." ~sd.exe_stderr.txt > nul
 if %errorlevel% == 0 goto :add_SG
REM --- Previous sd.exe failed to sync the file, and the error is not because the file not exist in depot ---
 goto :error_SG
:edit_SG
REM --- Compare two files, If they are same (errorlevel is 0), ignore ---
 fc %1 %2 > nul
 if %errorlevel% == 0 goto :same_SG
REM --- Not same, update the file in client ---
 call :sd edit -c %SG_CHANGELIST% -t binary %1
 if errorlevel 1 goto :error_SG
 copy /y %2 %1
 if errorlevel 1 goto :error_SG
 exit /b 0
:add_SG
 md %1
 rd %1
 copy /y %2 %1
 if errorlevel 1 goto :error_SG
 call :sd add -c %SG_CHANGELIST% -t binary %1
 if %errorlevel% == 0 exit /b 0
REM --- If failed to add the file, check if sd.exe said it's an existing file, if so force sync it ---
 find "existing file" ~sd.exe_stderr.txt > nul
 if %errorlevel% == 0 goto :force_sync
 goto :error_SG
:same_SG
 if "%~3" == "del" del %2
 exit /b 0
:error_SG
 echo Error in updating file %1 from %2
 type ~sd.exe_stderr.txt
 exit /b 1

REM ==== This routine will run sd.exe and return whether se.exe has written something to STDERR ====
:sd
sd.exe %* 2>~sd.exe_stderr.txt
call :get_file_size ~sd.exe_stderr.txt
if %errorlevel% == 0 exit /b 0
find "WSAETIMEDOUT" ~sd.exe_stderr.txt > nul
if %errorlevel% == 0 goto :sd
find "WSAECONNRESET" ~sd.exe_stderr.txt > nul
if %errorlevel% == 0 goto :sd
exit /b 1

:get_file_size
exit /b %~z1
goto :EOF

JScript */

function ParseDateTime(dt)
{
  if (dt == null || dt == "" || dt.toLowerCase() == "now" || dt.toLowerCase() == "utcnow")
  { // Local time now
    return new Date().valueOf();
  }

  return Date.parse(dt);
  
}

function GetDateTimeDiff(unit, start, end)
{
  // Compute the difference, in milliseconds, between the two date time values
  var diff = ParseDateTime(end) - ParseDateTime(start);

  if (unit == null || unit == "")
  {
    var millisecond = new String(diff % 1000);
    diff = Math.floor(diff / 1000);
    var second = new String(diff % 60 + 100).substr(1);
    diff = Math.floor(diff / 60);
    var minute = new String(diff % 60 + 100).substr(1);
    diff = Math.floor(diff / 60);
    var hour = new String(diff % 24 + 100).substr(1);
    diff = Math.floor(diff / 24);
    var day = new String(diff);

    return day + "." + hour + ":" + minute + ":" + second;
  }

  // Convert milliseconds to 
  switch (unit.toLowerCase())
  {
  case "second":
  case "seconds":
  case "sec":
    return Math.round(diff / 1000);
  case "minute":
  case "minutes":
  case "min":
    return Math.round(diff / (60 * 1000));
  case "hour":
  case "hours":
    return Math.round(diff / (60 * 60 * 1000));
  case "day":
  case "days":
    return Math.round(diff / (24 * 60 * 60 * 1000));
  }
}

switch (WScript.Arguments(0).toLowerCase())
{


case "datetimediff":
  WScript.Echo(GetDateTimeDiff(WScript.Arguments(1), WScript.Arguments(2), WScript.Arguments(3)));
  break;

}
