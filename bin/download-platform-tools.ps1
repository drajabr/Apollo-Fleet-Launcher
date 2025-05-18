$ErrorActionPreference = "Stop"

# Determine BinPath
$CurrentDir = Get-Location
$BinPath = if ($CurrentDir.Path -match "\\bin$") { "platform-tools" } else { "bin/platform-tools" }

# Record file to track downloaded versions
$RecordFile = Join-Path $BinPath "downloaded_versions.txt"

# Ensure target folder exists
if (-not (Test-Path $BinPath)) { New-Item -ItemType Directory -Force -Path $BinPath | Out-Null }

# Load saved versions into hashtable
$SavedVersions = @{}
if (Test-Path $RecordFile) {
    Get-Content $RecordFile | ForEach-Object {
        $parts = $_ -split '\|', 2
        if ($parts.Count -eq 2) { $SavedVersions[$parts[0]] = $parts[1] }
    }
}

# Save versions back to file
function SaveVersions {
    $SavedVersions.GetEnumerator() | ForEach-Object { "$($_.Key)|$($_.Value)" } | Set-Content -Path $RecordFile
}

# Download helper: apiUrl, toolName, asset filter scriptblock, optional: archive extract + move logic, optional: output file for direct download
function DownloadTool($apiUrl, $toolName, $assetFilter, $processArchive = $null, $outputFile = $null) {
    Write-Host "Fetching latest $toolName release info..."
    $json = Invoke-RestMethod -Uri $apiUrl
    $version = $json.tag_name

    if ($SavedVersions[$toolName] -eq $version) {
        Write-Host "Skipping $toolName download; version unchanged."
        return
    }

    $asset = $json.assets | Where-Object $assetFilter | Select-Object -First 1
    if (-not $asset) {
        Write-Host "No matching asset found for $toolName."
        return
    }

    Write-Host "Downloading $toolName version $version asset $($asset.name)..."

    if ($outputFile) {
        # Direct download without extraction (e.g. APK)
        if (Test-Path $outputFile) { Remove-Item $outputFile }
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $outputFile
    }
    else {
        # Download and extract
        $zipFile = "$toolName.zip"
        $tempDir = Join-Path $env:TEMP "$toolName-temp"

        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipFile

        Expand-Archive -Force -Path $zipFile -DestinationPath $tempDir

        if ($processArchive) { & $processArchive $tempDir $BinPath }

        Remove-Item $zipFile
        Remove-Item $tempDir -Recurse -Force
    }

    $SavedVersions[$toolName] = $version
    SaveVersions
}

# Extraction logic for Gnirehtet and Scrcpy
$extractAndMove = {
    param($src, $dest)
    $inner = Get-ChildItem -Path $src | Where-Object { $_.PSIsContainer } | Select-Object -First 1
    if ($inner) {
        Move-Item -Path (Join-Path $inner.FullName "*") -Destination $dest -Force
    }
}

# URLs
$GnirehtetApi = "https://api.github.com/repos/Genymobile/gnirehtet/releases/latest"
$ScrcpyApi = "https://api.github.com/repos/Genymobile/scrcpy/releases/latest"
$GnirehtetXApi = "https://api.github.com/repos/Linus789/gnirehtetx/releases/latest"

DownloadTool $GnirehtetApi "Gnirehtet" { $_.name -like "*win64*.zip" } $extractAndMove
DownloadTool $ScrcpyApi "Scrcpy" { $_.name -like "*win64*.zip" } $extractAndMove
DownloadTool $GnirehtetXApi "GnirehtetX" { $_.name -eq "app-release.apk" } $null (Join-Path $BinPath "gnirehtet.apk")

Write-Host "`n All tools downloaded and updated in '$BinPath'"
