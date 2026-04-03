# `test-umbraco-client-build.ps1`

Builds the generated client against a running generated TestSite.

## PowerShell

```powershell
.\test-umbraco-client-build.ps1 `
  -ProjectsNamespace "TestNewExtension" `
  -WorkingDirectory "C:\code\umbraco-extension-package" `
  -Configuration "Debug" `
  -LaunchProfile "Umbraco.Web.UI" `
  -StartupTimeoutSeconds 60 `
  -PollIntervalSeconds 2
```

## CMD

```cmd
test-umbraco-client-build.cmd ^
  -ProjectsNamespace "TestNewExtension" ^
  -WorkingDirectory "C:\code\umbraco-extension-package" ^
  -Configuration "Debug" ^
  -LaunchProfile "Umbraco.Web.UI" ^
  -StartupTimeoutSeconds 60 ^
  -PollIntervalSeconds 2
```

## Parameters

```text
-ProjectsNamespace      Required. Generated solution folder name
-SolutionName           Optional compatibility alias for older usage
-MetadataFile           Optional. Load parameters from JSON metadata
-WorkingDirectory       Optional. Default: current directory
-Configuration          Optional. Default: "Debug"
-LaunchProfile          Optional. Default: first Project launch profile from TestSite launchSettings.json
-StartupTimeoutSeconds  Optional. Default: 300
-PollIntervalSeconds    Optional. Default: 5
```

## Behavior

The script resolves:

- client folder: `.\<ProjectsNamespace>\src\<ProjectsNamespace>\Client`
- TestSite project: `.\<ProjectsNamespace>\src\<ProjectsNamespace>.TestSite\<ProjectsNamespace>.TestSite.csproj`
- launch profile from `Properties\launchSettings.json`
- Swagger URL from `Client\package.json`

It then runs:

- `npm install`
- `dotnet build` for the TestSite project
- `dotnet run --launch-profile <profile> --no-build` from the TestSite folder
- waits for TestSite stdout to include `Now listening on:` or `Application started.`
- `npm run generate-client`
- `npm run build`

## Notes

- Readiness is log-based, not HTTP-poll based.
- The script starts `dotnet run` from the TestSite folder, not from the package project folder.
- `generate-openapi.js` allows local self-signed HTTPS by setting `NODE_TLS_REJECT_UNAUTHORIZED=0`.
