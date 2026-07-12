# Windows 11 setup scripts og guide

## Steg for steg for å sette opp en fresh windows installasjon

### 0. Lag Win11 ISO
- Last ned fra [microsoft](https://www.microsoft.com/nb-no/software-download/windows11) (språk: Engelsk (USA)).
- Bruk [MicroWin](https://github.com/CodingWonders/MicroWin)/[Tiny11](https://github.com/ntdevlabs/tiny11builder) til å lage ISO.
- Flash USB med [Rufus](https://rufus.ie/en/). Rufus sine ISO innstillinger er ikke nødvendig etter ISO allerede er modifisert.

### 1. Drivere
Last ned fra [ASUS](https://www.asus.com/supportonly/ga503qm/helpdesk_download/).
Nvidia GPU drivere med NVCleanstall senere.

### 2. Windows Update
Gå inn på innstillinger og last ned oppdateringene som vises først.

### 3. Chris Titus WinUtil
Kjør anbefalte tweaks med WinUtil. 
```
irm https://christitus.com/win | iex
```
Kan også sette custom DNS, classic contex menu, right click end task m.m.

### 4. Kjør powershell script for å installere programmer
Last ned repoet.
Kjør script:
```
.\Setup-Windows.ps1
```
Scriptet kan kjøres gjentatte ganger. Hvert steg ber om bekreftelse.

På slutten gir det links til nedlastinger som må gjøres manuelt, de er også her:
- Ente Auth: https://github.com/ente/ente
- BCUninstaller: https://github.com/BCUninstaller/Bulk-Crap-Uninstaller/releases
- mpv: https://github.com/shinchiro/mpv-winbuild-cmake/releases (+ config fra configfiles/mpv.conf.zip -> $APPDATA$\mpv)
- GoodNotes/MagicPods (Microsoft Store)
- Microsoft 365 (https://m365.cloud.microsoft/apps) -> login med NTNU konto

### 5. Diverse oppsett:

#### G-helper
- Start ved oppstart
- Åpne med ASUS ROG knapp
- Sjekk andre innstillinger

#### Brave Browser:
- Importer bokmerker fra configfiles/bookmarks.html
- Extensions:
    - Bitwarden
    - Surfshark VPN
    - Unhook
    - SponsorBlock

#### Flow Launcher:
- installer Everything
- Font: Jetbrains Mono
- Appearance:
    - Windows 11 + Acrylic
    - Skru av klokke
- Extensions:
    - Caffeine
    - Bookmarks: sett til brave path

#### Windows Terminal:
- Skjul ubrukte profiler
- Startup -> Default Powershell 7
- Defaults -> Apperance:
    - Font: Jetbrains Mono
    - Enable Acrylic & Opacity 80%

#### Git:
- global navn og email:
```
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```
- ssh key for GitHub

#### Milennum for Steam
- Minimal Dark theme
- gå gjennom instillinger: fjern animasjoner, større play-knapp
- plugin: extendium
    - Augmented Steam
    - uBlock origin lite
- kjør Steam ROM Manager?

#### Div. Windows setup
- logg inn med personlig- og skolekonto
- onedrive?
- basic personalisering
- uncheck startup apps
- sett default apps
    - faststone for bilder
    - mpv for video
    - sumatra for PDF
    - brave som nettleser

## Til neste gang jeg oppdaterer denne:
- lag en Flow Launcher config som kan automatisk importeres


TODO:
mangler nyeste versjon av scriptet fra claude
slette søppel i onedrive/documents så før reinstallasjon, så det ikke ødelegger når onedrive lastes ned
lagre github ssh key for windows i bitwarden? slette wsl ssh key?