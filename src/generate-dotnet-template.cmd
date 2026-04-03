@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0generate-dotnet-template.ps1" %*
