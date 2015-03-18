# pip-update-all
A Windows Batch script for updating all installed python packages via pip

## pip_update_all.conf

+ python
> The path that contains a python install; usually C:\PythonXX (the X's indicate the version)  
> Never use quotes; No trailing slash; C:\Python34 (default)

+ pip
> The path that contains the pip executable; usually C:\PythonXX\Scripts\pipX.X.exe (the X's indicate the version)  
> Never use quotes; C:\Python34\Scripts\pip3.4.exe (default)

+ download_external
> This flag indicates whether or not pip should use --allow-external; might be required for some packages  
> 0 for false (default), -1 for true

+ download_insecure
> This flag indicates whether or not pip should use --allow-unverified; might be required for some packages  
> Typically, if --allow-external is needed, --allow unverified is also needed, thus if `download_external` is `-1` then `download_insecure` should also be `-1` for best results  
> 0 for false (default), -1 for true  

+ use_gohlke
> This flag indicates whether or not to search Christopher Gohlke's "Unofficial Windows Binaries for Python Extension Packages"  
> This may be necessary for some packages that need to be compiled. It will only work if the package is available there, and the package will only be downloaded and installed if a usual pip download/install fails  
> http://www.lfd.uci.edu/~gohlke/pythonlibs/  
> 0 for false (default), -1 for true
