param(
    [string]$ProjectsNamespace,

    [Alias('SolutionName')]
    [string]$LegacySolutionName,

    [string]$MetadataFile,

    [string]$WorkingDirectory = (Get-Location).Path,

    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "script-metadata.ps1")
$scriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$testProjectTemplateRoot = Join-Path $scriptRoot "Templates\src\__TEMPLATE_TESTS_PROJECT_NAMESPACE__"

$metadata = Get-MetadataObject -MetadataFile $MetadataFile -WorkingDirectory $WorkingDirectory
$ProjectsNamespace = Resolve-StringParameter -BoundParameters $PSBoundParameters -ParameterName "ProjectsNamespace" -CurrentValue $ProjectsNamespace -MetadataObject $metadata -MetadataPropertyNames @("projectsNamespace", "solutionName")
$LegacySolutionName = Resolve-StringParameter -BoundParameters $PSBoundParameters -ParameterName "LegacySolutionName" -CurrentValue $LegacySolutionName -MetadataObject $metadata -MetadataPropertyNames @("solutionName")
$WorkingDirectory = Resolve-WorkingDirectoryParameter -BoundParameters $PSBoundParameters -CurrentValue $WorkingDirectory -MetadataObject $metadata

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

function Get-ReplacedValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputValue,

        [Parameter(Mandatory = $true)]
        [System.Collections.IEnumerable]$TokenPairs
    )

    $result = $InputValue
    foreach ($pair in $TokenPairs) {
        $result = $result.Replace([string]$pair.Source, [string]$pair.Target)
    }

    return $result
}

function Copy-TemplateTree {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath,

        [Parameter(Mandatory = $true)]
        [System.Collections.IEnumerable]$TokenPairs
    )

    $templateFiles = Get-ChildItem -Path $SourcePath -Recurse -File
    foreach ($templateFile in $templateFiles) {
        $relativePath = $templateFile.FullName.Substring($SourcePath.Length).TrimStart('\', '/')
        $targetRelativePath = Get-ReplacedValue -InputValue $relativePath -TokenPairs $TokenPairs
        $targetPath = Join-Path $DestinationPath $targetRelativePath

        $content = Get-Content -Path $templateFile.FullName -Raw
        $updatedContent = Get-ReplacedValue -InputValue $content -TokenPairs $TokenPairs

        Set-Utf8FileContent -Path $targetPath -Content $updatedContent
    }
}

function Get-FirstRegexGroup {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputText,

        [Parameter(Mandatory = $true)]
        [string]$Pattern
    )

    $match = [System.Text.RegularExpressions.Regex]::Match($InputText, $Pattern)
    if (-not $match.Success) {
        throw "Could not match pattern: $Pattern"
    }

    return $match.Groups[1].Value
}

function Get-OptionalRegexGroup {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputText,

        [Parameter(Mandatory = $true)]
        [string]$Pattern
    )

    $match = [System.Text.RegularExpressions.Regex]::Match($InputText, $Pattern)
    if (-not $match.Success) {
        return $null
    }

    return $match.Groups[1].Value
}

if (-not [string]::IsNullOrWhiteSpace($ProjectsNamespace)) {
    $projectsNamespaceTrimmed = $ProjectsNamespace.Trim()
}
elseif (-not [string]::IsNullOrWhiteSpace($LegacySolutionName)) {
    $projectsNamespaceTrimmed = $LegacySolutionName.Trim()
}
else {
    throw "ProjectsNamespace is required."
}

$solutionDirectory = Join-Path $WorkingDirectory $projectsNamespaceTrimmed
 if (-not (Test-Path $solutionDirectory)) {
     throw "Solution directory was not found: $solutionDirectory"
 }
 
 $srcDirectory = Join-Path $solutionDirectory "src"
 $packageProjectPath = Join-Path $srcDirectory "$projectsNamespaceTrimmed\$projectsNamespaceTrimmed.csproj"
 if (-not (Test-Path $packageProjectPath)) {
     throw "Package project was not found: $packageProjectPath"
 }
 
 $solutionFile = Get-ChildItem -Path $srcDirectory -File -ErrorAction SilentlyContinue |
     Where-Object { $_.BaseName -eq $projectsNamespaceTrimmed -and $_.Extension -in @('.sln', '.slnx') } |
     Select-Object -First 1
 
 if (-not $solutionFile) {
     throw "Solution file was not found in $srcDirectory for $projectsNamespaceTrimmed"
 }
 
$testsProjectName = "$projectsNamespaceTrimmed.Tests"
$testsProjectDirectory = Join-Path $srcDirectory $testsProjectName
$testsProjectPath = Join-Path $testsProjectDirectory "$testsProjectName.csproj"

if (-not (Test-Path $testProjectTemplateRoot)) {
    throw "Test project template directory was not found: $testProjectTemplateRoot"
}

if (Test-Path $testsProjectDirectory) {
    if (-not $Force) {
        throw "Test project directory already exists: $testsProjectDirectory. Use -Force to recreate it."
    }

    Remove-Item -Path $testsProjectDirectory -Recurse -Force
}

$packageProjectContent = Get-Content -Path $packageProjectPath -Raw
$umbracoVersion = Get-OptionalRegexGroup -InputText $packageProjectContent -Pattern '<PackageReference\s+Include="Umbraco\.Cms[^"]*"\s+Version="([^"]+)"'

if (-not $umbracoVersion) {
    $packageProjectDirectory = Split-Path -Path $packageProjectPath -Parent
    $directoryPackagesPropsPath = Join-Path $packageProjectDirectory "Directory.Packages.props"

    if (Test-Path $directoryPackagesPropsPath) {
        $directoryPackagesPropsContent = Get-Content -Path $directoryPackagesPropsPath -Raw
        $umbracoVersion = Get-OptionalRegexGroup -InputText $directoryPackagesPropsContent -Pattern '<PackageVersion\s+Include="Umbraco\.Cms(?:\.[^"]*)?"\s+Version="([^"]+)"'
    }
}

if (-not $umbracoVersion) {
    throw "Could not determine the Umbraco package version from '$packageProjectPath' or a sibling Directory.Packages.props file."
}

 $controllerFile = Get-ChildItem -Path (Join-Path $srcDirectory $projectsNamespaceTrimmed) -Recurse -Filter *ApiController.cs -File |
     Where-Object { $_.Name -notlike '*Base.cs' } |
     Select-Object -First 1
 if (-not $controllerFile) {
     throw "Could not find a concrete API controller under $projectsNamespaceTrimmed."
 }
 
 $baseControllerFile = Get-ChildItem -Path (Join-Path $srcDirectory $projectsNamespaceTrimmed) -Recurse -Filter *ApiControllerBase.cs -File |
     Select-Object -First 1
 if (-not $baseControllerFile) {
     throw "Could not find an API controller base class under $projectsNamespaceTrimmed."
 }

$controllerContent = Get-Content -Path $controllerFile.FullName -Raw
$baseControllerContent = Get-Content -Path $baseControllerFile.FullName -Raw

$controllerClassName = Get-FirstRegexGroup -InputText $controllerContent -Pattern 'public\s+class\s+([A-Za-z0-9_]+)\s*(?:\(|:)'
$routeBase = Get-FirstRegexGroup -InputText $baseControllerContent -Pattern '\[BackOfficeRoute\("([^"]+)"\)\]'
$integrationTestName = [System.IO.Path]::GetFileNameWithoutExtension($controllerFile.Name) + "IntegrationTests"

$tokenPairs = @(
    [pscustomobject]@{ Source = "__TEMPLATE_PROJECTS_NAMESPACE__"; Target = $projectsNamespaceTrimmed },
    [pscustomobject]@{ Source = "__TEMPLATE_TESTS_PROJECT_NAMESPACE__"; Target = $testsProjectName },
    [pscustomobject]@{ Source = "__TEMPLATE_UMBRACO_VERSION__"; Target = $umbracoVersion },
    [pscustomobject]@{ Source = "__TEMPLATE_CONTROLLER_CLASS_NAME__"; Target = $controllerClassName },
    [pscustomobject]@{ Source = "__TEMPLATE_ROUTE_BASE__"; Target = $routeBase },
    [pscustomobject]@{ Source = "__TEMPLATE_INTEGRATION_TEST_NAME__"; Target = $integrationTestName }
)

Copy-TemplateTree -SourcePath $testProjectTemplateRoot -DestinationPath $testsProjectDirectory -TokenPairs $tokenPairs

Invoke-RequiredCommand -FilePath "dotnet" -ArgumentList @("sln", $solutionFile.FullName, "add", $testsProjectPath) -WorkingPath $solutionDirectory
Invoke-RequiredCommand -FilePath "dotnet" -ArgumentList @("build", $testsProjectPath) -WorkingPath $solutionDirectory

Write-Host ""
Write-Host "Test project scaffolded."
Write-Host "Test project     : $testsProjectPath"
Write-Host "Solution file    : $($solutionFile.FullName)"
Write-Host "Controller route : /$routeBase/ping"
