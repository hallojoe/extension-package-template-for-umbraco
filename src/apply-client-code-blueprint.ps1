param(
    [string]$ProjectsNamespace,

    [string]$MetadataFile,

    [string]$WorkingDirectory = (Get-Location).Path,

    [string]$AuthorName,

    [string]$AuthorOrganizationName,

    [string]$AuthorOrganizationUrl,

    [string]$AuthorEmail,

    [string]$BlueprintDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "script-metadata.ps1")

if ([string]::IsNullOrWhiteSpace($BlueprintDirectory)) {
    $BlueprintDirectory = Join-Path $PSScriptRoot "Templates"
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

function Test-IsDictionaryLike {
    param(
        $Value
    )

    return $Value -is [System.Collections.IDictionary] -or $Value -is [pscustomobject]
}

function ConvertTo-PlainData {
    param(
        $Value
    )

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [System.Collections.IDictionary]) {
        $result = [ordered]@{}
        foreach ($key in $Value.Keys) {
            $result[$key] = ConvertTo-PlainData -Value $Value[$key]
        }

        return $result
    }

    if ($Value -is [pscustomobject]) {
        $result = [ordered]@{}
        foreach ($property in $Value.PSObject.Properties) {
            $result[$property.Name] = ConvertTo-PlainData -Value $property.Value
        }

        return $result
    }

    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        $items = New-Object System.Collections.Generic.List[object]
        foreach ($item in $Value) {
            $items.Add((ConvertTo-PlainData -Value $item))
        }

        return ,$items.ToArray()
    }

    return $Value
}

function Merge-JsonObject {
    param(
        [Parameter(Mandatory = $true)]
        $TargetValue,

        [Parameter(Mandatory = $true)]
        $TemplateValue
    )

    $targetIsObject = Test-IsDictionaryLike -Value $TargetValue
    $templateIsObject = Test-IsDictionaryLike -Value $TemplateValue

    if ($targetIsObject -and $templateIsObject) {
        $merged = [ordered]@{}

        foreach ($property in (ConvertTo-PlainData -Value $TargetValue).Keys) {
            $merged[$property] = (ConvertTo-PlainData -Value $TargetValue)[$property]
        }

        foreach ($property in (ConvertTo-PlainData -Value $TemplateValue).Keys) {
            if ($merged.Contains($property)) {
                $merged[$property] = Merge-JsonObject -TargetValue $merged[$property] -TemplateValue ((ConvertTo-PlainData -Value $TemplateValue)[$property])
            }
            else {
                $merged[$property] = (ConvertTo-PlainData -Value $TemplateValue)[$property]
            }
        }

        return $merged
    }

    return ConvertTo-PlainData -Value $TemplateValue
}

function Format-JsonString {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Json
    )

    $builder = New-Object System.Text.StringBuilder
    $indentLevel = 0
    $indentUnit = '  '
    $inString = $false
    $isEscaped = $false

    foreach ($character in $Json.ToCharArray()) {
        if ($isEscaped) {
            [void]$builder.Append($character)
            $isEscaped = $false
            continue
        }

        if ($character -eq '\') {
            [void]$builder.Append($character)
            if ($inString) {
                $isEscaped = $true
            }

            continue
        }

        if ($character -eq '"') {
            [void]$builder.Append($character)
            $inString = -not $inString
            continue
        }

        if ($inString) {
            [void]$builder.Append($character)
            continue
        }

        switch ($character) {
            '{' {
                [void]$builder.AppendLine('{')
                $indentLevel++
                [void]$builder.Append(($indentUnit * $indentLevel))
            }

            '[' {
                [void]$builder.AppendLine('[')
                $indentLevel++
                [void]$builder.Append(($indentUnit * $indentLevel))
            }

            '}' {
                [void]$builder.AppendLine()
                $indentLevel--
                [void]$builder.Append(($indentUnit * $indentLevel))
                [void]$builder.Append('}')
            }

            ']' {
                [void]$builder.AppendLine()
                $indentLevel--
                [void]$builder.Append(($indentUnit * $indentLevel))
                [void]$builder.Append(']')
            }

            ',' {
                [void]$builder.AppendLine(',')
                [void]$builder.Append(($indentUnit * $indentLevel))
            }

            ':' {
                [void]$builder.Append(': ')
            }

            default {
                if (-not [char]::IsWhiteSpace($character)) {
                    [void]$builder.Append($character)
                }
            }
        }
    }

    return $builder.ToString().Trim() + [Environment]::NewLine
}

function Merge-JsonFileContent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetPath,

        [Parameter(Mandatory = $true)]
        [string]$TemplateContent
    )

    if (-not (Test-Path -LiteralPath $TargetPath)) {
        throw "JSON merge target was not found: $TargetPath"
    }

    try {
        $targetObject = ConvertTo-PlainData -Value (Get-Content -LiteralPath $TargetPath -Raw | ConvertFrom-Json)
    }
    catch {
        throw "Target JSON file could not be parsed for merge: $TargetPath. $($_.Exception.Message)"
    }

    try {
        $templateObject = ConvertTo-PlainData -Value ($TemplateContent | ConvertFrom-Json)
    }
    catch {
        throw "Template JSON content could not be parsed for merge: $TargetPath. $($_.Exception.Message)"
    }

    if (-not (Test-IsDictionaryLike -Value $targetObject) -or -not (Test-IsDictionaryLike -Value $templateObject)) {
        throw "JSON merge only supports object roots. Target: $TargetPath"
    }

    $mergedObject = Merge-JsonObject -TargetValue $targetObject -TemplateValue $templateObject
    $mergedJson = $mergedObject | ConvertTo-Json -Depth 100 -Compress
    return Format-JsonString -Json $mergedJson
}

$projectsNamespaceTrimmed = Get-TrimmedValue -Value $ProjectsNamespace
if ([string]::IsNullOrWhiteSpace($projectsNamespaceTrimmed)) {
    throw "ProjectsNamespace is required."
}

$projectSourceDirectory = Join-Path $WorkingDirectory "src\$projectsNamespaceTrimmed"
if (-not (Test-Path $projectSourceDirectory)) {
    throw "Generated project source directory was not found: $projectSourceDirectory"
}

$testSiteProjectsNamespace = "$projectsNamespaceTrimmed.TestSite"
$testSiteSourceDirectory = Join-Path $WorkingDirectory "src\$testSiteProjectsNamespace"

$templateRoots = @(
    [pscustomobject]@{
        TemplateRoot = Join-Path $BlueprintDirectory "src\__TEMPLATE_PROJECTS_NAMESPACE__"
        TargetRoot = $projectSourceDirectory
        EnableJsonMerge = $false
    },
    [pscustomobject]@{
        TemplateRoot = Join-Path $BlueprintDirectory "src\__TEMPLATE_TESTSITE_PROJECT_NAMESPACE__"
        TargetRoot = $testSiteSourceDirectory
        EnableJsonMerge = $true
    }
)

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
    [pscustomobject]@{ Source = "__TEMPLATE_PROJECTS_NAMESPACE__"; Target = $projectsNamespaceTrimmed },
    [pscustomobject]@{ Source = "__TEMPLATE_TESTSITE_PROJECT_NAMESPACE__"; Target = $testSiteProjectsNamespace },
    [pscustomobject]@{ Source = "__TEMPLATE_NAMESPACE_COMPACT__"; Target = $namespaceCompact },
    [pscustomobject]@{ Source = "__TEMPLATE_TESTSITE_NAMESPACE_COMPACT__"; Target = $testSiteNamespaceCompact },
    [pscustomobject]@{ Source = "__TEMPLATE_NAMESPACE_COMPACT_LOWER__"; Target = $namespaceCompactLower },
    [pscustomobject]@{ Source = "__TEMPLATE_NAMESPACE_KEBAB__"; Target = $namespaceKebab },
    [pscustomobject]@{ Source = "__TEMPLATE_NAMESPACE_DISPLAY_NAME__"; Target = $namespaceDisplayName },
    [pscustomobject]@{ Source = "__TEMPLATE_NAMESPACE_UPPER_SNAKE__"; Target = $namespaceUpperSnake },
    [pscustomobject]@{ Source = "__TEMPLATE_SERVICE_NAME__"; Target = $serviceName },
    [pscustomobject]@{ Source = "__TEMPLATE_WORKSPACE_CONTEXT_CONSTANT__"; Target = $workspaceContextConstant },
    [pscustomobject]@{ Source = "__TEMPLATE_WORKSPACE_CONTEXT_CLASS__"; Target = $workspaceContextClass },
    [pscustomobject]@{ Source = "__TEMPLATE_WORKSPACE_DATASOURCE_CLASS__"; Target = $workspaceDataSourceClass },
    [pscustomobject]@{ Source = "__TEMPLATE_WORKSPACE_REPOSITORY_CLASS__"; Target = $workspaceRepositoryClass },
    [pscustomobject]@{ Source = "__TEMPLATE_DATASOURCE_INTERFACE__"; Target = $dataSourceInterface },
    [pscustomobject]@{ Source = "__TEMPLATE_AUTHOR_NAME__"; Target = $authorNameTrimmed },
    [pscustomobject]@{ Source = "__TEMPLATE_AUTHOR_ORGANIZATION_NAME__"; Target = $authorOrganizationNameTrimmed },
    [pscustomobject]@{ Source = "__TEMPLATE_AUTHOR_ORGANIZATION_URL__"; Target = $authorOrganizationUrlTrimmed },
    [pscustomobject]@{ Source = "__TEMPLATE_AUTHOR_EMAIL__"; Target = $authorEmailTrimmed }
) | Sort-Object { $_.Source.Length } -Descending

foreach ($templateMapping in $templateRoots) {
    if (-not (Test-Path -LiteralPath $templateMapping.TemplateRoot)) {
        continue
    }

    if (-not (Test-Path -LiteralPath $templateMapping.TargetRoot)) {
        throw "Generated target directory was not found: $($templateMapping.TargetRoot)"
    }

    $blueprintFiles = Get-ChildItem -Path $templateMapping.TemplateRoot -Recurse -File
    foreach ($blueprintFile in $blueprintFiles) {
        $relativePath = $blueprintFile.FullName.Substring($templateMapping.TemplateRoot.Length).TrimStart('\', '/')
        $targetRelativePath = Get-ReplacedValue -InputValue $relativePath -TokenPairs $tokenPairs
        $targetPath = Join-Path $templateMapping.TargetRoot $targetRelativePath

        $content = Get-Content -Path $blueprintFile.FullName -Raw
        $updatedContent = Get-ReplacedValue -InputValue $content -TokenPairs $tokenPairs

        if ($templateMapping.EnableJsonMerge -and $blueprintFile.Extension.Equals('.json', [System.StringComparison]::OrdinalIgnoreCase)) {
            $updatedContent = Merge-JsonFileContent -TargetPath $targetPath -TemplateContent $updatedContent
        }

        Set-Utf8FileContent -Path $targetPath -Content $updatedContent
    }
}

Write-Host ""
Write-Host "Template overlay applied."
Write-Host "Project target   : $projectSourceDirectory"
Write-Host "TestSite target  : $testSiteSourceDirectory"
