# Tobias' Windows 11 setup script og guide

## Steg for steg for å sette opp en fresh windows installasjon

### 0. Lag Win11 ISO

- Last ned fra [Microsoft](https://www.microsoft.com/nb-no/software-download/windows11) (språk: Engelsk (USA)).
- Bruk [MicroWin](https://github.com/CodingWonders/MicroWin) til å lage ISO.
- Flash USB med [Rufus](https://rufus.ie/en/). Rufus sine ISO innstillinger er ikke nødvendig etter ISO allerede er modifisert.

### 1. Drivere
Last ned fra [ASUS](https://www.asus.com/supportonly/ga503qm/helpdesk_download/).
Tar NVIDIA GPU drivere med NVCleanstall senere.

### 2. Windows Update
Gå inn på innstillinger og installer tilgjengelige oppdateringer.

### 3. Chris Titus WinUtil

Kjør anbefalte tweaks med WinUtil. 
```powershell
irm https://christitus.com/win | iex
```
Kan også sette custom DNS, classic contex menu, right click end task m.m.

### 4. Kjør powershell script for å installere programmer

En fersk Windows 11-installasjon har vanligvis Winget, men ikke Git eller PowerShell 7. Kontroller først at `winget --version` fungerer. Hvis ikke, oppdater **App Installer** fra Microsoft Store.

Gjør deretter dette i to deler:

**A) I vanlig Windows PowerShell (5.1):**

```powershell
winget install Microsoft.PowerShell Git.Git
```
Lukk terminalvinduet etter installasjonen, slik at neste terminal får oppdatert `PATH`.

**B) Åpne en ny terminal:**

```powershell
git clone https://github.com/tobiashellerslien/windows11-setup.git
cd windows11-setup
pwsh -NoProfile -ExecutionPolicy Bypass -File .\Setup-Windows.ps1
```

`-ExecutionPolicy Bypass` gjelder bare denne PowerShell-prosessen. Scriptet ber selv om administratorrettigheter når det starter.

Scriptet ber om `y/n` før hver del og setter opp:

- Programmer fra `packages.json` med winget.
- Global Git-konfigurasjon.
- Brave-debloat.
- PowerShell, Windows Terminal og VS Code config. Terminal må ha vært åpnet minst én gang.
- Nyeste stabile Python.
- mpv-konfigurasjon.

Vinduet blir stående åpent til du trykker Enter.

#### Gjentatt kjøring og backup

Scriptet kan kjøres flere ganger. Installerte programmer og uendrede filer hoppes over. Endrede konfigurasjonsfiler får en tidsstemplet backup før de erstattes; for mpv sikkerhetskopieres hele den gamle mappen. Gamle backuper slettes ikke automatisk.

#### Manuelle installasjoner som gjenstår:

- Spotify fra [spotify.com/download/windows](https://www.spotify.com/download/windows/), eller med winget install Spotify.Spotify (ikke som administrator)
- GoodNotes og MagicPods (Microsoft Store)

### 5. Diverse oppsett:

#### NVIDIA Drivere
Kjør driverinstallasjon med NVCleanstall.

#### G-helper
Sett opp til å starte med PC-en og åpne med ASUS ROG knapp. Gå gjennom innstillinger.

#### Brave Browser:
Importer bokmerker fra configfiles/bookmarks.html på ``brave://bookmarks``.

#### Flow Launcher:
- Font: Jetbrains Mono
- Gå gjennom settings
- Appearance:
    - Windows 11 + Acrylic
    - Skru av klokke
- Extensions:
    - Installer Caffeine
    - Bookmarks: sett til brave path
    - Explorer: sett opp søk med everything

#### SSH key for GitHub:

1. Opprett `%USERPROFILE%\.ssh` og lagre nøklene fra Bitwarden som `github` (privat) og `github.pub` (offentlig). Behold linjeskiftene i privatnøkkelen.
2. Kjør PowerShell som administrator:

```powershell
Set-Service ssh-agent -StartupType Automatic
Start-Service ssh-agent
```
3. Kjør i powershell uten administrator:
```powershell
ssh-add "$env:USERPROFILE\.ssh\github"
```

4. Test tilkoblingen og svar `yes` hvis GitHub spør om verten skal godkjennes:

```powershell
ssh -T git@github.com
```

En melding med GitHub-brukernavnet ditt bekrefter at autentiseringen virker.

#### Div. Windows setup

- logg inn med personlig- og skolekonto
- innstillinger -> personalisering
- check/uncheck startup apps
- sett default apps
    - brave som nettleser
    - FastStone for bilder
        - `.jpg`, `.jpeg`, `.png`, `.webp`, `.avif`, `.heic`, `.gif`, `.bmp`, `.ico`
    - mpv for video
        - `.mp4`, `.mkv`, `.webm`, `.mov`, `.avi`, `.m4v`, `.mpeg`, `.mpg`
    - sumatra for PDF
- onedrive login/oppsett
- logge inn på alle andre apper og gjøre div. oppsett der. For mye for å kunne liste opp alt, men ta det som det kommer.

## Til neste gang jeg oppdaterer denne

- lag en Flow Launcher config som kan automatisk importeres
- slette søppel i onedrive/documents før reinstallasjon, så det ikke ødelegger når onedrive lastes ned
