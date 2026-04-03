# `create-packaged-template.ps1`

Runs the full packaged-template workflow: scaffold a package solution, generate a sibling dotnet template folder, and pack that template into an installable `.nupkg`.

## PowerShell

```powershell
.\create-packaged-template.ps1 `
  -SolutionName "Umbraco Thing" `
  -ProjectsNamespace "My.Company.UmbracoThing" `
  -SolutionDescription "Umbraco extension package." `
  -GitHubOrganization "hallojoe" `
  -RepositoryName "umbraco-thing" `
  -AuthorName "Casper Korsgaard" `
  -WorkingDirectory "C:\code\umbraco-extension-package" `
  -TemplateIdentity "Casko.ExtensionPackageTemplateForUmbraco" `
  -TemplateShortName "ctumbracoextensionpackage" `
  -PackageId "My.Company.UmbracoThing.Template" `
  -PackageVersion "1.0.0" `
  -Configuration "Release" `
  -Force:$true
```

## CMD

```cmd
create-packaged-template.cmd ^
  -SolutionName "Umbraco Thing" ^
  -ProjectsNamespace "My.Company.UmbracoThing" ^
  -SolutionDescription "Umbraco extension package." ^
  -GitHubOrganization "hallojoe" ^
  -RepositoryName "umbraco-thing" ^
  -AuthorName "Casper Korsgaard" ^
  -WorkingDirectory "C:\code\umbraco-extension-package" ^
  -TemplateIdentity "Casko.ExtensionPackageTemplateForUmbraco" ^
  -TemplateShortName "ctumbracoextensionpackage" ^
  -PackageId "My.Company.UmbracoThing.Template" ^
  -PackageVersion "1.0.0" ^
  -Configuration "Release" ^
  -Force
```

## Parameters

```text
-SolutionName           Required. Friendly solution name used for derived naming and setup.
-ProjectsNamespace      Optional. Exact namespace/folder name. Default: PascalCase of SolutionName
-SolutionDescription    Optional. Default: "Extension package template for Umbraco."
-GitHubOrganization     Optional. Default: "hallojoe"
-RepositoryName         Optional. Default: kebab-case of SolutionName
-AuthorName             Optional. Default: "Casper Korsgaard"
-MetadataFile           Optional. Load parameters from JSON metadata
-WorkingDirectory       Optional. Default: current directory
-TemplateIdentity       Optional. Default: "Casko.ExtensionPackageTemplateForUmbraco"
-TemplateShortName      Optional. Default: "extensionpackagetemplateforumbraco"
-PackageId              Optional. Default: "<ProjectsNamespace>.Template"
-PackageVersion         Optional. Default: "1.0.0"
-Configuration          Optional. Default: "Release"
-OutputDirectory        Optional. Default: generated template package `bin\<Configuration>` folder
-SkipTemplateInstall    Optional switch. Skip template installation/update during setup
-SkipBuild              Optional switch. Skip solution build during setup
-Force                  Optional switch. Recreate generated solution, template folder, and template package project if they already exist
```

## Behavior

The script runs these steps in order:

- `new-extention-package-for-umbraco.ps1`
- `generate-dotnet-template.ps1`
- `pack-dotnet-template.ps1`

It forwards an explicit `ProjectsNamespace` when provided. Otherwise it derives the namespace as `PascalCase(SolutionName)`.

## CI Example

For GitHub Actions, prefer `windows-latest` for the full packaged-template flow.

```yaml
name: Build Template Package

on:
  workflow_dispatch:
  push:
    branches:
      - main

jobs:
  build-template:
    runs-on: windows-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v5

      - name: Setup .NET
        uses: actions/setup-dotnet@v5
        with:
          dotnet-version: 10.0.x

      - name: Setup Node.js
        uses: actions/setup-node@v6
        with:
          node-version: 22

      - name: Run packaged template flow
        shell: pwsh
        run: |
          ./create-packaged-template.ps1 `
            -SolutionName "Umbraco Package Solution" `
            -WorkingDirectory "${{ github.workspace }}" `
            -Force
```
