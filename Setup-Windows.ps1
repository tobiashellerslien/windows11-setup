#Requires -Version 7.0
<#
.SYNOPSIS
    Automatiserer oppsett av en ny Windows-installasjon.
.DESCRIPTION
    Installerer valgte winget-pakker og kjører hver øvrige del etter bekreftelse.
    Delene er isolert, slik at en feil blir rapportert uten å stoppe resten av oppsettet.
.NOTES
    Kjør med: pwsh -File .\Setup-Windows.ps1
    Scriptet ber selv om administratorrettigheter og venter på Enter før det avsluttes.
#>

[CmdletBinding()]
param(
    [switch]$NoPause
)

$ErrorActionPreference = 'Stop'
$packagesJson = Join-Path $PSScriptRoot 'packages.json'
$profileSource = Join-Path $PSScriptRoot 'configfiles\Microsoft.PowerShell_profile.ps1'
$terminalSettingsSource = Join-Path $PSScriptRoot 'configfiles\terminal.settings.json'
$vscodeSettingsSource = Join-Path $PSScriptRoot 'configfiles\vscode.settings.json'
$script:WingetFailures = [System.Collections.Generic.List[string]]::new()
$script:SectionFailures = [System.Collections.Generic.List[string]]::new()

function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-Host 'Ber om administratorrettigheter ...' -ForegroundColor Yellow
    $argumentList = @(
        '-NoProfile'
        '-ExecutionPolicy'
        'Bypass'
        '-File'
        ('"{0}"' -f $PSCommandPath)
    )
    if ($NoPause) {
        $argumentList += '-NoPause'
    }

    Start-Process -FilePath (Get-Command pwsh).Source -ArgumentList $argumentList -Verb RunAs
    exit
}

function Confirm-Action {
    param([Parameter(Mandatory)][string]$Message)

    $response = Read-Host "$Message (y/n)"
    $response -match '^[yY]'
}

function Invoke-Section {
    param(
        [Parameter(Mandatory)][string]$Message,
        [Parameter(Mandatory)][scriptblock]$Action
    )

    if (-not (Confirm-Action -Message $Message)) {
        Write-Host 'Hoppet over.' -ForegroundColor DarkGray
        return
    }

    try {
        & $Action
    } catch {
        [void]$script:SectionFailures.Add($Message)
        Write-Warning "Delen feilet, men oppsettet fortsetter. Feil: $_"
    }
}

function Ensure-Directory {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Install-ConfigFile {
    param(
        [Parameter(Mandatory)][string]$SourcePath,
        [Parameter(Mandatory)][string]$DestinationPath,
        [Parameter(Mandatory)][string]$Description,
        [Parameter(Mandatory)][string]$BackupPrefix
    )

    if (-not (Test-Path -LiteralPath $SourcePath -PathType Leaf)) {
        throw "Fant ikke konfigurasjonsfila: $SourcePath"
    }

    $destinationDirectory = Split-Path -Path $DestinationPath -Parent
    Ensure-Directory -Path $destinationDirectory
    if (Test-Path -LiteralPath $DestinationPath -PathType Leaf) {
        $sourceHash = (Get-FileHash -LiteralPath $SourcePath -Algorithm SHA256).Hash
        $destinationHash = (Get-FileHash -LiteralPath $DestinationPath -Algorithm SHA256).Hash
        if ($sourceHash -eq $destinationHash) {
            Write-Host "$Description er allerede oppdatert." -ForegroundColor DarkGray
            return
        }

        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmssfff'
        $extension = [IO.Path]::GetExtension($DestinationPath)
        $backupPath = Join-Path $destinationDirectory "$BackupPrefix-backup-$timestamp$extension"
        Copy-Item -LiteralPath $DestinationPath -Destination $backupPath
        Write-Host "Eksisterende konfigurasjon sikkerhetskopiert: $backupPath" -ForegroundColor DarkGray
    }

    Copy-Item -LiteralPath $SourcePath -Destination $DestinationPath -Force
    Write-Host "$Description er installert: $DestinationPath" -ForegroundColor Green
}

function Get-DirectoryManifest {
    param([Parameter(Mandatory)][string]$Path)

    $rootPath = (Resolve-Path -LiteralPath $Path).ProviderPath
    $rootPrefix = $rootPath.TrimEnd('\') + '\'
    @(
        Get-ChildItem -LiteralPath $rootPath -Force -Recurse |
            ForEach-Object {
                $relativePath = $_.FullName.Substring($rootPrefix.Length)
                if ($_.PSIsContainer) {
                    "D`t$relativePath"
                } else {
                    $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
                    "F`t$relativePath`t$hash"
                }
            }
    ) | Sort-Object
}

function Test-DirectoryContentEqual {
    param(
        [Parameter(Mandatory)][string]$SourcePath,
        [Parameter(Mandatory)][string]$DestinationPath
    )

    if (-not (Test-Path -LiteralPath $DestinationPath -PathType Container)) {
        return $false
    }

    $sourceManifest = @(Get-DirectoryManifest -Path $SourcePath)
    $destinationManifest = @(Get-DirectoryManifest -Path $DestinationPath)
    if ($sourceManifest.Count -ne $destinationManifest.Count) {
        return $false
    }
    if ($sourceManifest.Count -eq 0) {
        return $true
    }

    $null -eq (Compare-Object -ReferenceObject $sourceManifest -DifferenceObject $destinationManifest | Select-Object -First 1)
}

function Install-ConfigDirectory {
    param(
        [Parameter(Mandatory)][string]$SourcePath,
        [Parameter(Mandatory)][string]$DestinationPath,
        [Parameter(Mandatory)][string]$Description,
        [Parameter(Mandatory)][string]$BackupPrefix
    )

    if (-not (Test-Path -LiteralPath $SourcePath -PathType Container)) {
        throw "Fant ikke konfigurasjonsmappa: $SourcePath"
    }
    if ((Test-Path -LiteralPath $DestinationPath) -and
        -not (Test-Path -LiteralPath $DestinationPath -PathType Container)) {
        throw "Målet for konfigurasjonsmappa er ikke en mappe: $DestinationPath"
    }

    $destinationParent = Split-Path -Path $DestinationPath -Parent
    Ensure-Directory -Path $destinationParent
    if (Test-DirectoryContentEqual -SourcePath $SourcePath -DestinationPath $DestinationPath) {
        Write-Host "$Description er allerede oppdatert." -ForegroundColor DarkGray
        return
    }

    $backupPath = $null
    if (Test-Path -LiteralPath $DestinationPath -PathType Container) {
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmssfff'
        $backupPath = Join-Path $destinationParent "$BackupPrefix-backup-$timestamp"
        Move-Item -LiteralPath $DestinationPath -Destination $backupPath
        Write-Host "Eksisterende konfigurasjon sikkerhetskopiert: $backupPath" -ForegroundColor DarkGray
    }

    try {
        Ensure-Directory -Path $DestinationPath
        Get-ChildItem -LiteralPath $SourcePath -Force |
            Copy-Item -Destination $DestinationPath -Recurse -Force
        Write-Host "$Description er installert: $DestinationPath" -ForegroundColor Green
    } catch {
        Remove-Item -LiteralPath $DestinationPath -Recurse -Force -ErrorAction SilentlyContinue
        if ($backupPath -and (Test-Path -LiteralPath $backupPath -PathType Container)) {
            Move-Item -LiteralPath $backupPath -Destination $DestinationPath
        }
        throw
    }
}

function Sync-EnvironmentPath {
    # Installerere oppdaterer PATH i registeret, men ikke i prosessen som allerede kjører.
    # Slå sammen nye og eksisterende verdier uten tomme eller dupliserte oppføringer.
    $pathValues = @(
        [Environment]::GetEnvironmentVariable('Path', 'Machine')
        [Environment]::GetEnvironmentVariable('Path', 'User')
        $env:Path
    )
    $seen = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $entries = foreach ($pathValue in $pathValues) {
        foreach ($entry in ($pathValue -split ';')) {
            $cleanEntry = [Environment]::ExpandEnvironmentVariables($entry.Trim().Trim('"'))
            if (-not [string]::IsNullOrWhiteSpace($cleanEntry) -and $seen.Add($cleanEntry)) {
                $cleanEntry
            }
        }
    }

    $newPath = $entries -join ';'
    if ($newPath.Length -ge 32767) {
        throw "PATH er fortsatt for lang etter opprydding ($($newPath.Length) tegn)."
    }

    $env:Path = $newPath
}

function Format-NativeExitCode {
    param([Parameter(Mandatory)][long]$ExitCode)

    $unsignedCode = [uint32]($ExitCode -band 0xFFFFFFFFL)
    "$ExitCode (0x$($unsignedCode.ToString('X8')))"
}

function Test-WingetPackageInstalled {
    param([Parameter(Mandatory)][string]$Id)

    & winget list --id $Id --exact --accept-source-agreements --disable-interactivity 2>$null | Out-Null
    $LASTEXITCODE -eq 0
}

function Install-WingetPackage {
    param([Parameter(Mandatory)][psobject]$Package)

    $id = [string]$Package.Id
    if ([string]::IsNullOrWhiteSpace($id)) {
        throw 'En oppføring i packages.json mangler Id.'
    }

    $displayName = $id
    $source = if ($Package.Source) { [string]$Package.Source } else { 'winget' }

    Write-Host "`n== $displayName ==" -ForegroundColor Cyan
    if (Test-WingetPackageInstalled -Id $id) {
        Write-Host 'Allerede installert, hopper over.' -ForegroundColor DarkGray
        return $true
    }

    $arguments = @(
        'install', '--exact', '--id', $id, '--source', $source,
        '--accept-package-agreements', '--accept-source-agreements',
        '--silent', '--disable-interactivity'
    )
    if ($Package.Scope) {
        $arguments += @('--scope', [string]$Package.Scope)
    }
    if ($Package.InstallerType) {
        $arguments += @('--installer-type', [string]$Package.InstallerType)
    }

    $exitCode = 0
    foreach ($attempt in 1..2) {
        Write-Host "Installerer $displayName ..."
        & winget @arguments | Out-Host
        $exitCode = $LASTEXITCODE
        if ($exitCode -eq 0 -or (Test-WingetPackageInstalled -Id $id)) {
            Write-Host "$displayName er installert." -ForegroundColor Green
            return $true
        }

        if ($attempt -eq 1 -and $exitCode -eq -2147467260) {
            Write-Warning 'Winget rapporterte E_ABORT. Venter kort og prøver én gang til.'
            Start-Sleep -Seconds 2
            continue
        }
        break
    }

    Write-Warning "Installasjon av $displayName feilet med exit code $(Format-NativeExitCode -ExitCode $exitCode)."
    return $false
}

function Install-WingetPackages {
    param([Parameter(Mandatory)][string]$JsonPath)

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'Fant ikke winget. Installer eller oppdater App Installer fra Microsoft Store.'
    }
    if (-not (Test-Path -LiteralPath $JsonPath -PathType Leaf)) {
        throw "Fant ikke pakkelista: $JsonPath"
    }

    $packages = Get-Content -LiteralPath $JsonPath -Raw -Encoding utf8 | ConvertFrom-Json
    $packages = @($packages)
    if ($packages.Count -eq 0) {
        throw 'packages.json inneholder ingen pakker.'
    }

    foreach ($package in $packages) {
        if (-not (Install-WingetPackage -Package $package)) {
            [void]$script:WingetFailures.Add([string]$package.Id)
        }
    }
}

function Get-ProfileDirectory {
    Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell'
}

function Install-OhMyPoshTheme {
    $themeDirectory = Get-ProfileDirectory
    $themePath = Join-Path $themeDirectory 'hul10.omp.json'
    $tempDirectory = Join-Path ([IO.Path]::GetTempPath()) ("oh-my-posh-theme-{0}" -f [guid]::NewGuid())
    $downloadPath = Join-Path $tempDirectory 'hul10.omp.json'
    Ensure-Directory -Path $tempDirectory

    try {
        Invoke-WebRequest `
            -Uri 'https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/hul10.omp.json' `
            -OutFile $downloadPath
        Install-ConfigFile `
            -SourcePath $downloadPath `
            -DestinationPath $themePath `
            -Description 'Oh My Posh-temaet' `
            -BackupPrefix 'hul10'
    } finally {
        Remove-Item -LiteralPath $tempDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Get-InstalledFontNames {
    try {
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop
        (New-Object System.Drawing.Text.InstalledFontCollection).Families.Name
    } catch {
        Write-Warning "Klarte ikke lese installerte fonter: $_"
        @()
    }
}

function Install-NerdFont {
    $fontDisplayName = 'JetBrainsMono Nerd Font'
    if ((Get-InstalledFontNames) -contains $fontDisplayName) {
        Write-Host "$fontDisplayName er allerede installert." -ForegroundColor DarkGray
        return
    }

    $tempDirectory = Join-Path ([IO.Path]::GetTempPath()) ("nerd-font-{0}" -f [guid]::NewGuid())
    $zipPath = Join-Path $tempDirectory 'JetBrainsMono.zip'
    $extractPath = Join-Path $tempDirectory 'files'
    Ensure-Directory -Path $tempDirectory

    try {
        Invoke-WebRequest `
            -Uri 'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip' `
            -OutFile $zipPath
        Expand-Archive -LiteralPath $zipPath -DestinationPath $extractPath -Force

        $fontShellFolder = (New-Object -ComObject Shell.Application).Namespace(0x14)
        if (-not $fontShellFolder) {
            throw 'Klarte ikke åpne Windows Fonts-mappa.'
        }

        $pendingFontPaths = [System.Collections.Generic.List[string]]::new()
        Get-ChildItem -LiteralPath $extractPath -Recurse -File |
            Where-Object Extension -in '.ttf', '.otf' |
            ForEach-Object {
                $installedPath = Join-Path "$env:WINDIR\Fonts" $_.Name
                if (-not (Test-Path -LiteralPath $installedPath)) {
                    $fontShellFolder.CopyHere($_.FullName, 0x10)
                    [void]$pendingFontPaths.Add($installedPath)
                }
            }

        # Shell.Application kopierer asynkront. Vent til filene finnes før temp-mappa slettes.
        foreach ($installedPath in $pendingFontPaths) {
            foreach ($attempt in 1..50) {
                if (Test-Path -LiteralPath $installedPath) {
                    break
                }
                Start-Sleep -Milliseconds 100
            }
            if (-not (Test-Path -LiteralPath $installedPath)) {
                throw "Fontkopieringen fullførte ikke: $installedPath"
            }
        }

        Write-Host "$fontDisplayName er installert." -ForegroundColor Green
    } finally {
        Remove-Item -LiteralPath $tempDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Install-TerminalIconsModule {
    if (Get-Module -ListAvailable -Name Terminal-Icons) {
        Write-Host 'Terminal-Icons er allerede installert.' -ForegroundColor DarkGray
        return
    }

    Install-Module -Name Terminal-Icons -Repository PSGallery -Scope CurrentUser -Force -SkipPublisherCheck
    Write-Host 'Terminal-Icons er installert.' -ForegroundColor Green
}

function Set-BravePolicies {
    $policyPath = 'HKLM:\Software\Policies\BraveSoftware\Brave'
    New-Item -Path $policyPath -Force | Out-Null
    $dwordPolicies = [ordered]@{
        BraveAIChatEnabled         = 0
        BraveRewardsDisabled       = 1
        BraveWalletDisabled        = 1
        BraveVPNDisabled           = 1
        TorDisabled                = 1
        BraveP3AEnabled            = 0
        BraveStatsPingEnabled      = 0
        BraveWebDiscoveryEnabled   = 0
        BraveNewsDisabled          = 1
        BraveTalkDisabled          = 1
        BraveSpeedreaderEnabled    = 0
        BraveWaybackMachineEnabled = 0
        BravePlaylistEnabled       = 0
        SyncDisabled               = 0
        PasswordManagerEnabled     = 0
        AutofillAddressEnabled     = 0
        AutofillCreditCardEnabled  = 0
        TranslateEnabled           = 0
    }
    foreach ($policy in $dwordPolicies.GetEnumerator()) {
        New-ItemProperty -Path $policyPath -Name $policy.Key -Value $policy.Value -PropertyType DWord -Force | Out-Null
    }
    New-ItemProperty -Path $policyPath -Name DnsOverHttpsMode -Value 'secure' -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $policyPath -Name DnsOverHttpsTemplates -Value 'https://dns.adguard-dns.com/dns-query' -PropertyType String -Force | Out-Null

    $extensionPath = Join-Path $policyPath 'ExtensionInstallForcelist'
    New-Item -Path $extensionPath -Force | Out-Null
    $extensions = @(
        'nngceckbapebfimnlniiiahkandclblb;https://clients2.google.com/service/update2/crx'
        'ailoabdmgclmfmhdagmlohpjlbpffblp;https://clients2.google.com/service/update2/crx'
        'khncfooichmfjbepaaaebmommgaepoid;https://clients2.google.com/service/update2/crx'
        'mnjggcdmjocbbbhaepdhchncahnbgone;https://clients2.google.com/service/update2/crx'
    )
    $existingProperties = (Get-ItemProperty -Path $extensionPath).PSObject.Properties |
        Where-Object Name -Match '^\d+$'
    $nextIndex = 1
    foreach ($extension in $extensions) {
        if ($existingProperties.Value -contains $extension) {
            continue
        }
        while ($existingProperties.Name -contains [string]$nextIndex) {
            $nextIndex++
        }
        New-ItemProperty -Path $extensionPath -Name $nextIndex -Value $extension -PropertyType String -Force | Out-Null
        $nextIndex++
    }

    Write-Host 'Brave-policyer og utvidelser er konfigurert.' -ForegroundColor Green
}

function Install-TerminalSettings {
    param([Parameter(Mandatory)][string]$SourcePath)

    $packageDirectory = Get-ChildItem -Path "$env:LOCALAPPDATA\Packages" `
        -Filter 'Microsoft.WindowsTerminal_*' -Directory -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $packageDirectory) {
        throw 'Fant ikke Windows Terminal-pakkemappa. Åpne Terminal én gang og kjør denne delen på nytt.'
    }

    $localStateDirectory = Join-Path $packageDirectory.FullName 'LocalState'
    $settingsPath = Join-Path $localStateDirectory 'settings.json'
    Install-ConfigFile `
        -SourcePath $SourcePath `
        -DestinationPath $settingsPath `
        -Description 'Windows Terminal-innstillingene' `
        -BackupPrefix 'settings'
}

function Get-VSCodeCliPath {
    Sync-EnvironmentPath
    $codeCommand = Get-Command code.cmd -ErrorAction SilentlyContinue
    if (-not $codeCommand) {
        $codeCommand = Get-Command code -ErrorAction SilentlyContinue
    }
    if ($codeCommand) {
        return $codeCommand.Source
    }

    $candidatePaths = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code\bin\code.cmd')
        (Join-Path $env:ProgramFiles 'Microsoft VS Code\bin\code.cmd')
    )
    foreach ($candidatePath in $candidatePaths) {
        if (Test-Path -LiteralPath $candidatePath -PathType Leaf) {
            return $candidatePath
        }
    }

    throw "Fant ikke VS Code-kommandolinjen 'code'. Kontroller at Microsoft.VisualStudioCode ble installert."
}

function Install-VSCodeSettings {
    param([Parameter(Mandatory)][string]$SourcePath)

    $settingsDirectory = Join-Path $env:APPDATA 'Code\User'
    $settingsPath = Join-Path $settingsDirectory 'settings.json'
    Install-ConfigFile `
        -SourcePath $SourcePath `
        -DestinationPath $settingsPath `
        -Description 'VS Code-innstillingene' `
        -BackupPrefix 'settings'

    $codeCli = Get-VSCodeCliPath
    $extensionId = 'PKief.material-icon-theme'
    $installedExtensions = @(& $codeCli --list-extensions 2>$null)
    if ($LASTEXITCODE -ne 0) {
        throw "Klarte ikke hente listen over installerte VS Code-utvidelser. Exit code: $(Format-NativeExitCode -ExitCode $LASTEXITCODE)."
    }

    if ($installedExtensions -contains $extensionId) {
        Write-Host 'Material Icon Theme er allerede installert.' -ForegroundColor DarkGray
        return
    }

    & $codeCli --install-extension $extensionId --force | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "Installasjon av Material Icon Theme feilet med exit code $(Format-NativeExitCode -ExitCode $LASTEXITCODE)."
    }
    Write-Host 'Material Icon Theme er installert.' -ForegroundColor Green
}

function Install-LatestPython {
    Sync-EnvironmentPath
    $pythonManager = Get-Command pymanager -ErrorAction SilentlyContinue
    if (-not $pythonManager) {
        throw "Fant ikke 'pymanager'. Kontroller at Python.PythonInstallManager ble installert."
    }

    Write-Host 'Kontrollerer Python Install Manager-konfigurasjonen ...'
    & $pythonManager.Source install --configure -y | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "Python-konfigurasjonen feilet med exit code $(Format-NativeExitCode -ExitCode $LASTEXITCODE)."
    }

    Sync-EnvironmentPath
    Write-Host 'Installerer nyeste stabile Python ...'
    & $pythonManager.Source install --update -y default | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "Python-installasjonen feilet med exit code $(Format-NativeExitCode -ExitCode $LASTEXITCODE)."
    }

    Sync-EnvironmentPath
    & $pythonManager.Source list | Out-Host

    $pythonLauncher = Get-Command py -ErrorAction SilentlyContinue
    if (-not $pythonLauncher) {
        throw "Python ble installert, men fant ikke 'py' etter oppdatering av PATH."
    }

    Write-Host "`nInstallert standardversjon:" -ForegroundColor Green
    & $pythonLauncher.Source --version 2>&1 | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "'py --version' feilet med exit code $(Format-NativeExitCode -ExitCode $LASTEXITCODE)."
    }
}

function Install-MpvConfig {
    $archiveUri = 'https://github.com/Zabooby/mpv-config/archive/refs/heads/main.zip'
    $tempDirectory = Join-Path ([IO.Path]::GetTempPath()) ("mpv-config-{0}" -f [guid]::NewGuid())
    $archivePath = Join-Path $tempDirectory 'mpv-config.zip'
    $extractPath = Join-Path $tempDirectory 'files'
    Ensure-Directory -Path $tempDirectory

    try {
        Write-Host 'Laster ned Zabooby/mpv-config ...'
        Invoke-WebRequest -Uri $archiveUri -OutFile $archivePath
        Expand-Archive -LiteralPath $archivePath -DestinationPath $extractPath -Force

        $portableConfig = Get-ChildItem -LiteralPath $extractPath -Directory -Recurse |
            Where-Object Name -EQ 'portable_config' |
            Select-Object -First 1
        if (-not $portableConfig -or
            -not (Test-Path -LiteralPath (Join-Path $portableConfig.FullName 'mpv.conf') -PathType Leaf) -or
            -not (Test-Path -LiteralPath (Join-Path $portableConfig.FullName 'scripts') -PathType Container)) {
            throw 'Den nedlastede mpv-konfigurasjonen har ikke forventet struktur.'
        }

        $destination = Join-Path $env:APPDATA 'mpv'
        Install-ConfigDirectory `
            -SourcePath $portableConfig.FullName `
            -DestinationPath $destination `
            -Description 'mpv-konfigurasjonen' `
            -BackupPrefix 'mpv'
        Write-Host "Stiene 'default_directory=~/' og 'mpv_path=mpv' beholdes fordi de er portable og fungerer med Winget-installasjonen." -ForegroundColor DarkGray
    } finally {
        Remove-Item -LiteralPath $tempDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Invoke-Section -Message "`nInstallere alle programmer fra packages.json med winget?" -Action {
    Write-Host "`n=== Winget-programmer ===" -ForegroundColor Magenta
    & winget source update --disable-interactivity | Out-Host
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Oppdatering av winget-kilder feilet med exit code $(Format-NativeExitCode -ExitCode $LASTEXITCODE). Fortsetter med eksisterende kilder."
    }
    Install-WingetPackages -JsonPath $packagesJson
    Sync-EnvironmentPath
}

Invoke-Section -Message "`nSette opp global Git-konfigurasjon (navn og e-post)?" -Action {
    Write-Host "`n=== Git-konfigurasjon ===" -ForegroundColor Magenta
    Sync-EnvironmentPath
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "Fant ikke 'git'. Kontroller at Git.Git ble installert."
    }

    $currentName = git config --global user.name 2>$null
    $currentEmail = git config --global user.email 2>$null
    $nameInput = Read-Host $(if ($currentName) { "Git-navn [$currentName]" } else { 'Git-navn' })
    $emailInput = Read-Host $(if ($currentEmail) { "Git-e-post [$currentEmail]" } else { 'Git-e-post' })
    if ([string]::IsNullOrWhiteSpace($nameInput)) { $nameInput = $currentName }
    if ([string]::IsNullOrWhiteSpace($emailInput)) { $emailInput = $currentEmail }
    if ([string]::IsNullOrWhiteSpace($nameInput) -or [string]::IsNullOrWhiteSpace($emailInput)) {
        throw 'Git-navn og e-post kan ikke være tomme.'
    }

    $gitConfigChanged = $false
    if ($currentName -cne $nameInput) {
        git config --global user.name $nameInput
        if ($LASTEXITCODE -ne 0) {
            throw "Klarte ikke lagre globalt Git-navn. Exit code: $(Format-NativeExitCode -ExitCode $LASTEXITCODE)."
        }
        $gitConfigChanged = $true
    }
    if ($currentEmail -cne $emailInput) {
        git config --global user.email $emailInput
        if ($LASTEXITCODE -ne 0) {
            throw "Klarte ikke lagre global Git-e-post. Exit code: $(Format-NativeExitCode -ExitCode $LASTEXITCODE)."
        }
        $gitConfigChanged = $true
    }

    if ($gitConfigChanged) {
        Write-Host 'Global Git-konfigurasjon er oppdatert:' -ForegroundColor Green
    } else {
        Write-Host 'Global Git-konfigurasjon er allerede oppdatert:' -ForegroundColor DarkGray
    }

    $savedName = git config --global --get user.name
    if ($LASTEXITCODE -ne 0) {
        throw 'Klarte ikke lese globalt Git-navn etter lagring.'
    }
    $savedEmail = git config --global --get user.email
    if ($LASTEXITCODE -ne 0) {
        throw 'Klarte ikke lese global Git-e-post etter lagring.'
    }
    Write-Host "  Navn: $savedName"
    Write-Host "  E-post: $savedEmail"
}

Invoke-Section -Message "`nKonfigurere Brave og installere Bitwarden, Surfshark, Unhook og SponsorBlock via policy?" -Action {
    Write-Host "`n=== Brave-policyer ===" -ForegroundColor Magenta
    Set-BravePolicies
}

Invoke-Section -Message "`nSette opp PowerShell med Oh My Posh, zoxide, Terminal-Icons, Nerd Font og profil?" -Action {
    Write-Host "`n=== PowerShell-oppsett ===" -ForegroundColor Magenta
    $dependencies = @(
        [pscustomobject]@{ Id = 'JanDeDobbeleer.OhMyPosh' }
        [pscustomobject]@{ Id = 'ajeetdsouza.zoxide' }
    )
    foreach ($dependency in $dependencies) {
        if (-not (Install-WingetPackage -Package $dependency)) {
            throw "Klarte ikke installere $($dependency.Id)."
        }
    }

    Sync-EnvironmentPath
    Install-OhMyPoshTheme
    Install-NerdFont
    Install-TerminalIconsModule
    Install-ConfigFile `
        -SourcePath $profileSource `
        -DestinationPath $PROFILE.CurrentUserCurrentHost `
        -Description 'PowerShell-profilen' `
        -BackupPrefix 'profile'
}

Invoke-Section -Message "`nInstallere innstillingene for Windows Terminal?" -Action {
    Write-Host "`n=== Windows Terminal ===" -ForegroundColor Magenta
    Install-TerminalSettings -SourcePath $terminalSettingsSource
}

Invoke-Section -Message "`nInstallere VS Code-innstillinger og Material Icon Theme?" -Action {
    Write-Host "`n=== VS Code ===" -ForegroundColor Magenta
    Install-VSCodeSettings -SourcePath $vscodeSettingsSource
}

Invoke-Section -Message "`nInstallere og konfigurere nyeste stabile Python?" -Action {
    Write-Host "`n=== Python ===" -ForegroundColor Magenta
    Install-LatestPython
}

Invoke-Section -Message "`nLaste ned og installere Zabooby/mpv-config i %APPDATA%\mpv?" -Action {
    Write-Host "`n=== mpv-konfigurasjon ===" -ForegroundColor Magenta
    Install-MpvConfig
}

Write-Host "`n=== Oppsett fullført ===" -ForegroundColor Cyan
if ($script:WingetFailures.Count -gt 0) {
    Write-Warning "Winget-pakker som feilet: $($script:WingetFailures -join ', ')"
    Write-Host "Winget-logger: $env:LOCALAPPDATA\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\DiagOutputDir" -ForegroundColor DarkGray
}
if ($script:SectionFailures.Count -gt 0) {
    Write-Warning "Deler som feilet: $($script:SectionFailures -join '; ')"
}

Write-Host "`nManuelle installasjoner som gjenstår:" -ForegroundColor Cyan
Write-Host '- Spotify: https://www.spotify.com/download/windows/, eller winget install Spotify.Spotify (ikke som administrator)'
Write-Host '- Goodnotes og MagicPods fra Microsoft Store'

if (-not $NoPause) {
    [void](Read-Host "`nTrykk Enter når du vil lukke vinduet")
}
