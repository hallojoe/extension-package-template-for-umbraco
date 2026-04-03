@echo off
rem Prefer -ProjectsNamespace; -SolutionName is kept as a compatibility alias
powershell -ExecutionPolicy Bypass -File "%~dp0test-umbraco-client-build.ps1" %*
