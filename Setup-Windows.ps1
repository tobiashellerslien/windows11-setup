#Requires -Version 7.0
<#
.SYNOPSIS
    Hovedscript for fresh Windows-oppsett.
.DESCRIPTION
    1) Installerer alle winget-pakker fra packages.json (idempotent - kan kjøres flere ganger).
    2) Kjører videre oppsett-steg, hvert med bekreftelse (j/N) før det kjøres.
    Hvert steg er isolert: hvis ett steg feiler, varsles det og resten av scriptet fortsetter.
.NOTES
    Kjør med: pwsh -File .\Setup-Windows.ps1
    Scriptet ber selv om admin-rettigheter hvis det ikke allerede kjører elevert.
    Forventer at Microsoft.PowerShell_profile.ps1, packages.json og configfiles\ (millennium.zip,
    terminal.settings.json) ligger i/under samme mappe som dette scriptet.
#>

[CmdletBinding()]
param(
    [string]$PackagesJson = (Join-Path $PSScriptRoot 'packages.json'),
    [string]$ProfileSource = (Join-Path $PSScriptRoot 'configfiles\Microsoft.PowerShell_profile.ps1'),
    [string]$ToolsDir     = 'C:\Tools',
    [string]$SteamDir     = 'C:\Program Files (x86)\Steam',
    [string]$MillenniumZip = (Join-Path $PSScriptRoot 'configfiles\millennium.zip'),
    [string]$TerminalSettingsSource = (Join-Path $PSScriptRoot 'configfiles\terminal.settings.json')
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

# Kjører ett steg isolert: ber om bekreftelse, kjører scriptblokka i try/catch,
# og varsler + fortsetter til neste steg i stedet for å drepe hele scriptet ved feil.
function Invoke-Step {
    param(
        [Parameter(Mandatory)][string]$Message,
        [Parameter(Mandatory)][scriptblock]$Action
    )

    if (-not (Confirm-Step $Message)) {
        return
    }

    try {
        & $Action
    } catch {
        Write-Warning "Steget feilet - hopper videre til neste steg. Feil: $_"
    }
}

# PATH oppdateres i registeret av winget/installere, men denne prosessens $env:Path
# er allerede lest inn og oppdages ikke automatisk. Kall denne etter winget-installasjoner
# som senere steg i SAMME kjøring er avhengig av (f.eks. 'py' rett etter Python-installasjon,
# eller 'git' rett etter git-installasjon).
function Sync-EnvironmentPath {
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath    = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = @($machinePath, $userPath) -join ';'
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
    Sync-EnvironmentPath
}

# Pakker ut en zip til $Destination uten å skape et dobbelt mappenivå.
# Hvis zip-en har én enkelt mappe på toppnivå (f.eks. "millennium\..."), kopieres
# INNHOLDET i den mappa direkte til $Destination i stedet for å beholde wrapper-mappa.
function Expand-ArchiveFlatten {
    param(
        [Parameter(Mandatory)][string]$ZipPath,
        [Parameter(Mandatory)][string]$Destination
    )

    if (-not (Test-Path -Path $ZipPath -PathType Leaf)) {
        throw "Fant ikke zip-fil: $ZipPath"
    }

    $tempExtract = Join-Path $env:TEMP ("extract_" + [guid]::NewGuid())
    Expand-Archive -Path $ZipPath -DestinationPath $tempExtract -Force

    try {
        $rootItems = Get-ChildItem -Path $tempExtract
        $sourceDir = $tempExtract
        if ($rootItems.Count -eq 1 -and $rootItems[0].PSIsContainer) {
            # Zip hadde én wrapper-mappe på toppnivå - bruk innholdet i den for å unngå dobbelt nivå
            $sourceDir = $rootItems[0].FullName
        }

        if (-not (Test-Path -Path $Destination)) {
            New-Item -ItemType Directory -Path $Destination -Force | Out-Null
        }

        Copy-Item -Path (Join-Path $sourceDir '*') -Destination $Destination -Recurse -Force
    } finally {
        Remove-Item -Path $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Lager en .lnk-snarvei i Startup-mappa, slik at $TargetPath starter automatisk ved innlogging.
function New-StartupShortcut {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$TargetPath
    )

    $startupDir = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
    Ensure-Directory $startupDir
    $shortcutPath = Join-Path $startupDir "$Name.lnk"

    $wshShell = New-Object -ComObject WScript.Shell
    $shortcut = $wshShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $TargetPath
    $shortcut.WorkingDirectory = Split-Path -Path $TargetPath -Parent
    $shortcut.Save()

    Write-Host "Autostart-snarvei laget: $shortcutPath" -ForegroundColor Green
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

#region Oppdater winget
Write-Host "`n=== Oppdaterer winget ===" -ForegroundColor Magenta
try {
    winget upgrade --id Microsoft.AppInstaller --source msstore --accept-package-agreements --accept-source-agreements --silent
    winget source update
} catch {
    Write-Warning "Klarte ikke oppdatere winget - fortsetter med eksisterende versjon. Feil: $_"
}
#endregion

#region Steg 1: Winget-pakker
Write-Host "`n=== STEG 1: Winget-pakker ===" -ForegroundColor Magenta
try {
    Install-WingetPackages -JsonPath $PackagesJson
} catch {
    Write-Warning "Steg 1 feilet delvis - hopper videre. Feil: $_"
}
Sync-EnvironmentPath
#endregion

#region Steg 2: Global git config
Invoke-Step -Message "`n=== STEG 2: Sette opp global git config (navn/e-post)? ===" -Action {
    Sync-EnvironmentPath

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Warning "Fant ikke 'git'. Sjekk at Git.Git ble installert i steg 1, eller kjør dette steget på nytt i en ny PowerShell-økt."
        return
    }

    $currentName  = git config --global user.name 2>$null
    $currentEmail = git config --global user.email 2>$null

    $namePrompt = if ($currentName) { "Git brukernavn [$currentName]" } else { 'Git brukernavn' }
    $nameInput = Read-Host $namePrompt
    if ([string]::IsNullOrWhiteSpace($nameInput)) { $nameInput = $currentName }

    $emailPrompt = if ($currentEmail) { "Git e-post [$currentEmail]" } else { 'Git e-post' }
    $emailInput = Read-Host $emailPrompt
    if ([string]::IsNullOrWhiteSpace($emailInput)) { $emailInput = $currentEmail }

    if ([string]::IsNullOrWhiteSpace($nameInput) -or [string]::IsNullOrWhiteSpace($emailInput)) {
        Write-Warning "Mangler brukernavn eller e-post - hopper over git config."
        return
    }

    git config --global user.name $nameInput
    git config --global user.email $emailInput

    Write-Host "`nGit global config:" -ForegroundColor Green
    git config --list
}
#endregion

#region Steg 3: Brave debloat (registry policies) + tvungen installasjon av extensions
Invoke-Step -Message "`n=== STEG 3: Kjøre Brave debloat + installere Bitwarden/Surfshark/Unhook/SponsorBlock via policy? ===" -Action {
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

; Tvungen installasjon av extensions (installeres stille ved neste Brave-oppstart)
; 1 = Bitwarden, 2 = Surfshark VPN, 3 = Unhook, 4 = SponsorBlock
[HKEY_LOCAL_MACHINE\Software\Policies\BraveSoftware\Brave\ExtensionInstallForcelist]
"1"="nngceckbapebfimnlniiiahkandclblb;https://clients2.google.com/service/update2/crx"
"2"="ailoabdmgclmfmhdagmlohpjlbpffblp;https://clients2.google.com/service/update2/crx"
"3"="khncfooichmfjbepaaaebmommgaepoid;https://clients2.google.com/service/update2/crx"
"4"="mnjggcdmjocbbbhaepdhchncahnbgone;https://clients2.google.com/service/update2/crx"
'@
    $regPath = Join-Path $env:TEMP 'brave-debloat.reg'
    Set-Content -Path $regPath -Value $regContent -Encoding Unicode
    reg import $regPath
    Remove-Item $regPath -Force
    Write-Host "Brave-policies satt (inkl. tvungen installasjon av extensions)." -ForegroundColor Green
}
#endregion

#region Steg 4: PowerShell-oppsett (oh-my-posh, zoxide, Terminal-Icons, JetBrains Mono font, profil)
Invoke-Step -Message "`n=== STEG 4: Sette opp PowerShell (oh-my-posh, zoxide, Terminal-Icons, JetBrains Mono Nerd Font, profil)? ===" -Action {
    Install-WinGetPackage -Id 'JanDeDobbeleer.OhMyPosh' -Name 'Oh My Posh' | Out-Null
    Install-WinGetPackage -Id 'ajeetdsouza.zoxide' -Name 'zoxide' | Out-Null
    Sync-EnvironmentPath
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

#region Steg 5: Windows Terminal-innstillinger
Invoke-Step -Message "`n=== STEG 5: Kopiere Windows Terminal-innstillinger fra configfiles\terminal.settings.json? ===" -Action {
    if (-not (Test-Path -Path $TerminalSettingsSource -PathType Leaf)) {
        Write-Warning "Fant ikke $TerminalSettingsSource. Hopper over."
        return
    }

    $packageDir = Get-ChildItem -Path "$env:LOCALAPPDATA\Packages" -Filter 'Microsoft.WindowsTerminal_*' -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $packageDir) {
        Write-Warning "Fant ikke Windows Terminal sin pakkemappe under $env:LOCALAPPDATA\Packages. Windows Terminal må som regel åpnes minst én gang før mappa opprettes - kjør dette steget på nytt etter det. Hopper over."
        return
    }

    $localStateDir = Join-Path $packageDir.FullName 'LocalState'
    Ensure-Directory $localStateDir
    $settingsPath = Join-Path $localStateDir 'settings.json'

    if (Test-Path -Path $settingsPath -PathType Leaf) {
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        Copy-Item -Path $settingsPath -Destination (Join-Path $localStateDir "settings-backup-$timestamp.json") -Force
        Write-Host "Gamle innstillinger sikkerhetskopiert." -ForegroundColor DarkGray
    }

    Copy-Item -Path $TerminalSettingsSource -Destination $settingsPath -Force
    Write-Host "Windows Terminal-innstillinger kopiert til $settingsPath" -ForegroundColor Green
}
#endregion

#region Steg 6: Python via Python Install Manager
Invoke-Step -Message "`n=== STEG 6: Installere nyeste Python via Python Install Manager? ===" -Action {
    # Nødvendig selv om Python.PythonInstallManager ble installert i steg 1 i samme kjøring:
    # denne prosessens PATH ble lest inn før winget skrev den nye verdien til registeret.
    Sync-EnvironmentPath

    if (Get-Command py -ErrorAction SilentlyContinue) {
        py install
        py install --configure
    }
    else {
        Write-Warning "Fant ikke kommandoen 'py' selv etter PATH-sync. Sjekk at Python.PythonInstallManager ble installert i steg 1, eller kjør steg 6 på nytt i en ny PowerShell-økt."
    }
}
#endregion

Write-Host "`n=== DIVERSE NEDLASTINGER OG UTPAKKING ===" -ForegroundColor Cyan

#region Steg 7: yt-dlp
Invoke-Step -Message "`n=== STEG 7: Laste ned yt-dlp.exe til $ToolsDir og legge i PATH? ===" -Action {
    Ensure-Directory $ToolsDir
    $ytDlpPath = Join-Path $ToolsDir 'yt-dlp.exe'
    Invoke-WebRequest -Uri 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe' -OutFile $ytDlpPath
    Add-ToMachinePath -Directory $ToolsDir
    Write-Host "yt-dlp installert: $ytDlpPath" -ForegroundColor Green
}
#endregion

#region Steg 8: Millennium (Steam-tema) - pakk ut lokal zip i Steam-mappen
Invoke-Step -Message "`n=== STEG 8: Pakke ut Millennium (configfiles\millennium.zip) til $SteamDir\millennium? ===" -Action {
    if (-not (Test-Path -Path $SteamDir)) {
        Write-Warning "Fant ikke Steam-mappen: $SteamDir. Hopper over Millennium."
        return
    }
    if (-not (Test-Path -Path $MillenniumZip -PathType Leaf)) {
        Write-Warning "Fant ikke $MillenniumZip. Hopper over Millennium."
        return
    }

    $millenniumDest = Join-Path $SteamDir 'millennium'
    Expand-ArchiveFlatten -ZipPath $MillenniumZip -Destination $millenniumDest
    Write-Host "Millennium pakket ut til $millenniumDest" -ForegroundColor Green
}
#endregion

#region Steg 9: G-Helper -> C:\Tools
Invoke-Step -Message "`n=== STEG 9: Laste ned GHelper.exe til $ToolsDir og sette opp autostart? ===" -Action {
    Ensure-Directory $ToolsDir
    $gHelperPath = Join-Path $ToolsDir 'GHelper.exe'
    Invoke-WebRequest -Uri 'https://github.com/seerge/g-helper/releases/latest/download/GHelper.exe' -OutFile $gHelperPath
    Write-Host "G-Helper lagt i $ToolsDir." -ForegroundColor Green
}
#endregion

#region Steg 10: FileConverter (ingen direktelink - åpner nedlastingsside)
Invoke-Step -Message "`n=== STEG 10: Åpne nedlastingssiden for FileConverter? (ingen stabil direktelink funnet) ===" -Action {
    Write-Host "FileConverter har ingen stabil direkte-nedlastingslink. Åpner siden i nettleser..." -ForegroundColor Yellow
    Start-Process 'https://file-converter.io/download.html'
}
#endregion

Write-Host "`n=== Oppsett fullført ===" -ForegroundColor Cyan
Write-Host "Manuelle installasjoner som gjenstår: " -ForegroundColor Cyan
Write-Host "Ente Auth: https://github.com/ente/ente" -ForegroundColor Cyan
Write-Host "BCUninstaller: https://github.com/BCUninstaller/Bulk-Crap-Uninstaller/releases" -ForegroundColor Cyan
Write-Host "mpv: https://github.com/shinchiro/mpv-winbuild-cmake/releases (+ config fra configfiles/mpv.conf.zip -> `$env:APPDATA\mpv)" -ForegroundColor Cyan
Write-Host "GoodNotes/MagicPods (Store)" -ForegroundColor Cyan
Write-Host "Microsoft 365 (https://m365.cloud.microsoft/apps)." -ForegroundColor Cyan
