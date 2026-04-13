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
    [switch]$SkipTemplateInstall,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "script-metadata.ps1")
. (Join-Path $PSScriptRoot "new-extention-package-for-umbraco.shared.ps1")

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
    "--allow-scripts", "No",
    "--force",
    "-gu", $gitHubOrganizationTrimmed,
    "-gr", $repositoryNameTrimmed
)

if (-not [string]::IsNullOrWhiteSpace($authorNameTrimmed)) {
    $templateArgs += @("-an", $authorNameTrimmed)
}

Push-Location $WorkingDirectory
try {
    Write-Host "> dotnet $($templateArgs -join ' ')"
    $stdoutPath = Join-Path ([System.IO.Path]::GetTempPath()) ("umbraco-package-starter-stdout-" + [System.Guid]::NewGuid().ToString("N") + ".log")
    $stderrPath = Join-Path ([System.IO.Path]::GetTempPath()) ("umbraco-package-starter-stderr-" + [System.Guid]::NewGuid().ToString("N") + ".log")
    $templateArgumentString = ConvertTo-ProcessArgumentString -ArgumentList $templateArgs

    try {
        $process = Start-Process -FilePath "dotnet" -ArgumentList $templateArgumentString -WorkingDirectory $WorkingDirectory -Wait -NoNewWindow -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
        $templateOutput = @()

        if (Test-Path $stdoutPath) {
            $templateOutput += Get-Content -Path $stdoutPath
        }

        if (Test-Path $stderrPath) {
            $templateOutput += Get-Content -Path $stderrPath
        }
    }
    finally {
        if (Test-Path $stdoutPath) {
            Remove-Item -Path $stdoutPath -Force
        }

        if (Test-Path $stderrPath) {
            Remove-Item -Path $stderrPath -Force
        }
    }

    if ($process.ExitCode -notin @(0, 104)) {
        $templateOutput | ForEach-Object { Write-Host $_ }
        throw "Command failed with exit code $($process.ExitCode)."
    }

    $suppressedTemplateOutputPatterns = @(
        "^Execution of 'Run script' post action is not allowed\.$",
        "^Description: Setups the project by calling 'setup\.cmd'$",
        "^Manual instructions: Run 'setup\.cmd'$",
        "^Actual command: setup\.cmd\s*$",
        "^For details on the exit code, refer to https://aka\.ms/templating-exit-codes#104$"
    )

    foreach ($line in $templateOutput) {
        if ($line -eq "Processing post-creation actions..." -and $process.ExitCode -eq 104) {
            continue
        }

        if ($suppressedTemplateOutputPatterns | Where-Object { $line -match $_ }) {
            continue
        }

        Write-Host $line
    }

    if ($process.ExitCode -eq 104) {
        Write-Host "Starter template created. Skipping the template's built-in setup script and applying the repository setup directly."
    }
}
finally {
    Pop-Location
}

$sourceDirectory = Join-Path $targetDirectory "src"
$packageProjectDirectory = Join-Path $sourceDirectory $projectsNamespace
$packageProjectPath = Join-Path $packageProjectDirectory "$projectsNamespace.csproj"
$packageProjectNugetPath = Join-Path $packageProjectDirectory "${projectsNamespace}_nuget.csproj"
$testSiteProjectPath = Join-Path $sourceDirectory "$projectsNamespace.TestSite\$projectsNamespace.TestSite.csproj"
$solutionPath = Join-Path $sourceDirectory "$projectsNamespace.slnx"

Invoke-RequiredCommand -FilePath "git" -ArgumentList @("init") -WorkingPath $targetDirectory
Invoke-RequiredCommand -FilePath "git" -ArgumentList @("branch", "-M", "main") -WorkingPath $targetDirectory
Invoke-RequiredCommand -FilePath "git" -ArgumentList @("remote", "add", "origin", "https://github.com/$gitHubOrganizationTrimmed/$repositoryNameTrimmed.git") -WorkingPath $targetDirectory

Invoke-RequiredCommand -FilePath "dotnet" -ArgumentList @(
    "new",
    "umbraco-extension",
    "-n", $projectsNamespace,
    "--site-domain", "https://localhost:44356",
    "--include-example"
) -WorkingPath $sourceDirectory

if (-not (Test-Path $packageProjectNugetPath)) {
    throw "Expected package project file was not found: $packageProjectNugetPath"
}

if (Test-Path $packageProjectPath) {
    Remove-Item -Path $packageProjectPath -Force
}

Rename-Item -Path $packageProjectNugetPath -NewName "$projectsNamespace.csproj"

if (Test-CentralPackageManagementEnabled -DirectoryPath $packageProjectDirectory) {
    Update-FileText -Path $packageProjectPath -Transform {
        param($content)

        [System.Text.RegularExpressions.Regex]::Replace(
            $content,
            '(<PackageReference\s+Include="Umbraco\.Cms[^"]*")\s+Version="[^"]+"(\s*/>)',
            '${1}${2}'
        )
    }
}

Invoke-RequiredCommand -FilePath "dotnet" -ArgumentList @("sln", $solutionPath, "add", $packageProjectPath) -WorkingPath $sourceDirectory
Invoke-RequiredCommand -FilePath "dotnet" -ArgumentList @("add", $testSiteProjectPath, "reference", $packageProjectPath) -WorkingPath $sourceDirectory

$setupCmdPath = Join-Path $targetDirectory "setup.cmd"
if (Test-Path $setupCmdPath) {
    Remove-Item -Path $setupCmdPath -Force
}

$setupShPath = Join-Path $targetDirectory "setup.sh"
if (Test-Path $setupShPath) {
    Remove-Item -Path $setupShPath -Force
}

$metadataObject = [ordered]@{
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
$metadataObject | ConvertTo-Json -Depth 3 | Set-Content -Path $metadataPath -Encoding UTF8

Write-Host ""
Write-Host "Initial scaffold completed."
Write-Host "Projects namespace : $projectsNamespace"
Write-Host "Target directory   : $targetDirectory"
Write-Host "Metadata           : $metadataPath"
