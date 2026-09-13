# ============================================================
#  Zylos Extension Installer / Uninstaller
#  Installs the Zylos Chrome extension via Windows Registry
#  (HKLM machine-wide force-install — applies to ALL profiles)
#
#  Usage:
#    Install   -> powershell -ExecutionPolicy Bypass -File install_extension.ps1
#    Uninstall -> powershell -ExecutionPolicy Bypass -File install_extension.ps1 -Uninstall
#    Specify path -> -ExtensionDir "C:\MyPath\zylos_extension"
#
#  Requires Administrator rights (writes to HKLM).
# ============================================================

param(
    [string]$ExtensionDir = "",
    [switch]$Uninstall
)

# ── CONFIG ────────────────────────────────────────────────────────────────────
# This 32-char ID is derived from the extension key / CRX hash.
# For an unpacked (developer) install we generate a stable ID from the folder path.
# The ID below matches the one used by Zylos (consistent across installs).
$ExtensionId  = "zylosmediadownloaderchromeextens"   # 32 chars, a-p only
$ExtVersion   = "1.0.0"
$ExtName      = "Zylos Downloader"

# Registry paths
$RegHKLM      = "HKLM:\SOFTWARE\Google\Chrome\Extensions\$ExtensionId"
$RegHKCU      = "HKCU:\Software\Google\Chrome\Extensions\$ExtensionId"
$RegPolicy    = "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist"
$RegPolicyCU  = "HKCU:\Software\Policies\Google\Chrome\ExtensionInstallForcelist"

# ── HELPERS ────────────────────────────────────────────────────────────────────
function Write-Step  { param($msg) Write-Host "  $msg" -ForegroundColor Cyan }
function Write-OK    { param($msg) Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Warn  { param($msg) Write-Host "  [!!] $msg" -ForegroundColor Yellow }
function Write-Fail  { param($msg) Write-Host "  [ERR] $msg" -ForegroundColor Red }
function Write-Title { param($msg) Write-Host "`n=== $msg ===" -ForegroundColor Magenta }

function Test-IsAdmin {
    $id  = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $pri = [System.Security.Principal.WindowsPrincipal]$id
    return $pri.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ── RESOLVE EXTENSION DIRECTORY ───────────────────────────────────────────────
if ([string]::IsNullOrWhiteSpace($ExtensionDir)) {
    $ExtensionDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
}
$ExtensionDir = (Resolve-Path -LiteralPath $ExtensionDir -ErrorAction Stop).Path.TrimEnd('\')

# ─────────────────────────────────────────────────────────────────────────────
# UNINSTALL
# ─────────────────────────────────────────────────────────────────────────────
if ($Uninstall) {
    Write-Title "Zylos Extension Uninstaller"

    # Remove HKLM key
    if (Test-Path $RegHKLM) {
        try {
            Remove-Item -Path $RegHKLM -Recurse -Force
            Write-OK "Removed HKLM registry key."
        } catch { Write-Fail "Could not remove HKLM key: $($_.Exception.Message)" }
    } else { Write-Warn "HKLM key not found (already removed?)." }

    # Remove HKCU key
    if (Test-Path $RegHKCU) {
        try {
            Remove-Item -Path $RegHKCU -Recurse -Force
            Write-OK "Removed HKCU registry key."
        } catch { Write-Fail "Could not remove HKCU key: $($_.Exception.Message)" }
    }

    # Remove from force-install policy list (HKLM)
    if (Test-Path $RegPolicy) {
        try {
            $vals = Get-ItemProperty -Path $RegPolicy
            $vals.PSObject.Properties | Where-Object {
                $_.MemberType -eq 'NoteProperty' -and $_.Name -notmatch '^PS' -and $_.Value -like "*$ExtensionId*"
            } | ForEach-Object {
                Remove-ItemProperty -Path $RegPolicy -Name $_.Name -Force
                Write-OK "Removed force-install policy entry: $($_.Name)"
            }
        } catch { Write-Warn "Could not clean policy list: $($_.Exception.Message)" }
    }

    # Remove External Extensions JSON descriptor for each profile
    $ChromeUserData = "$env:LOCALAPPDATA\Google\Chrome\User Data"
    $ExtJsonFile    = "$ChromeUserData\External Extensions\$ExtensionId.json"
    if (Test-Path $ExtJsonFile) {
        Remove-Item -LiteralPath $ExtJsonFile -Force
        Write-OK "Removed External Extensions descriptor."
    }

    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "  Zylos Extension UNINSTALLED successfully"   -ForegroundColor Cyan
    Write-Host "  Restart Chrome for changes to take effect." -ForegroundColor White
    Write-Host "=============================================" -ForegroundColor Cyan
    #  Also generate a .reg removal file for quick re-use
    $RemoveReg = Join-Path $ExtensionDir "uninstall_extension.reg"
    @"
Windows Registry Editor Version 5.00

; Zylos Extension - Remove all registry entries
[-HKEY_LOCAL_MACHINE\SOFTWARE\Google\Chrome\Extensions\$ExtensionId]
[-HKEY_CURRENT_USER\Software\Google\Chrome\Extensions\$ExtensionId]
"@ | Set-Content -LiteralPath $RemoveReg -Encoding ASCII
    Write-OK "Also wrote: uninstall_extension.reg (run as admin to remove reg keys again)"
    exit 0
}

# ─────────────────────────────────────────────────────────────────────────────
# INSTALL
# ─────────────────────────────────────────────────────────────────────────────
Write-Title "Zylos Extension Installer"

# ── Admin check for HKLM writes ───────────────────────────────────────────────
$isAdmin = Test-IsAdmin
if (-not $isAdmin) {
    Write-Warn "Not running as Administrator. Falling back to HKCU (current user only)."
    Write-Warn "For machine-wide install (all users / all profiles), re-run as Admin."
    $UseHKLM = $false
} else {
    $UseHKLM = $true
}

# ── Verify extension folder + manifest ────────────────────────────────────────
Write-Step "Extension folder : $ExtensionDir"
$ManifestPath = Join-Path $ExtensionDir "manifest.json"
if (-not (Test-Path $ManifestPath)) {
    Write-Fail "manifest.json not found in: $ExtensionDir"
    exit 1
}
try {
    $Manifest   = Get-Content $ManifestPath -Raw | ConvertFrom-Json
    $ExtVersion = $Manifest.version
    $ExtName    = $Manifest.name
    Write-OK "Manifest loaded  : $ExtName v$ExtVersion"
} catch {
    Write-Warn "Could not parse manifest.json — using defaults."
}

# ── Write HKLM / HKCU extension registry key ──────────────────────────────────
# Chrome looks here for externally-installed paths:
#   HKLM\SOFTWARE\Google\Chrome\Extensions\<ID>
#     path    = "C:\full\path\to\extension_folder"
#     version = "1.0.0"
$TargetReg = if ($UseHKLM) { $RegHKLM } else { $RegHKCU }
Write-Step "Writing registry extension entry..."
try {
    if (-not (Test-Path $TargetReg)) { New-Item -Path $TargetReg -Force | Out-Null }
    Set-ItemProperty -Path $TargetReg -Name "path"    -Value $ExtensionDir
    Set-ItemProperty -Path $TargetReg -Name "version" -Value $ExtVersion
    Write-OK "Wrote: $TargetReg"
} catch {
    Write-Fail "Could not write registry key: $($_.Exception.Message)"
    exit 2
}

# ── Also write HKCU if we're admin (belt-and-suspenders for all profiles) ──────
if ($UseHKLM -and ($RegHKCU -ne $RegHKLM)) {
    try {
        if (-not (Test-Path $RegHKCU)) { New-Item -Path $RegHKCU -Force | Out-Null }
        Set-ItemProperty -Path $RegHKCU -Name "path"    -Value $ExtensionDir
        Set-ItemProperty -Path $RegHKCU -Name "version" -Value $ExtVersion
        Write-OK "Wrote: $RegHKCU"
    } catch { Write-Warn "Could not write HKCU key: $($_.Exception.Message)" }
}

# ── Write External Extensions descriptor (alternative mechanism) ───────────────
$ChromeUserData = "$env:LOCALAPPDATA\Google\Chrome\User Data"
$ChromeExtDir   = "$ChromeUserData\External Extensions"
if (Test-Path $ChromeUserData) {
    if (-not (Test-Path $ChromeExtDir)) {
        New-Item -Path $ChromeExtDir -ItemType Directory -Force | Out-Null
    }
    $ExtJson     = @{ external_path = $ExtensionDir } | ConvertTo-Json -Compress
    $ExtJsonFile = Join-Path $ChromeExtDir "$ExtensionId.json"
    try {
        $ExtJson | Set-Content -LiteralPath $ExtJsonFile -Encoding ASCII
        Write-OK "External extension descriptor: $ExtJsonFile"
    } catch { Write-Warn "Could not write descriptor: $($_.Exception.Message)" }
} else {
    Write-Warn "Chrome User Data not found — descriptor not written."
}

# ── Generate install.reg file for easy re-install on other machines ─────────
$RegFilePath = Join-Path $ExtensionDir "install_extension.reg"
$RegPathEscaped = $ExtensionDir.Replace('\', '\\')
@"
Windows Registry Editor Version 5.00

; ============================================================
;  Zylos Extension - Force Install for ALL Chrome profiles
;  Run this file as Administrator to install.
;
;  Extension : $ExtName
;  Version   : $ExtVersion
;  Path      : $ExtensionDir
; ============================================================

[HKEY_LOCAL_MACHINE\SOFTWARE\Google\Chrome\Extensions\$ExtensionId]
"path"="$RegPathEscaped"
"version"="$ExtVersion"

[HKEY_CURRENT_USER\Software\Google\Chrome\Extensions\$ExtensionId]
"path"="$RegPathEscaped"
"version"="$ExtVersion"
"@ | Set-Content -LiteralPath $RegFilePath -Encoding ASCII
Write-OK "Generated: install_extension.reg  (double-click as Admin to install on any machine)"

# ── Generate uninstall.reg file ────────────────────────────────────────────────
$RemoveRegPath = Join-Path $ExtensionDir "uninstall_extension.reg"
@"
Windows Registry Editor Version 5.00

; ============================================================
;  Zylos Extension - Remove from ALL Chrome profiles
;  Run this file as Administrator to uninstall.
; ============================================================

[-HKEY_LOCAL_MACHINE\SOFTWARE\Google\Chrome\Extensions\$ExtensionId]
[-HKEY_CURRENT_USER\Software\Google\Chrome\Extensions\$ExtensionId]
"@ | Set-Content -LiteralPath $RemoveRegPath -Encoding ASCII
Write-OK "Generated: uninstall_extension.reg  (double-click as Admin to uninstall)"

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "  Zylos Extension INSTALLED successfully"     -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "  Name     : $ExtName v$ExtVersion"           -ForegroundColor White
Write-Host "  ID       : $ExtensionId"                    -ForegroundColor White
Write-Host "  Path     : $ExtensionDir"                   -ForegroundColor White
Write-Host "  Scope    : $( if ($UseHKLM) { 'Machine-wide (all users)' } else { 'Current user only' } )" -ForegroundColor White
Write-Host ""
Write-Host "  NEXT STEPS:" -ForegroundColor Yellow
Write-Host "  1. Fully close Chrome (check Task Manager for chrome.exe)" -ForegroundColor White
Write-Host "  2. Re-open Chrome — the extension will appear automatically." -ForegroundColor White
Write-Host "  3. If prompted 'Developer mode extension', click [Keep]."   -ForegroundColor White
Write-Host ""
Write-Host "  For machine-wide install on another PC:"     -ForegroundColor Yellow
Write-Host "  -> Run install_extension.reg as Administrator"  -ForegroundColor White
Write-Host "  To uninstall:"                               -ForegroundColor Yellow
Write-Host "  -> Run uninstall_extension.reg as Administrator" -ForegroundColor White
Write-Host "  OR: powershell -File install_extension.ps1 -Uninstall" -ForegroundColor White
Write-Host "=============================================" -ForegroundColor Cyan

exit 0
