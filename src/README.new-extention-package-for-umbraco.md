# `new-extention-package-for-umbraco.ps1`

Creates a new Umbraco package starter solution from `Umbraco.Community.Templates.PackageStarter`, then applies the repo's post-processing steps.

## What It Does

- installs or updates required templates with `--force`
- forces template post-actions to run with `--allow-scripts Yes`
- derives a default `ProjectsNamespace` from `SolutionName` when not supplied
- cleans generated `Umbraco.Community.` package naming from selected output files
- updates generated package metadata from derived API values
- aligns generated `Umbraco.Cms*` package references to the installed `Umbraco.Templates` version
- clones `https://github.com/umbraco/Umbraco-CMS-Backoffice-Skills.git` into the generated project under `.agents/skills`
- adds the test project and GitHub workflow files
- applies the repo `Templates` overlay by default
- converts generated C# files to file-scoped namespaces and runs `dotnet format`
- writes `setup-metadata.json`

## PowerShell

```powershell
.\new-extention-package-for-umbraco.ps1 `
  -SolutionName "Umbraco Thing" `
  -ProjectsNamespace "My.Company.UmbracoThing" `
  -SolutionDescription "Umbraco extension package." `
  -GitHubOrganization "hallojoe" `
  -RepositoryName "umbraco-thing" `
  -AuthorName "Casper Korsgaard" `
  -WorkingDirectory "C:\code\umbraco-extension-package" `
  -SkipTemplateInstall:$false `
  -SkipBuild:$false `
  -Force:$true
```

## CMD

```cmd
new-extention-package-for-umbraco.cmd ^
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
-SkipTemplateInstall         Optional switch. Skip template installation/update
-SkipBuild                   Optional switch. Skip solution build
-Force                       Optional switch. Delete and recreate the target folder if it already exists
```

## Output

The script creates:

- `.\<ProjectsNamespace>\`
- `.\<ProjectsNamespace>\.agents\skills\`
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

- The template's own internal post-action may still print restore noise before the script's fix-up steps run.
- `ProjectsNamespace` is the real generated project root and namespace; use it explicitly when you need dotted namespaces.
