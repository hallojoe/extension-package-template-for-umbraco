@echo off
rem Forwards optional -ProjectsNamespace and all other arguments to scaffold-extention-package-for-umbraco.ps1
powershell -ExecutionPolicy Bypass -File "%~dp0scaffold-extention-package-for-umbraco.ps1" %*
