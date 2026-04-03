param(
    [string]$ProjectsNamespace,

    [Alias('SolutionName')]
    [string]$LegacySolutionName,

    [string]$MetadataFile,

    [string]$WorkingDirectory = (Get-Location).Path,

    [string]$Configuration = "Release"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "script-metadata.ps1")

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

if (-not [string]::IsNullOrWhiteSpace($ProjectsNamespace)) {
    $projectsNamespaceTrimmed = $ProjectsNamespace.Trim()
}
elseif (-not [string]::IsNullOrWhiteSpace($LegacySolutionName)) {
    $projectsNamespaceTrimmed = $LegacySolutionName.Trim()
}
else {
    throw "ProjectsNamespace is required."
}

$targetDirectory = Join-Path $WorkingDirectory $projectsNamespaceTrimmed
if (-not (Test-Path $targetDirectory)) {
    throw "Solution directory was not found: $targetDirectory"
}

$srcDirectory = Join-Path $targetDirectory "src"
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

Invoke-RequiredCommand -FilePath "dotnet" -ArgumentList @("build", $solutionFile.FullName, "--configuration", $Configuration) -WorkingPath $targetDirectory
Invoke-RequiredCommand -FilePath "dotnet" -ArgumentList @("pack", $packageProjectPath, "--configuration", $Configuration, "--no-build") -WorkingPath $targetDirectory

Write-Host ""
Write-Host "Build and pack completed."
Write-Host "Solution file  : $($solutionFile.FullName)"
Write-Host "Package project: $packageProjectPath"
