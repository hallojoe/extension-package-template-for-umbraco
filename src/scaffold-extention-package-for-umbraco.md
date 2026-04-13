# `scaffold-extention-package-for-umbraco.ps1`

Creates the initial Umbraco package starter solution and writes scaffold metadata, without applying the repo's later customization steps.

## What It Does

- installs or updates required templates with `--force`
- derives a default `ProjectsNamespace` from `SolutionName` when not supplied
- creates the starter solution with `umbracopackagestarter`
- runs the replacement setup flow directly instead of relying on the template's blocked `setup.cmd`
- initializes git and adds the default origin remote
- creates the package project with `umbraco-extension`
- renames `_nuget.csproj` to the final package project file
- removes `Version` attributes from `Umbraco.Cms*` references when central package management is enabled
- adds the package project to the solution and the test site reference to the package project
- removes generated `setup.cmd` and `setup.sh`
- writes `setup-metadata.json`

## PowerShell

```powershell
.\scaffold-extention-package-for-umbraco.ps1 `
  -SolutionName "Umbraco Thing" `
  -ProjectsNamespace "My.Company.UmbracoThing" `
  -SolutionDescription "Umbraco extension package." `
  -GitHubOrganization "hallojoe" `
  -RepositoryName "umbraco-thing" `
  -AuthorName "Casper Korsgaard" `
  -WorkingDirectory "C:\code\umbraco-extension-package" `
  -SkipTemplateInstall:$false `
  -Force:$true
```

## CMD

```cmd
scaffold-extention-package-for-umbraco.cmd ^
  -SolutionName "Umbraco Thing" ^
  -ProjectsNamespace "My.Company.UmbracoThing" ^
  -SolutionDescription "Umbraco extension package." ^
  -GitHubOrganization "hallojoe" ^
  -RepositoryName "umbraco-thing" ^
  -AuthorName "Casper Korsgaard" ^
  -WorkingDirectory "C:\code\umbraco-extension-package" ^
  -Force
```

## Parameters

```text
-SolutionName            Required. Friendly solution name used for derived naming.
-ProjectsNamespace       Optional. Exact namespace/folder name. Default: PascalCase of SolutionName
-SolutionDescription     Optional. Default: "Extension package template for Umbraco."
-GitHubOrganization      Optional. Default: "hallojoe"
-RepositoryName          Optional. Default: kebab-case of SolutionName
-AuthorName              Optional. Default: "Casper Korsgaard"
-AuthorOrganizationName  Optional. Stored in scaffold metadata
-AuthorOrganizationUrl   Optional. Stored in scaffold metadata
-AuthorEmail             Optional. Stored in scaffold metadata
-MetadataFile            Optional. Load parameters from JSON metadata
-WorkingDirectory        Optional. Default: current directory
-SkipTemplateInstall     Optional switch. Skip template installation/update
-Force                   Optional switch. Delete and recreate the target folder if it already exists
```

## Output

The script creates:

- `.\<ProjectsNamespace>\`
- `.\<ProjectsNamespace>\setup-metadata.json`

The metadata file includes:

- `solutionName`
- `solutionDescription`
- `projectsNamespace`
- `gitHubOrganization`
- `repositoryName`
- `authorName`
- `authorOrganizationName`
- `authorOrganizationUrl`
- `authorEmail`
- `apiName`
- `apiGroup`
- `apiDescription`
- `apiOrganizationName`
- `apiOrganizationUrl`
- `apiContactEmail`
- `umbracoTemplateVersion`
- `targetDirectory`

## Notes

- This is the first phase of the full `new-extention-package-for-umbraco.ps1` workflow.
- Use `customize-extention-package-for-umbraco.ps1` after scaffolding when you want the repo's post-processing steps applied.
