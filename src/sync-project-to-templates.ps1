param(
    [string]$ProjectsNamespace,

    [string[]]$Include,

    [string]$MetadataFile,

    [string]$WorkingDirectory = (Get-Location).Path,

    [string]$AuthorName,

    [string]$AuthorOrganizationName,

    [string]$AuthorOrganizationUrl,

    [string]$AuthorEmail,

    [string]$TemplateDirectory,

    [switch]$Preview,

    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "script-metadata.ps1")

if ([string]::IsNullOrWhiteSpace($TemplateDirectory)) {
    $TemplateDirectory = Join-Path $PSScriptRoot "Templates"
}

$metadata = Get-MetadataObject -MetadataFile $MetadataFile -WorkingDirectory $WorkingDirectory
$ProjectsNamespace = Resolve-StringParameter -BoundParameters $PSBoundParameters -ParameterName "ProjectsNamespace" -CurrentValue $ProjectsNamespace -MetadataObject $metadata -MetadataPropertyNames @("projectsNamespace", "solutionName")
$AuthorName = Resolve-StringParameter -BoundParameters $PSBoundParameters -ParameterName "AuthorName" -CurrentValue $AuthorName -MetadataObject $metadata -MetadataPropertyNames @("authorName")
$AuthorOrganizationName = Resolve-StringParameter -BoundParameters $PSBoundParameters -ParameterName "AuthorOrganizationName" -CurrentValue $AuthorOrganizationName -MetadataObject $metadata -MetadataPropertyNames @("authorOrganizationName", "apiOrganizationName", "gitHubOrganization")
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

function ConvertTo-KebabCase {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputValue
    )

    $tokens = ConvertTo-WordTokens -InputValue $InputValue
    if ($tokens.Count -eq 0) {
        throw "Input must contain at least one letter or digit."
    }

    return [string]::Join('-', ($tokens | ForEach-Object { $_.ToLowerInvariant() }))
}

function ConvertTo-DisplayName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputValue
    )

    $tokens = ConvertTo-WordTokens -InputValue $InputValue
    if ($tokens.Count -eq 0) {
        throw "Input must contain at least one letter or digit."
    }

    return [string]::Join(' ', $tokens)
}

function ConvertTo-UpperSnakeCase {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputValue
    )

    $tokens = ConvertTo-WordTokens -InputValue $InputValue
    if ($tokens.Count -eq 0) {
        throw "Input must contain at least one letter or digit."
    }

    return [string]::Join('_', ($tokens | ForEach-Object { $_.ToUpperInvariant() }))
}

function ConvertTo-CompactNamespace {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputValue
    )

    return ($InputValue -replace '[^A-Za-z0-9]', '')
}

function ConvertTo-LowerCase {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputValue
    )

    return $InputValue.ToLowerInvariant()
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

function Test-IsTextFile {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File
    )

    $textExtensions = @(
        '.cs', '.csproj', '.json', '.yml', '.yaml', '.md', '.txt', '.sln', '.slnx',
        '.props', '.targets', '.xml', '.config', '.editorconfig', '.gitignore',
        '.js', '.ts', '.tsx', '.jsx', '.css', '.scss', '.html', '.cshtml',
        '.razor', '.sh', '.cmd', '.ps1', '.psm1', '.npmrc'
    )

    return $textExtensions -contains $File.Extension.ToLowerInvariant() -or $File.Name -in @('.gitignore', '.editorconfig')
}

function Resolve-IncludedPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathValue,

        [Parameter(Mandatory = $true)]
        [string]$ProjectSourceDirectory,

        [Parameter(Mandatory = $true)]
        [string]$SolutionDirectory
    )

    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }

    $projectCandidate = [System.IO.Path]::GetFullPath((Join-Path $ProjectSourceDirectory $PathValue))
    if (Test-Path -LiteralPath $projectCandidate) {
        return $projectCandidate
    }

    $solutionCandidate = [System.IO.Path]::GetFullPath((Join-Path $SolutionDirectory $PathValue))
    if (Test-Path -LiteralPath $solutionCandidate) {
        return $solutionCandidate
    }

    throw "Included path was not found relative to the project or solution directory: $PathValue"
}

function Assert-PathWithinDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathValue,

        [Parameter(Mandatory = $true)]
        [string]$RootDirectory
    )

    $fullPath = [System.IO.Path]::GetFullPath($PathValue)
    $separator = [System.IO.Path]::DirectorySeparatorChar
    $rootPath = [System.IO.Path]::GetFullPath($RootDirectory).TrimEnd('\', '/') + $separator

    if (-not $fullPath.StartsWith($rootPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path '$fullPath' is outside the project source directory '$rootPath'."
    }
}

$projectsNamespaceTrimmed = Get-TrimmedValue -Value $ProjectsNamespace
if ([string]::IsNullOrWhiteSpace($projectsNamespaceTrimmed)) {
    throw "ProjectsNamespace is required."
}

if ($null -eq $Include -or $Include.Count -eq 0) {
    throw "At least one -Include path is required."
}

$solutionDirectory = Join-Path $WorkingDirectory $projectsNamespaceTrimmed
if (-not (Test-Path $solutionDirectory)) {
    throw "Solution directory was not found: $solutionDirectory"
}

$projectSourceDirectory = Join-Path $solutionDirectory "src\$projectsNamespaceTrimmed"
if (-not (Test-Path $projectSourceDirectory)) {
    throw "Generated project source directory was not found: $projectSourceDirectory"
}

$testSiteProjectsNamespace = "$projectsNamespaceTrimmed.TestSite"
$testSiteSourceDirectory = Join-Path $solutionDirectory "src\$testSiteProjectsNamespace"

$namespaceCompact = ConvertTo-CompactNamespace -InputValue $projectsNamespaceTrimmed
$namespaceCompactLower = ConvertTo-LowerCase -InputValue $namespaceCompact
$namespaceKebab = ConvertTo-KebabCase -InputValue $projectsNamespaceTrimmed
$namespaceDisplayName = ConvertTo-DisplayName -InputValue $projectsNamespaceTrimmed
$namespaceUpperSnake = ConvertTo-UpperSnakeCase -InputValue $projectsNamespaceTrimmed
$serviceName = "$namespaceCompact" + "Service"
$workspaceContextConstant = "$namespaceUpperSnake" + "_WORKSPACE_CONTEXT"
$workspaceContextClass = "$namespaceCompact" + "WorkspaceContext"
$workspaceDataSourceClass = "$namespaceCompact" + "WorkspaceDataSource"
$workspaceRepositoryClass = "$namespaceCompact" + "WorkspaceRepository"
$dataSourceInterface = "$namespaceCompact" + "DataSource"
$testSiteNamespaceCompact = ConvertTo-CompactNamespace -InputValue $testSiteProjectsNamespace
$authorNameTrimmed = Get-TrimmedValue -Value ([string]$AuthorName)
$authorOrganizationNameTrimmed = Get-TrimmedValue -Value ([string]$AuthorOrganizationName)
$authorOrganizationUrlTrimmed = Get-TrimmedValue -Value ([string]$AuthorOrganizationUrl)
$authorEmailTrimmed = Get-TrimmedValue -Value ([string]$AuthorEmail)

$tokenPairs = @(
    [pscustomobject]@{ Source = $projectsNamespaceTrimmed; Target = "__TEMPLATE_PROJECTS_NAMESPACE__" },
    [pscustomobject]@{ Source = $testSiteProjectsNamespace; Target = "__TEMPLATE_TESTSITE_PROJECT_NAMESPACE__" },
    [pscustomobject]@{ Source = $namespaceCompactLower; Target = "__TEMPLATE_NAMESPACE_COMPACT_LOWER__" },
    [pscustomobject]@{ Source = $namespaceCompact; Target = "__TEMPLATE_NAMESPACE_COMPACT__" },
    [pscustomobject]@{ Source = $testSiteNamespaceCompact; Target = "__TEMPLATE_TESTSITE_NAMESPACE_COMPACT__" },
    [pscustomobject]@{ Source = $namespaceKebab; Target = "__TEMPLATE_NAMESPACE_KEBAB__" },
    [pscustomobject]@{ Source = $namespaceDisplayName; Target = "__TEMPLATE_NAMESPACE_DISPLAY_NAME__" },
    [pscustomobject]@{ Source = $namespaceUpperSnake; Target = "__TEMPLATE_NAMESPACE_UPPER_SNAKE__" },
    [pscustomobject]@{ Source = $serviceName; Target = "__TEMPLATE_NAMESPACE_COMPACT__Service" },
    [pscustomobject]@{ Source = $workspaceContextConstant; Target = "__TEMPLATE_NAMESPACE_UPPER_SNAKE__WORKSPACE_CONTEXT" },
    [pscustomobject]@{ Source = $workspaceContextClass; Target = "__TEMPLATE_NAMESPACE_COMPACT__WorkspaceContext" },
    [pscustomobject]@{ Source = $workspaceDataSourceClass; Target = "__TEMPLATE_NAMESPACE_COMPACT__WorkspaceDataSource" },
    [pscustomobject]@{ Source = $workspaceRepositoryClass; Target = "__TEMPLATE_NAMESPACE_COMPACT__WorkspaceRepository" },
    [pscustomobject]@{ Source = $dataSourceInterface; Target = "__TEMPLATE_NAMESPACE_COMPACT__DataSource" },
    [pscustomobject]@{ Source = $authorNameTrimmed; Target = "__TEMPLATE_AUTHOR_NAME__" },
    [pscustomobject]@{ Source = $authorOrganizationNameTrimmed; Target = "__TEMPLATE_AUTHOR_ORGANIZATION_NAME__" },
    [pscustomobject]@{ Source = $authorOrganizationUrlTrimmed; Target = "__TEMPLATE_AUTHOR_ORGANIZATION_URL__" },
    [pscustomobject]@{ Source = $authorEmailTrimmed; Target = "__TEMPLATE_AUTHOR_EMAIL__" }
) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.Source) } | Sort-Object { $_.Source.Length } -Descending

$templateMappings = @(
    [pscustomobject]@{
        SourceRoot = $projectSourceDirectory
        TemplateRoot = Join-Path $TemplateDirectory "src\__TEMPLATE_PROJECTS_NAMESPACE__"
    }
)

if (Test-Path -LiteralPath $testSiteSourceDirectory) {
    $templateMappings += [pscustomobject]@{
        SourceRoot = $testSiteSourceDirectory
        TemplateRoot = Join-Path $TemplateDirectory "src\__TEMPLATE_TESTSITE_PROJECT_NAMESPACE__"
    }
}

foreach ($mapping in $templateMappings) {
    if (-not (Test-Path -LiteralPath $mapping.TemplateRoot)) {
        throw "Template scaffold root was not found: $($mapping.TemplateRoot)"
    }
}

$filesToPromote = New-Object System.Collections.Generic.List[System.IO.FileInfo]
$fileMappings = New-Object System.Collections.Generic.List[object]
foreach ($includePath in $Include) {
    $resolvedPath = $null
    $resolvedMapping = $null
    foreach ($mapping in $templateMappings) {
        try {
            $candidatePath = Resolve-IncludedPath -PathValue $includePath -ProjectSourceDirectory $mapping.SourceRoot -SolutionDirectory $solutionDirectory
            Assert-PathWithinDirectory -PathValue $candidatePath -RootDirectory $mapping.SourceRoot
            $resolvedPath = $candidatePath
            $resolvedMapping = $mapping
            break
        }
        catch {
            continue
        }
    }

    if ($null -eq $resolvedPath -or $null -eq $resolvedMapping) {
        throw "Included path was not found relative to the project, TestSite project, or solution directory: $includePath"
    }

    $item = Get-Item -LiteralPath $resolvedPath
    if ($item.PSIsContainer) {
        foreach ($file in Get-ChildItem -LiteralPath $resolvedPath -Recurse -File) {
            Assert-PathWithinDirectory -PathValue $file.FullName -RootDirectory $resolvedMapping.SourceRoot
            $filesToPromote.Add($file)
            $fileMappings.Add([pscustomobject]@{
                File = $file
                Mapping = $resolvedMapping
            })
        }
        continue
    }

    $filesToPromote.Add([System.IO.FileInfo]$item)
    $fileMappings.Add([pscustomobject]@{
        File = [System.IO.FileInfo]$item
        Mapping = $resolvedMapping
    })
}

if ($filesToPromote.Count -eq 0) {
    throw "No files were selected for promotion."
}

$seenTargetPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($entry in $fileMappings | Sort-Object { $_.File.FullName } -Unique) {
    $file = $entry.File
    $mapping = $entry.Mapping
    if (-not (Test-IsTextFile -File $file)) {
        throw "Only text files are supported by sync-project-to-templates.ps1 right now: $($file.FullName)"
    }

    $relativePath = $file.FullName.Substring($mapping.SourceRoot.Length).TrimStart('\', '/')
    $templateRelativePath = Get-ReplacedValue -InputValue $relativePath -TokenPairs $tokenPairs
    $templateTargetPath = Join-Path $mapping.TemplateRoot $templateRelativePath

    if (-not $seenTargetPaths.Add($templateTargetPath)) {
        continue
    }

    if ((Test-Path -LiteralPath $templateTargetPath) -and -not $Force -and -not $Preview) {
        throw "Template file already exists: $templateTargetPath. Use -Force to overwrite it."
    }

    $content = Get-Content -LiteralPath $file.FullName -Raw
    $templateContent = Get-ReplacedValue -InputValue $content -TokenPairs $tokenPairs

    if ($Preview) {
        Write-Host "[preview] $($file.FullName) -> $templateTargetPath"
        continue
    }

    Set-Utf8FileContent -Path $templateTargetPath -Content $templateContent
    Write-Host "Promoted $($file.FullName) -> $templateTargetPath"
}

Write-Host ""
Write-Host "Project sync to templates completed."
Write-Host "Project source : $projectSourceDirectory"
Write-Host "TestSite source: $testSiteSourceDirectory"
Write-Host "Template roots : $($templateMappings.TemplateRoot -join ', ')"
