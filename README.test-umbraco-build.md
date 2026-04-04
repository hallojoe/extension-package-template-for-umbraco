# `test-umbraco-build.ps1`

Builds an existing generated solution and packs the main package project.

## PowerShell

```powershell
.\test-umbraco-build.ps1 `
  -ProjectsNamespace "TestNewExtension" `
  -WorkingDirectory "C:\code\umbraco-extension-package" `
  -Configuration "Release"
```

## CMD

```cmd
test-umbraco-build.cmd ^
  -ProjectsNamespace "TestNewExtension" ^
  -WorkingDirectory "C:\code\umbraco-extension-package" ^
  -Configuration "Release"
```

## Parameters

```text
-ProjectsNamespace      Required. Generated solution folder name
-MetadataFile           Optional. Load parameters from JSON metadata
-WorkingDirectory       Optional. Default: current directory
-Configuration          Optional. Default: "Release"
```

## Behavior

The script resolves:

- solution file: `.\<ProjectsNamespace>\src\<ProjectsNamespace>.slnx`
- package project: `.\<ProjectsNamespace>\src\<ProjectsNamespace>\<ProjectsNamespace>.csproj`

It then runs:

- `dotnet build`
- `dotnet pack --no-build`
