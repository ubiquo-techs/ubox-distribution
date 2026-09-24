# ubox-update.ps1 - checks the player and every enabled node against their CDN
# manifests, updates whatever's stale, then launches ubox.exe.
#
# Invoked by ubox-start.bat. Not meant to be run interactively, though it's
# safe to double-click on its own for testing.
#
# Why this exists outside ubox.exe: a self-replacing exe (download a new
# version, rename over itself, re-exec) is exactly the behavioral shape
# Windows Defender's ML heuristics flag as a trojan dropper. Moving the whole
# check-and-replace step here means ubox.exe itself never downloads or
# overwrites anything, for itself or for any node.

$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
$uboxExe = Join-Path $here "ubox.exe"

function Get-RemoteJson {
    param([string]$Url)
    try {
        return Invoke-RestMethod -Uri $Url -Headers @{ "ngrok-skip-browser-warning" = "1" } -TimeoutSec 15
    } catch {
        Write-Warning "manifest fetch failed ($Url): $($_.Exception.Message)"
        return $null
    }
}

function Get-LocalVersion {
    param([string]$ExePath)
    $versionFile = "$ExePath.version"
    if (Test-Path $versionFile) {
        return (Get-Content $versionFile -Raw).Trim()
    }
    return ""
}

function Set-LocalVersion {
    param([string]$ExePath, [string]$Version)
    $noBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText("$ExePath.version", $Version, $noBom)
}

function Stop-ProcessByPath {
    param([string]$ExePath)
    Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -eq $ExePath } |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 300
}

# Downloads and extracts $ManifestUrl's zip over $ExePath if its version
# differs from the local <exe>.version sidecar. Retries the extract a couple
# times - a process we just killed can hold the file briefly even after exit.
function Update-Binary {
    param([string]$ExePath, [string]$ManifestUrl, [string]$Label)

    $manifest = Get-RemoteJson $ManifestUrl
    if (-not $manifest) {
        Write-Host "[$Label] manifest unavailable, skipping update check"
        return
    }

    $localVersion = Get-LocalVersion $ExePath
    if ($manifest.version -eq $localVersion) {
        Write-Host "[$Label] up to date (v$localVersion)"
        return
    }

    Write-Host "[$Label] updating v$localVersion -> v$($manifest.version)..."
    Stop-ProcessByPath $ExePath

    $tmpZip = Join-Path $env:TEMP "ubox-update-$([guid]::NewGuid()).zip"
    try {
        Invoke-WebRequest -Uri $manifest.url -OutFile $tmpZip -Headers @{ "ngrok-skip-browser-warning" = "1" }

        $destDir = Split-Path $ExePath -Parent
        New-Item -ItemType Directory -Force $destDir | Out-Null

        $attempts = 0
        while ($true) {
            $attempts++
            try {
                Expand-Archive -Path $tmpZip -DestinationPath $destDir -Force
                break
            } catch {
                if ($attempts -ge 3) { throw }
                Start-Sleep -Milliseconds 500
            }
        }

        Set-LocalVersion $ExePath $manifest.version
        Write-Host "[$Label] updated to v$($manifest.version)"
    } catch {
        Write-Warning "[$Label] update failed, will run with existing binary: $($_.Exception.Message)"
    } finally {
        Remove-Item $tmpZip -Force -ErrorAction SilentlyContinue
    }
}

# 1. Ask ubox.exe (possibly still the old version) what to check. Read-only -
#    no self-modification involved in this call.
$planJson = & $uboxExe print-update-plan 2>$null
if (-not $planJson) {
    Write-Warning "could not read update plan from ubox.exe - launching as-is"
} else {
    $plan = $planJson | ConvertFrom-Json

    if ($plan.update_url) {
        Update-Binary -ExePath $uboxExe -ManifestUrl $plan.update_url -Label "player"
    }

    foreach ($node in $plan.nodes) {
        if ($node.enabled -and $node.manifest_url) {
            Update-Binary -ExePath $node.script -ManifestUrl $node.manifest_url -Label $node.id
        }
    }
}

# 2. Launch the now-up-to-date player.
Start-Process -FilePath $uboxExe -ArgumentList "--via-launcher" -WorkingDirectory $here
