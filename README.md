# Windows 11 setup scripts og guide

## Steg for steg for å sette opp en fresh windows installasjon

### 0. Lag Win11 ISO
- Last ned fra [microsoft](https://www.microsoft.com/nb-no/software-download/windows11) (språk: Engelsk (USA)).
- Bruk [MicroWin](https://github.com/CodingWonders/MicroWin) til å lage ISO.
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

Fresh PC har ikke git ennå, og Windows PowerShell 5.1 (ikke pwsh) er det eneste som finnes før PowerShell 7 er installert. Gjør derfor dette i to steg:

**A) I vanlig Windows PowerShell (5.1):**
```
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
winget install --id Microsoft.PowerShell -e --silent
winget install --id Git.Git -e --silent
```
Lukk vinduet.

**B) Åpne en ny terminal og skriv `pwsh`:**
```
git clone https://github.com/<bruker>/<repo>.git
cd <repo>
.\Setup-Windows.ps1
```

Scriptet kan kjøres gjentatte ganger. Hvert steg ber om bekreftelse. Steg:
1. Winget-pakker (idempotent, sjekker om allerede installert)
2. Global git config (navn/e-post, printer `git config --list` etterpå)
3. Brave debloat (registry policies) + tvungen installasjon av extensions (Bitwarden, Surfshark VPN, Unhook, SponsorBlock)
4. PowerShell-oppsett: oh-my-posh (hul10-tema), zoxide, Terminal-Icons, JetBrains Mono Nerd Font, kopierer inn `Microsoft.PowerShell_profile.ps1`
5. Windows Terminal-innstillinger (kopierer configfiles/terminal.settings.json inn - krever at Terminal er åpnet minst én gang først)
6. Python (nyeste versjon via Python Install Manager)
7. yt-dlp -> C:\Tools + PATH
8. Millennium (Steam-tema) - pakker ut configfiles/millennium.zip til Steam-mappen
9. G-Helper -> C:\Tools + autostart-snarvei
10. FileConverter (åpner nedlastingssiden, ingen stabil direktelink)

På slutten gir det links til nedlastinger som fortsatt må gjøres manuelt, de er også her:
- Ente Auth: https://github.com/ente/ente
- BCUninstaller: https://github.com/BCUninstaller/Bulk-Crap-Uninstaller/releases
- mpv: https://github.com/shinchiro/mpv-winbuild-cmake/releases (+ config fra configfiles/mpv.conf.zip -> $APPDATA$\mpv)
- GoodNotes/MagicPods (Microsoft Store)
- Microsoft 365 (https://m365.cloud.microsoft/apps) -> login med NTNU konto

### 5. Diverse oppsett:

#### NVIDIA Drivere
Kjør driverinstallasjon med NVCleanstall

#### G-helper
- Åpne med ASUS ROG knapp
- Sjekk andre innstillinger

#### Brave Browser:
- Importer bokmerker fra configfiles/bookmarks.html på ``brave://bookmarks``
(Extensions installeres automatisk av scriptet: Bitwarden, Surfshark VPN, Unhook, SponsorBlock)

#### Flow Launcher:
- Font: Jetbrains Mono
- Gå gjennom settings
- Appearance:
    - Windows 11 + Acrylic
    - Skru av klokke
- Extensions:
    - Installer Caffeine
    - Bookmarks: sett til brave path
    - Explorer: sett opp everything. Hvis man prøver et søk blir man promptet til å installere.

#### Git:
- ssh key for GitHub, hent fra Bitwarden

#### Div. Windows setup
- logg inn med personlig- og skolekonto
- onedrive
- basic innstillinger -> personalisering
- uncheck startup apps
- sett default apps
    - faststone for bilder
    - mpv for video
    - sumatra for PDF
    - brave som nettleser

## Til neste gang jeg oppdaterer denne:
- lag en Flow Launcher config som kan automatisk importeres


TODO:
slette søppel i onedrive/documents før reinstallasjon, så det ikke ødelegger når onedrive lastes ned
legg til et steg som alene godkjenner om man vil installere Microsoft.OneDrive med winget


Feil fra testkjøring:
- 7 zip feilet (stod cancelled, selv om jeg ikke kansellerte) (exit code -2147467260)
- spotify kan ikke lastes ned fra admin, fikk error
- ved reload av path før python install kom det en lang melding om for lang path/for mange characters i path elns. Men alt så til å funke og python ble installert. Vet du hva det kan være? 
- vindu lukkes med en gang det er ferdig, vil at det stopper på slutten og holder vinduet åpent, så man faktisk kan lese prints på slutten og lukke vindu når man vil
- milennium kopier mappe funket ikke. Roll back til å laste ned installer til downloads. Kan 
- la flow launcher installere everything, i stedet for å ha i winget

fjern døde profiler fra terminal config, fjern alt utenom powershell 7 & 5, og cmd

microwin fjernet ingen bloat apps, test tiny11 heller
