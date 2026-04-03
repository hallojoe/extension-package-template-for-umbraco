function Get-MetadataObject {
    param(
        [string]$MetadataFile,

        [string]$WorkingDirectory = (Get-Location).Path
    )

    $candidatePaths = [System.Collections.Generic.List[string]]::new()

    if (-not [string]::IsNullOrWhiteSpace($MetadataFile)) {
        $candidatePaths.Add($MetadataFile)
    }
    else {
        if (-not [string]::IsNullOrWhiteSpace($WorkingDirectory)) {
            $candidatePaths.Add((Join-Path $WorkingDirectory "setup-metadata.json"))
        }

        $currentDirectory = (Get-Location).Path
        if (-not [string]::IsNullOrWhiteSpace($currentDirectory)) {
            $candidatePaths.Add((Join-Path $currentDirectory "setup-metadata.json"))
        }

        if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
            $candidatePaths.Add((Join-Path $PSScriptRoot "setup-metadata.json"))
        }
    }

    $seenPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($candidatePath in $candidatePaths) {
        if ([string]::IsNullOrWhiteSpace($candidatePath)) {
            continue
        }

        $absolutePath = [System.IO.Path]::GetFullPath($candidatePath)
        if (-not $seenPaths.Add($absolutePath)) {
            continue
        }

        if (-not (Test-Path -LiteralPath $absolutePath)) {
            continue
        }

        return Get-Content -Path $absolutePath -Raw | ConvertFrom-Json
    }

    return $null
}

function Get-MetadataStringProperty {
    param(
        $MetadataObject,

        [Parameter(Mandatory = $true)]
        [string[]]$PropertyNames
    )

    if ($null -eq $MetadataObject) {
        return $null
    }

    foreach ($propertyName in $PropertyNames) {
        $property = $MetadataObject.PSObject.Properties[$propertyName]
        if ($null -eq $property) {
            continue
        }

        $value = [string]$property.Value
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value.Trim()
        }
    }

    return $null
}

function Resolve-StringParameter {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$BoundParameters,

        [Parameter(Mandatory = $true)]
        [string]$ParameterName,

        [AllowEmptyString()]
        [string]$CurrentValue,

        $MetadataObject,

        [Parameter(Mandatory = $true)]
        [string[]]$MetadataPropertyNames
    )

    if ($BoundParameters.ContainsKey($ParameterName)) {
        return $CurrentValue
    }

    $metadataValue = Get-MetadataStringProperty -MetadataObject $MetadataObject -PropertyNames $MetadataPropertyNames
    if ($null -ne $metadataValue) {
        return $metadataValue
    }

    return $CurrentValue
}

function Resolve-WorkingDirectoryParameter {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$BoundParameters,

        [Parameter(Mandatory = $true)]
        [string]$CurrentValue,

        $MetadataObject
    )

    if ($BoundParameters.ContainsKey("WorkingDirectory")) {
        return $CurrentValue
    }

    $metadataWorkingDirectory = Get-MetadataStringProperty -MetadataObject $MetadataObject -PropertyNames @("workingDirectory")
    if ($null -ne $metadataWorkingDirectory) {
        return $metadataWorkingDirectory
    }

    $targetDirectory = Get-MetadataStringProperty -MetadataObject $MetadataObject -PropertyNames @("targetDirectory")
    if ($null -ne $targetDirectory) {
        return (Split-Path -Path $targetDirectory -Parent)
    }

    return $CurrentValue
}
