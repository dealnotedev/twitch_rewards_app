<#
.SYNOPSIS
  Keeps tools\yt-dlp.exe at the release pinned in tools\yt-dlp.json.

.DESCRIPTION
  Without parameters, the script does nothing when the existing executable has
  the pinned SHA-256. Otherwise it downloads the pinned release and replaces the
  executable only after its SHA-256 matches the pin. The Windows build runs this
  before packaging.

  -Update pins a new release: the latest stable one, or -Version. Its SHA-256 is
  taken from the release's SHA2-256SUMS and written to tools\yt-dlp.json.
#>
[CmdletBinding()]
param(
  [switch]$Update,
  [string]$Version
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
# MSBuild can inherit another PowerShell edition's module search path. Load the
# utility cmdlets from the running host so hashing and downloads work there too.
Import-Module (Join-Path $PSHOME 'Modules\Microsoft.PowerShell.Utility\Microsoft.PowerShell.Utility.psd1')
[Net.ServicePointManager]::SecurityProtocol =
  [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$toolDirectory = $PSScriptRoot
$pinPath = Join-Path $toolDirectory 'yt-dlp.json'
$executablePath = Join-Path $toolDirectory 'yt-dlp.exe'
$downloadPath = Join-Path $toolDirectory 'yt-dlp.exe.download'
$releases = 'https://github.com/yt-dlp/yt-dlp/releases'

function Get-Sha256 {
  param([Parameter(Mandatory = $true)][string]$Path)
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Assert-Version {
  param([Parameter(Mandatory = $true)][string]$Value)
  # Release tags look like 2026.08.19 or 2026.08.19.1; never build URLs from
  # anything else.
  if ($Value -notmatch '^\d{4}\.\d{2}\.\d{2}(\.\d+)?$') {
    throw "Unexpected yt-dlp version '$Value'"
  }
}

if ($Update) {
  if (-not $Version) {
    $Version = (Invoke-RestMethod -UseBasicParsing `
        -Uri 'https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest').tag_name
  }
  Assert-Version $Version
  $sums = (Invoke-WebRequest -UseBasicParsing `
      -Uri "$releases/download/$Version/SHA2-256SUMS").Content
  if ($sums -is [byte[]]) { $sums = [Text.Encoding]::UTF8.GetString($sums) }
  $match = [Text.RegularExpressions.Regex]::Match(
    $sums,
    '(?im)^([a-f0-9]{64})\s+\*?yt-dlp\.exe\s*$'
  )
  if (-not $match.Success) {
    throw "yt-dlp.exe checksum was not found for release $Version"
  }
  $sha256 = $match.Groups[1].Value.ToLowerInvariant()
  # Written by hand: ConvertTo-Json formatting differs between PowerShell
  # versions. UTF-8 without BOM keeps the file readable by other tools.
  [IO.File]::WriteAllText(
    $pinPath,
    "{`n  `"version`": `"$Version`",`n  `"sha256`": `"$sha256`"`n}`n",
    (New-Object Text.UTF8Encoding($false))
  )
  Write-Host "Pinned yt-dlp $Version in $pinPath"
}

$pin = Get-Content -LiteralPath $pinPath -Raw | ConvertFrom-Json
Assert-Version $pin.version
$expected = ([string]$pin.sha256).Trim().ToLowerInvariant()
if ($expected -notmatch '^[a-f0-9]{64}$') {
  throw "Invalid yt-dlp SHA-256 in $pinPath"
}

if ((Test-Path -LiteralPath $executablePath) -and
    ((Get-Sha256 $executablePath) -eq $expected)) {
  Write-Host "yt-dlp $($pin.version) is up to date."
  exit 0
}

Write-Host "Downloading yt-dlp $($pin.version)"
try {
  Invoke-WebRequest -UseBasicParsing `
    -Uri "$releases/download/$($pin.version)/yt-dlp.exe" `
    -OutFile $downloadPath
  $actual = Get-Sha256 $downloadPath
  if ($actual -ne $expected) {
    throw "SHA-256 mismatch for yt-dlp $($pin.version). Expected $expected, got $actual"
  }
  Move-Item -LiteralPath $downloadPath -Destination $executablePath -Force
  Write-Host "yt-dlp $($pin.version) downloaded and verified."
}
finally {
  if (Test-Path -LiteralPath $downloadPath) {
    Remove-Item -LiteralPath $downloadPath -Force
  }
}
