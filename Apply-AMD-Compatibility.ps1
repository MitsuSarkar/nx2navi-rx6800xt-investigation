# Independently written helper published by MitsuSarkar with Codex assistance.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$GameDirectory,
    [switch]$ResetPrewarmMarkers
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $GameDirectory).Path
if (-not (Test-Path -LiteralPath (Join-Path $root 'ocarina.exe'))) {
    throw 'Choose the game folder containing ocarina.exe.'
}
if (Get-Process -Name ocarina -ErrorAction SilentlyContinue) {
    throw 'Save and close all ocarina game instances before running this helper.'
}
$ini = Join-Path $root 'nx2navi.ini'
if (-not (Test-Path -LiteralPath $ini)) { throw 'nx2navi.ini was not found.' }
$backup = Join-Path $root ('diagnostics\amd-compatibility-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $backup | Out-Null
Copy-Item -LiteralPath $ini -Destination (Join-Path $backup 'nx2navi.ini.before')
$text = [IO.File]::ReadAllText($ini)
$pattern = '(?im)^[ \t]*(?:NX2NAVI_)?gpl[ \t]*=.*$'
if ([regex]::IsMatch($text, $pattern)) {
    $text = [regex]::Replace($text, $pattern, 'gpl = 0')
} else {
    $text += "`r`n[renderer compatibility]`r`n# AMD Vulkan pipeline-library compatibility workaround.`r`ngpl = 0`r`n"
}
[IO.File]::WriteAllText($ini, $text, [Text.UTF8Encoding]::new($false))
if ($ResetPrewarmMarkers) {
    foreach ($name in 'pipeline-prewarm-skip.txt','pipeline-prewarm-running.txt') {
        $file = Join-Path $root $name
        if (Test-Path -LiteralPath $file) {
            Move-Item -LiteralPath $file -Destination (Join-Path $backup $name)
        }
    }
}
Write-Output "Applied gpl = 0. Backup: $backup"
Write-Output 'Launch normally and allow pipeline preparation to finish. This helper does not launch or stop the game.'
Write-Output 'Saves, executable and pipeline/shader caches were not changed by this helper.'
