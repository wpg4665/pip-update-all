@ECHO off
	rem Delayed Expansion needed for ERRORLEVEL within FOR loop
SETLOCAL EnableDelayedExpansion
	rem Create TRUE / FALSE variables for clearer value testing
SET TRUE=-1
SET FALSE=0
	rem Not exactly the fasted script in the world...likely due to network lag

	rem Read in extenal variables from pip_update_all.conf
CALL :import_vars


	rem Ensure localized working directory
PUSHD "%python%"


	rem Ensures portable python is used for pip as opposed to locally installed
SET PATH=%python%\Scripts;%python%;%PATH%


	rem Loop through all portably installed packages and update if needed
FOR /F "delims===" %%A IN ('%pip% freeze') DO (
	ECHO Checking %%A for updates
	%pip% install --no-cache-dir --upgrade --no-deps %%A > error.txt
	IF !ERRORLEVEL! NEQ 0 (
		ECHO.
		TYPE error.txt
		ECHO.
	)
	%pip% install --no-cache-dir %%A > error.txt
	IF !ERRORLEVEL! NEQ 0 (
		ECHO.
		TYPE error.txt
		ECHO.
	)
)


	rem Delete potentially created error output message
DEL /F /Q error.txt


	rem Restore initial working directory
POPD

GOTO :eof


	rem Read variables from pip_update_all.conf in current directory
:import_vars
	PUSHD "%~dp0" 
	FOR /F "tokens=1,2 delims===" %%B IN ('type pip_update_all.conf ^| find "="') DO SET %%B=%%C
	POPD
GOTO :eof