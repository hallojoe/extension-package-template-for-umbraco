# Umbraco Package Setup Agent

This workspace contains helper scripts for scaffolding, validating, templating, and packaging Umbraco package solutions.

Each PowerShell script also has a matching `.cmd` wrapper.

## Script Docs

- [`new-extention-package-for-umbraco.ps1`](README.new-extention-package-for-umbraco.md)
- [`create-packaged-template.ps1`](README.create-packaged-template.md)
- [`test-umbraco-build.ps1`](README.test-umbraco-build.md)
- [`add-umbraco-test-project.ps1`](README.add-umbraco-test-project.md)
- [`add-github-actions.ps1`](README.add-github-actions.md)
- [`test-umbraco-client-build.ps1`](README.test-umbraco-client-build.md)
- [`generate-dotnet-template.ps1`](README.generate-dotnet-template.md)
- [`pack-dotnet-template.ps1`](README.pack-dotnet-template.md)
- [`sync-project-to-templates.ps1`](README.sync-project-to-templates.md)

## Shared Notes

### Naming Rules

- `Pascal(input)` => trimmed `PascalCase`
- `Kebab(input)` => trimmed `kebab-case`

Given:

- `SolutionName`: `Umbraco Thing`
- `SolutionDescription`: `Umbraco extension package.`
- `GitHubOrganization`: `hallojoe`

The scaffold flow derives:

- `ProjectsNamespace`: `UmbracoThing`
- `RepositoryName`: `umbraco-thing`
- `ApiName`: `umbraco-thing-api`
- `ApiGroup`: `Umbraco Thing`
- `ApiDescription`: `Umbraco extension package.`

### Metadata File Support

Most scripts support `-MetadataFile` and can read values from `setup-metadata.json`.

Precedence is:

- explicit CLI argument
- explicit `-MetadataFile`
- project-local `setup-metadata.json` in the current/working directory
- repo-root `setup-metadata.json`
- script default

### Prerequisites

- PowerShell or CMD
- `.NET 10 SDK`
- Network access for template installation and NuGet restore

The scaffold script validates that a `.NET 10` SDK is installed before scaffolding.
