@echo off
rem Forwards optional -ProjectsNamespace, -MetadataFile, and all other arguments to sync-project-to-templates.ps1
powershell -ExecutionPolicy Bypass -File "%~dp0sync-project-to-templates.ps1" %*
