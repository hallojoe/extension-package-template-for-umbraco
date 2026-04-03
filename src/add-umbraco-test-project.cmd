@echo off
rem Prefer -ProjectsNamespace; -SolutionName is kept as a compatibility alias
powershell -ExecutionPolicy Bypass -File "%~dp0add-umbraco-test-project.ps1" %*
