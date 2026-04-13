function Get-TrimmedValue {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value
    )

    return $Value.Trim()
}

function Get-JsonFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return Get-Content -Path $Path -Raw | ConvertFrom-Json
}

function ConvertTo-WordTokens {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputValue
    )

    $trimmed = Get-TrimmedValue -Value $InputValue
    if ([string]::IsNullOrWhiteSpace($trimmed)) {
        return @()
    }

    $normalized = $trimmed `
        -creplace '([a-z0-9])([A-Z])', '$1 $2' `
        -replace '[^A-Za-z0-9]+', ' '

    return @(
        $normalized.Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries) |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ }
    )
}

function ConvertTo-PascalCase {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputValue
    )

    $tokens = ConvertTo-WordTokens -InputValue $InputValue
    if ($tokens.Count -eq 0) {
        throw "Input must contain at least one letter or digit."
    }

    $parts = foreach ($token in $tokens) {
        if ($token.Length -eq 1) {
            $token.ToUpperInvariant()
        }
        else {
            $token.Substring(0, 1).ToUpperInvariant() + $token.Substring(1).ToLowerInvariant()
        }
    }

    return [string]::Concat($parts)
}

function ConvertTo-KebabCase {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputValue
    )

    $tokens = ConvertTo-WordTokens -InputValue $InputValue
    if ($tokens.Count -eq 0) {
        throw "Input must contain at least one letter or digit."
    }

    $parts = foreach ($token in $tokens) {
        $token.ToLowerInvariant()
    }

    return [string]::Join('-', $parts)
}

function Get-ProjectsNamespace {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SolutionName,

        [AllowEmptyString()]
        [string]$ProjectsNamespace
    )

    if (-not [string]::IsNullOrWhiteSpace($ProjectsNamespace)) {
        return $ProjectsNamespace.Trim()
    }

    return ConvertTo-PascalCase -InputValue $SolutionName
}

function Assert-DotNet10SdkInstalled {
    $sdks = & dotnet --list-sdks
    if (-not ($sdks | Where-Object { $_ -match '^10\.' })) {
        throw "The .NET 10 SDK is required but was not found in 'dotnet --list-sdks'."
    }
}

function Install-TemplatePackage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageId
    )

    Write-Host "Installing/updating template package: $PackageId"
    & dotnet new install $PackageId --force
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install template package '$PackageId'."
    }
}

function Get-InstalledTemplatePackageVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageId
    )

    $installedPackagesOutput = & dotnet new uninstall
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to inspect installed template packages."
    }

    $lines = @($installedPackagesOutput -split '\r?\n')
    for ($index = 0; $index -lt $lines.Count; $index++) {
        if ($lines[$index].Trim() -ne $PackageId) {
            continue
        }

        for ($innerIndex = $index + 1; $innerIndex -lt $lines.Count; $innerIndex++) {
            $trimmedLine = $lines[$innerIndex].Trim()
            if ($trimmedLine -match '^Version:\s*([0-9A-Za-z\.\-\+]+)$') {
                return $matches[1]
            }

            if (-not [string]::IsNullOrWhiteSpace($trimmedLine) -and -not $lines[$innerIndex].StartsWith(' ')) {
                break
            }
        }
    }

    throw "Could not determine installed version for template package '$PackageId'."
}

function Invoke-RequiredCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [string[]]$ArgumentList,

        [Parameter(Mandatory = $true)]
        [string]$WorkingPath
    )

    Push-Location $WorkingPath
    try {
        Write-Host "> $FilePath $($ArgumentList -join ' ')"
        & $FilePath @ArgumentList
        if ($LASTEXITCODE -ne 0) {
            throw "Command failed with exit code $LASTEXITCODE."
        }
    }
    finally {
        Pop-Location
    }
}

function ConvertTo-ProcessArgumentString {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$ArgumentList
    )

    return ($ArgumentList | ForEach-Object {
        if ($_ -match '\s' -or $_ -match '"') {
            '"' + ($_ -replace '"', '\"') + '"'
        }
        else {
            $_
        }
    }) -join ' '
}

function Get-PowerShellExecutable {
    $pwshCommand = Get-Command -Name "pwsh" -ErrorAction SilentlyContinue
    if ($null -ne $pwshCommand) {
        return $pwshCommand.Source
    }

    $windowsPowerShellCommand = Get-Command -Name "powershell" -ErrorAction SilentlyContinue
    if ($null -ne $windowsPowerShellCommand) {
        return $windowsPowerShellCommand.Source
    }

    throw "Neither 'pwsh' nor 'powershell' is available on PATH."
}

function Update-FileText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [scriptblock]$Transform
    )

    if (-not (Test-Path $Path)) {
        return
    }

    $content = Get-Content -Path $Path -Raw
    $updated = & $Transform $content

    if ($updated -ne $content) {
        Set-Content -Path $Path -Value $updated -Encoding UTF8
    }
}

function Set-Utf8FileContent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $directory = Split-Path -Path $Path -Parent
    if (-not (Test-Path $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    Set-Content -Path $Path -Value $Content -Encoding UTF8
}

function Ensure-EditorConfigForDotNetFormat {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetDirectory
    )

    $editorConfigPath = Join-Path $TargetDirectory ".editorconfig"
    $requiredLine = "csharp_style_namespace_declarations = file_scoped:suggestion"

    if (-not (Test-Path $editorConfigPath)) {
        $content = @"
root = true

[*.cs]
csharp_style_namespace_declarations = file_scoped:suggestion
"@
        Set-Utf8FileContent -Path $editorConfigPath -Content $content
        return
    }

    Update-FileText -Path $editorConfigPath -Transform {
        param($content)

        if ($content -match '(?m)^\s*csharp_style_namespace_declarations\s*=') {
            return [System.Text.RegularExpressions.Regex]::Replace(
                $content,
                '(?m)^\s*csharp_style_namespace_declarations\s*=.*$',
                $requiredLine
            )
        }

        $trimmed = $content.TrimEnd()
        if ($trimmed -match '(?m)^\[.*\]$') {
            return $trimmed + [Environment]::NewLine + $requiredLine + [Environment]::NewLine
        }

        return $trimmed + [Environment]::NewLine + [Environment]::NewLine + "[*.cs]" + [Environment]::NewLine + $requiredLine + [Environment]::NewLine
    }
}

function ConvertTo-FileScopedNamespaceContent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    if ($Content -match '(?m)^\s*namespace\s+[A-Za-z0-9_\.]+\s*;') {
        return $Content
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in ($Content -split "\r?\n")) {
        $lines.Add($line)
    }

    $namespaceLineIndex = -1
    $namespaceName = ""
    for ($index = 0; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -match '^\s*namespace\s+([A-Za-z0-9_\.]+)\s*$') {
            $namespaceLineIndex = $index
            $namespaceName = $matches[1]
            break
        }
    }

    if ($namespaceLineIndex -lt 0) {
        return $Content
    }

    $openBraceIndex = -1
    for ($index = $namespaceLineIndex + 1; $index -lt $lines.Count; $index++) {
        if ([string]::IsNullOrWhiteSpace($lines[$index])) {
            continue
        }

        if ($lines[$index].Trim() -ne "{") {
            return $Content
        }

        $openBraceIndex = $index
        break
    }

    if ($openBraceIndex -lt 0) {
        return $Content
    }

    $braceDepth = 0
    $closeBraceIndex = -1
    for ($index = $openBraceIndex; $index -lt $lines.Count; $index++) {
        $line = $lines[$index]
        $braceDepth += ([regex]::Matches($line, '\{')).Count
        $braceDepth -= ([regex]::Matches($line, '\}')).Count

        if ($braceDepth -eq 0) {
            $closeBraceIndex = $index
            break
        }
    }

    if ($closeBraceIndex -lt 0) {
        return $Content
    }

    for ($index = $closeBraceIndex + 1; $index -lt $lines.Count; $index++) {
        if (-not [string]::IsNullOrWhiteSpace($lines[$index])) {
            return $Content
        }
    }

    $builder = [System.Text.StringBuilder]::new()

    for ($index = 0; $index -lt $namespaceLineIndex; $index++) {
        [void]$builder.AppendLine($lines[$index])
    }

    [void]$builder.AppendLine("namespace $namespaceName;")

    $bodyLines = $lines[($openBraceIndex + 1)..($closeBraceIndex - 1)]

    while ($bodyLines.Count -gt 0 -and [string]::IsNullOrWhiteSpace($bodyLines[0])) {
        $bodyLines = if ($bodyLines.Count -gt 1) { $bodyLines[1..($bodyLines.Count - 1)] } else { @() }
    }

    while ($bodyLines.Count -gt 0 -and [string]::IsNullOrWhiteSpace($bodyLines[$bodyLines.Count - 1])) {
        $bodyLines = if ($bodyLines.Count -gt 1) { $bodyLines[0..($bodyLines.Count - 2)] } else { @() }
    }

    if ($bodyLines.Count -gt 0) {
        [void]$builder.AppendLine()
    }

    foreach ($line in $bodyLines) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            [void]$builder.AppendLine()
            continue
        }

        if ($line.StartsWith("    ")) {
            [void]$builder.AppendLine($line.Substring(4))
        }
        elseif ($line.StartsWith("`t")) {
            [void]$builder.AppendLine($line.Substring(1))
        }
        else {
            [void]$builder.AppendLine($line)
        }
    }

    return $builder.ToString().TrimEnd("`r", "`n") + [Environment]::NewLine
}

function Convert-CSharpFilesToFileScopedNamespaces {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetDirectory
    )

    $sourceDirectory = Join-Path $TargetDirectory "src"
    if (-not (Test-Path $sourceDirectory)) {
        return
    }

    $csFiles = Get-ChildItem -Path $sourceDirectory -Recurse -Filter *.cs -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](bin|obj)[\\/]' }

    foreach ($file in $csFiles) {
        $content = Get-Content -Path $file.FullName -Raw
        $updatedContent = ConvertTo-FileScopedNamespaceContent -Content $content

        if ($updatedContent -ne $content) {
            Set-Utf8FileContent -Path $file.FullName -Content $updatedContent
        }
    }
}

function Test-CentralPackageManagementEnabled {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DirectoryPath
    )

    $propsPath = Join-Path $DirectoryPath "Directory.Packages.props"
    if (-not (Test-Path $propsPath)) {
        return $false
    }

    $content = Get-Content -Path $propsPath -Raw
    return $content -match '<ManagePackageVersionsCentrally>\s*true\s*</ManagePackageVersionsCentrally>'
}

function Copy-BackofficeSkills {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetDirectory
    )

    $repositoryUrl = "https://github.com/umbraco/Umbraco-CMS-Backoffice-Skills.git"
    $temporaryCloneDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("umbraco-backoffice-skills-" + [System.Guid]::NewGuid().ToString("N"))
    $sourceSkillsDirectory = Join-Path $temporaryCloneDirectory "plugins/umbraco-backoffice-skills/skills"
    $destinationSkillsDirectory = Join-Path $TargetDirectory ".agents/skills"

    Write-Host "Cloning Umbraco backoffice skills into temporary directory..."
    try {
        & git clone --depth 1 $repositoryUrl $temporaryCloneDirectory
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to clone '$repositoryUrl'."
        }

        if (-not (Test-Path $sourceSkillsDirectory)) {
            throw "Expected skills directory was not found in the cloned repository: $sourceSkillsDirectory"
        }

        New-Item -ItemType Directory -Path $destinationSkillsDirectory -Force | Out-Null

        Get-ChildItem -Path $sourceSkillsDirectory -Directory | ForEach-Object {
            $destinationPath = Join-Path $destinationSkillsDirectory $_.Name
            Copy-Item -Path $_.FullName -Destination $destinationPath -Recurse -Force
        }
    }
    finally {
        if (Test-Path $temporaryCloneDirectory) {
            Remove-Item -Path $temporaryCloneDirectory -Recurse -Force
        }
    }
}
