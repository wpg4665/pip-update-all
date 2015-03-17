@ECHO off
	rem Not exactly the fasted script in the world...likely due to network lag

	rem Location of portably installed python and pip
SET python=%cd%\python-3.4.3.amd64
SET pip=%python%\Scripts\pip3.4.exe


	rem Ensure localized working directory
PUSHD %python%


	rem Ensures portable python is used for pip as opposed to locally installed
SET oldpath=%PATH%
SET PATH=%python%\Lib\site-packages\PyQt4;%python%\;%python%\DLLs;%python%\Scripts;%python%\..\tools;%python%\..\tools\mingw32\bin;%python%\..\tools\R\bin\x64;%python%\..\tools\Julia\bin;%oldpath%


	rem Loop through all portably installed packages and update if needed
FOR /F "delims===" %%A IN ('%pip% freeze -l') DO (
	ECHO Checking %%A for updates
	%pip% install --no-cache-dir --upgrade --no-deps %%A > error.txt
	IF %ERRORLEVEL% NEQ 0 (
		ECHO.
		ECHO error.txt
		ECHO.
	)
	%pip% install --no-cache-dir %%A > error.txt
	IF %ERRORLEVEL% NEQ 0 (
		ECHO.
		ECHO error.txt
		ECHO.
	)
)


	rem Delete potentially created error output message
DEL /F /Q error.txt


	rem Restore old path
SET PATH=%oldpath%


	rem Restore initial working directory
POPD