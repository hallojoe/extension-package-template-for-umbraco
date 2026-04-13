# `add-umbraco-test-project.ps1`

Scaffolds a `<ProjectsNamespace>.Tests` project for an existing generated solution and adds it to the solution file.

## PowerShell

```powershell
.\add-umbraco-test-project.ps1 `
  -ProjectsNamespace "TestNewExtension" `
  -WorkingDirectory "C:\code\umbraco-extension-package" `
  -Force:$true
```

## CMD

```cmd
add-umbraco-test-project.cmd ^
  -ProjectsNamespace "TestNewExtension" ^
  -WorkingDirectory "C:\code\umbraco-extension-package" ^
  -Force
```

## Parameters

```text
-ProjectsNamespace      Required. Generated solution folder name
-SolutionName           Optional compatibility alias for older usage
-MetadataFile           Optional. Load parameters from JSON metadata
-WorkingDirectory       Optional. Default: current directory
-Force                  Optional switch. Delete and recreate the test project folder if it already exists
```

## Scaffolded Output

The script creates:

- `.\<ProjectsNamespace>\src\<ProjectsNamespace>.Tests\<ProjectsNamespace>.Tests.csproj`
- `.\<ProjectsNamespace>\src\<ProjectsNamespace>.Tests\TestAssemblySetup.cs`
- `.\<ProjectsNamespace>\src\<ProjectsNamespace>.Tests\appsettings.Tests.json`
- `.\<ProjectsNamespace>\src\<ProjectsNamespace>.Tests\appsettings.Tests.Local.json`
- `.\<ProjectsNamespace>\src\<ProjectsNamespace>.Tests\Integration\UmbracoTestServerBase.cs`
- `.\<ProjectsNamespace>\src\<ProjectsNamespace>.Tests\Integration\*IntegrationTests.cs`
- `.\<ProjectsNamespace>\src\<ProjectsNamespace>.Tests\Unit\ExampleUnitTests.cs`

## Behavior

The generated test project:

- references the main package project directly
- uses `NUnit`, `NSubstitute`, `coverlet.msbuild`, and `Umbraco.Cms.Tests.Integration`
- aligns `Umbraco.Cms.Tests.Integration` to the package project's detected Umbraco version
- adds the `.Tests` project to the solution file
- scaffolds integration-test infrastructure for backoffice controller endpoints
- includes a simple passing unit test
