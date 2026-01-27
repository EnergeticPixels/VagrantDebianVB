Param(
  [string]$KeyDir = ".vagrant_keys",
  [string]$KeyName = "vagrant_ed25519"
)

$ErrorActionPreference = "SilentlyContinue"

function Unquote([string]$s) {
  if ([string]::IsNullOrWhiteSpace($s)) { return $s }
  return $s.Trim('"', "'")
}

function Expand-EnvPath([string]$p) {
  if ([string]::IsNullOrWhiteSpace($p)) { return $p }
  $p = Unquote $p

  # Expand %FOO% style first
  $expanded = [Environment]::ExpandEnvironmentVariables($p)

  # Expand $env:FOO style if present
  if ($expanded -match '^\$env:([^\\\/]+)([\\\/]?.*)$') {
    $var = $Matches[1]; $rest = $Matches[2]
    $base = [Environment]::GetEnvironmentVariable($var,'Process')
    if (-not $base) { $base = [Environment]::GetEnvironmentVariable($var,'User') }
    if (-not $base) { $base = [Environment]::GetEnvironmentVariable($var,'Machine') }
    if ($rest) {
      $expanded = [System.IO.Path]::Combine($base, $rest.TrimStart('\','/'))
    } else {
      $expanded = $base
    }
  }
  return $expanded
}

# Normalize working directory to project root based on script location
try {
  $ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
  Set-Location $ProjectRoot
} catch {}

# Resolve the target key directory
$KeyDir = Expand-EnvPath $KeyDir
if (-not [System.IO.Path]::IsPathRooted($KeyDir)) {
  $KeyDir = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine((Get-Location).Path, $KeyDir))
}

# Build absolute paths
$KeyPath = [System.IO.Path]::Combine($KeyDir, $KeyName)
$PubPath = "$KeyPath.pub"

# Delete files if present
if ([System.IO.File]::Exists($KeyPath)) { Remove-Item -LiteralPath $KeyPath -Force }
if ([System.IO.File]::Exists($PubPath)) { Remove-Item -LiteralPath $PubPath -Force }

# Remove dir if empty
if ([System.IO.Directory]::Exists($KeyDir)) {
  $items = [System.IO.Directory]::EnumerateFileSystemEntries($KeyDir)
  if (-not $items.MoveNext()) {
    Remove-Item -LiteralPath $KeyDir -Force -Recurse
  }
}

Write-Host "✅ Removed SSH keys from $KeyDir"