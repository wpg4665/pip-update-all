@ECHO off
rem -----------------------------  INITIALIZATION  ----------------------------
	rem Delayed Expansion needed for ERRORLEVEL within FOR loop
	SETLOCAL EnableDelayedExpansion

	rem Create TRUE / FALSE / EMPTY variables for clearer value testing
	SET TRUE=-1
	SET FALSE=0
	SET EMPTY=%TRUE%

	rem Read in extenal variables from pip_update_all.conf
	rem Replace empty variables with default variables, allows bat to run
	rem without *.conf file
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

	rem Capture enviroment details necessary to derive the *.whl file name for
	rem Christopher Gohlke's website, specifically OS architecture and major.minor Python version
	CALL :determine_env_details

	rem Output results of current pip freeze list, to be used for comparison after upgrades
	pip freeze > pip_freeze_results.before 2>NUL

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


rem ------------------------------  UPDATE PIP  -------------------------------
	rem Perform an innocuous pip command to check for output suggesting that pip
	rem should be upgraded
	pip show 2>NUL | FIND "pip install --upgrade pip" >NUL 2>&1
	IF %ERRORLEVEL%==0 (
		pip install --upgrade pip >NUL 2>&1
	)
rem ------------------------------  UPDATE PIP  -------------------------------


rem ------------------------------  UPDATE LOOP  ------------------------------
	rem Loop through all installed packages and update if needed
	FOR /F "delims===" %%A IN (pip_freeze_results.before) DO (
		ECHO +++ Checking %%A for updates +++

		rem Because these flags require the package name, they can only be added in the FOR loop
		IF "%try_external_and_unverified%"=="%TRUE%" (
			SET pip1=%pip1% --allow-external %%A --allow-unverified %%A
			SET pip2=%pip2% --allow-external %%A --allow-unverified %%A
		)

		pip install !pip1! %%A > output.txt 2>&1

		CALL :check_empty output.txt
		IF !EMPTY!==%FALSE% (
			TYPE output.txt 2>NUL | FIND "use --allow-external" >NUL 2>&1
			IF !ERRORLEVEL!==0 (
				SET change_conf_reminder=%TRUE%
			) ELSE (
				IF "%use_gohlke%"=="%TRUE%" (
					CALL :download_from_gohlke %%A !pip1!
					IF "!updated!"=="%FALSE%" CALL :output_error
				) ELSE (
					CALL :output_error
				)
			)
		)

		pip install !pip2! %%A
	)
rem ------------------------------  UPDATE LOOP  ------------------------------


rem ----------------------------  SCRIPT SHUT DOWN  ---------------------------
	rem Output results of new pip freeze list with upgrades
	pip freeze > pip_freeze_results.after 2>NUL

	rem Compare the outputs of each pip freeze
	CALL :compare_freezes

	IF "%change_conf_reminder%"=="%TRUE%" (
		ECHO.
		CALL :color_text "Yellow" "    You *may* have better luck upgrading by changing your"
		CALL :color_text "Yellow" "    configuration file to try_external_and_unverified=-1"
	)

	rem Delete created files
	DEL /F /Q output.txt 2>NUL
	DEL /F /Q version.txt 2>NUL
	DEL /F /Q search_results.txt 2>NUL
	DEL /F /Q pip_freeze_results.before 2>NUL
	DEL /F /Q pip_freeze_results.after 2>NUL

	rem Restore initial working directory
	POPD

	GOTO :eof
rem ----------------------------  SCRIPT SHUT DOWN  ---------------------------


rem -----------------------------  FUNCTION DEFS  -----------------------------
	rem Read variables from pip_update_all.conf in current directory
	rem If *.conf file doesn't exist, fill variables with defaults
	:import_vars
		PUSHD "%~dp0"
		IF EXIST pip_update_all.conf.local (
			FOR /F "tokens=1,2 delims===" %%A IN ('TYPE pip_update_all.conf.local ^| FIND /V "#"') DO SET %%A=%%B
		) ELSE (
			IF EXIST pip_update_all.conf (
				FOR /F "tokens=1,2 delims===" %%A IN ('TYPE pip_update_all.conf ^| FIND /V "#"') DO SET %%A=%%B
			)
		)
		POPD
		IF "%python%"=="" SET python=C:\Python34
		IF "%try_external_and_unverified%"=="" SET try_external_and_unverified=0
		IF "%use_gohlke%"=="" SET use_gohlke=0
	GOTO :eof

	rem Capture enviroment details necessary to derive the *.whl file name for
	rem Christopher Gohlke's website, specifically OS architecture and major.minor Python version
	:determine_env_details
		rem Determine OS architecture
		REG Query HKLM\Hardware\Description\System\CentralProcessor\0 | FIND /I "x86" >NUL 2>&1
		IF "%ERRORLEVEL%"=="0" (
			SET architecture=32
		) ELSE (
			SET architecture=_amd64
		)

		rem Determine Python major.minor version
		python -V > version.txt 2>&1
		FOR /F "tokens=1,2" %%A IN (version.txt) DO (
			FOR /F "tokens=1,2 delims=." %%C IN ("%%B") DO (
				SET py_version=%%C%%D
			)
		)
	GOTO :eof

	rem Use pip to figure out updated version of package
	rem Compile the required string, and then tell pip to use Christopher Gohlke's
	rem website as the index and attempt to install from there
	rem %1 == Package; %2 == pip command
	:download_from_gohlke
		SET updated=%FALSE%
		pip search %1 > search_results.txt 2>NUL

		SET package_level=
		SET skip_update=
		CALL :parse_pip_search %1 search_results.txt
		rem The function didn't find the latest package version, can't perform an update without it
		IF "%package_level%"=="" (
			CALL :color_text "Yellow" "    Unable to determine latest version, %1 will not be updated"
			GOTO :eof
		)

		IF "%skip_update%"=="%TRUE%" GOTO :eof

	GOTO :eof

	rem Use some `findstr` magic to find the line number of the required package
	rem and parse the next two lines afterward to find if there's a new package
	rem or if it's already the latest
	rem %1 == Package; %2 == `pip search` output
	:parse_pip_search
		rem Find starting line number
		FOR /F "delims=:" %%A IN ('TYPE %2 ^| FINDSTR /B /N /C:"%1 "') DO (
			SET line_number=%%A
		)

		SET /A INSTALLED=%line_number% + 1
		SET /A LATEST=%line_number% + 2

		SET curr_line=1
		FOR /F "tokens=1,2 delims=:" %%A IN (%2) DO (
			IF "!curr_line!"=="%INSTALLED%" (
				ECHO %%B | FINDSTR /C:"(latest)" >NUL 2>&1
				rem ERRORLEVEL == 0 when (latest) exists, and therefore is not necessary to update
				IF !ERRORLEVEL!==0 (
					SET skip_update=%TRUE%
					GOTO :eof
				)
			)

			IF "!curr_line!"=="%LATEST%" (
				SET package_level=%%B
				SET package_level=!package_level: =!
				GOTO :eof
			)

			SET /A curr_line=!curr_line! + 1
		)
	GOTO :eof

	rem Compare output of *.before and *.after files to output upgrade successes
	:compare_freezes
		FOR /F "tokens=1,2 delims===" %%A IN (pip_freeze_results.after) DO (
			SET found=%FALSE%
			FOR /F "tokens=1,2 delims===" %%C IN (pip_freeze_results.before) DO (
				rem Compare package name
				IF "%%A"=="%%C" (
					SET found=%TRUE%
					rem Compare package version
					IF "%%B" NEQ "%%D" (
						ECHO %%A^(%%D^) -^> upgraded to %%B
					)
				)
			)
			IF "!found!"=="%FALSE%" (
				ECHO %%A -^> installed @ %%B
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
		FOR /F tokens^=*^ delims^=^ eol^= %%A IN (output.txt) DO (
			SET file_txt=%%A
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