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


	rem Output results of current pip freeze list, to be used for comparison after upgrades
pip freeze > pip_freeze_results.before


	rem Loop through all portably installed packages and update if needed
FOR /F "delims===" %%A IN (pip_freeze_results.before) DO (
	ECHO +++ Checking %%A for updates +++
	pip install --no-cache-dir --upgrade --no-deps -q %%A > output.txt 2>NUL
	TYPE output.txt 2>NUL | FIND "use --allow-external" >NUL 2>&1
	IF !ERRORLEVEL!==0 (
		IF "%download_external%"=="%TRUE%" (
			pip install --no-cache-dir --upgrade --no-deps -q --allow-external %%A %%A > output.txt 2>NUL
			TYPE output.txt 2>NUL | FIND "use --allow-unverified" >NUL 2>&1
			IF !ERRORLEVEL!==0 (
				IF "%download_insecure%"=="%TRUE%" (
					pip install --no-cache-dir --upgrade --no-deps -q --allow-external %%A --allow-unverified %%A %%A > output.txt 2>NUL
				)
			)
		)
	)
	pip install --no-cache-dir -q %%A >NUL 2>&1
)


	rem Output results of new pip freeze list with upgrades
pip freeze > pip_freeze_results.after

	rem Compare the outputs of each pip freeze
CALL :compare_freezes


	rem Delete created files
DEL /F /Q output.txt 2>NUL
DEL /F /Q pip_freeze_results.before 2>NUL
DEL /F /Q pip_freeze_results.after 2>NUL


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


	rem Compare output of *.before and *.after files to output upgrade successes
:compare_freezes
	FOR /F "tokens=1,2 delims===" %%D IN (pip_freeze_results.after) DO (
		SET found=%FALSE%
		FOR /F "tokens=1,2 delims===" %%F IN (pip_freeze_results.before) DO (
			rem Compare package name
			IF "%%D"=="%%F" (
				SET found=%TRUE%
				rem Compare package version
				IF "%%E" NEQ "%%G" (
					ECHO %%D^(%%G^) -^> upgraded to %%E
				)
			)
		)
		IF "!found!"=="%FALSE%" (
			ECHO %%D -^> installed @ %%E
		)
	)
GOTO :eof