param(
    [string]$ProjectsNamespace,

    [string]$MetadataFile,

    [string]$WorkingDirectory = (Get-Location).Path,

    [string]$DotNetVersion = "10.0.x",

    [string]$NodeVersion = "22",

    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "script-metadata.ps1")

$metadata = Get-MetadataObject -MetadataFile $MetadataFile -WorkingDirectory $WorkingDirectory
$ProjectsNamespace = Resolve-StringParameter -BoundParameters $PSBoundParameters -ParameterName "ProjectsNamespace" -CurrentValue $ProjectsNamespace -MetadataObject $metadata -MetadataPropertyNames @("projectsNamespace", "solutionName")
$WorkingDirectory = Resolve-WorkingDirectoryParameter -BoundParameters $PSBoundParameters -CurrentValue $WorkingDirectory -MetadataObject $metadata

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

function Assert-CanWriteFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [bool]$ForceWrite
    )

    if ((Test-Path $Path) -and -not $ForceWrite) {
        throw "File already exists: $Path. Use -Force to overwrite it."
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

$srcDirectory = Join-Path $solutionDirectory "src"
$packageProjectRelative = "src/$projectsNamespaceTrimmed/$projectsNamespaceTrimmed.csproj"
$testsProjectRelative = "src/$projectsNamespaceTrimmed.Tests/$projectsNamespaceTrimmed.Tests.csproj"
$testSiteProjectRelative = "src/$projectsNamespaceTrimmed.TestSite/$projectsNamespaceTrimmed.TestSite.csproj"
$clientDirRelative = "src/$projectsNamespaceTrimmed/Client"

$packageProjectPath = Join-Path $solutionDirectory $packageProjectRelative
$testsProjectPath = Join-Path $solutionDirectory $testsProjectRelative
$testSiteProjectPath = Join-Path $solutionDirectory $testSiteProjectRelative
$clientDirPath = Join-Path $solutionDirectory $clientDirRelative

if (-not (Test-Path $packageProjectPath)) {
    throw "Package project was not found: $packageProjectPath"
}

if (-not (Test-Path $clientDirPath)) {
    throw "Client directory was not found: $clientDirPath"
}

$hasTestsProject = Test-Path $testsProjectPath
$hasTestSiteProject = Test-Path $testSiteProjectPath

$githubWorkflowsDirectory = Join-Path $solutionDirectory ".github\workflows"
$ciWorkflowPath = Join-Path $githubWorkflowsDirectory "ci-build.yml"
$publishWorkflowPath = Join-Path $githubWorkflowsDirectory "publish-github-packages.yml"
$releaseWorkflowPath = Join-Path $githubWorkflowsDirectory "release.yml"

Assert-CanWriteFile -Path $ciWorkflowPath -ForceWrite $Force
Assert-CanWriteFile -Path $publishWorkflowPath -ForceWrite $Force

$ciEnvLines = @(
    "  DOTNET_VERSION: $DotNetVersion",
    "  NODE_VERSION: $NodeVersion",
    "  PACKAGE_PROJECT: $packageProjectRelative",
    "  CLIENT_DIR: $clientDirRelative"
)

if ($hasTestsProject) {
    $ciEnvLines += "  TEST_PROJECT: $testsProjectRelative"
}

if ($hasTestSiteProject) {
    $ciEnvLines += "  TESTSITE_PROJECT: $testSiteProjectRelative"
}

$buildStepLines = @(
    '      - name: Restore package project',
    '        run: dotnet restore "${{ env.PACKAGE_PROJECT }}"',
    ''
)

if ($hasTestsProject) {
    $buildStepLines += @(
        '      - name: Restore tests project',
        '        run: dotnet restore "${{ env.TEST_PROJECT }}"',
        ''
    )
}

if ($hasTestSiteProject) {
    $buildStepLines += @(
        '      - name: Restore local test site project',
        '        run: dotnet restore "${{ env.TESTSITE_PROJECT }}"',
        ''
    )
}

$buildStepLines += @(
    '      - name: Build package project',
    '        run: dotnet build "${{ env.PACKAGE_PROJECT }}" --configuration Release --no-restore',
    ''
)

if ($hasTestsProject) {
    $buildStepLines += @(
        '      - name: Build tests project',
        '        run: dotnet build "${{ env.TEST_PROJECT }}" --configuration Release --no-restore',
        ''
    )
}

if ($hasTestSiteProject) {
    $buildStepLines += @(
        '      - name: Build local test site project',
        '        run: dotnet build "${{ env.TESTSITE_PROJECT }}" --configuration Release --no-restore',
        ''
    )
}

$buildStepLines += @(
    '      - name: Install client dependencies',
    '        working-directory: ${{ env.CLIENT_DIR }}',
    '        run: npm ci',
    '',
    '      - name: Build backoffice client',
    '        working-directory: ${{ env.CLIENT_DIR }}',
    '        run: npm run build'
)

$testJobLines = @()
if ($hasTestsProject) {
    $testJobLines = @(
        "",
        '  test:',
        '    runs-on: ubuntu-latest',
        '    needs: build',
        '',
        '    steps:',
        '      - name: Checkout',
        '        uses: actions/checkout@v5',
        '',
        '      - name: Setup .NET',
        '        uses: actions/setup-dotnet@v5',
        '        with:',
        '          dotnet-version: ${{ env.DOTNET_VERSION }}',
        '',
        '      - name: Restore tests project',
        '        run: dotnet restore "${{ env.TEST_PROJECT }}"',
        '',
        '      - name: Run tests',
        '        run: dotnet test "${{ env.TEST_PROJECT }}" --configuration Release --no-restore'
    )
}

$ciWorkflowContent = (@(
    'name: CI Build Validation',
    '',
    'on:',
    '  push:',
    '    branches:',
    '      - develop',
    '      - main',
    '  pull_request:',
    '    branches:',
    '      - develop',
    '      - main',
    '',
    'permissions:',
    '  contents: read',
    '',
    'env:'
) + $ciEnvLines + @(
    '',
    'jobs:',
    '  build:',
    '    runs-on: ubuntu-latest',
    '',
    '    steps:',
    '      - name: Checkout',
    '        uses: actions/checkout@v5',
    '',
    '      - name: Setup .NET',
    '        uses: actions/setup-dotnet@v5',
    '        with:',
    '          dotnet-version: ${{ env.DOTNET_VERSION }}',
    '',
    '      - name: Setup Node.js',
    '        uses: actions/setup-node@v6',
    '        with:',
    '          node-version: ${{ env.NODE_VERSION }}',
    '          cache: npm',
    '          cache-dependency-path: ${{ env.CLIENT_DIR }}/package-lock.json',
    ''
) + $buildStepLines + $testJobLines) -join "`r`n"

$publishWorkflowTemplate = @'
name: Publish NuGet package to GitHub Packages

on:
  release:
    types: [published]

permissions:
  contents: read
  packages: write

env:
  DOTNET_VERSION: __DOTNET_VERSION__
  PROJECT_FILE: __PROJECT_FILE__
  PACKAGE_SOURCE: https://nuget.pkg.github.com/${{ github.repository_owner }}/index.json

jobs:
  publish:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v5

      - name: Setup .NET
        uses: actions/setup-dotnet@v5
        with:
          dotnet-version: ${{ env.DOTNET_VERSION }}

      - name: Derive and validate package version
        id: versioning
        shell: bash
        run: |
          set -euo pipefail

          TAG="${{ github.event.release.tag_name }}"
          TARGET_BRANCH="${{ github.event.release.target_commitish }}"

          echo "Release tag: $TAG"
          echo "Target branch: $TARGET_BRANCH"

          if [[ ! "$TAG" =~ ^v.+ ]]; then
            echo "::error::Release tag must start with 'v'. Got: $TAG"
            exit 1
          fi

          VERSION="${TAG#v}"

          if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z][0-9A-Za-z.-]*)?$ ]]; then
            echo "::error::Derived version is not valid: $VERSION"
            exit 1
          fi

          if [[ "$VERSION" == *-* ]]; then
            IS_PRERELEASE=true
          else
            IS_PRERELEASE=false
          fi

          if [[ "$IS_PRERELEASE" == "false" && "$TARGET_BRANCH" != "main" ]]; then
            echo "::error::Stable releases are only allowed from 'main'. Tag '$TAG' targets '$TARGET_BRANCH'."
            exit 1
          fi

          if [[ "$IS_PRERELEASE" == "true" && "$TARGET_BRANCH" == "main" ]]; then
            echo "::error::Prerelease versions are not allowed from 'main'. Tag '$TAG' targets '$TARGET_BRANCH'."
            exit 1
          fi

          echo "package_version=$VERSION" >> "$GITHUB_OUTPUT"
          echo "is_prerelease=$IS_PRERELEASE" >> "$GITHUB_OUTPUT"

          echo "Resolved package version: $VERSION"
          echo "Prerelease: $IS_PRERELEASE"

      - name: Restore
        run: dotnet restore "${{ env.PROJECT_FILE }}"

      - name: Pack
        run: |
          dotnet pack "${{ env.PROJECT_FILE }}" \
            --configuration Release \
            --no-restore \
            -p:Version=${{ steps.versioning.outputs.package_version }} \
            -o ./artifacts

      - name: Push package to GitHub Packages
        env:
          GITHUB_TOKEN: ${{ secrets.NUGET_GITHUB_TOKEN }}
        shell: bash
        run: |
          set -euo pipefail
          shopt -s nullglob

          packages=(./artifacts/*.nupkg)
          symbols=(./artifacts/*.snupkg)

          if [ ${#packages[@]} -eq 0 ]; then
            echo "::error::No .nupkg files were produced."
            exit 1
          fi

          for pkg in "${packages[@]}"; do
            if [[ "$pkg" == *.snupkg ]]; then
              continue
            fi

            echo "Pushing $pkg"
            dotnet nuget push "$pkg" \
              --source "${{ env.PACKAGE_SOURCE }}" \
              --api-key "$GITHUB_TOKEN" \
              --skip-duplicate
          done

          if [ ${#symbols[@]} -gt 0 ]; then
            echo "::notice::Symbol packages were produced but are not being pushed in this workflow."
          fi

      - name: Summarize
        run: |
          echo "Published version: ${{ steps.versioning.outputs.package_version }}"
          echo "Prerelease: ${{ steps.versioning.outputs.is_prerelease }}"
          echo "Package source: ${{ env.PACKAGE_SOURCE }}"
'@

$publishWorkflowContent = $publishWorkflowTemplate.Replace('__DOTNET_VERSION__', $DotNetVersion).Replace('__PROJECT_FILE__', $packageProjectRelative)

Set-Utf8FileContent -Path $ciWorkflowPath -Content $ciWorkflowContent
Set-Utf8FileContent -Path $publishWorkflowPath -Content $publishWorkflowContent

if (Test-Path $releaseWorkflowPath) {
    Remove-Item -Path $releaseWorkflowPath -Force
}

Write-Host ""
Write-Host "GitHub workflows created."
Write-Host "CI workflow      : $ciWorkflowPath"
Write-Host "Publish workflow : $publishWorkflowPath"
Write-Host "Release workflow : removed if present"
Write-Host "Tests detected   : $hasTestsProject"
Write-Host "TestSite detected: $hasTestSiteProject"
