@echo off
setlocal enabledelayedexpansion

REM ==== Find Visual Studio 2012 (11.0) installation dir ====
set TF_EXE=
for /f "tokens=1,2,*" %%a in ('reg.exe QUERY HKLM\SOFTWARE\Microsoft\VisualStudio\11.0 /v InstallDir') do set TF_EXE=%%c
if not defined TF_EXE for /f "tokens=1,2,*" %%a in ('reg.exe QUERY HKLM\SOFTWARE\Wow6432Node\Microsoft\VisualStudio\11.0 /v InstallDir') do set TF_EXE=%%c
if not defined TF_EXE goto :err_novs
set TF_EXE=%TF_EXE%\
set TF_EXE=%TF_EXE:\\=\%
if not exist "%TF_EXE%tf.exe" goto :err_notf
set TF_EXE="%TF_EXE%tf.exe"
echo %TF_EXE%
set si="site.ini"
for /f "tokens=3" %%a in ('%TF_EXE% status ^|findstr /i site.ini') do (
    set diff_temp=%%a
    %TF_EXE% diff %%a /format:brief | find "files differ"
    if !errorlevel!==0 goto :autotemplate
    
)

goto :pack

:autotemplate
call AutoTemplate.bat

:pack
DAPackGUI.exe



