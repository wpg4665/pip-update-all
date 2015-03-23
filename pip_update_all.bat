@ECHO off
rem -----------------------------  INITIALIZATION  ----------------------------
	rem Delayed Expansion needed for ERRORLEVEL within FOR loop
	SETLOCAL EnableDelayedExpansion

	rem Create TRUE / FALSE / EMPTY variables for clearer value testing
	SET TRUE=-1
	SET FALSE=0
	SET EMPTY=%TRUE%

	rem Read in extenal variables from pip_update_all.conf
	CALL :import_vars
rem -----------------------------  INITIALIZATION  ----------------------------


rem -----------------------------  SCRIPT SET UP  -----------------------------
	rem Ensure %python% directory exists; exit now if not
	IF NOT EXIST %python% (
		ECHO %python% directory not found
		GOTO :eof
	)

	rem Ensure localized working directory
	PUSHD "%python%"

	rem Ensures portable python is used for pip as opposed to locally installed
	SET PATH=%python%\Scripts;%python%;%PATH%

	rem Output results of current pip freeze list, to be used for comparison after upgrades
	pip freeze > pip_freeze_results.before

	rem Global pip flags to ensure no data is cached, and also to enforce quiet output
	SET pip=--no-cache-dir -q
	rem Set pip flags for "Only if needed" Recursive upgrade as
	rem specified, https://pip.pypa.io/en/latest/user_guide.html#only-if-needed-recursive-upgrade
	SET pip1=--upgrade --no-deps %pip%
	rem The second pip command ensure new dependencies are installed
	SET pip2=%pip%

	rem Variable created for flagging if --allow-external/--allow-unverified would be helpful
	SET change_conf_reminder=%FALSE%
rem -----------------------------  SCRIPT SET UP  -----------------------------


rem ------------------------------  UPDATE LOOP  ------------------------------
	rem Loop through all installed packages and update if needed
	FOR /F "delims===" %%A IN (pip_freeze_results.before) DO (
		ECHO +++ Checking %%A for updates +++

		rem Because these flags require the package name, they can only be added in the FOR loop
		IF "%try_external_and_unverified%"=="%TRUE%" (
			SET pip1=%pip1% --allow-external %%A --allow-unverified %%A
			SET pip2=%pip2% --allow-external %%A --allow-unverified %%A
		)

		pip install !pip1! %%A > output.txt 2>NUL

		CALL :check_empty output.txt
		IF !EMPTY!==%FALSE% (
			TYPE output.txt 2>NUL | FIND "use --allow-external" >NUL 2>&1
			IF !ERRORLEVEL!==0 ( 
				SET change_conf_reminder=%TRUE%
			) ELSE (
				CALL :output_error
			)
		)
		
		pip install !pip2! %%A
	)
rem ------------------------------  UPDATE LOOP  ------------------------------


rem ----------------------------  SCRIPT SHUT DOWN  ---------------------------
	rem Output results of new pip freeze list with upgrades
	pip freeze > pip_freeze_results.after

	rem Compare the outputs of each pip freeze
	CALL :compare_freezes

	IF "%change_conf_reminder%"=="%TRUE%" (
		ECHO.
		CALL :color_text "Yellow" "    You *may* have better luck upgrading by changing your"
		CALL :color_text "Yellow" "    configuration file to try_external_and_unverified=-1"
	)

	rem Delete created files
	DEL /F /Q output.txt 2>NUL
	DEL /F /Q pip_freeze_results.before 2>NUL
	DEL /F /Q pip_freeze_results.after 2>NUL

	rem Restore initial working directory
	POPD

	GOTO :eof
rem ----------------------------  SCRIPT SHUT DOWN  ---------------------------


rem -----------------------------  FUNCTION DEFS  -----------------------------
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


	rem Helper section for checking for empty files
	:check_empty
		IF "%~z1"=="" (
			SET EMPTY=%TRUE%
		) ELSE IF "%~z1"=="0" (
			SET EMPTY=%TRUE%
		) ELSE (
			SET EMPTY=%FALSE%
		)
	GOTO :eof


	rem Somewhat stylized output for errors
	:output_error
		CALL :color_text "Red" "    ERROR:"
		FOR /F tokens^=*^ delims^=^ eol^= %%H IN (output.txt) DO (
			SET file_txt=%%H
			SET file_txt=!file_txt:"=!
			SET file_txt=!file_txt:'=!
			rem " <- Quote here to close from above to fix syntax highlighting
			CALL :color_text "DarkRed" "    !file_txt!"
		)
	GOTO :eof


	rem Helper section for colorized output
	:color_text
		POWERSHELL -Command Write-Host '%2' -foreground '%1'
	GOTO :eof
rem -----------------------------  FUNCTION DEFS  -----------------------------