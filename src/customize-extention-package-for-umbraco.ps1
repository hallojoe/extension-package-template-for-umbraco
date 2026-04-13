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
    [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "script-metadata.ps1")
. (Join-Path $PSScriptRoot "new-extention-package-for-umbraco.shared.ps1")

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
$scaffoldMetadataPath = Join-Path $targetDirectory "setup-metadata.json"
if (-not (Test-Path $scaffoldMetadataPath)) {
    throw "Scaffold metadata was not found: $scaffoldMetadataPath"
}

$scaffoldMetadata = Get-JsonFile -Path $scaffoldMetadataPath
$solutionDescriptionTrimmed = if ([string]::IsNullOrWhiteSpace($solutionDescriptionTrimmed)) { Get-TrimmedValue -Value ([string]$scaffoldMetadata.solutionDescription) } else { $solutionDescriptionTrimmed }
$gitHubOrganizationTrimmed = if ([string]::IsNullOrWhiteSpace($gitHubOrganizationTrimmed)) { Get-TrimmedValue -Value ([string]$scaffoldMetadata.gitHubOrganization) } else { $gitHubOrganizationTrimmed }
$repositoryNameTrimmed = if ([string]::IsNullOrWhiteSpace($repositoryNameTrimmed)) { Get-TrimmedValue -Value ([string]$scaffoldMetadata.repositoryName) } else { $repositoryNameTrimmed }
$authorNameTrimmed = if ([string]::IsNullOrWhiteSpace($authorNameTrimmed)) { Get-TrimmedValue -Value ([string]$scaffoldMetadata.authorName) } else { $authorNameTrimmed }
$authorOrganizationNameTrimmed = if ([string]::IsNullOrWhiteSpace($authorOrganizationNameTrimmed)) { Get-TrimmedValue -Value ([string]$scaffoldMetadata.authorOrganizationName) } else { $authorOrganizationNameTrimmed }
$authorOrganizationUrlTrimmed = if ([string]::IsNullOrWhiteSpace($authorOrganizationUrlTrimmed)) { Get-TrimmedValue -Value ([string]$scaffoldMetadata.authorOrganizationUrl) } else { $authorOrganizationUrlTrimmed }
$authorEmailTrimmed = if ([string]::IsNullOrWhiteSpace($authorEmailTrimmed)) { Get-TrimmedValue -Value ([string]$scaffoldMetadata.authorEmail) } else { $authorEmailTrimmed }
$apiName = if ([string]::IsNullOrWhiteSpace($apiName)) { Get-TrimmedValue -Value ([string]$scaffoldMetadata.apiName) } else { $apiName }
$apiGroup = if ([string]::IsNullOrWhiteSpace($apiGroup)) { Get-TrimmedValue -Value ([string]$scaffoldMetadata.apiGroup) } else { $apiGroup }
$apiDescription = if ([string]::IsNullOrWhiteSpace($apiDescription)) { Get-TrimmedValue -Value ([string]$scaffoldMetadata.apiDescription) } else { $apiDescription }
$umbracoTemplateVersion = Get-TrimmedValue -Value ([string]$scaffoldMetadata.umbracoTemplateVersion)
if ([string]::IsNullOrWhiteSpace($umbracoTemplateVersion)) {
    throw "The scaffold metadata did not contain 'umbracoTemplateVersion': $scaffoldMetadataPath"
}

$sourceDirectory = Join-Path $targetDirectory "src"
$packageProjectDirectory = Join-Path $sourceDirectory $projectsNamespace
$projectFilePath = Join-Path $packageProjectDirectory "$projectsNamespace.csproj"
$githubReadmePath = Join-Path $targetDirectory ".github\README.md"
$nugetReadmePath = Join-Path $targetDirectory "docs\README_nuget.md"
$umbracoMarketplacePath = Join-Path $targetDirectory "umbraco-marketplace.json"

Update-FileText -Path $githubReadmePath -Transform {
    param($content)
    $content.Replace("Umbraco.Community.", "")
}

Update-FileText -Path $nugetReadmePath -Transform {
    param($content)
    $content.Replace("Umbraco.Community.", "")
}

if (Test-Path $umbracoMarketplacePath) {
    $umbracoMarketplace = Get-JsonFile -Path $umbracoMarketplacePath
    $umbracoMarketplace.Title = $solutionNameTrimmed
    $umbracoMarketplace.Description = $solutionDescriptionTrimmed
    $umbracoMarketplace | ConvertTo-Json -Depth 10 | Set-Content -Path $umbracoMarketplacePath -Encoding UTF8
}

Update-FileText -Path $projectFilePath -Transform {
    param($content)

    $updated = $content.Replace("Umbraco.Community.", "")
    $updated = [System.Text.RegularExpressions.Regex]::Replace($updated, '<Title>.*?</Title>', "<Title>$apiGroup</Title>")
    $updated = [System.Text.RegularExpressions.Regex]::Replace($updated, '<Description>.*?</Description>', "<Description>$apiDescription</Description>")
    $updated
}

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

$projectFiles = Get-ChildItem -Path $sourceDirectory -Recurse -Filter *.csproj -File -ErrorAction SilentlyContinue
foreach ($projectFile in $projectFiles) {
    $projectDirectory = Split-Path -Path $projectFile.FullName -Parent
    if (Test-CentralPackageManagementEnabled -DirectoryPath $projectDirectory) {
        continue
    }

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

$powerShellExecutable = Get-PowerShellExecutable

Invoke-RequiredCommand -FilePath $powerShellExecutable -ArgumentList @(
    "-ExecutionPolicy", "Bypass",
    "-File", $addUmbracoTestProjectScriptPath,
    "-ProjectsNamespace", $projectsNamespace,
    "-WorkingDirectory", $WorkingDirectory
) -WorkingPath $WorkingDirectory

Invoke-RequiredCommand -FilePath $powerShellExecutable -ArgumentList @(
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

    Invoke-RequiredCommand -FilePath $powerShellExecutable -ArgumentList $applyBlueprintArguments -WorkingPath $WorkingDirectory
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
Write-Host "Metadata           : $scaffoldMetadataPath"
Write-Host "Skills             : $(Join-Path $targetDirectory '.agents/skills')"
Write-Host "Tests script       : $addUmbracoTestProjectScriptPath"
Write-Host "GitHub actions     : $addGitHubActionsScriptPath"
