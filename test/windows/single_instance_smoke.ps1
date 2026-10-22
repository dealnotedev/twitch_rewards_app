param(
  [string]$Executable = (Join-Path $PSScriptRoot '..\..\build\windows\x64\runner\Release\twitch_listener.exe')
)

$ErrorActionPreference = 'Stop'
$executable = (Resolve-Path -LiteralPath $Executable).Path
if (Get-Process -Name twitch_listener -ErrorAction SilentlyContinue) {
  throw 'An existing Listener is running; smoke test will not touch it.'
}

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class ListenerWindowSmoke {
  [DllImport("user32.dll", CharSet = CharSet.Unicode)]
  public static extern IntPtr FindWindow(string className, string title);
  [DllImport("user32.dll")]
  public static extern bool ShowWindow(IntPtr window, int command);
  [DllImport("user32.dll")]
  public static extern bool IsIconic(IntPtr window);
  [DllImport("user32.dll")]
  public static extern bool IsZoomed(IntPtr window);
  [DllImport("user32.dll")]
  public static extern bool IsWindowVisible(IntPtr window);
  [DllImport("user32.dll")]
  public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")]
  public static extern bool PostMessage(IntPtr window, uint message, IntPtr wparam, IntPtr lparam);
}
'@

$launched = [Collections.Generic.List[Diagnostics.Process]]::new()
function Start-Listener {
  $process = Start-Process -FilePath $executable -WorkingDirectory (Split-Path $executable) -WindowStyle Hidden -PassThru
  $launched.Add($process)
  return $process
}
function Wait-Until([scriptblock]$condition, [string]$description) {
  $watch = [Diagnostics.Stopwatch]::StartNew()
  while (-not (& $condition)) {
    if ($watch.Elapsed.TotalSeconds -gt 20) { throw "Timed out: $description" }
    Start-Sleep -Milliseconds 50
  }
}
function Assert-SecondaryExits {
  $secondary = Start-Listener
  if (-not $secondary.WaitForExit(5000)) { throw 'A second Listener stayed running.' }
  if ($secondary.ExitCode -ne 0) { throw "Second launch failed: $($secondary.ExitCode)" }
}
function Close-Listener([Diagnostics.Process]$process, [IntPtr]$window) {
  [void][ListenerWindowSmoke]::PostMessage($window, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
  if (-not $process.WaitForExit(10000)) { throw 'Listener did not close normally.' }
}

try {
  # Reproduce a second launch before the owner's native window exists.
  $activation = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::AutoReset, 'Local\TwitchListener.Activate')
  $created = $false
  $gate = [Threading.Mutex]::new($false, 'Local\TwitchListener.SingleInstance', [ref]$created)
  try {
    if (-not $created) { throw 'Single-instance gate already exists.' }
    Assert-SecondaryExits
    if (-not $activation.WaitOne(1000)) { throw 'Early activation request was lost.' }
    Write-Output 'PASS: duplicate before window creation exits and queues activation'
  } finally {
    $gate.Dispose()
    $activation.Dispose()
  }

  $primary = Start-Listener
  $window = [IntPtr]::Zero
  Wait-Until {
    $script:window = [ListenerWindowSmoke]::FindWindow('FLUTTER_RUNNER_WIN32_WINDOW', 'twitch_listener')
    $script:window -ne [IntPtr]::Zero -and [ListenerWindowSmoke]::IsWindowVisible($script:window)
  } 'initial Listener window'
  Wait-Until {
    try {
      $null = Invoke-RestMethod -Uri 'http://127.0.0.1:47822/v1/health' -TimeoutSec 1
      $true
    } catch { $false }
  } 'music server startup'
  Assert-SecondaryExits
  if (@(Get-Process -Name twitch_listener).Count -ne 1) { throw 'Unexpected Listener process count.' }
  Write-Output 'PASS: normal duplicate exits successfully; only one Listener and server'

  [void][ListenerWindowSmoke]::ShowWindow($window, 6)
  Wait-Until { [ListenerWindowSmoke]::IsIconic($window) } 'minimized window'
  Assert-SecondaryExits
  Wait-Until {
    -not [ListenerWindowSmoke]::IsIconic($window) -and
      [ListenerWindowSmoke]::GetForegroundWindow() -eq $window
  } 'restored foreground window'
  Write-Output 'PASS: duplicate restores minimized Listener to foreground'

  [void][ListenerWindowSmoke]::ShowWindow($window, 3)
  Wait-Until { [ListenerWindowSmoke]::IsZoomed($window) } 'maximized window'
  Assert-SecondaryExits
  if (-not [ListenerWindowSmoke]::IsZoomed($window)) { throw 'Duplicate changed maximized state.' }
  Write-Output 'PASS: duplicate preserves maximized state'

  [void][ListenerWindowSmoke]::ShowWindow($window, 0)
  Assert-SecondaryExits
  Wait-Until {
    [ListenerWindowSmoke]::IsWindowVisible($window) -and
      [ListenerWindowSmoke]::GetForegroundWindow() -eq $window
  } 'hidden window foreground activation'
  Write-Output 'PASS: duplicate shows hidden Listener in foreground'
  Close-Listener $primary $window

  $first = Start-Listener
  $second = Start-Listener
  Wait-Until { $first.HasExited -or $second.HasExited } 'simultaneous launch loser'
  $winner = if ($first.HasExited) { $second } else { $first }
  $loser = if ($first.HasExited) { $first } else { $second }
  if ($loser.ExitCode -ne 0) { throw 'Simultaneous duplicate did not exit successfully.' }
  Wait-Until {
    $script:window = [ListenerWindowSmoke]::FindWindow('FLUTTER_RUNNER_WIN32_WINDOW', 'twitch_listener')
    $script:window -ne [IntPtr]::Zero -and [ListenerWindowSmoke]::IsWindowVisible($script:window)
  } 'simultaneous launch winner window'
  if ($winner.HasExited -or @(Get-Process -Name twitch_listener).Count -ne 1) { throw 'Simultaneous launches did not leave exactly one Listener.' }
  Write-Output 'PASS: relaunch after close and simultaneous starts leave one visible Listener'
  Close-Listener $winner $window

  $updating = [Threading.Mutex]::new($false, 'Local\TwitchListener.UpdateInProgress')
  try {
    $blocked = Start-Listener
    if (-not $blocked.WaitForExit(5000) -or $blocked.ExitCode -eq 0) { throw 'Update gate no longer blocks launch.' }
    Write-Output 'PASS: update-in-progress gate still blocks launch'
  } finally { $updating.Dispose() }

  if (Test-Path -LiteralPath (Join-Path (Split-Path $executable) 'data\flutter_assets\kernel_blob.bin')) {
    throw 'Release must not contain kernel_blob.bin.'
  }
  Write-Output 'PASS: Release excludes kernel_blob.bin'
} finally {
  foreach ($process in $launched) {
    if (-not $process.HasExited) { Stop-Process -Id $process.Id -Force }
    $process.Dispose()
  }
}
