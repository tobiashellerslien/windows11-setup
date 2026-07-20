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
git clone https://github.com/tobiashellerslien/windows11-setup.git
cd windows11-setup
.\Setup-Windows.ps1
```

Scriptet kan kjøres gjentatte ganger. Hvert steg ber om bekreftelse. Steg:
- Winget-pakker (sjekker om programmer allerede er installert før den installerer)
- Global git config (navn/e-post, printer `git config --list` etterpå)
- Brave debloat (registry policies) + tvungen installasjon av extensions (Bitwarden, Surfshark VPN, Unhook, SponsorBlock)
- PowerShell-oppsett: oh-my-posh (hul10-tema), zoxide, Terminal-Icons, JetBrains Mono Nerd Font, kopierer inn `Microsoft.PowerShell_profile.ps1`
- Windows Terminal-innstillinger (kopierer configfiles/terminal.settings.json inn - krever at Terminal er åpnet minst én gang først)
- Python (nyeste versjon via Python Install Manager)
- FileConverter (åpner nedlastingssiden, ingen stabil direktelink og ligger ikke i winget)

På slutten gir det links til nedlastinger som fortsatt må gjøres manuelt, de er også her:
- GoodNotes/MagicPods (Microsoft Store)
- Microsoft 365 (https://m365.cloud.microsoft/apps) -> login med NTNU konto

### 5. Diverse oppsett:

#### NVIDIA Drivere
Kjør driverinstallasjon med NVCleanstall

#### G-helper
- Sett opp til å starte med PC-en og åpne med ASUS ROG knapp
- Gå gjennom innstillinger

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
    - Explorer: sett opp søk med everything

#### Git:
- ssh key for GitHub, hent fra Bitwarden

#### Div. Windows setup
- logg inn med personlig- og skolekonto
- basic innstillinger -> personalisering
- check/uncheck startup apps
- sett default apps
    - faststone for bilder
    - mpv for video
    - sumatra for PDF
    - brave som nettleser
- onedrive login/oppsett

## Til neste gang jeg oppdaterer denne:
- lag en Flow Launcher config som kan automatisk importeres


TODO:
- slette søppel i onedrive/documents før reinstallasjon, så det ikke ødelegger når onedrive lastes ned
- undersøk om terminal config om den er grei
- undersøk vscode config, hva som kan spares på (autosave, telemetry?)
- installere dark cursom?

prompt:
holder på å lage et powershell script for å automatisere oppsett av en fresh widows installasjon. Her er nåværende script vedlagt.

er flere endringer jeg ønsker å gjøre. Først, her er feil jeg støtte på etter å ha kjørt scriptet i en ny windows VM:
- 7 zip feilet (stod cancelled, selv om jeg ikke kansellerte) (exit code -2147467260)
- spotify kan ikke lastes ned som admin, fikk error
- ved reload av path før python install kom det en lang melding om for lang path/for mange characters i path elns. Men alt så til å funke og python ble installert. Vet du hva det kan være? Ser at både py install og py install --configure ligger inne, trengs det?
- vindu lukkes med en gang det er ferdig, vil at det stopper på slutten og holder vinduet åpent, så man faktisk kan lese prints på slutten og lukke vindu når man vil
Resten funket (utenom millennium, men det skal fjernes uansett). 

Her er andre endringer jeg har lyst til å gjøre:

- fjern alt av STEG NR, vil fortsatt at hver del skal ha en prompt med y/n, men ikke ha dem som nummererte steg
- gjør j/n til y/n
- ha en prompt rundt installering av alle winget programmene
- skal laste ned mpv med winget (jeg legger inn pakken i ekstern fil, winget steget tar seg av denne automatisk nå) så den kan fjernes fra manuell delen. Men vil ha et steg som legger inn configen fra dette repoet: https://github.com/Zabooby/mpv-config her vil jeg at alle filene inni portable_config mappen blir flyttet til %APPDATA%/mpv. Finn en god løsning på dette
- skal også laste ned BCUninstaller, yt-dlp, g-helper, ente auth med winget, fjern fra manuell. Legger også disse inn i packages filen selv, så winget steget tar nå hånd om dem. skal bare være fileconverter, m365 og appene fra ms store som skal være igjen som manuelle installasjoner
- fjern alt av millennium greier, vil ikke ha det 

se om scriptet har rot eller gjør unødvendige ting, lager unødvendige filer eller snarveier, er uoversiktlig. Rydd opp i det.
