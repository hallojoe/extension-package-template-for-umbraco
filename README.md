# Umbraco Extension Package Template Workspace

This repository contains the scripts, docs, and template files used to create and maintain an Umbraco extension package starter solution.

In practice, it gives you a repeatable workflow for:

- creating a new Umbraco package site from the starter template
- evolving that generated site until the structure and code are where you want them
- syncing the useful changes back into this repository's `Templates` folder so future generated sites include them

The working scripts and detailed docs live under [`src`](src).

## Maintenance Workflow

Use this repository as the source of truth for the starter template, and maintain it with this loop:

1. Create a site with [`src/new-extention-package-for-umbraco.ps1`](src/new-extention-package-for-umbraco.ps1).
2. Make changes in the generated site until the template behavior is improved.
3. Sync those changes back into the template with [`src/sync-project-to-templates.ps1`](src/sync-project-to-templates.ps1).

## Key Scripts

- [Script Docs](README.md)
- [new-extention-package-for-umbraco.ps1](src/new-extention-package-for-umbraco.ps1)
- [sync-project-to-templates.ps1](src/sync-project-to-templates.ps1)
- [create-packaged-template.ps1](src/create-packaged-template.ps1)
- [generate-dotnet-template.ps1](src/generate-dotnet-template.ps1)
- [pack-dotnet-template.ps1](src/pack-dotnet-template.ps1)

Root-level wrapper scripts are kept for compatibility and forward into `src`.


## Umbraco Package Setup Agent

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
