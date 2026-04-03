# `sync-project-to-templates.ps1`

Promotes selected files or folders from a generated project back into `Templates`, reverse-templating known namespace, filename, class-name, and author tokens on the way.

## What It Does

- reads the current project from `.\<ProjectsNamespace>\src\<ProjectsNamespace>\`
- copies selected files into `Templates/src/__TEMPLATE_PROJECTS_NAMESPACE__/`
- reverse-templates known values such as:
  - `__TEMPLATE_PROJECTS_NAMESPACE__`
  - `__TEMPLATE_NAMESPACE_COMPACT__`
  - `__TEMPLATE_NAMESPACE_COMPACT_LOWER__`
  - `__TEMPLATE_NAMESPACE_KEBAB__`
  - `__TEMPLATE_NAMESPACE_DISPLAY_NAME__`
  - `__TEMPLATE_SERVICE_NAME__`
  - author/org/email tokens
- supports promoting single files or whole folders
- supports preview mode

## PowerShell

```powershell
.\sync-project-to-templates.ps1 `
  -ProjectsNamespace "My.Company.UmbracoThing" `
  -Include "Client\src\context" `
  -Include "Composers\MyCompanyUmbracoThingApiComposer.cs" `
  -WorkingDirectory "C:\code\umbraco-extension-package" `
  -Force:$true
```

## CMD

```cmd
sync-project-to-templates.cmd ^
  -ProjectsNamespace "My.Company.UmbracoThing" ^
  -Include "Client\src\context" ^
  -Include "Composers\MyCompanyUmbracoThingApiComposer.cs" ^
  -WorkingDirectory "C:\code\umbraco-extension-package" ^
  -Force
```

## Parameters

```text
-ProjectsNamespace           Required. Generated project namespace/folder name
-Include                     Required. One or more files or folders to promote
-MetadataFile                Optional. Load parameters from JSON metadata
-WorkingDirectory            Optional. Default: current directory
-AuthorName                  Optional. Used for reverse-templating author tokens
-AuthorOrganizationName      Optional. Used for reverse-templating author tokens
-AuthorOrganizationUrl       Optional. Used for reverse-templating author tokens
-AuthorEmail                 Optional. Used for reverse-templating author tokens
-TemplateDirectory           Optional. Default: .\Templates
-Preview                     Optional switch. Show planned promotions without writing files
-Force                       Optional switch. Overwrite existing template files
```

## Notes

- This first version is intentionally scoped to the scaffold template tree under `Templates/src/__TEMPLATE_PROJECTS_NAMESPACE__/`.
- It currently supports text files only.
- Relative `-Include` paths are resolved against the generated project source directory first, then the solution directory.
