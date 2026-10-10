[CmdletBinding()]
param(
    [switch]$Publish,
    [string]$NotesFile
)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Set-Location -LiteralPath $projectRoot

function Invoke-Checked {
    param([scriptblock]$Command)
    & $Command
    if ($LASTEXITCODE -ne 0) { throw "Command failed with exit code $LASTEXITCODE" }
}

$versionMatch = [regex]::Match([IO.File]::ReadAllText((Join-Path $projectRoot 'pubspec.yaml')), '(?m)^version:\s*(\d+\.\d+\.\d+\+\d+)\s*$')
if (-not $versionMatch.Success) { throw 'Expected a stable version with a build number in pubspec.yaml.' }
$releaseVersion = $versionMatch.Groups[1].Value
$releaseTag = $releaseVersion.Split('+')[0]
if ($Publish) {
    $changes = git status --porcelain
    if ($LASTEXITCODE -ne 0 -or $changes) { throw 'Commit all source changes before publishing.' }
    $releaseCommit = git rev-parse HEAD
    $releaseBranch = git branch --show-current
    $remoteHead = git ls-remote origin "refs/heads/$releaseBranch"
    if ($LASTEXITCODE -ne 0 -or -not $remoteHead -or $remoteHead.Split()[0] -ne $releaseCommit) {
        throw 'Push the current commit to origin before publishing.'
    }
}

Invoke-Checked { flutter pub get }
Invoke-Checked { flutter test }
Invoke-Checked { flutter analyze --no-fatal-infos }
Push-Location (Join-Path $projectRoot 'updater')
try {
    Invoke-Checked { flutter pub get }
    Invoke-Checked { flutter test }
    Invoke-Checked { flutter analyze --no-fatal-infos }
    Invoke-Checked { flutter build windows --release }
} finally { Pop-Location }
$previousOpusSetting = $env:NO_OPUS_OGG_LIBS
try {
    $env:NO_OPUS_OGG_LIBS = '1'
    Invoke-Checked { flutter build windows --release }
} finally { $env:NO_OPUS_OGG_LIBS = $previousOpusSetting }

# Every run gets a new directory: no stale files from older packages.
$output = Join-Path $projectRoot ("build/releases/" + $releaseVersion + '-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$payload = Join-Path $output 'payload'
$bundle = Join-Path $output 'bundle'
$updaterOutput = Join-Path $projectRoot 'updater/build/windows/x64/runner/Release'
[IO.Directory]::CreateDirectory($payload) | Out-Null
[IO.Directory]::CreateDirectory($bundle) | Out-Null

$flutterOutput = Join-Path $projectRoot 'build/windows/x64/runner/Release'
$exe = Join-Path $flutterOutput 'twitch_listener.exe'
foreach ($relative in @('tools/yt-dlp.exe', 'tools/deno.exe', 'tools/ffmpeg.exe', 'libmpv-2.dll', 'sqlite3.dll')) {
    $required = Join-Path $flutterOutput $relative
    if (-not (Test-Path -LiteralPath $required -PathType Leaf) -or (Get-Item -LiteralPath $required).Length -eq 0) {
        throw "Required release file missing or empty: $relative"
    }
}
if ([Diagnostics.FileVersionInfo]::GetVersionInfo($exe).ProductVersion -ne $releaseVersion) {
    throw 'The built executable does not match pubspec.yaml.'
}

$managedRoots = @(Get-ChildItem -LiteralPath $flutterOutput | Where-Object {
    $_.Name -notin @('updater', '.listener-update', 'listener-update.json') -and $_.Extension -notin @('.pdb', '.lib', '.exp')
} | ForEach-Object Name)
foreach ($name in $managedRoots) {
    $source = Join-Path $flutterOutput $name
    if (-not (Test-Path -LiteralPath $source)) { throw "Required release file missing: $name" }
    Copy-Item -LiteralPath $source -Destination $payload -Recurse
}
$manifest = @{
    schema = 1
    application = 'twitch_listener'
    version = $releaseVersion
    roots = @($managedRoots) + @('listener-update.json')
} | ConvertTo-Json -Depth 4
[IO.File]::WriteAllText((Join-Path $payload 'listener-update.json'), $manifest, [Text.UTF8Encoding]::new($false))

Get-ChildItem -LiteralPath $payload | Copy-Item -Destination $bundle -Recurse
$bundledUpdater = Join-Path $bundle 'updater'
[IO.Directory]::CreateDirectory($bundledUpdater) | Out-Null
Get-ChildItem -LiteralPath $updaterOutput | Where-Object { $_.Extension -notin @('.pdb', '.lib', '.exp') } | Copy-Item -Destination $bundledUpdater -Recurse

Add-Type -AssemblyName System.IO.Compression.FileSystem
$updateZip = Join-Path $output 'update.zip'
$releaseZip = Join-Path $output 'Release.zip'
[IO.Compression.ZipFile]::CreateFromDirectory($payload, $updateZip, 'Optimal', $false)
[IO.Compression.ZipFile]::CreateFromDirectory($bundle, $releaseZip, 'Optimal', $false)
foreach ($zipPath in @($updateZip, $releaseZip)) {
    $zip = [IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        if (@($zip.Entries | Where-Object { $_.Name -ieq 'kernel_blob.bin' }).Count -gt 0) {
            throw "Release archives must not contain kernel_blob.bin: $zipPath"
        }
        if (-not $zip.GetEntry('twitch_listener.exe') -or -not $zip.GetEntry('listener-update.json')) {
            throw "Invalid archive root: $zipPath"
        }
        if ($zipPath -eq $releaseZip -and -not $zip.GetEntry('updater/listener_updater.exe')) {
            throw 'The full package is missing the updater.'
        }
    } finally { $zip.Dispose() }
}
$checksums = @($updateZip, $releaseZip) | ForEach-Object {
    (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + [IO.Path]::GetFileName($_)
}
[IO.File]::WriteAllLines((Join-Path $output 'SHA256SUMS.txt'), $checksums, [Text.UTF8Encoding]::new($false))
Write-Output "Release artifacts: $output"
Write-Output 'Release.zip is the full distribution. update.zip is installed by the updater.'

if ($Publish) {
    $releaseArgs = @('release', 'create', $releaseTag, $releaseZip, $updateZip, (Join-Path $output 'SHA256SUMS.txt'),
        '--repo', 'dealnotedev/twitch_rewards_app', '--target', $releaseCommit, '--title', "Twitch Listener $releaseTag")
    if ($NotesFile) { $releaseArgs += @('--notes-file', $NotesFile) }
    else { $releaseArgs += '--generate-notes' }
    Invoke-Checked { gh @releaseArgs }
}
