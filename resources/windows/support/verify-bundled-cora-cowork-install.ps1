# Verify bundled CoraCore resources during installation.
#
# Invoked by the NSIS installer from
# `resources/windows/installer-update-verify.nsh` (macro
# CORA_COWORK_VERIFY_BUNDLED_CoraCore_RESOURCES) which always passes
# -InstallDir, -RuntimeKey and -LogPath. A non-zero exit code triggers the
# E1030 (bundled-cora-cowork-incomplete) installer failure.
#
# This script is the install-time counterpart of the build-time verifier in
# `packages/shared-scripts/src/verify-bundled-cora-cowork-resources.js`.
# Both MUST agree on:
#   - directory:  resources\bundled-cora-cowork\{runtime}\
#   - backend binary on Windows:  cora-cowork-app.exe   (NOT coracore.exe)
#   - manifest.json platform/arch fields
#   - managed-resources\node\<version>\node.exe
#   - managed-resources\acp\<tool>\<version>\{runtime}\{manifest.entrypoint,
#     package.json, package-lock.json, node_modules\, platform executable}
#
# Exit codes:
#   0 = all required resources present and non-empty
#   1 = one or more required resources missing/empty/invalid

param(
  [Parameter(Mandatory = $true)]
  [string]$InstallDir,

  [Parameter(Mandatory = $true)]
  [ValidateSet('win32-x64', 'win32-arm64')]
  [string]$RuntimeKey,

  [Parameter(Mandatory = $true)]
  [string]$LogPath
)

$ErrorActionPreference = 'Stop'

# Vendor triple used by @openai/codex-<runtimeKey> vendor layout.
$CODEX_VENDOR_TRIPLE = switch ($RuntimeKey) {
  'win32-x64'   { 'x86_64-pc-windows-msvc' }
  'win32-arm64' { 'aarch64-pc-windows-msvc' }
  default       { '' }
}

function Write-VerifyLog {
  param([string]$Message)
  try {
    $payload = [ordered]@{
      schemaVersion = 1
      ts            = (Get-Date -Format o)
      event         = 'verify-bundled-cora-cowork'
      arch          = $RuntimeKey
      instDir       = $InstallDir
      message       = $Message
    }
    Add-Content -LiteralPath $LogPath -Encoding UTF8 -Value ($payload | ConvertTo-Json -Compress -Depth 8)
  } catch {
    # Logging is best-effort; never fail the verification because of it.
  }
}

function ConvertTo-RelativeResourcePath {
  param([string]$Path)
  $resourcesRoot = Join-Path $InstallDir 'resources'
  if ($Path.StartsWith($resourcesRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    return $Path.Substring($resourcesRoot.Length).TrimStart('\').Replace('\', '/')
  }
  return $Path.Replace('\', '/')
}

function New-Failure {
  param(
    [string]$Category,
    [string]$Component,
    [string]$Version,
    [string]$Path,
    [string]$Reason
  )
  [PSCustomObject]@{
    category  = $Category
    component = $Component
    version   = $Version
    platform  = $RuntimeKey
    path      = ConvertTo-RelativeResourcePath $Path
    reason    = $Reason
  }
}

function Test-NonEmptyFile {
  param(
    [System.Collections.Generic.List[object]]$Failures,
    [string]$Component,
    [string]$Version,
    [string]$Path
  )
  $item = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
  if (-not $item -or $item.PSIsContainer) {
    $Failures.Add((New-Failure 'publish_or_install_missing' $Component $Version $Path 'missing_file')) | Out-Null
    return $false
  }
  if ($item.Length -le 0) {
    $Failures.Add((New-Failure 'publish_or_install_missing' $Component $Version $Path 'empty_file')) | Out-Null
    return $false
  }
  return $true
}

function Test-Directory {
  param(
    [System.Collections.Generic.List[object]]$Failures,
    [string]$Component,
    [string]$Version,
    [string]$Path
  )
  if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    $Failures.Add((New-Failure 'publish_or_install_missing' $Component $Version $Path 'missing_directory')) | Out-Null
    return $false
  }
  return $true
}

function Read-JsonFile {
  param([string]$Path)
  try {
    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
  } catch {
    return $null
  }
}

function Test-BundledResourcesOnce {
  $failures = [System.Collections.Generic.List[object]]::new()

  $runtimeParts = $RuntimeKey.Split('-', 2)
  $expectedPlatform = $runtimeParts[0]
  $expectedArch = $runtimeParts[1]
  $baseDir = Join-Path $InstallDir "resources\bundled-cora-cowork\$RuntimeKey"

  if (-not (Test-Directory $failures 'cora-cowork' '' $baseDir)) {
    return $failures
  }

  # Backend binary — Windows ships cora-cowork-app.exe (see prepare-cora-cowork.js getBinaryName).
  Test-NonEmptyFile $failures 'cora-cowork' '' (Join-Path $baseDir 'cora-cowork-app.exe') | Out-Null

  # manifest.json with platform/arch validation.
  $bundleManifestPath = Join-Path $baseDir 'manifest.json'
  if (Test-NonEmptyFile $failures 'cora-cowork-manifest' '' $bundleManifestPath) {
    $bundleManifest = Read-JsonFile $bundleManifestPath
    if (-not $bundleManifest) {
      $failures.Add((New-Failure 'publish_or_install_missing' 'cora-cowork-manifest' '' $bundleManifestPath 'invalid_json')) | Out-Null
    } else {
      if ($bundleManifest.platform -ne $expectedPlatform) {
        $failures.Add((New-Failure 'publish_or_install_missing' 'cora-cowork-manifest' '' $bundleManifestPath "platform_mismatch:$($bundleManifest.platform)")) | Out-Null
      }
      if ($bundleManifest.arch -ne $expectedArch) {
        $failures.Add((New-Failure 'publish_or_install_missing' 'cora-cowork-manifest' '' $bundleManifestPath "arch_mismatch:$($bundleManifest.arch)")) | Out-Null
      }
    }
  }

  # managed-resources\node\<version>\node.exe
  $nodeRoot = Join-Path $baseDir 'managed-resources\node'
  if (Test-Directory $failures 'node' '' $nodeRoot) {
    $nodeVersions = @(Get-ChildItem -LiteralPath $nodeRoot -Directory -ErrorAction SilentlyContinue)
    if ($nodeVersions.Count -eq 0) {
      $failures.Add((New-Failure 'publish_or_install_missing' 'node' '<version>' $nodeRoot 'missing_version_directory')) | Out-Null
    }
    foreach ($nodeVersion in $nodeVersions) {
      Test-NonEmptyFile $failures 'node' $nodeVersion.Name (Join-Path $nodeVersion.FullName 'node.exe') | Out-Null
    }
  }

  # managed-resources\acp\<tool>\<version>\{runtime}\...
  $tools = @(
    @{ id = 'codex-acp';        executable = "node_modules\@openai\codex-$RuntimeKey\vendor\$CODEX_VENDOR_TRIPLE\bin\codex.exe" },
    @{ id = 'claude-agent-acp'; executable = "node_modules\@anthropic-ai\claude-agent-sdk-$RuntimeKey\claude.exe" }
  )

  foreach ($tool in $tools) {
    $toolId = $tool.id
    $toolRoot = Join-Path $baseDir "managed-resources\acp\$toolId"
    if (-not (Test-Directory $failures $toolId '' $toolRoot)) {
      continue
    }

    $versions = @(Get-ChildItem -LiteralPath $toolRoot -Directory -ErrorAction SilentlyContinue)
    if ($versions.Count -eq 0) {
      $failures.Add((New-Failure 'publish_or_install_missing' $toolId '<version>' $toolRoot 'missing_version_directory')) | Out-Null
      continue
    }

    foreach ($version in $versions) {
      $platformRoot = Join-Path $version.FullName $RuntimeKey
      if (-not (Test-Directory $failures $toolId $version.Name $platformRoot)) {
        continue
      }

      $manifestPath = Join-Path $platformRoot 'manifest.json'
      if (Test-NonEmptyFile $failures $toolId $version.Name $manifestPath) {
        $manifest = Read-JsonFile $manifestPath
        if (-not $manifest) {
          $failures.Add((New-Failure 'publish_or_install_missing' $toolId $version.Name $manifestPath 'invalid_json')) | Out-Null
        } elseif (-not $manifest.entrypoint) {
          $failures.Add((New-Failure 'publish_or_install_missing' $toolId $version.Name $manifestPath 'missing_entrypoint')) | Out-Null
        } else {
          Test-NonEmptyFile $failures $toolId $version.Name (Join-Path $platformRoot $manifest.entrypoint) | Out-Null
        }
      }

      Test-NonEmptyFile $failures $toolId $version.Name (Join-Path $platformRoot 'package.json') | Out-Null
      Test-NonEmptyFile $failures $toolId $version.Name (Join-Path $platformRoot 'package-lock.json') | Out-Null
      Test-Directory $failures $toolId $version.Name (Join-Path $platformRoot 'node_modules') | Out-Null
      Test-NonEmptyFile $failures $toolId $version.Name (Join-Path $platformRoot $tool.executable) | Out-Null

      # Fallback accepted by the build-time verifier: some artifacts pack a
      # different codex layout (@zed-industries/codex-acp-<runtime>/bin/...).
      # If the primary codex.exe is missing but this alternative exists, treat
      # it as present by removing the recorded failure.
      if ($toolId -eq 'codex-acp' -and $CODEX_VENDOR_TRIPLE) {
        $altPath = Join-Path $platformRoot "node_modules\@zed-industries\codex-acp-$RuntimeKey\bin\codex-acp.exe"
        if ((Test-Path -LiteralPath $altPath) -and (Get-Item -LiteralPath $altPath).Length -gt 0) {
          $expectedRel = ConvertTo-RelativeResourcePath (Join-Path $platformRoot $tool.executable)
          for ($i = $failures.Count - 1; $i -ge 0; $i--) {
            if ($failures[$i].path -eq $expectedRel) { $failures.RemoveAt($i) }
          }
        }
      }
    }
  }

  return $failures
}

# Retry loop: the installer runs this immediately after extraction. On busy or
# AV-scanning machines files can still be finalising on disk for a moment, so
# re-check a few times before declaring failure (mirrors verify-bundled-coracore-install.ps1).
$maxAttempts = 5
for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
  $failures = @(Test-BundledResourcesOnce)
  if ($failures.Count -eq 0) {
    Write-VerifyLog "verify-bundled-cora-cowork result=ok runtime=$RuntimeKey attempts=$attempt"
    Write-Host "All bundled CoraCore resources verified successfully"
    exit 0
  }

  $summary = ($failures | ConvertTo-Json -Compress -Depth 5)
  if ($attempt -lt $maxAttempts) {
    Write-VerifyLog "verify-bundled-cora-cowork result=retry classification=resource_pending_landing runtime=$RuntimeKey attempt=$attempt failures=$summary"
    Start-Sleep -Milliseconds 500
  } else {
    Write-VerifyLog "verify-bundled-cora-cowork result=fail runtime=$RuntimeKey failures=$summary"
    Write-Warning "Missing bundled resources: $(($failures | ForEach-Object { $_.component }) -join ', ')"
  }
}

exit 1
