param(
    [string]$ProjectsNamespace,

    [Alias('SolutionName')]
    [string]$LegacySolutionName,

    [string]$MetadataFile,

    [string]$WorkingDirectory = (Get-Location).Path,

    [string]$Configuration = "Debug",

    [string]$LaunchProfile,

    [int]$StartupTimeoutSeconds = 300,

    [int]$PollIntervalSeconds = 5
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName "System.Net.Http"
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

function Get-RequiredRegexGroup {
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

function Get-SwaggerUrlFromPackageJson {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageJsonPath
    )

    $packageJson = Get-Content -Path $PackageJsonPath -Raw | ConvertFrom-Json
    $generateClientScript = [string]$packageJson.scripts.'generate-client'
    if ([string]::IsNullOrWhiteSpace($generateClientScript)) {
        throw "The generate-client script was not found in $PackageJsonPath"
    }

    return Get-RequiredRegexGroup -InputText $generateClientScript -Pattern '(https?://\S+)'
}

function Get-LaunchProfileName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LaunchSettingsPath,

        [string]$PreferredProfile
    )

    $launchSettings = Get-Content -Path $LaunchSettingsPath -Raw | ConvertFrom-Json
    $profileNames = @($launchSettings.profiles.PSObject.Properties.Name)
    if ($profileNames.Count -eq 0) {
        throw "No launch profiles were found in $LaunchSettingsPath"
    }

    if (-not [string]::IsNullOrWhiteSpace($PreferredProfile)) {
        if ($profileNames -contains $PreferredProfile) {
            return $PreferredProfile
        }

        throw "Launch profile '$PreferredProfile' was not found in $LaunchSettingsPath"
    }

    $projectProfile = $launchSettings.profiles.PSObject.Properties |
        Where-Object { $_.Value.commandName -eq "Project" } |
        Select-Object -First 1

    if ($projectProfile) {
        return $projectProfile.Name
    }

    return $profileNames[0]
}

function Get-ApplicationUrl {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LaunchSettingsPath,

        [Parameter(Mandatory = $true)]
        [string]$ProfileName,

        [Parameter(Mandatory = $true)]
        [string]$SwaggerUrl
    )

    $launchSettings = Get-Content -Path $LaunchSettingsPath -Raw | ConvertFrom-Json
    $profile = $launchSettings.profiles.$ProfileName
    if ($profile -and -not [string]::IsNullOrWhiteSpace([string]$profile.applicationUrl)) {
        $applicationUrls = ([string]$profile.applicationUrl).Split(';', [System.StringSplitOptions]::RemoveEmptyEntries)
        $httpsUrl = $applicationUrls | Where-Object { $_ -like 'https://*' } | Select-Object -First 1
        if ($httpsUrl) {
            return ($httpsUrl.TrimEnd('/') + "/umbraco")
        }

        return ($applicationUrls[0].TrimEnd('/') + "/umbraco")
    }

    $swaggerUri = [Uri]$SwaggerUrl
    return ($swaggerUri.GetLeftPart([System.UriPartial]::Authority).TrimEnd('/') + "/umbraco")
}

function Wait-ForLogReady {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$ReadyPatterns,

        [Parameter(Mandatory = $true)]
        [int]$TimeoutSeconds,

        [Parameter(Mandatory = $true)]
        [int]$PollIntervalSeconds,

        [Parameter(Mandatory = $true)]
        [System.Diagnostics.Process]$Process,

        [Parameter(Mandatory = $true)]
        [string]$StdOutLogPath,

        [Parameter(Mandatory = $true)]
        [string]$StdErrLogPath
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)

    while ((Get-Date) -lt $deadline) {
        if ($Process.HasExited) {
            $stdOut = if (Test-Path $StdOutLogPath) { Get-Content -Path $StdOutLogPath -Raw } else { "" }
            $stdErr = if (Test-Path $StdErrLogPath) { Get-Content -Path $StdErrLogPath -Raw } else { "" }
            throw "The TestSite process exited before readiness was detected.`nSTDOUT:`n$stdOut`nSTDERR:`n$stdErr"
        }

        if (Test-Path $StdOutLogPath) {
            $stdOut = Get-Content -Path $StdOutLogPath -Raw
            foreach ($pattern in $ReadyPatterns) {
                if ($stdOut -match $pattern) {
                    return
                }
            }
        }

        Start-Sleep -Seconds $PollIntervalSeconds
    }

    $timedOutStdOut = if (Test-Path $StdOutLogPath) { Get-Content -Path $StdOutLogPath -Raw } else { "" }
    $timedOutStdErr = if (Test-Path $StdErrLogPath) { Get-Content -Path $StdErrLogPath -Raw } else { "" }
    throw "Timed out waiting for TestSite readiness after $TimeoutSeconds seconds.`nSTDOUT:`n$timedOutStdOut`nSTDERR:`n$timedOutStdErr"
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
$clientDirectory = Join-Path $srcDirectory "$projectsNamespaceTrimmed\Client"
$testSiteDirectory = Join-Path $srcDirectory "$projectsNamespaceTrimmed.TestSite"
$packageJsonPath = Join-Path $clientDirectory "package.json"
$launchSettingsPath = Join-Path $testSiteDirectory "Properties\launchSettings.json"
$testSiteProjectPath = Join-Path $testSiteDirectory "$projectsNamespaceTrimmed.TestSite.csproj"

foreach ($path in @($clientDirectory, $testSiteDirectory, $packageJsonPath, $launchSettingsPath, $testSiteProjectPath)) {
    if (-not (Test-Path $path)) {
        throw "Required path was not found: $path"
    }
}

$swaggerUrl = Get-SwaggerUrlFromPackageJson -PackageJsonPath $packageJsonPath
$resolvedLaunchProfile = Get-LaunchProfileName -LaunchSettingsPath $launchSettingsPath -PreferredProfile $LaunchProfile
$applicationUrl = Get-ApplicationUrl -LaunchSettingsPath $launchSettingsPath -ProfileName $resolvedLaunchProfile -SwaggerUrl $swaggerUrl

Invoke-RequiredCommand -FilePath "npm.cmd" -ArgumentList @("install") -WorkingPath $clientDirectory
Invoke-RequiredCommand -FilePath "dotnet" -ArgumentList @("build", $testSiteProjectPath, "--configuration", $Configuration) -WorkingPath $testSiteDirectory

$stdOutLogPath = Join-Path $testSiteDirectory "test-umbraco-client-build.stdout.log"
$stdErrLogPath = Join-Path $testSiteDirectory "test-umbraco-client-build.stderr.log"
if (Test-Path $stdOutLogPath) {
    Remove-Item -Path $stdOutLogPath -Force
}
if (Test-Path $stdErrLogPath) {
    Remove-Item -Path $stdErrLogPath -Force
}

$testSiteProcess = $null

try {
    Write-Host "> dotnet run --configuration $Configuration --launch-profile $resolvedLaunchProfile --no-build"
    $testSiteProcess = Start-Process -FilePath "dotnet" `
        -ArgumentList @("run", "--configuration", $Configuration, "--launch-profile", $resolvedLaunchProfile, "--no-build") `
        -WorkingDirectory $testSiteDirectory `
        -RedirectStandardOutput $stdOutLogPath `
        -RedirectStandardError $stdErrLogPath `
        -PassThru

    Wait-ForLogReady `
        -ReadyPatterns @(
            'Now listening on:\s+https?://',
            'Application started\.'
        ) `
        -TimeoutSeconds $StartupTimeoutSeconds `
        -PollIntervalSeconds $PollIntervalSeconds `
        -Process $testSiteProcess `
        -StdOutLogPath $stdOutLogPath `
        -StdErrLogPath $stdErrLogPath

    Invoke-RequiredCommand -FilePath "npm.cmd" -ArgumentList @("run", "generate-client") -WorkingPath $clientDirectory
    Invoke-RequiredCommand -FilePath "npm.cmd" -ArgumentList @("run", "build") -WorkingPath $clientDirectory
}
finally {
    if ($testSiteProcess -and -not $testSiteProcess.HasExited) {
        Stop-Process -Id $testSiteProcess.Id -Force
    }
}

Write-Host ""
Write-Host "Client build flow completed."
Write-Host "Client directory : $clientDirectory"
Write-Host "TestSite project : $testSiteProjectPath"
Write-Host "Launch profile   : $resolvedLaunchProfile"
Write-Host "Application URL  : $applicationUrl"
Write-Host "Swagger URL      : $swaggerUrl"
