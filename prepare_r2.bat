@ECHO OFF
SETLOCAL ENABLEDELAYEDEXPANSION

SET BADARG=1
FOR %%i IN ("" "32" "64") DO (IF "%1" == %%i SET BADARG=) 
IF DEFINED BADARG (
	ECHO Usage: %0 [32^|64]
	EXIT /B
)
SET BITS=%1

FOR %%i IN (python.exe) DO (IF NOT DEFINED PYTHON SET PYTHON=%%~dp$PATH:i)

IF NOT DEFINED PYTHON SET PYTHON=C:\Program Files\Python36
IF NOT DEFINED NINJA_URL SET NINJA_URL=https://github.com/ninja-build/ninja/releases/download/v1.8.2/ninja-win.zip
IF NOT DEFINED VSVARSALLPATH SET VSVARSALLPATH=C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\vcvarsall.bat

IF NOT EXIST %PYTHON%\python.exe EXIT /B

SET "PYTHONHOME=%PYTHON%"
SET "PATH=%CD%;%PYTHON%;%PYTHON%\Scripts;%PATH%"

git submodule update --init

ECHO Downloading meson and ninja
python -m pip install meson
IF !ERRORLEVEL! NEQ 0 EXIT /B
IF NOT EXIST ninja.exe (
	powershell -Command wget %NINJA_URL% -OutFile ninja.zip && powershell -Command Expand-Archive .\ninja.zip -DestinationPath .\ && DEL ninja.zip
	IF !ERRORLEVEL! NEQ 0 EXIT /B
)

IF NOT "%BITS%" == "32" (
	SET VARSALL=x64
	SET BI=64
	CALL :BUILD
	IF !ERRORLEVEL! NEQ 0 EXIT /B
)
IF NOT "%BITS%" == "64" (
	SET VARSALL=x86
	SET BI=32
	CALL :BUILD
	IF !ERRORLEVEL! NEQ 0 EXIT /B
)

ECHO Copying relevant files in cutter_win32
IF "%BITS%" == "64" (
	XCOPY /S /Y dist64\include\libr cutter_win32\radare2\include\libr\
) ELSE (
	XCOPY /S /Y dist32\include\libr cutter_win32\radare2\include\libr\
)
EXIT /B

:BUILD
ECHO Building radare2 (%VARSALL%)
CD radare2
git clean -xfd
RMDIR /s /q ..\dist%BI%
CALL "%VSVARSALLPATH%" %VARSALL%
python sys\meson.py --release --shared --prefix="%CD%"
IF !ERRORLEVEL! NEQ 0 EXIT /B 1
CALL sys\meson_install.bat --with-static ..\dist%BI%
COPY /Y build\r_userconf.h ..\dist%BI%\include\libr\
COPY /Y build\r_version.h ..\dist%BI%\include\libr\
COPY /Y build\shlr\liblibr2sdb.a ..\dist%BI%\r_sdb.lib
CD ..
COPY /Y dist%BI%\*.lib cutter_win32\radare2\lib%BI%\
EXIT /B 0
