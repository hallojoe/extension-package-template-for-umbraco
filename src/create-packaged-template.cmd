@echo off
rem Forwards optional -ProjectsNamespace and all other arguments to create-packaged-template.ps1
powershell -ExecutionPolicy Bypass -File "%~dp0create-packaged-template.ps1" %*
