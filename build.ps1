#requires -Version 5.1
<#
.SYNOPSIS
    Build (and optionally run) the WinUI/WPF port of Apollo Fleet Launcher.
.PARAMETER Configuration
    Debug (default) or Release.
.PARAMETER Run
    Launch the built ApolloFleet.App.exe after a successful build.
.PARAMETER Clean
    Run `dotnet clean` before building.
.PARAMETER Test
    Run the test project after build.
.PARAMETER Publish
    Create a self-contained single-file publish in dist\<Configuration>\<Runtime>.
.PARAMETER Runtime
    Runtime identifier used for publish. Default: win-x64.
.EXAMPLE
    .\build.ps1 -Run
    .\build.ps1 -Configuration Release -Clean -Test
    .\build.ps1 -Configuration Release -Publish
#>
[CmdletBinding()]
param(
    [ValidateSet('Debug','Release')]
    [string]$Configuration = 'Debug',
    [switch]$Run,
    [switch]$Clean,
    [switch]$Test,
    [switch]$Publish,
    [string]$Runtime = 'win-x64'
)

$ErrorActionPreference = 'Stop'
$repoRoot   = $PSScriptRoot
$solution   = Join-Path $repoRoot 'src\ApolloFleet.sln'
$appProject = Join-Path $repoRoot 'src\ApolloFleet.App\ApolloFleet.App.csproj'
$appExe     = Join-Path $repoRoot "src\ApolloFleet.App\bin\$Configuration\net8.0-windows\ApolloFleet.App.exe"
$publishDir = Join-Path $repoRoot "dist\$Configuration\$Runtime"
$publishedExe = Join-Path $publishDir 'ApolloFleet.App.exe'

if (-not (Test-Path $solution)) {
    throw "Solution not found at $solution"
}

# Kill any running instance so the build can replace locked binaries.
Get-Process -ErrorAction SilentlyContinue |
    Where-Object { $_.ProcessName -like 'ApolloFleet*' } |
    Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 400

Push-Location $repoRoot
try {
    if ($Clean) {
        Write-Host "==> dotnet clean ($Configuration)" -ForegroundColor Cyan
        dotnet clean $solution -c $Configuration --nologo | Out-Host
    }

    Write-Host "==> dotnet build ($Configuration)" -ForegroundColor Cyan
    dotnet build $solution -c $Configuration --nologo
    if ($LASTEXITCODE -ne 0) { throw "Build failed (exit $LASTEXITCODE)." }

    if ($Test) {
        Write-Host "==> dotnet test ($Configuration)" -ForegroundColor Cyan
        dotnet test $solution -c $Configuration --nologo --no-build
        if ($LASTEXITCODE -ne 0) { throw "Tests failed (exit $LASTEXITCODE)." }
    }

    if ($Run) {
        $exeToRun = if ($Publish) { $publishedExe } else { $appExe }
        if (-not (Test-Path $exeToRun)) { throw "App exe not found at $exeToRun" }
        Write-Host "==> launching $exeToRun" -ForegroundColor Cyan
        Start-Process -FilePath $exeToRun
    }

    if ($Publish) {
        Write-Host "==> dotnet publish ($Configuration, $Runtime, single-file)" -ForegroundColor Cyan
        dotnet publish $appProject -c $Configuration -r $Runtime --self-contained true --nologo -o $publishDir /p:PublishSingleFile=true /p:EnableCompressionInSingleFile=true /p:IncludeNativeLibrariesForSelfExtract=true /p:DebugType=None /p:DebugSymbols=false
        if ($LASTEXITCODE -ne 0) { throw "Publish failed (exit $LASTEXITCODE)." }
        Write-Host "==> published to $publishDir" -ForegroundColor Green
    }
}
finally {
    Pop-Location
}
