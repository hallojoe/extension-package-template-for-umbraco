# `pack-dotnet-template.ps1`

Packs a generated sibling dotnet template folder into an installable `.nupkg`.

## PowerShell

```powershell
.\pack-dotnet-template.ps1 `
  -ProjectsNamespace "My.Company.UmbracoThing" `
  -WorkingDirectory "C:\code\umbraco-extension-package" `
  -TemplateIdentity "Casko.ExtensionPackageTemplateForUmbraco" `
  -TemplateShortName "ctumbracoextensionpackage" `
  -PackageId "My.Company.UmbracoThing.Template" `
  -PackageVersion "1.0.0" `
  -Configuration "Release" `
  -RegenerateTemplate:$true `
  -Force:$true
```

## CMD

```cmd
pack-dotnet-template.cmd ^
  -ProjectsNamespace "My.Company.UmbracoThing" ^
  -WorkingDirectory "C:\code\umbraco-extension-package" ^
  -TemplateIdentity "Casko.ExtensionPackageTemplateForUmbraco" ^
  -TemplateShortName "ctumbracoextensionpackage" ^
  -PackageId "My.Company.UmbracoThing.Template" ^
  -PackageVersion "1.0.0" ^
  -Configuration "Release" ^
  -RegenerateTemplate ^
  -Force
```

## Parameters

```text
-ProjectsNamespace      Required. Generated solution folder name
-MetadataFile           Optional. Load parameters from JSON metadata
-WorkingDirectory       Optional. Default: current directory
-TemplateIdentity       Optional. Default: "Casko.ExtensionPackageTemplateForUmbraco"
-TemplateShortName      Optional. Default: "extensionpackagetemplateforumbraco"
-PackageId              Optional. Default: "<ProjectsNamespace>.Template"
-PackageVersion         Optional. Default: "1.0.0"
-Configuration          Optional. Default: "Release"
-OutputDirectory        Optional. Default: `.\<ProjectsNamespace>.Template.Package\bin\<Configuration>`
-RegenerateTemplate     Optional switch. Rebuild the sibling template folder first
-Force                  Optional switch. Recreate the generated template package project if it already exists
```

## Behavior

The script:

- optionally regenerates `.\<ProjectsNamespace>.Template\` by calling `generate-dotnet-template.ps1`
- creates `.\<ProjectsNamespace>.Template.Package\`
- writes an SDK-style template packaging project with `PackageType` set to `Template`
- packs the generated template into an installable `.nupkg`
- reads `setup-metadata.json` and package project metadata to derive package defaults

## Example Install

Install the packed template:

```powershell
dotnet new install .\My.Company.UmbracoThing.Template.Package\bin\Release\My.Company.UmbracoThing.Template.1.0.0.nupkg
```
