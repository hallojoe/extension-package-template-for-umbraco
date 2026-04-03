param(
    [string]$ProjectsNamespace,

    [string]$MetadataFile,

    [string]$WorkingDirectory = (Get-Location).Path,

    [string]$TemplateIdentity = "Casko.ExtensionPackageTemplateForUmbraco",

    [string]$TemplateShortName = "extensionpackagetemplateforumbraco",

    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "script-metadata.ps1")

$metadata = Get-MetadataObject -MetadataFile $MetadataFile -WorkingDirectory $WorkingDirectory
$ProjectsNamespace = Resolve-StringParameter -BoundParameters $PSBoundParameters -ParameterName "ProjectsNamespace" -CurrentValue $ProjectsNamespace -MetadataObject $metadata -MetadataPropertyNames @("projectsNamespace", "solutionName")
$WorkingDirectory = Resolve-WorkingDirectoryParameter -BoundParameters $PSBoundParameters -CurrentValue $WorkingDirectory -MetadataObject $metadata

function Get-JsonFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return Get-Content -Path $Path -Raw | ConvertFrom-Json
}

function Get-TrimmedValue {
    param(
        [AllowEmptyString()]
        [string]$Value
    )

    if ($null -eq $Value) {
        return ""
    }

    return $Value.Trim()
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

function Get-TokenizedValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputValue,

        [Parameter(Mandatory = $true)]
        [System.Collections.IEnumerable]$TokenPairs
    )

    $result = $InputValue
    foreach ($pair in $TokenPairs) {
        $result = $result.Replace($pair.Source, $pair.Token)
    }

    return $result
}

function Get-RelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BasePath,

        [Parameter(Mandatory = $true)]
        [string]$FullPath
    )

    $resolvedBasePath = (Resolve-Path $BasePath).Path
    $resolvedFullPath = (Resolve-Path $FullPath).Path
    $relativePath = [System.IO.Path]::GetRelativePath($resolvedBasePath, $resolvedFullPath)

    return $relativePath.Replace('\', '/')
}

function Test-ExcludedDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    if ($Name -in @('.git', '.vs', 'bin', 'obj', 'node_modules', 'TEMP')) {
        return $true
    }

    if ($RelativePath -like 'src/*/wwwroot/App_Plugins' -or $RelativePath -like 'src/*/wwwroot/App_Plugins/*') {
        return $true
    }

    return $false
}

function Test-ExcludedFile {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File,

        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    if ($File.Name -eq 'setup-metadata.json') {
        return $true
    }

    if ($File.Name -eq 'release.yml') {
        return $true
    }

    if ($File.Name -like '*.log' -or $File.Name -like '*.nupkg' -or $File.Name -like '*.snupkg') {
        return $true
    }

    if ($File.Name -like 'appsettings-schema*.json' -or $File.Name -eq 'umbraco-package-schema.json') {
        return $true
    }

    if ($RelativePath -like 'src/*/wwwroot/App_Plugins/*') {
        return $true
    }

    return $false
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

function Get-DetectedAuthorName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageProjectPath
    )

    $projectContent = Get-Content -Path $PackageProjectPath -Raw
    $match = [System.Text.RegularExpressions.Regex]::Match($projectContent, '<Authors>(.*?)</Authors>')
    if ($match.Success) {
        return $match.Groups[1].Value
    }

    return 'Unknown Author'
}

function Get-ApiAlias {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectsNamespaceValue
    )

    return ($ProjectsNamespaceValue -replace '[^A-Za-z0-9]', '').ToLowerInvariant()
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

function ConvertTo-DisplayName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputValue
    )

    $tokens = ConvertTo-WordTokens -InputValue $InputValue
    if ($tokens.Count -eq 0) {
        return ""
    }

    return [string]::Join(' ', $tokens)
}

function ConvertTo-KebabCase {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputValue
    )

    $tokens = ConvertTo-WordTokens -InputValue $InputValue
    if ($tokens.Count -eq 0) {
        return ""
    }

    return [string]::Join('-', ($tokens | ForEach-Object { $_.ToLowerInvariant() }))
}

function New-TokenPair {
    param(
        [AllowEmptyString()]
        [string]$Source,

        [Parameter(Mandatory = $true)]
        [string]$Token
    )

    if ([string]::IsNullOrWhiteSpace($Source)) {
        return $null
    }

    return [pscustomobject]@{
        Source = $Source
        Token = $Token
    }
}

function Copy-SanitizedTree {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath,

        [Parameter(Mandatory = $true)]
        [System.Collections.IEnumerable]$TokenPairs
    )

    if (-not (Test-Path $DestinationPath)) {
        New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
    }

    foreach ($item in Get-ChildItem -Path $SourcePath -Force) {
        $relativePath = Get-RelativePath -BasePath $SourcePath -FullPath $item.FullName
        $tokenizedItemName = Get-TokenizedValue -InputValue $item.Name -TokenPairs $TokenPairs
        $destinationItemPath = Join-Path $DestinationPath $tokenizedItemName

        if ($item.PSIsContainer) {
            if (Test-ExcludedDirectory -Name $item.Name -RelativePath $relativePath) {
                continue
            }

            Copy-SanitizedTree -SourcePath $item.FullName -DestinationPath $destinationItemPath -TokenPairs $TokenPairs
            continue
        }

        if (Test-ExcludedFile -File $item -RelativePath $relativePath) {
            continue
        }

        if (Test-IsTextFile -File $item) {
            $content = Get-Content -Path $item.FullName -Raw
            $content = Get-TokenizedValue -InputValue $content -TokenPairs $TokenPairs

            Set-Utf8FileContent -Path $destinationItemPath -Content $content
        }
        else {
            $destinationDirectory = Split-Path -Path $destinationItemPath -Parent
            if (-not (Test-Path $destinationDirectory)) {
                New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
            }

            Copy-Item -Path $item.FullName -Destination $destinationItemPath -Force
        }
    }
}

$projectsNamespaceTrimmed = $ProjectsNamespace.Trim()
if ([string]::IsNullOrWhiteSpace($projectsNamespaceTrimmed)) {
    throw "ProjectsNamespace is required."
}

$solutionDirectory = Join-Path $WorkingDirectory $projectsNamespaceTrimmed
if (-not (Test-Path $solutionDirectory)) {
    throw "Solution directory was not found: $solutionDirectory"
}

$metadataPath = Join-Path $solutionDirectory 'setup-metadata.json'
if (-not (Test-Path $metadataPath)) {
    throw "setup-metadata.json was not found: $metadataPath"
}

$metadata = Get-JsonFile -Path $metadataPath
$solutionName = [string]$metadata.solutionName
$solutionDescription = [string]$metadata.solutionDescription
$gitHubOrganization = [string]$metadata.gitHubOrganization
$repositoryName = [string]$metadata.repositoryName
$authorOrganizationName = Get-MetadataStringProperty -MetadataObject $metadata -PropertyNames @("authorOrganizationName", "apiOrganizationName", "gitHubOrganization")
$authorOrganizationUrl = Get-MetadataStringProperty -MetadataObject $metadata -PropertyNames @("authorOrganizationUrl", "apiOrganizationUrl")
$authorEmail = Get-MetadataStringProperty -MetadataObject $metadata -PropertyNames @("authorEmail", "apiContactEmail")
$currentApiAlias = Get-ApiAlias -ProjectsNamespaceValue $projectsNamespaceTrimmed
$currentNamespaceCompact = $projectsNamespaceTrimmed -replace '[^A-Za-z0-9]', ''
$currentNamespaceDisplayName = ConvertTo-DisplayName -InputValue $projectsNamespaceTrimmed
$currentNamespaceKebab = ConvertTo-KebabCase -InputValue $projectsNamespaceTrimmed

$packageProjectDirectory = Join-Path (Join-Path $solutionDirectory 'src') $projectsNamespaceTrimmed
$packageProjectPath = Join-Path $packageProjectDirectory "$projectsNamespaceTrimmed.csproj"
if (-not (Test-Path $packageProjectPath)) {
    throw "Package project was not found: $packageProjectPath"
}

$authorName = Get-DetectedAuthorName -PackageProjectPath $packageProjectPath

$templateOutputDirectory = Join-Path $WorkingDirectory "$projectsNamespaceTrimmed.Template"
if (Test-Path $templateOutputDirectory) {
    if (-not $Force) {
        throw "Template output directory already exists: $templateOutputDirectory. Use -Force to recreate it."
    }

    Remove-Item -Path $templateOutputDirectory -Recurse -Force
}

$tokenPairs = @(
    New-TokenPair -Source $projectsNamespaceTrimmed -Token $projectsNamespaceTrimmed
    New-TokenPair -Source $currentNamespaceDisplayName -Token '__TEMPLATE_NAMESPACE_DISPLAY_NAME__'
    New-TokenPair -Source $currentNamespaceKebab -Token '__TEMPLATE_NAMESPACE_KEBAB__'
    New-TokenPair -Source $currentNamespaceCompact -Token '__TEMPLATE_NAMESPACE_COMPACT__'
    New-TokenPair -Source $currentApiAlias -Token '__TEMPLATE_API_ALIAS__'
    New-TokenPair -Source $currentApiAlias -Token '__TEMPLATE_NAMESPACE_COMPACT_LOWER__'
    New-TokenPair -Source $solutionName -Token '__TEMPLATE_SOLUTION_NAME__'
    New-TokenPair -Source $solutionDescription -Token '__TEMPLATE_SOLUTION_DESCRIPTION__'
    New-TokenPair -Source $gitHubOrganization -Token '__TEMPLATE_GITHUB_ORGANIZATION__'
    New-TokenPair -Source $repositoryName -Token '__TEMPLATE_REPOSITORY_NAME__'
    New-TokenPair -Source $authorName -Token '__TEMPLATE_AUTHOR_NAME__'
    New-TokenPair -Source $authorOrganizationName -Token '__TEMPLATE_AUTHOR_ORGANIZATION_NAME__'
    New-TokenPair -Source $authorOrganizationUrl -Token '__TEMPLATE_AUTHOR_ORGANIZATION_URL__'
    New-TokenPair -Source $authorEmail -Token '__TEMPLATE_AUTHOR_EMAIL__'
) | Where-Object { $null -ne $_ } | Sort-Object { $_.Source.Length } -Descending

Copy-SanitizedTree -SourcePath $solutionDirectory -DestinationPath $templateOutputDirectory -TokenPairs $tokenPairs

$templateConfigDirectory = Join-Path $templateOutputDirectory '.template.config'
$templateJsonPath = Join-Path $templateConfigDirectory 'template.json'
$templateDisplayName = "$solutionName Template"

$templateJsonContent = @"
{
  "`$schema": "http://json.schemastore.org/template",
  "author": "$authorName",
  "classifications": [
    "Web",
    "Umbraco",
    "Package",
    "Casko"
  ],
  "identity": "$TemplateIdentity",
  "name": "$templateDisplayName",
  "shortName": "$TemplateShortName",
  "sourceName": "$projectsNamespaceTrimmed",
  "preferNameDirectory": true,
  "tags": {
    "language": "C#",
    "type": "solution"
  },
  "primaryOutputs": [
    {
      "path": "src/$projectsNamespaceTrimmed.slnx"
    }
  ],
  "symbols": {
    "SolutionName": {
      "type": "parameter",
      "datatype": "text",
      "defaultValue": "$solutionName",
      "description": "Friendly solution name.",
      "replaces": "__TEMPLATE_SOLUTION_NAME__"
    },
    "SolutionDescription": {
      "type": "parameter",
      "datatype": "text",
      "defaultValue": "$solutionDescription",
      "description": "Solution description.",
      "replaces": "__TEMPLATE_SOLUTION_DESCRIPTION__"
    },
    "GitHubOrganization": {
      "type": "parameter",
      "datatype": "text",
      "defaultValue": "$gitHubOrganization",
      "description": "GitHub organization or user.",
      "replaces": "__TEMPLATE_GITHUB_ORGANIZATION__"
    },
    "RepositoryName": {
      "type": "parameter",
      "datatype": "text",
      "defaultValue": "$repositoryName",
      "description": "Repository name.",
      "replaces": "__TEMPLATE_REPOSITORY_NAME__"
    },
    "AuthorName": {
      "type": "parameter",
      "datatype": "text",
      "defaultValue": "$authorName",
      "description": "Author name.",
      "replaces": "__TEMPLATE_AUTHOR_NAME__"
    },
    "AuthorOrganizationName": {
      "type": "parameter",
      "datatype": "text",
      "defaultValue": "$authorOrganizationName",
      "description": "Author organization name.",
      "replaces": "__TEMPLATE_AUTHOR_ORGANIZATION_NAME__"
    },
    "AuthorOrganizationUrl": {
      "type": "parameter",
      "datatype": "text",
      "defaultValue": "$authorOrganizationUrl",
      "description": "Author organization URL.",
      "replaces": "__TEMPLATE_AUTHOR_ORGANIZATION_URL__"
    },
    "AuthorEmail": {
      "type": "parameter",
      "datatype": "text",
      "defaultValue": "$authorEmail",
      "description": "Author contact email.",
      "replaces": "__TEMPLATE_AUTHOR_EMAIL__"
    },
    "NamespaceDisplayName": {
      "type": "parameter",
      "datatype": "text",
      "defaultValue": "$currentNamespaceDisplayName",
      "description": "Display name derived from the projects namespace.",
      "replaces": "__TEMPLATE_NAMESPACE_DISPLAY_NAME__"
    },
    "NamespaceKebab": {
      "type": "derived",
      "valueSource": "name",
      "valueTransform": "ReplaceNonAlphanumericWithHyphen",
      "description": "Projects namespace in kebab-case, used for client filenames and imports.",
      "replaces": "__TEMPLATE_NAMESPACE_KEBAB__",
      "fileRename": "__TEMPLATE_NAMESPACE_KEBAB__"
    },
    "NamespaceCompact": {
      "type": "derived",
      "valueSource": "name",
      "valueTransform": "RemoveNonAlphanumeric",
      "description": "Projects namespace without separators, used for class names and file renames.",
      "replaces": "__TEMPLATE_NAMESPACE_COMPACT__",
      "fileRename": "__TEMPLATE_NAMESPACE_COMPACT__"
    },
    "NamespaceCompactLower": {
      "type": "generated",
      "generator": "casing",
      "parameters": {
        "source": "NamespaceCompact",
        "toLower": true
      },
      "description": "Lowercase compact namespace for API names and other identifiers.",
      "replaces": "__TEMPLATE_NAMESPACE_COMPACT_LOWER__"
    },
    "ApiAlias": {
      "type": "generated",
      "generator": "casing",
      "parameters": {
        "source": "NamespaceCompact",
        "toLower": true
      },
      "description": "Lowercase API alias used in controller routes, manifests, and generated client URLs.",
      "replaces": "__TEMPLATE_API_ALIAS__"
    }
  },
  "forms": {
    "RemoveNonAlphanumeric": {
      "identifier": "replace",
      "pattern": "[^A-Za-z0-9]",
      "replacement": ""
    },
    "ReplaceNonAlphanumericWithHyphen": {
      "identifier": "replace",
      "pattern": "[^A-Za-z0-9]+",
      "replacement": "-"
    }
  }
}
"@

Set-Utf8FileContent -Path $templateJsonPath -Content $templateJsonContent

Write-Host ""
Write-Host "Dotnet template generated."
Write-Host "Source solution   : $solutionDirectory"
Write-Host "Template output   : $templateOutputDirectory"
Write-Host "Template identity : $TemplateIdentity"
Write-Host "Template shortName: $TemplateShortName"
