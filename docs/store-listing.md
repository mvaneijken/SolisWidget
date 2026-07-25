# Connect IQ store listing texts

Texts for the [store listing](https://apps.garmin.com/nl-NL/apps/10aaf779-d874-453f-a0cc-6795f5dad76c),
updated for version 0.1.0 (SolisCloud API v2). Copy these into the developer
dashboard when uploading a new version.

---

## Description (English)

The Solis Solar Panels Widget allows you to monitor your solar output from your Ginlong Solis solar panels on your Garmin Connect IQ device.

IMPORTANT: As of version 0.1.0 this widget uses the new SolisCloud API. Signing in with your Solis username and password is no longer possible — you now need a SolisCloud API Key and API Secret:

1. Sign in to the SolisCloud portal at https://www.soliscloud.com
2. Enable API access via Basic Settings → API Management. If this option is not available for your account, request API access from Solis first: https://solis-service.solisinverters.com/support/solutions/articles/44002212561-api-access-soliscloud
3. Enter the KeyID (API Key) and KeySecret (API Secret) in the widget settings, using the Garmin Connect app or Garmin Express

The widget automatically detects your station (plant) the first time it connects, so no further configuration is needed.

This widget requires the following to run correctly:

- a Garmin device that supports Connect IQ 3.0 or higher
- an internet connected Android or iOS device with the Garmin Connect app installed
- the Garmin device must be paired with the phone running the Garmin Connect app
- a SolisCloud account with API access, with the API Key and API Secret configured in the widget settings

This widget supports Glances on devices that support them.

Common errors:

- "Invalid settings": the API Key or API Secret is missing or incorrect — check the widget settings
- "API Err: ...": the SolisCloud API rejected the request — check that API access is enabled and your Key/Secret are correct
- "No Connection": your watch cannot reach your phone — check the Bluetooth connection

Note: I am an enthusiastic Solis and Garmin user who created this widget as a hobby. I am not affiliated with Solis in any form.

---

## What's New (English)

Version 0.1.0

0.1.0: IMPORTANT — the widget now uses the new SolisCloud API. Your old username/password no longer works: create an API Key and API Secret in the SolisCloud portal (see the description for instructions) and enter them in the widget settings. Your station is now detected automatically. Also includes glance improvements and small bug fixes.

0.0.15: Error handling for missing plant id, support for new devices

0.0.14: Stability improvements

0.0.13: Fix incorrect total generation value

0.0.12: Correct last update time display

0.0.11: Fix glance initial value and when null

0.0.10: Add support for new devices

0.0.9: Use different API endpoint to reduce the chance of -403 errors at the end of the day

0.0.8: Again reduce memory usage. Note: You need to re-enter your credentials!

0.0.7: Optimize variables

0.0.6: Improved handling app settings

0.0.5: Attempt to fix widget crashes on some devices

0.0.4: More reduced memory usage

0.0.3: Reduced memory usage

0.0.2: Added error handling

0.0.1: Initial (test) version

---

## Omschrijving (Nederlands)

Met de Solis Solar Panels Widget bekijk je de opbrengst van je Ginlong Solis zonnepanelen rechtstreeks op je Garmin Connect IQ-toestel.

BELANGRIJK: Vanaf versie 0.1.0 gebruikt deze widget de nieuwe SolisCloud API. Inloggen met je Solis gebruikersnaam en wachtwoord werkt niet meer — je hebt nu een SolisCloud API Key en API Secret nodig:

1. Log in op het SolisCloud-portaal via https://www.soliscloud.com
2. Schakel API-toegang in via Basic Settings → API Management. Is deze optie niet zichtbaar voor je account, vraag dan eerst API-toegang aan bij Solis: https://solis-service.solisinverters.com/support/solutions/articles/44002212561-api-access-soliscloud
3. Vul de KeyID (API Key) en KeySecret (API Secret) in bij de instellingen van de widget, via de Garmin Connect-app of Garmin Express

De widget detecteert automatisch je station (installatie) bij de eerste verbinding; verdere configuratie is niet nodig.

Voor deze widget heb je het volgende nodig:

- een Garmin-toestel met Connect IQ 3.0 of hoger
- een Android- of iOS-telefoon met internetverbinding en de Garmin Connect-app
- het Garmin-toestel moet gekoppeld zijn met de telefoon waarop de Garmin Connect-app draait
- een SolisCloud-account met API-toegang, met de API Key en API Secret ingevuld in de instellingen van de widget

Deze widget ondersteunt Glances op toestellen die dat ondersteunen.

Veelvoorkomende meldingen:

- "Invalid settings": de API Key of API Secret ontbreekt of is onjuist — controleer de instellingen van de widget
- "API Err: ...": de SolisCloud API heeft het verzoek geweigerd — controleer of API-toegang is ingeschakeld en of je Key/Secret kloppen
- "Geen Internet" / "No Connection": je horloge kan je telefoon niet bereiken — controleer de Bluetooth-verbinding

Let op: ik ben een enthousiaste Solis- en Garmin-gebruiker die deze widget als hobby heeft gemaakt. Ik ben op geen enkele manier verbonden aan Solis.

---

## Wat is er nieuw (Nederlands)

Versie 0.1.0

0.1.0: BELANGRIJK — de widget gebruikt nu de nieuwe SolisCloud API. Je oude gebruikersnaam/wachtwoord werkt niet meer: maak een API Key en API Secret aan in het SolisCloud-portaal (zie de omschrijving voor instructies) en vul deze in bij de instellingen van de widget. Je station wordt voortaan automatisch gedetecteerd. Daarnaast verbeteringen aan de glance-weergave en kleine bugfixes.

0.0.15: Foutafhandeling voor ontbrekend plant-id, ondersteuning voor nieuwe toestellen

0.0.14: Stabiliteitsverbeteringen

0.0.13: Onjuiste totale opbrengst gecorrigeerd

0.0.12: Weergave van laatste updatetijd gecorrigeerd

0.0.11: Beginwaarde van de glance gecorrigeerd (ook bij lege waarde)

0.0.10: Ondersteuning voor nieuwe toestellen toegevoegd

0.0.9: Ander API-endpoint om de kans op -403-fouten aan het einde van de dag te verkleinen

0.0.8: Geheugengebruik verder verlaagd. Let op: je moet je gegevens opnieuw invoeren!

0.0.7: Variabelen geoptimaliseerd

0.0.6: Verbeterde verwerking van app-instellingen

0.0.5: Poging om crashes op sommige toestellen te verhelpen

0.0.4: Geheugengebruik verder verlaagd

0.0.3: Geheugengebruik verlaagd

0.0.2: Foutafhandeling toegevoegd

0.0.1: Eerste (test)versie
