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

- [Script Docs](src/README.md)
- [new-extention-package-for-umbraco.ps1](src/new-extention-package-for-umbraco.ps1)
- [sync-project-to-templates.ps1](src/sync-project-to-templates.ps1)
- [create-packaged-template.ps1](src/create-packaged-template.ps1)
- [generate-dotnet-template.ps1](src/generate-dotnet-template.ps1)
- [pack-dotnet-template.ps1](src/pack-dotnet-template.ps1)

Root-level wrapper scripts are kept for compatibility and forward into `src`.
