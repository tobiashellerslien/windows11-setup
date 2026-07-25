# Tobias' Windows 11-oppsett

## 0. Lag Windows 11-ISO

- Last ned Windows 11 fra [Microsoft](https://www.microsoft.com/nb-no/software-download/windows11) med språk Engelsk (USA).
- Bygg ISO-en med Chris Titus WinUtil:

```powershell
irm https://christitus.com/win | iex
```

- Flash ISO-en med [Rufus](https://rufus.ie/en/).

## 1. Drivere og oppdateringer

- Last ned drivere fra [ASUS](https://www.asus.com/supportonly/ga503qm/helpdesk_download/).
- Installer alle Windows Update-oppdateringer.

## 2. Windows-justeringer

- Kjør Chris Titus WinUtil og bruk anbefalte tweaks.
- Kjør O&O ShutUp10++ med anbefalte innstillinger.

```powershell
irm https://christitus.com/win | iex
```

## 3. Kjør setup-scriptet

Kontroller at `winget --version` fungerer. Oppdater ellers **App Installer** fra Microsoft Store.

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
- Kom i gang → importer `configfiles/bookmarks.html` via `brave://bookmarks`.
- Kom i gang → Ved oppstart → Ny fane.
- Utseende → vis startsideknappen.
- Utseende → bruk bred adresselinje.

### G-Helper

Start med Windows, åpne med ASUS ROG-knappen, gå gjennom innstillingene.

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




