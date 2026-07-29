# Tobias' Windows 11-oppsett

## Forberedelser
1. Lag Windows 11 ISO

    - Last ned Windows 11 fra [Microsoft](https://www.microsoft.com/nb-no/software-download/windows11) med språk Engelsk (USA).
    - Bygg ISO-en med Chris Titus WinUtil:

```powershell
irm https://christitus.com/win | iex
```

    - Flash ISO-en med [Rufus](https://rufus.ie/en/) eller med WinUtil etter ISO er ferdig bygget.

2. Last ned drivere fra [ASUS](https://www.asus.com/supportonly/ga503qm/helpdesk_download/), alt utenom NVIDIA drivere, til en minnepinne.

## 1. Drivere

Rett etter fresh windows installasjon:
- Installer driverne fra minnepinnen, begynn med AMD chipset driver
- Restart
- Nå som internett funker, installer NVCleanstall
```powershell
winget install TechPowerUp.NVCleanstall
```
- Installer NVIDIA GPU driver med NVCleanstall
- Gå deretter inn på Windows Update og installer alle oppdateringer

## 2. WinUtil

- Kjør Chris Titus WinUtil
    - Advanced tweaks++
    - Toggles
    - DNS
    - Kjør O&O ShutUp10++ med anbefalte innstillinger.
    - Power Panel -> skru av Fast Startup, skru på Hibernation

```powershell
irm https://christitus.com/win | iex
```

## 3. Kjør setup-scriptet

Kjør først i Windows PowerShell 5.1:

```powershell
winget install Microsoft.PowerShell Git.Git
```

Lukk terminalen, åpne en ny og kjør:

```powershell
git clone https://github.com/tobiashellerslien/windows11-setup.git
cd windows11-setup
pwsh .\Setup-Windows.ps1
```

Scriptet ber om administratorrettigheter og `y/n` før hver del. Det kan kjøres flere ganger, installerte pakker og identisk config hoppes over, mens endret config sikkerhetskopieres.

## 4. Manuelle installasjoner

- [Spotify](https://www.spotify.com/download/windows/), eller `winget install Spotify.Spotify` uten administratorrettigheter.
- GoodNotes og MagicPods fra Microsoft Store.
- Microsoft 365/Office fra [m365.cloud.microsoft/apps](https://m365.cloud.microsoft/apps).

## 5. Manuelt oppsett

### Brave

- Sett som standard nettleser
- Kom i gang → importer `configfiles/bookmarks.html`
- Kom i gang → Ved oppstart → Ny fane.
- Utseende → vis startsideknappen, bruk bred adresselinje.

### G-Helper

- Start med Windows
- Åpne med ASUS ROG-knappen
- Stopp ASUS services
- Gå gjennom innstillingene.

### SSH-nøkkel for GitHub

1. Opprett `%USERPROFILE%\.ssh` og lagre nøklene fra Bitwarden som `github` og `github.pub`.
2. Kjør som administrator:

```powershell
Set-Service ssh-agent -StartupType Automatic
Start-Service ssh-agent
```

3. Kjør uten administratorrettigheter:

```powershell
ssh-add "$env:USERPROFILE\.ssh\github"
ssh -T git@github.com
```

### Øvrig

- Logg inn med personlig konto og skolekonto.
- Kontroller oppstartsapper og personalisering.
- Sett standard apper:
    - FastStone for bilder
        - `.jpg`, `.jpeg`, `.png`, `.webp`, `.avif`, `.heic`, `.gif`, `.bmp`, `.ico`
    - mpv for video
        - `.mp4`, `.mkv`, `.webm`, `.mov`, `.avi`, `.m4v`, `.mpeg`, `.mpg`
    - Sumatra for PDF
- Sett opp OneDrive og logg inn i øvrige apper.
- Sjekk om Dolby Access er installert, hvis ikke, installer fra msstore. Sjekk at Dolby Atmos er valgt under "Spatial sound".
