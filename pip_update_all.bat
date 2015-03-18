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
	ECHO +++ Checking %%A for updates +++
	%pip% install --no-cache-dir --upgrade --no-deps -q %%A > output.txt
	TYPE output.txt 2>NUL | FIND "use --allow-external" >NUL 2>&1
	IF !ERRORLEVEL!==0 (
		IF "%download_external%"=="%TRUE%" (
			%pip% install --no-cache-dir --upgrade --no-deps -q --allow-external %%A %%A > output.txt
			TYPE output.txt 2>NUL | FIND "use --allow-unverified" >NUL 2>&1
			IF !ERRORLEVEL!==0 (
				IF "%download_insecure%"=="%TRUE%" (
					%pip% install --no-cache-dir --upgrade --no-deps -q --allow-external %%A --allow-unverified %%A %%A > output.txt
				)
			)
		)
	)
	%pip% install --no-cache-dir -q %%A
)


	rem Delete potentially created error output message
DEL /F /Q output.txt 2>NUL


	rem Restore initial working directory
POPD

GOTO :eof


	rem Read variables from pip_update_all.conf in current directory
:import_vars
	PUSHD "%~dp0"
	IF EXIST pip_update_all.conf.local (
		FOR /F "tokens=1,2 delims===" %%B IN ('TYPE pip_update_all.conf.local ^| FIND /V "#"') DO SET %%B=%%C
	) ELSE (
		FOR /F "tokens=1,2 delims===" %%B IN ('TYPE pip_update_all.conf ^| FIND /V "#"') DO SET %%B=%%C
	)
	POPD
GOTO :eof