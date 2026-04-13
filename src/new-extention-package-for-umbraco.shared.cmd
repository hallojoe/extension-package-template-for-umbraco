@echo off
rem Forwards all arguments to new-extention-package-for-umbraco.shared.ps1
powershell -ExecutionPolicy Bypass -File "%~dp0new-extention-package-for-umbraco.shared.ps1" %*
