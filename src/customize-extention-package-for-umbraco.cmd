@echo off
rem Forwards optional -ProjectsNamespace and all other arguments to customize-extention-package-for-umbraco.ps1
powershell -ExecutionPolicy Bypass -File "%~dp0customize-extention-package-for-umbraco.ps1" %*
