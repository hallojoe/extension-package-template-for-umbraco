# `new-extention-package-for-umbraco.ps1`

Creates a new Umbraco package starter solution from `Umbraco.Community.Templates.PackageStarter`, then applies the repo's post-processing steps.

## What It Does

- runs `scaffold-extention-package-for-umbraco.ps1` for the initial starter creation and project wiring
- runs `customize-extention-package-for-umbraco.ps1` for repo-specific mutations and post-processing
- keeps the end-to-end setup flow available as a single command

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

## Notes

- `ProjectsNamespace` is the real generated project root and namespace; use it explicitly when you need dotted namespaces.
- The workflow is now split across scaffold, customize, and shared helper scripts, but this remains the main entry point.
