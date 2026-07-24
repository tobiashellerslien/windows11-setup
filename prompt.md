# Generelt
Her er et prosjekt der jeg vil sette opp et script for å installere apper og sette opp div konfigurasjon automatisk på en fresh windows installasjon, samt noen manuelle instruksjoner som jeg må huske på. Dette er kun for mitt personlige bruk, trenger ikke å vre utdypende forklaringer.
Jeg vil teste dette selv i en VM. Ikke kjør egne tester. Bare verifiser syntax og slikt.

Setup-Windows.ps1 er scriptet som skal sette opp alt. Det har ulike deler, med prompts. Det skal kunne kjøres gjentatte ganger uten å ødelegge noe. Det skal ikke være for bloated og unødvendig stort. Det skal ikke etterlate seg fotprint på pc-en.
I configfiles/ mappene ligger mine personlige configfiler. Du trenger ikke laste inn hele bookmarks.html, den inneholder bare mine bokmerker og skal forbli som den er.

Har kjørt scriptet i en VM, og har noen tilbakemeldinger, samt andre ting jeg har lyst til å endre. Les prosjektet, les disse notatene/instruksene, og 

# Readme
- Legg inn punkt om OO shutup 10++ sammen med Chris Titus winutil. Recommended settings, men ha password reveal button og skru av game bar
- legg inn punkt under manuell installasjon om å laste ned office fra  m365.cloud.microsoft/apps. 

# Script
- Kun kosmetisk, men under kjøring nå printer scriptet alt som ny linje, så spinnende bar under winget nedlasting kommer som masse tegn alle på ny linje i stedet for en spinnende bar in place. 
- Fjern git gui og bash fra Shell automatisk. Ligger i registry under Shell. Kommer automatisk med git install. Legg inn i git config steget?
- Legg inn steg om å sette downloads som default windows explorer start mappe. Kan gjøres i registry. 
- Endre brave dns til adguard family
- fjern manuell installasjon delen i slutten av scriptet. Denne ligger i readme og det er nok.

## Winget
- Fjern evt. package type options. Hadde tidligere msi versjon av 7zip men endret tilbake til vanlig. Vet ikke om det henger igjen gammel kode.

## Errors
- Fikk Warning: del feilet fontkopiering fullførte ikke på powershell profile delen. Men fonten ble installert. Powershell profil ble ikke kopiert inn og terminal icons ikke installert. Hvis jeg kommenterte ut font installen så funket alt annet. Undersøke slutten av font install, og vurdere å flytte til eget steg i tillegg. 
- Nerd font second run, prompt for hver font som krevde bekreftelse fordi allerede var installert. Veldig tungvint. flytte font ut til eget steg med prompt, la resten av terminal greiene være uten font installasjon i eget steg. Oh-my-posh har også innebygd font installasjon tror jeg. Trenger en bedre måte å gjøre dette på enn nå.

## Flow launcher:
- Har lagt inn userdata mappen min som en .zip i configfiles. Legg inn et steg i scriptet om å kopiere innholdet i denne inn i appdata/roaming/FlowLauncher. 
- Fjern info om manuelt oppsett i readme nå

## Brave:
- Utvid/endre kort guide til manuelt setup
- Kom i gang: bokmerker
- Kom i gang: ved oppstart: ny fane
- Utseende: vis startsideknapp, bruk vid adresselinje

## Terminal:
- Keybinds virker ikke etter settings import. Går inn på settings og de står ikke der. Åpner jeg settings.json ligger de der, men trykker jeg save i terminal settings å blir alle unbound i settings.json. Er det syntax feil i config filen? 

# Verifisering
Verifiser at readme er kort og konsis, uten unødvedig info.