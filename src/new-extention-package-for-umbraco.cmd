@echo off
rem Forwards optional -ProjectsNamespace and all other arguments to new-extention-package-for-umbraco.ps1
powershell -ExecutionPolicy Bypass -File "%~dp0new-extention-package-for-umbraco.ps1" %*
