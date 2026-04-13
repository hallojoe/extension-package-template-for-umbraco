# `customize-extention-package-for-umbraco.ps1`

Applies the repo's post-processing steps to a scaffolded Umbraco package starter solution.

## What It Does

- reads scaffold defaults from `setup-metadata.json`
- cleans generated `Umbraco.Community.` package naming from selected output files
- updates generated package metadata from derived API values
- aligns generated `Umbraco.Cms*` package references to the stored `Umbraco.Templates` version
- optionally builds the scaffolded solution
- clones `https://github.com/umbraco/Umbraco-CMS-Backoffice-Skills.git` into the generated project under `.agents/skills`
- adds the test project and GitHub workflow files
- applies the repo `Templates` overlay by default
- converts generated C# files to file-scoped namespaces and runs `dotnet format`

## PowerShell

```powershell
.\customize-extention-package-for-umbraco.ps1 `
  -ProjectsNamespace "My.Company.UmbracoThing" `
  -SolutionName "Umbraco Thing" `
  -SolutionDescription "Umbraco extension package." `
  -GitHubOrganization "hallojoe" `
  -RepositoryName "umbraco-thing" `
  -AuthorName "Casper Korsgaard" `
  -WorkingDirectory "C:\code\umbraco-extension-package" `
  -SkipBuild:$false `
  -RunDotNetFormat:$true `
  -IncludeClientCodeBlueprint:$true
```

## CMD

```cmd
customize-extention-package-for-umbraco.cmd ^
  -ProjectsNamespace "My.Company.UmbracoThing" ^
  -SolutionName "Umbraco Thing" ^
  -SolutionDescription "Umbraco extension package." ^
  -GitHubOrganization "hallojoe" ^
  -RepositoryName "umbraco-thing" ^
  -AuthorName "Casper Korsgaard" ^
  -WorkingDirectory "C:\code\umbraco-extension-package"
```

## Parameters

```text
-SolutionName                Required. Friendly solution name used for derived naming.
-ProjectsNamespace           Optional. Exact namespace/folder name. Default: PascalCase of SolutionName
-SolutionDescription         Optional. Default: "Extension package template for Umbraco."
-GitHubOrganization          Optional. Default: "hallojoe"
-RepositoryName              Optional. Default: kebab-case of SolutionName
-AuthorName                  Optional. Default: "Casper Korsgaard"
-AuthorOrganizationName      Optional. Used for template token replacement and metadata
-AuthorOrganizationUrl       Optional. Used for template token replacement and metadata
-AuthorEmail                 Optional. Used for template token replacement and metadata
-MetadataFile                Optional. Load parameters from JSON metadata
-WorkingDirectory            Optional. Default: current directory
-IncludeClientCodeBlueprint  Optional switch. Default: true
-RunDotNetFormat             Optional switch. Default: true
-SkipBuild                   Optional switch. Skip solution build
```

## Behavior

The script expects:

- `.\<ProjectsNamespace>\`
- `.\<ProjectsNamespace>\setup-metadata.json`
- `.\<ProjectsNamespace>\src\<ProjectsNamespace>\<ProjectsNamespace>.csproj`

It updates:

- selected readme and project metadata files
- project package reference versions
- the generated solution by adding tests, workflows, copied skills, and optional client blueprint content

## Notes

- This is the second phase of the full `new-extention-package-for-umbraco.ps1` workflow.
- Scaffold first with `scaffold-extention-package-for-umbraco.ps1` or the full orchestrator script.
