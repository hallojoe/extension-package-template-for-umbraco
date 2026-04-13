# `new-extention-package-for-umbraco.shared.ps1`

Internal helper script for the `new-extention-package-for-umbraco.ps1` workflow and its scaffold/customize sub-scripts.

## What It Contains

- naming helpers for namespace and kebab-case generation
- template installation and command invocation helpers
- file update helpers for UTF-8 writes and text transforms
- formatting helpers for file-scoped namespaces and `.editorconfig`
- central package management detection
- helper logic for copying Umbraco backoffice skills

## PowerShell

```powershell
.\new-extention-package-for-umbraco.shared.ps1
```

## CMD

```cmd
new-extention-package-for-umbraco.shared.cmd
```

## Parameters

```text
No parameters. This script defines shared functions and is intended to be dot-sourced by other scripts.
```

## Notes

- This script is not intended to be the main entry point for the setup workflow.
- Use `new-extention-package-for-umbraco.ps1`, `scaffold-extention-package-for-umbraco.ps1`, or `customize-extention-package-for-umbraco.ps1` for direct execution.
