param(
    [string]$SolutionName,
    [string]$SolutionDescription,
    [string]$GitHubOrganization,
    [string]$ProjectsNamespace,
    [string]$RepositoryName,
    [string]$AuthorName,
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

function Add-OptionalStringParameter {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Target,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [AllowEmptyString()]
        [string]$Value
    )

    if (-not [string]::IsNullOrWhiteSpace($Value)) {
        $Target[$Name] = $Value
    }
}

$scriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$scaffoldScriptPath = Join-Path $scriptRoot "scaffold-extention-package-for-umbraco.ps1"
$customizeScriptPath = Join-Path $scriptRoot "customize-extention-package-for-umbraco.ps1"

if (-not (Test-Path $scaffoldScriptPath)) {
    throw "Required script was not found: $scaffoldScriptPath"
}

if (-not (Test-Path $customizeScriptPath)) {
    throw "Required script was not found: $customizeScriptPath"
}

$scaffoldArguments = [ordered]@{
    WorkingDirectory = $WorkingDirectory
    SkipTemplateInstall = $SkipTemplateInstall
    Force = $Force
}
Add-OptionalStringParameter -Target $scaffoldArguments -Name "SolutionName" -Value $SolutionName
Add-OptionalStringParameter -Target $scaffoldArguments -Name "SolutionDescription" -Value $SolutionDescription
Add-OptionalStringParameter -Target $scaffoldArguments -Name "GitHubOrganization" -Value $GitHubOrganization
Add-OptionalStringParameter -Target $scaffoldArguments -Name "ProjectsNamespace" -Value $ProjectsNamespace
Add-OptionalStringParameter -Target $scaffoldArguments -Name "RepositoryName" -Value $RepositoryName
Add-OptionalStringParameter -Target $scaffoldArguments -Name "AuthorName" -Value $AuthorName
Add-OptionalStringParameter -Target $scaffoldArguments -Name "AuthorOrganizationName" -Value $AuthorOrganizationName
Add-OptionalStringParameter -Target $scaffoldArguments -Name "AuthorOrganizationUrl" -Value $AuthorOrganizationUrl
Add-OptionalStringParameter -Target $scaffoldArguments -Name "AuthorEmail" -Value $AuthorEmail
Add-OptionalStringParameter -Target $scaffoldArguments -Name "MetadataFile" -Value $MetadataFile

$customizeArguments = [ordered]@{
    WorkingDirectory = $WorkingDirectory
    IncludeClientCodeBlueprint = $IncludeClientCodeBlueprint
    RunDotNetFormat = $RunDotNetFormat
    SkipBuild = $SkipBuild
}
Add-OptionalStringParameter -Target $customizeArguments -Name "SolutionName" -Value $SolutionName
Add-OptionalStringParameter -Target $customizeArguments -Name "SolutionDescription" -Value $SolutionDescription
Add-OptionalStringParameter -Target $customizeArguments -Name "GitHubOrganization" -Value $GitHubOrganization
Add-OptionalStringParameter -Target $customizeArguments -Name "ProjectsNamespace" -Value $ProjectsNamespace
Add-OptionalStringParameter -Target $customizeArguments -Name "RepositoryName" -Value $RepositoryName
Add-OptionalStringParameter -Target $customizeArguments -Name "AuthorName" -Value $AuthorName
Add-OptionalStringParameter -Target $customizeArguments -Name "AuthorOrganizationName" -Value $AuthorOrganizationName
Add-OptionalStringParameter -Target $customizeArguments -Name "AuthorOrganizationUrl" -Value $AuthorOrganizationUrl
Add-OptionalStringParameter -Target $customizeArguments -Name "AuthorEmail" -Value $AuthorEmail
Add-OptionalStringParameter -Target $customizeArguments -Name "MetadataFile" -Value $MetadataFile

& $scaffoldScriptPath @scaffoldArguments
& $customizeScriptPath @customizeArguments
