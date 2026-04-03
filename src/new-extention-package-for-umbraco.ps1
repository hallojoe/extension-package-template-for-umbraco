param(
    [string]$SolutionName,

    [string]$SolutionDescription = "Extension package template for Umbraco.",

    [string]$GitHubOrganization = "hallojoe",

    [string]$ProjectsNamespace,

    [string]$RepositoryName,

    [string]$AuthorName = "Casper Korsgaard",

    [string]$AuthorOrganizationName,

    [string]$AuthorOrganizationUrl,

    [string]$AuthorEmail,

    [string]$MetadataFile,

    [string]$WorkingDirectory = (Get-Location).Path,

    [switch]$IncludeClientCodeBlueprint = $true,

    [switch]$RunDotNetFormat = $true,

    [switch]$SkipTemplateInstall,

    [switch]$SkipBuild,

    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "script-metadata.ps1")

$scriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$addUmbracoTestProjectScriptPath = Join-Path $scriptRoot "add-umbraco-test-project.ps1"
$addGitHubActionsScriptPath = Join-Path $scriptRoot "add-github-actions.ps1"
$applyClientCodeBlueprintScriptPath = Join-Path $scriptRoot "apply-client-code-blueprint.ps1"

$metadata = Get-MetadataObject -MetadataFile $MetadataFile -WorkingDirectory $WorkingDirectory
$SolutionName = Resolve-StringParameter -BoundParameters $PSBoundParameters -ParameterName "SolutionName" -CurrentValue $SolutionName -MetadataObject $metadata -MetadataPropertyNames @("solutionName")
$SolutionDescription = Resolve-StringParameter -BoundParameters $PSBoundParameters -ParameterName "SolutionDescription" -CurrentValue $SolutionDescription -MetadataObject $metadata -MetadataPropertyNames @("solutionDescription")
$GitHubOrganization = Resolve-StringParameter -BoundParameters $PSBoundParameters -ParameterName "GitHubOrganization" -CurrentValue $GitHubOrganization -MetadataObject $metadata -MetadataPropertyNames @("gitHubOrganization")
$ProjectsNamespace = Resolve-StringParameter -BoundParameters $PSBoundParameters -ParameterName "ProjectsNamespace" -CurrentValue $ProjectsNamespace -MetadataObject $metadata -MetadataPropertyNames @("projectsNamespace")
$RepositoryName = Resolve-StringParameter -BoundParameters $PSBoundParameters -ParameterName "RepositoryName" -CurrentValue $RepositoryName -MetadataObject $metadata -MetadataPropertyNames @("repositoryName")
$AuthorName = Resolve-StringParameter -BoundParameters $PSBoundParameters -ParameterName "AuthorName" -CurrentValue $AuthorName -MetadataObject $metadata -MetadataPropertyNames @("authorName")
$AuthorOrganizationName = Resolve-StringParameter -BoundParameters $PSBoundParameters -ParameterName "AuthorOrganizationName" -CurrentValue $AuthorOrganizationName -MetadataObject $metadata -MetadataPropertyNames @("authorOrganizationName", "apiOrganizationName")
$AuthorOrganizationUrl = Resolve-StringParameter -BoundParameters $PSBoundParameters -ParameterName "AuthorOrganizationUrl" -CurrentValue $AuthorOrganizationUrl -MetadataObject $metadata -MetadataPropertyNames @("authorOrganizationUrl", "apiOrganizationUrl")
$AuthorEmail = Resolve-StringParameter -BoundParameters $PSBoundParameters -ParameterName "AuthorEmail" -CurrentValue $AuthorEmail -MetadataObject $metadata -MetadataPropertyNames @("authorEmail", "apiContactEmail")
$WorkingDirectory = Resolve-WorkingDirectoryParameter -BoundParameters $PSBoundParameters -CurrentValue $WorkingDirectory -MetadataObject $metadata

function Get-TrimmedValue {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value
    )

    return $Value.Trim()
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

$solutionNameTrimmed = Get-TrimmedValue -Value $SolutionName
if ([string]::IsNullOrWhiteSpace($solutionNameTrimmed)) {
    throw "SolutionName is required."
}

$solutionDescriptionTrimmed = Get-TrimmedValue -Value $SolutionDescription
$gitHubOrganizationTrimmed = Get-TrimmedValue -Value $GitHubOrganization
$authorNameTrimmed = Get-TrimmedValue -Value $AuthorName
$projectsNamespace = Get-ProjectsNamespace -SolutionName $solutionNameTrimmed -ProjectsNamespace $ProjectsNamespace
$repositoryNameTrimmed = Get-TrimmedValue -Value $RepositoryName

if ([string]::IsNullOrWhiteSpace($repositoryNameTrimmed)) {
    $repositoryNameTrimmed = ConvertTo-KebabCase -InputValue $solutionNameTrimmed
}

$apiName = "$repositoryNameTrimmed-api"
$apiGroup = $solutionNameTrimmed
$apiDescription = $solutionDescriptionTrimmed
$authorOrganizationNameTrimmed = Get-TrimmedValue -Value $AuthorOrganizationName
$authorOrganizationUrlTrimmed = Get-TrimmedValue -Value $AuthorOrganizationUrl
$authorEmailTrimmed = Get-TrimmedValue -Value $AuthorEmail

if ([string]::IsNullOrWhiteSpace($authorOrganizationNameTrimmed)) {
    $authorOrganizationNameTrimmed = $gitHubOrganizationTrimmed
}

if ([string]::IsNullOrWhiteSpace($authorOrganizationUrlTrimmed) -and -not [string]::IsNullOrWhiteSpace($gitHubOrganizationTrimmed)) {
    $authorOrganizationUrlTrimmed = "https://github.com/$gitHubOrganizationTrimmed"
}

$targetDirectory = Join-Path $WorkingDirectory $projectsNamespace

if (Test-Path $targetDirectory) {
    if (-not $Force) {
        throw "Target directory already exists: $targetDirectory. Use -Force to remove and recreate it."
    }

    Remove-Item -Path $targetDirectory -Recurse -Force
}

Assert-DotNet10SdkInstalled

if (-not $SkipTemplateInstall) {
    Install-TemplatePackage -PackageId "Umbraco.Templates"
    Install-TemplatePackage -PackageId "Umbraco.Community.Templates.PackageStarter"
}

$umbracoTemplateVersion = Get-InstalledTemplatePackageVersion -PackageId "Umbraco.Templates"

if (-not (Test-Path $WorkingDirectory)) {
    New-Item -ItemType Directory -Path $WorkingDirectory | Out-Null
}

$templateArgs = @(
    "new",
    "umbracopackagestarter",
    "-n", $projectsNamespace,
    "--allow-scripts", "Yes",
    "--force",
    "-an", $authorNameTrimmed,
    "-gu", $gitHubOrganizationTrimmed,
    "-gr", $repositoryNameTrimmed
)

Invoke-RequiredCommand -FilePath "dotnet" -ArgumentList $templateArgs -WorkingPath $WorkingDirectory

$metadata = [ordered]@{
    solutionName = $solutionNameTrimmed
    solutionDescription = $solutionDescriptionTrimmed
    projectsNamespace = $projectsNamespace
    gitHubOrganization = $gitHubOrganizationTrimmed
    repositoryName = $repositoryNameTrimmed
    authorName = $authorNameTrimmed
    authorOrganizationName = $authorOrganizationNameTrimmed
    authorOrganizationUrl = $authorOrganizationUrlTrimmed
    authorEmail = $authorEmailTrimmed
    apiName = $apiName
    apiGroup = $apiGroup
    apiDescription = $apiDescription
    apiOrganizationName = $authorOrganizationNameTrimmed
    apiOrganizationUrl = $authorOrganizationUrlTrimmed
    apiContactEmail = $authorEmailTrimmed
    umbracoTemplateVersion = $umbracoTemplateVersion
    targetDirectory = $targetDirectory
}

$metadataPath = Join-Path $targetDirectory "setup-metadata.json"
$metadata | ConvertTo-Json -Depth 3 | Set-Content -Path $metadataPath -Encoding UTF8

$githubReadmePath = Join-Path $targetDirectory ".github\README.md"
$nugetReadmePath = Join-Path $targetDirectory "docs\README_nuget.md"
$projectFilePath = Join-Path $targetDirectory "src\$projectsNamespace\$projectsNamespace.csproj"
$packageId = "Umbraco.Community.$projectsNamespace"

Update-FileText -Path $githubReadmePath -Transform {
    param($content)
    $content.Replace("Umbraco.Community.", "")
}

Update-FileText -Path $nugetReadmePath -Transform {
    param($content)
    $content.Replace("Umbraco.Community.", "")
}

Update-FileText -Path $projectFilePath -Transform {
    param($content)

    $updated = $content.Replace("Umbraco.Community.", "")
    $updated = [System.Text.RegularExpressions.Regex]::Replace(
        $updated,
        '<Title>.*?</Title>',
        "<Title>$apiGroup</Title>"
    )
    $updated = [System.Text.RegularExpressions.Regex]::Replace(
        $updated,
        '<Description>.*?</Description>',
        "<Description>$apiDescription</Description>"
    )

    $updated
}

$packageProjectDirectory = Split-Path -Path $projectFilePath -Parent
if (Test-CentralPackageManagementEnabled -DirectoryPath $packageProjectDirectory) {
    Update-FileText -Path $projectFilePath -Transform {
        param($content)

        [System.Text.RegularExpressions.Regex]::Replace(
            $content,
            '(<PackageReference\s+Include="Umbraco\.Cms[^"]*")\s+Version="[^"]+"(\s*/>)',
            '${1}${2}'
        )
    }
}

$projectFiles = Get-ChildItem -Path (Join-Path $targetDirectory "src") -Recurse -Filter *.csproj -File -ErrorAction SilentlyContinue
foreach ($projectFile in $projectFiles) {
    Update-FileText -Path $projectFile.FullName -Transform {
        param($content)

        [System.Text.RegularExpressions.Regex]::Replace(
            $content,
            '(<PackageReference\s+Include="Umbraco\.Cms[^"]*"\s+Version=")([^"]+)(")',
            ('${1}' + $umbracoTemplateVersion + '${3}')
        )
    }
}

$solutionFile = Get-ChildItem -Path $targetDirectory -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -in @('.sln', '.slnx') } |
    Select-Object -First 1
if (-not $solutionFile) {
    throw "Scaffold completed, but no solution file was found under $targetDirectory."
}

if (-not $SkipBuild) {
    Invoke-RequiredCommand -FilePath "dotnet" -ArgumentList @("build", $solutionFile.FullName) -WorkingPath $targetDirectory
}

Copy-BackofficeSkills -TargetDirectory $targetDirectory

if (-not (Test-Path $addUmbracoTestProjectScriptPath)) {
    throw "Required script was not found: $addUmbracoTestProjectScriptPath"
}

if (-not (Test-Path $addGitHubActionsScriptPath)) {
    throw "Required script was not found: $addGitHubActionsScriptPath"
}

if ($IncludeClientCodeBlueprint -and -not (Test-Path $applyClientCodeBlueprintScriptPath)) {
    throw "Required script was not found: $applyClientCodeBlueprintScriptPath"
}

Invoke-RequiredCommand -FilePath "powershell" -ArgumentList @(
    "-ExecutionPolicy", "Bypass",
    "-File", $addUmbracoTestProjectScriptPath,
    "-ProjectsNamespace", $projectsNamespace,
    "-WorkingDirectory", $WorkingDirectory
) -WorkingPath $WorkingDirectory

Invoke-RequiredCommand -FilePath "powershell" -ArgumentList @(
    "-ExecutionPolicy", "Bypass",
    "-File", $addGitHubActionsScriptPath,
    "-ProjectsNamespace", $projectsNamespace,
    "-WorkingDirectory", $WorkingDirectory,
    "-DotNetVersion", "10.0.x",
    "-NodeVersion", "22"
) -WorkingPath $WorkingDirectory

if ($IncludeClientCodeBlueprint) {
    $applyBlueprintArguments = @(
        "-ExecutionPolicy", "Bypass",
        "-File", $applyClientCodeBlueprintScriptPath,
        "-ProjectsNamespace", $projectsNamespace,
        "-WorkingDirectory", $targetDirectory,
        "-AuthorName", $authorNameTrimmed
    )

    if (-not [string]::IsNullOrWhiteSpace($authorOrganizationNameTrimmed)) {
        $applyBlueprintArguments += @("-AuthorOrganizationName", $authorOrganizationNameTrimmed)
    }

    if (-not [string]::IsNullOrWhiteSpace($authorOrganizationUrlTrimmed)) {
        $applyBlueprintArguments += @("-AuthorOrganizationUrl", $authorOrganizationUrlTrimmed)
    }

    if (-not [string]::IsNullOrWhiteSpace($authorEmailTrimmed)) {
        $applyBlueprintArguments += @("-AuthorEmail", $authorEmailTrimmed)
    }

    Invoke-RequiredCommand -FilePath "powershell" -ArgumentList $applyBlueprintArguments -WorkingPath $WorkingDirectory
}

Convert-CSharpFilesToFileScopedNamespaces -TargetDirectory $targetDirectory

if ($RunDotNetFormat) {
    Ensure-EditorConfigForDotNetFormat -TargetDirectory $targetDirectory
    Invoke-RequiredCommand -FilePath "dotnet" -ArgumentList @(
        "format",
        $solutionFile.FullName,
        "style",
        "--verbosity",
        "minimal"
    ) -WorkingPath $targetDirectory
}

Write-Host ""
Write-Host "Setup completed."
Write-Host "Projects namespace : $projectsNamespace"
Write-Host "Repository name    : $repositoryNameTrimmed"
Write-Host "API name           : $apiName"
Write-Host "API group          : $apiGroup"
Write-Host "API description    : $apiDescription"
Write-Host "Solution file      : $($solutionFile.FullName)"
Write-Host "Metadata           : $metadataPath"
Write-Host "Skills             : $(Join-Path $targetDirectory '.agents/skills')"
Write-Host "Tests script       : $addUmbracoTestProjectScriptPath"
Write-Host "GitHub actions     : $addGitHubActionsScriptPath"
