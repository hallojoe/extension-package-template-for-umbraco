# `generate-dotnet-template.ps1`

Converts a generated solution into a sanitized sibling dotnet template folder.

## PowerShell

```powershell
.\generate-dotnet-template.ps1 `
  -ProjectsNamespace "My.Company.UmbracoThing" `
  -WorkingDirectory "C:\code\umbraco-extension-package" `
  -TemplateIdentity "Casko.ExtensionPackageTemplateForUmbraco" `
  -TemplateShortName "ctumbracoextensionpackage" `
  -Force:$true
```

## CMD

```cmd
generate-dotnet-template.cmd ^
  -ProjectsNamespace "My.Company.UmbracoThing" ^
  -WorkingDirectory "C:\code\umbraco-extension-package" ^
  -TemplateIdentity "Casko.ExtensionPackageTemplateForUmbraco" ^
  -TemplateShortName "ctumbracoextensionpackage" ^
  -Force
```

## Parameters

```text
-ProjectsNamespace      Required. Generated solution folder name
-MetadataFile           Optional. Load parameters from JSON metadata
-WorkingDirectory       Optional. Default: current directory
-TemplateIdentity       Optional. Default: "Casko.ExtensionPackageTemplateForUmbraco"
-TemplateShortName      Optional. Default: "extensionpackagetemplateforumbraco"
-Force                  Optional switch. Delete and recreate the sibling template output folder if it already exists
```

## Behavior

The script expects:

- `.\<ProjectsNamespace>\`
- `.\<ProjectsNamespace>\setup-metadata.json`
- `.\<ProjectsNamespace>\src\<ProjectsNamespace>\<ProjectsNamespace>.csproj`

It creates:

- `.\<ProjectsNamespace>.Template\`
- `.\<ProjectsNamespace>.Template\.template.config\template.json`

The generated template:

- uses `setup-metadata.json` defaults for friendly metadata values
- detects author metadata from the package project and setup metadata
- tokenizes file contents and filenames for namespace, controller, route, manifest, and author replacements
- preserves explicit `__TEMPLATE_*__` placeholders already present in the repo `Templates` overlay
- excludes generated artifacts like `bin`, `obj`, `node_modules`, `.git`, `.vs`, package output, logs, and generated `App_Plugins` assets

## Example Install And Use

Install the generated local template:

```powershell
dotnet new install .\My.Company.UmbracoThing.Template
```

Create a new solution from the template:

```powershell
dotnet new ctumbracoextensionpackage `
  -n "My.Company.TemplateSmoke" `
  --SolutionName "Template Smoke" `
  --SolutionDescription "Template smoke description." `
  --GitHubOrganization "hallojoe" `
  --RepositoryName "template-smoke" `
  --AuthorName "Casper Korsgaard" `
  -o ".\TemplateSmoke.Output"
```
