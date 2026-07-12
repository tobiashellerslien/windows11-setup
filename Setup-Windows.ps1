#Requires -Version 7.0
<#
.SYNOPSIS
    Hovedscript for fresh Windows-oppsett.
.DESCRIPTION
    1) Installerer alle winget-pakker fra packages.json (idempotent - kan kjøres flere ganger).
    2) Kjører videre oppsett-steg, hvert med bekreftelse (j/N) før det kjøres.
.NOTES
    Kjør med: pwsh -File .\Setup-Windows.ps1
    Scriptet ber selv om admin-rettigheter hvis det ikke allerede kjører elevert.
    Forventer at Microsoft.PowerShell_profile.ps1 og packages.json ligger i samme mappe som dette scriptet.
#>

[CmdletBinding()]
param(
    [string]$PackagesJson = (Join-Path $PSScriptRoot 'packages.json'),
    [string]$ProfileSource = (Join-Path $PSScriptRoot 'Microsoft.PowerShell_profile.ps1'),
    [string]$ToolsDir     = 'C:\Tools'
)

$ErrorActionPreference = 'Stop'

#region Elevation
function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-Host "Ber om administrator-rettigheter..." -ForegroundColor Yellow
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
    Start-Process -FilePath 'pwsh' -ArgumentList $argList -Verb RunAs
    exit
}
#endregion

#region Hjelpefunksjoner - generelt
function Confirm-Step {
    param([string]$Message)
    $resp = Read-Host "$Message (j/N)"
    return $resp -match '^[jJyY]'
}

function Test-WingetPackageInstalled {
    param([string]$Id)
    winget list --id $Id --exact --accept-source-agreements 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0)
}

function Install-WingetPackages {
    param([string]$JsonPath)
    if (-not (Test-Path $JsonPath)) {
        Write-Warning "Fant ikke $JsonPath"
        return
    }
    $packages = Get-Content $JsonPath -Raw | ConvertFrom-Json
    foreach ($pkg in $packages) {
        $id = $pkg.Id
        Write-Host "== $id ==" -ForegroundColor Cyan
        if (Test-WingetPackageInstalled -Id $id) {
            Write-Host "Allerede installert, hopper over." -ForegroundColor DarkGray
            continue
        }
        Write-Host "Installerer $id..."
        winget install --exact --id $id --source winget `
            --accept-package-agreements --accept-source-agreements --silent
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Installasjon av $id feilet (exit code $LASTEXITCODE)"
        }
    }
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Add-ToMachinePath {
    param([string]$Directory)
    $current = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    if ($current -split ';' -notcontains $Directory) {
        [Environment]::SetEnvironmentVariable('Path', "$current;$Directory", 'Machine')
        Write-Host "La til $Directory i systemets PATH." -ForegroundColor Green
    }
    else {
        Write-Host "$Directory er allerede i PATH." -ForegroundColor DarkGray
    }
}
#endregion

#region Hjelpefunksjoner - PowerShell-oppsett (basert på Chris Titus Tech sin setup.ps1)
function Get-ProfileDirectory {
    switch ($PSVersionTable.PSEdition) {
        'Core' { Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell'; break }
        'Desktop' { Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'WindowsPowerShell'; break }
        default { throw "Unsupported PowerShell edition: $($PSVersionTable.PSEdition)" }
    }
}

function Install-WinGetPackage {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Name
    )

    if (Test-WingetPackageInstalled -Id $Id) {
        Write-Host "$Name er allerede installert." -ForegroundColor DarkGray
        return $true
    }

    try {
        winget install --id $Id --exact --source winget --accept-source-agreements --accept-package-agreements --silent
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "winget klarte ikke installere $Name. Exit code: $LASTEXITCODE"
            return $false
        }
        return $true
    } catch {
        Write-Warning "Feil ved installasjon av $Name : $_"
        return $false
    }
}

function Install-OhMyPoshTheme {
    param(
        [string]$ThemeName = 'hul10',
        [string]$ThemeUri = 'https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/hul10.omp.json'
    )

    $dir = Get-ProfileDirectory
    if (-not (Test-Path -Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }

    $themePath = Join-Path $dir "$ThemeName.omp.json"
    try {
        Invoke-WebRequest -Uri $ThemeUri -OutFile $themePath
        Write-Host "Oh My Posh-tema '$ThemeName' installert: $themePath" -ForegroundColor Green
        return $themePath
    } catch {
        Write-Warning "Klarte ikke laste ned Oh My Posh-tema. Feil: $_"
        return $null
    }
}

function Get-InstalledFontName {
    try {
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop
        return (New-Object System.Drawing.Text.InstalledFontCollection).Families.Name
    } catch {
        Write-Warning "Klarte ikke lese installerte fonter. Feil: $_"
        return @()
    }
}

function Install-NerdFont {
    param(
        [string]$FontName = 'JetBrainsMono',
        [string]$FontDisplayName = 'JetBrainsMono Nerd Font',
        [string]$Version = '3.4.0'
    )

    if ((Get-InstalledFontName) -contains $FontDisplayName) {
        Write-Host "Font [$FontDisplayName] er allerede installert." -ForegroundColor DarkGray
        return $true
    }

    $fontZipUrl = "https://github.com/ryanoasis/nerd-fonts/releases/download/v$Version/$FontName.zip"
    $zipFilePath = Join-Path $env:TEMP "$FontName.zip"
    $extractPath = Join-Path $env:TEMP $FontName

    try {
        Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
        Invoke-WebRequest -Uri $fontZipUrl -OutFile $zipFilePath
        Expand-Archive -Path $zipFilePath -DestinationPath $extractPath -Force

        $fontShellFolder = (New-Object -ComObject Shell.Application).Namespace(0x14)
        Get-ChildItem -Path $extractPath -Recurse -Include '*.ttf', '*.otf' | ForEach-Object {
            if (-not (Test-Path "$env:WINDIR\Fonts\$($_.Name)")) {
                $fontShellFolder.CopyHere($_.FullName, 0x10)
            }
        }

        Write-Host "Font [$FontDisplayName] installert." -ForegroundColor Green
        return $true
    } catch {
        Write-Warning "Klarte ikke installere $FontDisplayName. Feil: $_"
        return $false
    } finally {
        Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $zipFilePath -Force -ErrorAction SilentlyContinue
    }
}

function Install-TerminalIconsModule {
    if (Get-Module -ListAvailable -Name Terminal-Icons) {
        Write-Host "Terminal-Icons er allerede installert." -ForegroundColor DarkGray
        return $true
    }

    try {
        Install-Module -Name Terminal-Icons -Repository PSGallery -Scope CurrentUser -Force -SkipPublisherCheck
        Write-Host 'Terminal-Icons installert.' -ForegroundColor Green
        return $true
    } catch {
        Write-Warning "Klarte ikke installere Terminal-Icons. Feil: $_"
        return $false
    }
}

function Install-CustomProfile {
    param(
        [Parameter(Mandatory)][string]$SourcePath,
        [Parameter(Mandatory)][string]$ProfilePath
    )

    $dir = Split-Path -Path $ProfilePath -Parent
    if (-not (Test-Path -Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }

    if (Test-Path -Path $ProfilePath -PathType Leaf) {
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $backupPath = Join-Path $dir "oldprofile-$timestamp.ps1"
        Copy-Item -Path $ProfilePath -Destination $backupPath -Force
        Write-Host "Gammel profil sikkerhetskopiert til: $backupPath" -ForegroundColor DarkGray
    }

    Copy-Item -Path $SourcePath -Destination $ProfilePath -Force
    Write-Host "Profil installert: $ProfilePath" -ForegroundColor Green
}
#endregion

#region Steg 1: Winget-pakker
Write-Host "`n=== STEG 1: Winget-pakker ===" -ForegroundColor Magenta
Install-WingetPackages -JsonPath $PackagesJson
#endregion

#region Steg 2: Brave debloat (registry policies)
if (Confirm-Step "`n=== STEG 2: Kjøre Brave debloat (registry policies)? ===") {
    $regContent = @'
Windows Registry Editor Version 5.00
; Brave Debloat Policy by Anxarden (v1.84-v1.92+)
; Sync and HTTPS/DNS Untouched

[HKEY_LOCAL_MACHINE\Software\Policies\BraveSoftware\Brave]

"BraveAIChatEnabled"=dword:00000000
"BraveRewardsDisabled"=dword:00000001
"BraveWalletDisabled"=dword:00000001
"BraveVPNDisabled"=dword:00000001
"TorDisabled"=dword:00000001
"BraveP3AEnabled"=dword:00000000
"BraveStatsPingEnabled"=dword:00000000
"BraveWebDiscoveryEnabled"=dword:00000000
"BraveNewsDisabled"=dword:00000001
"BraveTalkDisabled"=dword:00000001
"BraveSpeedreaderEnabled"=dword:00000000
"BraveWaybackMachineEnabled"=dword:00000000
"BravePlaylistEnabled"=dword:00000000
"SyncDisabled"=dword:00000000
"PasswordManagerEnabled"=dword:00000000
"AutofillAddressEnabled"=dword:00000000
"AutofillCreditCardEnabled"=dword:00000000
"TranslateEnabled"=dword:00000000
"DnsOverHttpsMode"="secure"
"DnsOverHttpsTemplates"="https://dns.adguard-dns.com/dns-query"
'@
    $regPath = Join-Path $env:TEMP 'brave-debloat.reg'
    Set-Content -Path $regPath -Value $regContent -Encoding Unicode
    reg import $regPath
    Remove-Item $regPath -Force
    Write-Host "Brave-policies satt." -ForegroundColor Green
}
#endregion

#region Steg 3: PowerShell-oppsett (oh-my-posh, zoxide, Terminal-Icons, JetBrains Mono font, profil)
if (Confirm-Step "`n=== STEG 3: Sette opp PowerShell (oh-my-posh, zoxide, Terminal-Icons, JetBrains Mono Nerd Font, profil)? ===") {
    Install-WinGetPackage -Id 'JanDeDobbeleer.OhMyPosh' -Name 'Oh My Posh' | Out-Null
    Install-WinGetPackage -Id 'ajeetdsouza.zoxide' -Name 'zoxide' | Out-Null
    Install-OhMyPoshTheme | Out-Null
    Install-NerdFont | Out-Null
    Install-TerminalIconsModule | Out-Null

    if (Test-Path -Path $ProfileSource -PathType Leaf) {
        Install-CustomProfile -SourcePath $ProfileSource -ProfilePath $PROFILE.CurrentUserCurrentHost
    } else {
        Write-Warning "Fant ikke $ProfileSource - hopper over profil-installasjon."
    }
}
#endregion

#region Steg 4: Python via Python Install Manager
if (Confirm-Step "`n=== STEG 4: Installere nyeste Python via Python Install Manager? ===") {
    if (Get-Command py -ErrorAction SilentlyContinue) {
        py install
        py install --configure
    }
    else {
        Write-Warning "Fant ikke kommandoen 'py' - sjekk at Python.PythonInstallManager ble installert i steg 1 (kan kreve ny PowerShell-sesjon for at PATH skal oppdateres)."
    }
}
#endregion

Write-Host "`n=== DIVERSE NEDLASTINGER ===" -ForegroundColor Cyan

#region Steg 5: yt-dlp
if (Confirm-Step "`n=== STEG 5: Laste ned yt-dlp.exe til $ToolsDir og legge i PATH? ===") {
    Ensure-Directory $ToolsDir
    $ytDlpPath = Join-Path $ToolsDir 'yt-dlp.exe'
    Invoke-WebRequest -Uri 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe' -OutFile $ytDlpPath
    Add-ToMachinePath -Directory $ToolsDir
    Write-Host "yt-dlp installert: $ytDlpPath" -ForegroundColor Green
}
#endregion

#region Steg 6: Millennium (Steam-tema-installer) -> Downloads
if (Confirm-Step "`n=== STEG 6: Laste ned Millennium-installer til Downloads? ===") {
    $downloads = Join-Path $env:USERPROFILE 'Downloads'
    Invoke-WebRequest -Uri 'https://github.com/SteamClientHomebrew/Installer/releases/latest/download/MillenniumInstaller-Windows.exe' `
        -OutFile (Join-Path $downloads 'MillenniumInstaller-Windows.exe')
    Write-Host "Lagt i $downloads - kjør installeren manuelt." -ForegroundColor Green
}
#endregion

#region Steg 7: G-Helper -> C:\Tools
if (Confirm-Step "`n=== STEG 7: Laste ned GHelper.exe til $ToolsDir? ===") {
    Ensure-Directory $ToolsDir
    Invoke-WebRequest -Uri 'https://github.com/seerge/g-helper/releases/latest/download/GHelper.exe' `
        -OutFile (Join-Path $ToolsDir 'GHelper.exe')
    Write-Host "G-Helper lagt i $ToolsDir. Husk å sette 'start ved oppstart' manuelt inne i appen." -ForegroundColor Green
}
#endregion

#region Steg 8: FileConverter (ingen direktelink - åpner nedlastingsside)
if (Confirm-Step "`n=== STEG 8: Åpne nedlastingssiden for FileConverter? (ingen stabil direktelink funnet) ===") {
    Write-Host "FileConverter har ingen stabil direkte-nedlastingslink. Åpner siden i nettleser..." -ForegroundColor Yellow
    Start-Process 'https://file-converter.io/download.html'
}
#endregion

Write-Host "`n=== Oppsett fullført ===" -ForegroundColor Cyan
Write-Host "Gjenstår manuelt: " -ForegroundColor Cyan
Write-Host "Ente Auth: https://github.com/ente/ente" -ForegroundColor Cyan
Write-Host "BCUninstaller: https://github.com/BCUninstaller/Bulk-Crap-Uninstaller/releases" -ForegroundColor Cyan
Write-Host "mpv: https://github.com/shinchiro/mpv-winbuild-cmake/releases (+ config fra configfiles/mpv.conf.zip -> `$env:APPDATA\mpv)" -ForegroundColor Cyan
Write-Host "GoodNotes/MagicPods (Store)" -ForegroundColor Cyan
Write-Host "Microsoft 365 (https://m365.cloud.microsoft/apps)." -ForegroundColor Cyan
