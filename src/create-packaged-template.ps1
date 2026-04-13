param(
    [string]$SolutionName,

    [string]$SolutionDescription,

    [string]$GitHubOrganization,

    [string]$ProjectsNamespace,

    [string]$RepositoryName,

    [string]$AuthorName,

    [string]$MetadataFile,

    [string]$WorkingDirectory = (Get-Location).Path,

    [string]$TemplateIdentity = "Casko.ExtensionPackageTemplateForUmbraco",

    [string]$TemplateShortName = "extensionpackagetemplateforumbraco",

    [string]$PackageId,

    [string]$PackageVersion = "1.0.0",

    [string]$Configuration = "Release",

    [string]$OutputDirectory,

    [switch]$SkipTemplateInstall,

    [switch]$SkipBuild,

    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "script-metadata.ps1")

$metadata = Get-MetadataObject -MetadataFile $MetadataFile -WorkingDirectory $WorkingDirectory
$SolutionName = Resolve-StringParameter -BoundParameters $PSBoundParameters -ParameterName "SolutionName" -CurrentValue $SolutionName -MetadataObject $metadata -MetadataPropertyNames @("solutionName")
$SolutionDescription = Resolve-StringParameter -BoundParameters $PSBoundParameters -ParameterName "SolutionDescription" -CurrentValue $SolutionDescription -MetadataObject $metadata -MetadataPropertyNames @("solutionDescription")
$GitHubOrganization = Resolve-StringParameter -BoundParameters $PSBoundParameters -ParameterName "GitHubOrganization" -CurrentValue $GitHubOrganization -MetadataObject $metadata -MetadataPropertyNames @("gitHubOrganization")
$ProjectsNamespace = Resolve-StringParameter -BoundParameters $PSBoundParameters -ParameterName "ProjectsNamespace" -CurrentValue $ProjectsNamespace -MetadataObject $metadata -MetadataPropertyNames @("projectsNamespace")
$RepositoryName = Resolve-StringParameter -BoundParameters $PSBoundParameters -ParameterName "RepositoryName" -CurrentValue $RepositoryName -MetadataObject $metadata -MetadataPropertyNames @("repositoryName")
$AuthorName = Resolve-StringParameter -BoundParameters $PSBoundParameters -ParameterName "AuthorName" -CurrentValue $AuthorName -MetadataObject $metadata -MetadataPropertyNames @("authorName")
$WorkingDirectory = Resolve-WorkingDirectoryParameter -BoundParameters $PSBoundParameters -CurrentValue $WorkingDirectory -MetadataObject $metadata

$scriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$setupScriptPath = Join-Path $scriptRoot "new-extention-package-for-umbraco.ps1"
$generateTemplateScriptPath = Join-Path $scriptRoot "generate-dotnet-template.ps1"
$packTemplateScriptPath = Join-Path $scriptRoot "pack-dotnet-template.ps1"

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

function Get-TrimmedValueOrNull {
    param(
        [AllowEmptyString()]
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    return $Value.Trim()
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

function ConvertTo-ArgumentDisplay {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Parameters
    )

    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($key in $Parameters.Keys) {
        $value = $Parameters[$key]
        if ($value -is [switch]) {
            if ($value.IsPresent) {
                $parts.Add("-$key")
            }

            continue
        }

        if ($value -is [bool]) {
            if ($value) {
                $parts.Add("-$key")
            }

            continue
        }

        $parts.Add("-$key")
        $parts.Add([string]$value)
    }

    return $parts -join ' '
}

function Invoke-RequiredCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [hashtable]$Parameters,

        [Parameter(Mandatory = $true)]
        [string]$WorkingPath
    )

    Push-Location $WorkingPath
    try {
        Write-Host "> $FilePath $(ConvertTo-ArgumentDisplay -Parameters $Parameters)"
        & $FilePath @Parameters
    }
    finally {
        Pop-Location
    }
}

$solutionNameTrimmed = Get-TrimmedValue -Value $SolutionName
if ([string]::IsNullOrWhiteSpace($solutionNameTrimmed)) {
    throw "SolutionName is required."
}

$projectsNamespace = Get-ProjectsNamespace -SolutionName $solutionNameTrimmed -ProjectsNamespace $ProjectsNamespace
$packageIdTrimmed = Get-TrimmedValueOrNull -Value $PackageId
$repositoryNameTrimmed = Get-TrimmedValueOrNull -Value $RepositoryName
$outputDirectoryTrimmed = Get-TrimmedValueOrNull -Value $OutputDirectory

$setupArguments = [ordered]@{
    SolutionName = $solutionNameTrimmed
    SolutionDescription = $SolutionDescription
    GitHubOrganization = $GitHubOrganization
    WorkingDirectory = $WorkingDirectory
}

if ($repositoryNameTrimmed) {
    $setupArguments.RepositoryName = $repositoryNameTrimmed
}

if (-not [string]::IsNullOrWhiteSpace($AuthorName)) {
    $setupArguments.AuthorName = $AuthorName.Trim()
}

if (-not [string]::IsNullOrWhiteSpace($MetadataFile)) {
    $setupArguments.MetadataFile = $MetadataFile
}

if ($ProjectsNamespace) {
    $setupArguments.ProjectsNamespace = $projectsNamespace
}

if ($SkipTemplateInstall) {
    $setupArguments.SkipTemplateInstall = $true
}

if ($SkipBuild) {
    $setupArguments.SkipBuild = $true
}

if ($Force) {
    $setupArguments.Force = $true
}

$generateArguments = [ordered]@{
    ProjectsNamespace = $projectsNamespace
    WorkingDirectory = $WorkingDirectory
    TemplateIdentity = $TemplateIdentity
    TemplateShortName = $TemplateShortName
}

if ($Force) {
    $generateArguments.Force = $true
}

$packArguments = [ordered]@{
    ProjectsNamespace = $projectsNamespace
    WorkingDirectory = $WorkingDirectory
    TemplateIdentity = $TemplateIdentity
    TemplateShortName = $TemplateShortName
    PackageVersion = $PackageVersion
    Configuration = $Configuration
}

if ($packageIdTrimmed) {
    $packArguments.PackageId = $packageIdTrimmed
}

if ($outputDirectoryTrimmed) {
    $packArguments.OutputDirectory = $outputDirectoryTrimmed
}

if ($Force) {
    $packArguments.Force = $true
}

Write-Host ""
Write-Host "Creating packaged template for $projectsNamespace"

Invoke-RequiredCommand -FilePath $setupScriptPath -Parameters $setupArguments -WorkingPath $WorkingDirectory
Invoke-RequiredCommand -FilePath $generateTemplateScriptPath -Parameters $generateArguments -WorkingPath $WorkingDirectory
Invoke-RequiredCommand -FilePath $packTemplateScriptPath -Parameters $packArguments -WorkingPath $WorkingDirectory

Write-Host ""
Write-Host "Packaged template workflow completed."
Write-Host "Projects namespace: $projectsNamespace"
