<#
.SYNOPSIS
  Clones a Qubic Core repository, updates seeds, peer IPs, and optionally constants from a config file, then builds Qubic.efi (Qubic.vcxproj).
  Creates the output folder if it does not exist.

.DESCRIPTION
  1. Clones the repository from a GitHub URL that points to a branch (e.g., https://github.com/qubic/core/tree/testnets/2025-03-10-release-237).
  2. Checks out the specified branch.
  3. Replaces the "computorSeeds" array with lines from SEED_LIST.
  4. Replaces the "knownPublicPeers" array with lines from PEER_LIST (IPv4 addresses).
  5. If provided, parses CONFIG_FILE (YAML) and updates constants in specified files (e.g., src/public_settings.h).
  6. If single node mode is enabled, applies specific modifications to src/qubic.cpp and src/network_core/peers.h.
  7. Builds ONLY Qubic.vcxproj (skips test projects).
  8. Copies the resulting Qubic.efi to the specified (or default) output path.

.NOTES
  Version: 1.7
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$GITHUB_URL,

    [Parameter(Mandatory=$true)]
    [string]$SEED_LIST,

    [Parameter(Mandatory=$true)]
    [string]$PEER_LIST,

    [Parameter(Mandatory=$false)]
    [string]$CONFIG_FILE,

    [Parameter(Mandatory=$false)]
    [ValidateSet('release','debug')]
    [string]$BUILD_MODE = "release",

    [Parameter(Mandatory=$false)]
    [int]$SINGLE_NODE_MODE = 0,

    [Parameter(Mandatory=$false)]
    [string]$OUTPUT_FILE_PATH
)

# Ensure powershell-yaml module is available if config file is provided
if ($CONFIG_FILE -and -not (Get-Module -ListAvailable -Name powershell-yaml)) {
    Write-Error "powershell-yaml module is required when using a config file. Please install it with: Install-Module -Name powershell-yaml -Scope CurrentUser"
    exit 1
}
if ($CONFIG_FILE) {
    Import-Module powershell-yaml
}

Write-Host "==== Qubic EFI Build Script (Qubic.vcxproj only) ===="

# Stores the original working directory to revert after the build completes
$originalDir = Get-Location

# Helper function to locate msbuild if it's not in PATH
function Get-MsBuildPath {
    Write-Host "[DEBUG] Checking for msbuild in PATH..."
    $msbuildFromPath = Get-Command msbuild.exe -ErrorAction SilentlyContinue
    if ($msbuildFromPath) {
        Write-Host "[DEBUG] Found msbuild.exe at: $($msbuildFromPath.Path)"
        return $msbuildFromPath.Path
    }

    # HARDCODED FALLBACK: Adjust to your actual MSBuild location
    $possiblePath = "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe"
    if (Test-Path $possiblePath) {
        Write-Host "[DEBUG] msbuild.exe not found in PATH; using fallback: $possiblePath"
        return $possiblePath
    }

    Write-Warning "Could not locate msbuild in PATH or at: $possiblePath. Run from a Developer Command Prompt or update the script with your MSBuild path."
    return $null
}

try {
    # Validate & resolve seed/peer files before changing directories
    Write-Host "[DEBUG] Attempting Resolve-Path on SEED_LIST: $SEED_LIST"
    $seedFullPath = Resolve-Path -LiteralPath $SEED_LIST -ErrorAction SilentlyContinue
    if (-not $seedFullPath) {
        $seedFullPath = Join-Path -Path $originalDir -ChildPath $SEED_LIST
        if (-not (Test-Path $seedFullPath -PathType Leaf)) {
            Write-Error "SEED_LIST file not found: $SEED_LIST"
            exit 1
        }
    }
    else {
        $seedFullPath = $seedFullPath.Path
    }

    Write-Host "[DEBUG] Attempting Resolve-Path on PEER_LIST: $PEER_LIST"
    $peerFullPath = Resolve-Path -LiteralPath $PEER_LIST -ErrorAction SilentlyContinue
    if (-not $peerFullPath) {
        $peerFullPath = Join-Path -Path $originalDir -ChildPath $PEER_LIST
        if (-not (Test-Path $peerFullPath -PathType Leaf)) {
            Write-Error "PEER_LIST file not found: $PEER_LIST"
            exit 1
        }
    }
    else {
        $peerFullPath = $peerFullPath.Path
    }

    # Read seed & peer contents
    $seedLines = Get-Content $seedFullPath
    $peerLines = Get-Content $peerFullPath

    # If no OUTPUT_FILE_PATH, default to <current>/Qubic.efi
    if (-not $OUTPUT_FILE_PATH) {
        $OUTPUT_FILE_PATH = Join-Path -Path $originalDir -ChildPath "Qubic.efi"
    }

    # Attempt to parse GITHUB_URL for <org>/<repo>/tree/<branch>
    $repoRegex = '^https:\/\/github\.com\/([^\/]+)\/([^\/]+)\/tree\/(.+)$'
    if ($GITHUB_URL -match $repoRegex) {
        $org        = $Matches[1]
        $repo       = $Matches[2]
        $branchName = $Matches[3]
        $cloneUrl   = "https://github.com/$org/$repo.git"
    }
    else {
        Write-Error "GITHUB_URL must be in the form https://github.com/<org>/<repo>/tree/<branch>"
        exit 1
    }

    Write-Host "Repository   : $cloneUrl"
    Write-Host "Branch       : $branchName"
    Write-Host "Seed List    : $seedFullPath"
    Write-Host "Peer List    : $peerFullPath"
    Write-Host "Build Mode   : $BUILD_MODE"
    Write-Host "Output File  : $OUTPUT_FILE_PATH"
    Write-Host ""

    # Path to Git
    $gitExe = "C:\Program Files\Git\bin\git.exe"
    $repoDir = "cloned_repo"
    if (Test-Path $repoDir) {
        Write-Host "Removing existing folder: $repoDir"
        Remove-Item -Recurse -Force $repoDir
    }

    Write-Host "Cloning repository..."
    & $gitExe clone $cloneUrl $repoDir | Out-Null

    Set-Location $repoDir
    Write-Host "Checking out branch '$branchName'..."
    & $gitExe checkout $branchName | Out-Null

    # Path to private_settings.h
    $privateSettingsPath = Join-Path (Get-Location) "src\private_settings.h"
    if (-not (Test-Path $privateSettingsPath -PathType Leaf)) {
        Write-Error "Could not find private_settings.h in src folder."
        exit 1
    }

    Write-Host "Modifying seeds and peers in private_settings.h"
    $privateSettingsContent = Get-Content $privateSettingsPath -Raw

    # Replace computorSeeds block
    $startPatternSeeds = '(static\s+unsigned\s+char\s+computorSeeds\[\]\[\s*\d+\s*\+\s*\d+\]\s*=\s*\{)'
    $endPatternSeeds   = '(\};)'
    $newSeedsBlock = "static unsigned char computorSeeds[][55 + 1] = {" + "`r`n"
    foreach ($seedLine in $seedLines) {
        $newSeedsBlock += "    $seedLine`r`n"
    }
    $newSeedsBlock += "};"
    $regexSeeds = "(?s)$startPatternSeeds.*?$endPatternSeeds"
    if ($privateSettingsContent -notmatch $regexSeeds) {
        Write-Warning "Could not find the computorSeeds block for replacement. Check your private_settings.h format."
    }
    else {
        $privateSettingsContent = [System.Text.RegularExpressions.Regex]::Replace(
            $privateSettingsContent,
            $regexSeeds,
            [System.Text.RegularExpressions.MatchEvaluator] { param($m) return $newSeedsBlock }
        )
    }

    # Replace knownPublicPeers block
    $startPatternPeers = '(static\s+const\s+unsigned\s+char\s+knownPublicPeers\[\]\[\s*\d+\]\s*=\s*\{)'
    $endPatternPeers   = '(\};)'
    $newPeerBlock = "static const unsigned char knownPublicPeers[][4] = {" + "`r`n"
    foreach ($peer in $peerLines) {
        $octets = $peer.Split('.')
        if ($octets.Count -ne 4) {
            Write-Warning "Skipping invalid IP in '$($peerFullPath)': $peer"
            continue
        }
        $ipLine = "    {" + ($octets -join ", ") + "},"
        $newPeerBlock += $ipLine + "`r`n"
    }
    $newPeerBlock += "};"
    $regexPeers = "(?s)$startPatternPeers.*?$endPatternPeers"
    if ($privateSettingsContent -notmatch $regexPeers) {
        Write-Warning "Could not find the knownPublicPeers block for replacement. Check your private_settings.h format."
    }
    else {
        $privateSettingsContent = [System.Text.RegularExpressions.Regex]::Replace(
            $privateSettingsContent,
            $regexPeers,
            [System.Text.RegularExpressions.MatchEvaluator] { param($m) return $newPeerBlock }
        )
    }

    Set-Content $privateSettingsPath $privateSettingsContent
    Write-Host "Seeds and peers have been updated in private_settings.h"

    # Process config.yaml if provided
    if ($CONFIG_FILE) {
        Write-Host "Processing config file: $CONFIG_FILE"
        $configFullPath = Resolve-Path -LiteralPath $CONFIG_FILE -ErrorAction SilentlyContinue
        if (-not $configFullPath) {
            $configFullPath = Join-Path -Path $originalDir -ChildPath $CONFIG_FILE
            if (-not (Test-Path $configFullPath -PathType Leaf)) {
                Write-Error "CONFIG_FILE not found: $CONFIG_FILE"
                exit 1
            }
        }
        else {
            $configFullPath = $configFullPath.Path
        }
        $configContent = Get-Content $configFullPath -Raw | ConvertFrom-Yaml

        foreach ($filePath in $configContent.Keys) {
            $fullFilePath = Join-Path (Get-Location) $filePath
            if (-not (Test-Path $fullFilePath -PathType Leaf)) {
                Write-Warning "File not found: $fullFilePath. Skipping."
                continue
            }
            Write-Host "Updating constants in $filePath"
            $fileContent = Get-Content $fullFilePath -Raw
            if ($configContent[$filePath].ContainsKey('constants')) {
                foreach ($constant in $configContent[$filePath]['constants'].GetEnumerator()) {
                    $varName = $constant.Name
                    $varValue = $constant.Value
                    Write-Host "[DEBUG] Replacing $varName with $varValue in $filePath"
                  # $pattern = "(#define\s+$varName\s+)\d+"
                    $pattern = "(#define\s+$varName\s+)(.+)"
                    if ($fileContent -match $pattern) {
                        $fileContent = $fileContent -replace $pattern, "`${1}$varValue"
                        Write-Host "Updated $varName to $varValue"
                    } else {
                        Write-Warning "Could not find #define $varName in $filePath. Skipping."
                    }
                }
                Set-Content $fullFilePath $fileContent
            }
        }
    } else {
        Write-Host "No config file provided. Skipping constant updates."
    }

    # Enable single node mode if specified
    if ($SINGLE_NODE_MODE -eq 1) {
        Write-Host "Enabling single node mode..."

        # Modify src/qubic.cpp
        $qubicCppPath = Join-Path (Get-Location) "src\qubic.cpp"
        if (-not (Test-Path $qubicCppPath -PathType Leaf)) {
            Write-Error "Could not find src/qubic.cpp"
            exit 1
        }
        $qubicCppLines = Get-Content $qubicCppPath
        $insertAfterPattern = "// - all votes are treated equally.*"
        $insertCode = @"
ts.ticks.acquireLock(broadcastTick.tick.computorIndex);
Tick* tsTick = ts.ticks.getByTickInCurrentEpoch(broadcastTick.tick.tick) + broadcastTick.tick.computorIndex;
// Copy the sent tick to the tick storage
bs->CopyMem(tsTick, &broadcastTick.tick, sizeof(Tick));
ts.ticks.releaseLock(broadcastTick.tick.computorIndex);
"@

        $found = $false
        $newContent = @()
        foreach ($line in $qubicCppLines) {
            $newContent += $line
            if ($line -match $insertAfterPattern) {
                $newContent += $insertCode
                $found = $true
            }
        }
        if (-not $found) {
            Write-Error "Could not find the insertion point matching pattern '$insertAfterPattern' in src/qubic.cpp"
            exit 1
        }
        Set-Content $qubicCppPath $newContent
        Write-Host "Inserted code snippet under line matching '$insertAfterPattern' in src/qubic.cpp"

        # Modify src/network_core/peers.h
        $peersHPath = Join-Path (Get-Location) "src\network_core\peers.h"
        if (-not (Test-Path $peersHPath -PathType Leaf)) {
            Write-Error "Could not find src/network_core/peers.h"
            exit 1
        }
        $peersHLines = Get-Content $peersHPath
        $replaceBeforePattern = "return \(!address.u8\[0\]"
        $insertCodePeers = "return false;"

        $found = $false
        $newContentPeers = @()
        foreach ($line in $peersHLines) {
            if ($line -match $replaceBeforePattern) {
                $newContentPeers += $insertCodePeers
                $found = $true
            }
            $newContentPeers += $line
        }
        if (-not $found) {
            Write-Error "Could not find the line matching pattern '$replaceBeforePattern' in src/network_core/peers.h"
            exit 1
        }
        Set-Content $peersHPath $newContentPeers
        Write-Host "Inserted '$insertCodePeers' above line matching '$replaceBeforePattern' in src/network_core/peers.h"
    }

    # Build Qubic.vcxproj
    $qubicProjPath = Join-Path (Get-Location) "src\Qubic.vcxproj"
    if (-not (Test-Path $qubicProjPath -PathType Leaf)) {
        Write-Error "Could not find Qubic.vcxproj in src folder."
        exit 1
    }

    Write-Host "Building ONLY Qubic.vcxproj in '$BUILD_MODE' mode..."
    $msbuildExe = Get-MsBuildPath
    if (-not $msbuildExe) {
        Write-Error "MSBuild not found. Please run from a Developer Command Prompt or set path in the script."
        exit 1
    }

    Write-Host "Using MSBuild: $msbuildExe"
    Write-Host "Project: $qubicProjPath"

    & $msbuildExe $qubicProjPath `
        /p:Configuration=$BUILD_MODE `
        /p:Platform=x64 `
        /t:Rebuild

    # Verify Qubic.efi at src\x64\<BUILD_MODE>\Qubic.efi
    $builtEfiDir = Join-Path (Get-Location) "src\x64\$BUILD_MODE"
    $builtEfi = Join-Path $builtEfiDir "Qubic.efi"
    if (-not (Test-Path $builtEfi -PathType Leaf)) {
        Write-Error "Build failed or Qubic.efi not found at $builtEfi"
        exit 1
    }

    # Prepare OUTPUT_FILE_PATH (create folder if needed)
    if (Test-Path $OUTPUT_FILE_PATH) {
        $existingItem = Get-Item $OUTPUT_FILE_PATH
        if ($existingItem.PSIsContainer -eq $true) {
            $OUTPUT_FILE_PATH = Join-Path $OUTPUT_FILE_PATH "Qubic.efi"
        }
    }
    else {
        $extension = [System.IO.Path]::GetExtension($OUTPUT_FILE_PATH)
        if ($extension -eq ".efi") {
            $destDir = [System.IO.Path]::GetDirectoryName($OUTPUT_FILE_PATH)
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
        }
        else {
            New-Item -ItemType Directory -Path $OUTPUT_FILE_PATH -Force | Out-Null
            $OUTPUT_FILE_PATH = Join-Path $OUTPUT_FILE_PATH "Qubic.efi"
        }
    }

    Write-Host "Copying $builtEfi to $OUTPUT_FILE_PATH..."
    Copy-Item -Path $builtEfi -Destination $OUTPUT_FILE_PATH -Force

    Write-Host "`n==== Build completed successfully (Qubic.efi only) ===="
    Write-Host "EFI output: $OUTPUT_FILE_PATH"
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
finally {
    Set-Location $originalDir
}
