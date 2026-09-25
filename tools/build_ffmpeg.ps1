[CmdletBinding()]
param(
  [ValidateRange(1, 32)][int]$Jobs = 4
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$repositoryDirectory = Split-Path -Parent $PSScriptRoot
$sourceDirectory = Join-Path $repositoryDirectory 'build/ffmpeg-sources'
$outputDirectory = Join-Path $repositoryDirectory 'build/ffmpeg-minimal'
New-Item -ItemType Directory -Path $sourceDirectory -Force | Out-Null

function Get-VerifiedSource {
  param([string]$Name, [string]$Uri, [string]$Sha256)
  $destination = Join-Path $sourceDirectory $Name
  if (-not (Test-Path -LiteralPath $destination)) {
    Write-Host "Downloading $Name"
    Invoke-WebRequest -Uri $Uri -OutFile $destination -UseBasicParsing
  }
  $actual = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
  if ($actual -ne $Sha256) {
    throw "SHA256 mismatch for $Name. Remove the invalid archive and retry."
  }
}

# FFmpeg's archive hash was checked against its signed release, key fingerprint
# FCF986EA15E6E293A5644F10B4322F04D67658D8. LAME's unmodified upstream tarball
# is also mirrored by Debian; its checksum matches the MSYS2 source package.
Get-VerifiedSource -Name 'ffmpeg-9.0.2.tar.xz' `
  -Uri 'https://ffmpeg.org/releases/ffmpeg-9.0.2.tar.xz' `
  -Sha256 '8c3850283eb25fa026482078a04051e0be17347b09ef81a0849bec15a96e002e'
Get-VerifiedSource -Name 'lame-3.100.tar.gz' `
  -Uri 'https://deb.debian.org/debian/pool/main/l/lame/lame_3.100.orig.tar.gz' `
  -Sha256 'ddfe36cab873794038ae2c1210557ad34857a4b6bdc515785d1da9e175b1da1e'

& docker build --progress=plain --build-arg "JOBS=$Jobs" `
  --file (Join-Path $PSScriptRoot 'ffmpeg/Dockerfile') `
  --output "type=local,dest=$outputDirectory" $sourceDirectory
if ($LASTEXITCODE -ne 0) { throw 'Minimal FFmpeg build failed. Ensure Docker is running in Linux container mode.' }

$builtExecutable = Join-Path $outputDirectory 'ffmpeg.exe'
& $builtExecutable -hide_banner -version
if ($LASTEXITCODE -ne 0) { throw 'Built FFmpeg failed to start on Windows.' }
$sha256 = (Get-FileHash -LiteralPath $builtExecutable -Algorithm SHA256).Hash.ToLowerInvariant()
$manifest = [ordered]@{
  profile = 'twitch-listener-audio-v1'
  ffmpeg = '9.0.2'
  lame = '3.100'
  sha256 = $sha256
  bytes = (Get-Item -LiteralPath $builtExecutable).Length
  recipe = 'tools/ffmpeg/Dockerfile'
  recipeSha256 = (Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'ffmpeg/Dockerfile') -Algorithm SHA256).Hash.ToLowerInvariant()
  sources = @(
    'https://ffmpeg.org/releases/ffmpeg-9.0.2.tar.xz',
    'https://deb.debian.org/debian/pool/main/l/lame/lame_3.100.orig.tar.gz'
  )
}
$manifest | ConvertTo-Json -Depth 3 | Set-Content `
  -LiteralPath (Join-Path $outputDirectory 'ffmpeg-build.json') -Encoding UTF8
Copy-Item -LiteralPath $builtExecutable -Destination (Join-Path $PSScriptRoot 'ffmpeg.exe') -Force
Copy-Item -LiteralPath (Join-Path $outputDirectory 'ffmpeg-build.json') -Destination $PSScriptRoot -Force
Copy-Item -LiteralPath (Join-Path $outputDirectory 'ffmpeg-notices') -Destination $PSScriptRoot -Recurse -Force
Write-Host "Installed minimal FFmpeg: $($manifest.bytes) bytes, SHA256 $sha256"
