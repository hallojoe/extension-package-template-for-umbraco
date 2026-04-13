# Agent Notes

This folder holds repo-specific guidance for coding agents working in this workspace.

## What This Repository Does

This repository is the source template workspace for Umbraco extension package starter solutions.

The main maintenance loop is:

1. Create a site from the starter scripts.
2. Make changes in the generated site.
3. Sync the useful changes back into `src/Templates`.

## How To Work In This Repo

When making changes here:

- treat `src` as the real working area
- keep the top-level `README.md` aligned with the script-based workflow
- prefer updating the matching script docs in `src/*.md` when script behavior changes
- preserve the generated-template flow instead of hard-coding project-specific assumptions

## Important Paths

- `README.md`: overview of the workspace and maintenance workflow
- `src/new-extention-package-for-umbraco.ps1`: creates a new starter solution
- `src/new-extention-package-for-umbraco.md`: doc for the starter solution flow
- `src/sync-project-to-templates.ps1`: promotes generated project changes back into `src/Templates`
- `src/sync-project-to-templates.md`: doc for syncing generated project changes back into the template
- `src/create-packaged-template.ps1`: builds a packed template artifact from the maintained template
- `src/create-packaged-template.md`: doc for the packaged-template workflow
- `src/Templates/`: the source-of-truth template content that future generated projects inherit
- `.github/workflows/`: release and publishing automation

## Agent Workflow

Before editing:

- read the top-level `README.md`
- inspect the relevant script doc under `src/*.md`
- check whether the change belongs in scripts, docs, workflow automation, or `src/Templates`

When changing behavior:

- update the script first
- update the matching `src/<script>.md` file if behavior or parameters changed
- update the top-level `README.md` if the repo workflow changed

When maintaining the template:

- make the improvement in a generated project first when that is the clearest way to validate it
- use `src/sync-project-to-templates.ps1` to bring those changes back into `src/Templates`
- avoid editing generated output and template source inconsistently

## Conventions

- prefer PowerShell examples because the repo is script-first
- keep docs short and task-oriented
- use the repo's existing wording: create site, make changes, sync changes
- do not remove compatibility wrapper behavior unless the task explicitly requires it
