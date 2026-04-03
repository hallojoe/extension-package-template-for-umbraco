param(
    [string]$ProjectsNamespace,

    [string]$MetadataFile,

    [string]$WorkingDirectory = (Get-Location).Path,

    [string]$TemplateIdentity = "Casko.ExtensionPackageTemplateForUmbraco",

    [string]$TemplateShortName = "extensionpackagetemplateforumbraco",

    [string]$PackageId,

    [string]$PackageVersion = "1.0.0",

    [string]$Configuration = "Release",

    [string]$OutputDirectory,

    [switch]$RegenerateTemplate,

    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "script-metadata.ps1")

$metadata = Get-MetadataObject -MetadataFile $MetadataFile -WorkingDirectory $WorkingDirectory
$ProjectsNamespace = Resolve-StringParameter -BoundParameters $PSBoundParameters -ParameterName "ProjectsNamespace" -CurrentValue $ProjectsNamespace -MetadataObject $metadata -MetadataPropertyNames @("projectsNamespace", "solutionName")
$WorkingDirectory = Resolve-WorkingDirectoryParameter -BoundParameters $PSBoundParameters -CurrentValue $WorkingDirectory -MetadataObject $metadata

$scriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$generateTemplateScriptPath = Join-Path $scriptRoot "generate-dotnet-template.ps1"

function Join-PathSegments {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BasePath,

        [Parameter(Mandatory = $true)]
        [string[]]$ChildPaths
    )

    $currentPath = $BasePath
    foreach ($childPath in $ChildPaths) {
        $currentPath = Join-Path $currentPath $childPath
    }

    return $currentPath
}

function Get-JsonFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return Get-Content -Path $Path -Raw | ConvertFrom-Json
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

function Get-ProjectPropertyValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectPath,

        [Parameter(Mandatory = $true)]
        [string]$PropertyName,

        [string]$DefaultValue = ""
    )

    [xml]$projectXml = Get-Content -Path $ProjectPath -Raw
    $propertyNodes = $projectXml.SelectNodes("/Project/PropertyGroup/$PropertyName")
    if ($null -eq $propertyNodes -or $propertyNodes.Count -eq 0) {
        return $DefaultValue
    }

    foreach ($propertyNode in $propertyNodes) {
        $value = [string]$propertyNode.InnerText
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value.Trim()
        }
    }

    return $DefaultValue
}

function Get-TrimmedValueOrDefault {
    param(
        [AllowEmptyString()]
        [string]$Value,

        [Parameter(Mandatory = $true)]
        [string]$DefaultValue
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $DefaultValue
    }

    return $Value.Trim()
}

function Get-AbsolutePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return [System.IO.Path]::GetFullPath($Path)
}

$projectsNamespaceTrimmed = $ProjectsNamespace.Trim()
if ([string]::IsNullOrWhiteSpace($projectsNamespaceTrimmed)) {
    throw "ProjectsNamespace is required."
}

$solutionDirectory = Join-Path $WorkingDirectory $projectsNamespaceTrimmed
if (-not (Test-Path $solutionDirectory)) {
    throw "Solution directory was not found: $solutionDirectory"
}

$metadataPath = Join-Path $solutionDirectory "setup-metadata.json"
if (-not (Test-Path $metadataPath)) {
    throw "setup-metadata.json was not found: $metadataPath"
}

$metadata = Get-JsonFile -Path $metadataPath
$solutionName = Get-TrimmedValueOrDefault -Value ([string]$metadata.solutionName) -DefaultValue $projectsNamespaceTrimmed
$solutionDescription = Get-TrimmedValueOrDefault -Value ([string]$metadata.solutionDescription) -DefaultValue "Umbraco extension package."
$gitHubOrganization = Get-TrimmedValueOrDefault -Value ([string]$metadata.gitHubOrganization) -DefaultValue "hallojoe"
$repositoryName = Get-TrimmedValueOrDefault -Value ([string]$metadata.repositoryName) -DefaultValue ($projectsNamespaceTrimmed.ToLowerInvariant())

$packageProjectPath = Join-PathSegments -BasePath $solutionDirectory -ChildPaths @('src', $projectsNamespaceTrimmed, "$projectsNamespaceTrimmed.csproj")
if (-not (Test-Path $packageProjectPath)) {
    throw "Package project was not found: $packageProjectPath"
}

$templateOutputDirectory = Join-Path $WorkingDirectory "$projectsNamespaceTrimmed.Template"
$shouldGenerateTemplate = (-not (Test-Path $templateOutputDirectory)) -or $RegenerateTemplate
if ($shouldGenerateTemplate) {
    & $generateTemplateScriptPath `
        -ProjectsNamespace $projectsNamespaceTrimmed `
        -WorkingDirectory $WorkingDirectory `
        -TemplateIdentity $TemplateIdentity `
        -TemplateShortName $TemplateShortName `
        -Force:$RegenerateTemplate

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to generate the dotnet template folder."
    }
}

$templateJsonPath = Join-PathSegments -BasePath $templateOutputDirectory -ChildPaths @('.template.config', 'template.json')
if (-not (Test-Path $templateJsonPath)) {
    throw "Generated template configuration was not found: $templateJsonPath"
}

$templatePackageProjectDirectory = Join-Path $WorkingDirectory "$projectsNamespaceTrimmed.Template.Package"
if (Test-Path $templatePackageProjectDirectory) {
    if (-not $Force) {
        throw "Template package project directory already exists: $templatePackageProjectDirectory. Use -Force to recreate it."
    }

    Remove-Item -Path $templatePackageProjectDirectory -Recurse -Force
}

$defaultPackageId = "$projectsNamespaceTrimmed.Template"
$resolvedPackageId = Get-TrimmedValueOrDefault -Value $PackageId -DefaultValue $defaultPackageId
$resolvedOutputDirectory = if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    Join-PathSegments -BasePath $templatePackageProjectDirectory -ChildPaths @('bin', $Configuration)
}
else {
    Get-AbsolutePath -Path $OutputDirectory
}

$authorName = Get-TrimmedValueOrDefault `
    -Value (Get-ProjectPropertyValue -ProjectPath $packageProjectPath -PropertyName "Authors" -DefaultValue "") `
    -DefaultValue "Casper Korsgaard"

$projectTitle = Get-TrimmedValueOrDefault `
    -Value (Get-ProjectPropertyValue -ProjectPath $packageProjectPath -PropertyName "Title" -DefaultValue "") `
    -DefaultValue $solutionName

$repositoryUrlDefault = "https://github.com/$gitHubOrganization/$repositoryName"
$repositoryUrl = Get-TrimmedValueOrDefault `
    -Value (Get-ProjectPropertyValue -ProjectPath $packageProjectPath -PropertyName "RepositoryUrl" -DefaultValue "") `
    -DefaultValue $repositoryUrlDefault

$packageProjectUrl = Get-TrimmedValueOrDefault `
    -Value (Get-ProjectPropertyValue -ProjectPath $packageProjectPath -PropertyName "PackageProjectUrl" -DefaultValue "") `
    -DefaultValue $repositoryUrl

$packageLicenseExpression = Get-TrimmedValueOrDefault `
    -Value (Get-ProjectPropertyValue -ProjectPath $packageProjectPath -PropertyName "PackageLicenseExpression" -DefaultValue "") `
    -DefaultValue "MIT"

$packageTags = Get-TrimmedValueOrDefault `
    -Value (Get-ProjectPropertyValue -ProjectPath $packageProjectPath -PropertyName "PackageTags" -DefaultValue "") `
    -DefaultValue "dotnet-new;template;umbraco;"

$templatePackageTitle = "$projectTitle Dotnet Template"
$templatePackageDescription = "dotnet new template package for $solutionName. $solutionDescription"
$templateFolderName = Split-Path -Path $templateOutputDirectory -Leaf
$templateSourcePath = Get-AbsolutePath -Path $templateOutputDirectory
$templatePackageProjectPath = Join-Path $templatePackageProjectDirectory "${resolvedPackageId}.csproj"
$templatePackageReadmePath = Join-Path $templatePackageProjectDirectory "README.md"

$templatePackageReadmeContent = @(
    "# $templatePackageTitle",
    "",
    "Install the template package from a feed:",
    "",
    '```powershell',
    "dotnet new install $resolvedPackageId",
    '```',
    "",
    "Or install the packed file directly:",
    "",
    '```powershell',
    "dotnet new install .\${resolvedPackageId}.${PackageVersion}.nupkg",
    '```',
    "",
    "After installation, create a solution with:",
    "",
    '```powershell',
    ('dotnet new {0} -n ".MyPackage" -o ".\output"' -f $TemplateShortName),
    '```',
    "",
    "Template identity: $TemplateIdentity",
    "Template short name: $TemplateShortName",
    "Source template folder: $templateFolderName"
) -join [Environment]::NewLine

Set-Utf8FileContent -Path $templatePackageReadmePath -Content $templatePackageReadmeContent

$templatePackageProjectContent = @(
    '<Project Sdk="Microsoft.NET.Sdk">',
    '  <PropertyGroup>',
    '    <TargetFramework>net10.0</TargetFramework>',
    '    <NoDefaultExcludes>true</NoDefaultExcludes>',
    '    <IncludeBuildOutput>false</IncludeBuildOutput>',
    '    <NoWarn>$(NoWarn);NU5128</NoWarn>',
    '    <PackageType>Template</PackageType>',
    "    <PackageId>$resolvedPackageId</PackageId>",
    "    <Version>$PackageVersion</Version>",
    "    <Authors>$authorName</Authors>",
    "    <Title>$templatePackageTitle</Title>",
    "    <Description>$templatePackageDescription</Description>",
    "    <PackageTags>$packageTags;dotnet-new;template</PackageTags>",
    "    <PackageProjectUrl>$packageProjectUrl</PackageProjectUrl>",
    "    <RepositoryUrl>$repositoryUrl</RepositoryUrl>",
    '    <RepositoryType>git</RepositoryType>',
    "    <PackageLicenseExpression>$packageLicenseExpression</PackageLicenseExpression>",
    '    <PackageReadmeFile>README.md</PackageReadmeFile>',
    '    <GeneratePackageOnBuild>false</GeneratePackageOnBuild>',
    '    <IsPackable>true</IsPackable>',
    '    <SuppressDependenciesWhenPacking>true</SuppressDependenciesWhenPacking>',
    '    <NoPackageAnalysis>true</NoPackageAnalysis>',
    '  </PropertyGroup>',
    '',
    '  <ItemGroup>',
    '    <None Include="README.md" Pack="true" PackagePath="/" />',
    ('    <None Include="{0}/**/*" Pack="true" PackagePath="content/{1}/%(RecursiveDir)%(Filename)%(Extension)" />' -f ($templateSourcePath -replace '\\', '/'), $templateFolderName),
    '  </ItemGroup>',
    '</Project>'
) -join [Environment]::NewLine

Set-Utf8FileContent -Path $templatePackageProjectPath -Content $templatePackageProjectContent

if (-not (Test-Path $resolvedOutputDirectory)) {
    New-Item -ItemType Directory -Path $resolvedOutputDirectory -Force | Out-Null
}

& dotnet pack $templatePackageProjectPath --configuration $Configuration --output $resolvedOutputDirectory
if ($LASTEXITCODE -ne 0) {
    throw "dotnet pack failed for $templatePackageProjectPath"
}

$packageFilePath = Join-Path $resolvedOutputDirectory "$resolvedPackageId.$PackageVersion.nupkg"
if (-not (Test-Path $packageFilePath)) {
    $packageFile = Get-ChildItem -Path $resolvedOutputDirectory -Filter "*.nupkg" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($null -eq $packageFile) {
        throw "Template package was not found in $resolvedOutputDirectory"
    }

    $packageFilePath = $packageFile.FullName
}

Write-Host ""
Write-Host "Dotnet template package created."
Write-Host "Source solution      : $solutionDirectory"
Write-Host "Template output      : $templateOutputDirectory"
Write-Host "Template package dir : $templatePackageProjectDirectory"
Write-Host "Package project      : $templatePackageProjectPath"
Write-Host "Package id           : $resolvedPackageId"
Write-Host "Package version      : $PackageVersion"
Write-Host "Package output       : $packageFilePath"
Write-Host "Install command      : dotnet new install `"$packageFilePath`""
