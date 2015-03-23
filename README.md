# pip-update-all
A Windows Batch script for updating all installed python packages via pip. The idea for this came from playing with WinPython as a portable deploy in an enterprise environment. WinPython didn't have a good method for updating packages, and it came installed with so many, that doing this by hand would've been painful.

Now, I can use my script to run this auto-updater as a scheduled task, and always be ensured to be running the most up to date packages.

This script was tested against a locally installed Python install 3.4.1, portably and locally installed WinPython 3.3.5, and a portably and network installed WinPython 3.4.3

## pip_update_all.conf

+ python
> The path that contains a python install; usually C:\PythonXX (the X's indicate the version)  
> Never use quotes; No trailing slash; C:\Python34 (default)

+ try_external_and_unverified
> This variable indicates whether or not pip should use --allow-external [package] --allow-unverified [package]  
> These flags might be required for some packages; and because of how often they need to go together, they've been combined into one variable  
> 0 for false (default), -1 for true  

+ use_gohlke
> This flag indicates whether or not to search Christopher Gohlke's "Unofficial Windows Binaries for Python Extension Packages"  
> This may be necessary for some packages that need to be compiled. It will only work if the package is available there, and the package will only be downloaded and installed if a usual pip download/install fails  
> http://www.lfd.uci.edu/~gohlke/pythonlibs/  
> 0 for false (default), -1 for true
