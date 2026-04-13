# `add-github-actions.ps1`

Scaffolds GitHub Actions workflow files for an existing generated solution.

## PowerShell

```powershell
.\add-github-actions.ps1 `
  -ProjectsNamespace "TestNewExtension" `
  -WorkingDirectory "C:\code\umbraco-extension-package" `
  -DotNetVersion "10.0.x" `
  -NodeVersion "22" `
  -Force:$true
```

## CMD

```cmd
add-github-actions.cmd ^
  -ProjectsNamespace "TestNewExtension" ^
  -WorkingDirectory "C:\code\umbraco-extension-package" ^
  -DotNetVersion "10.0.x" ^
  -NodeVersion "22" ^
  -Force
```

## Parameters

```text
-ProjectsNamespace      Required. Generated solution folder name
-MetadataFile           Optional. Load parameters from JSON metadata
-WorkingDirectory       Optional. Default: current directory
-DotNetVersion          Optional. Default: "10.0.x"
-NodeVersion            Optional. Default: "22"
-Force                  Optional switch. Overwrite generated workflow files if they already exist
```

## Behavior

The script creates:

- `.\<ProjectsNamespace>\.github\workflows\ci-build.yml`
- `.\<ProjectsNamespace>\.github\workflows\publish-github-packages.yml`

The script also:

- removes `.\<ProjectsNamespace>\.github\workflows\release.yml` if present
- adjusts package project paths
- adjusts test project paths if `.\src\<ProjectsNamespace>.Tests\` exists
- adjusts TestSite project paths if `.\src\<ProjectsNamespace>.TestSite\` exists
- adjusts client paths if `.\src\<ProjectsNamespace>\Client\` exists
