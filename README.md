# Aarhus ToGo

En klikbar iPhone-prototype til franske turister i Aarhus. Appen viser bæredygtige steder, beregner CO₂ for dagens ture og giver rabat hos partnere: jo mindre CO₂ man udleder i dag, jo større rabat. Den finder også den grønneste vej til et sted (gå, Donkey-cykel, Lime, bus eller letbane).

Det er et skoleprojekt og et koncept. Appen er ikke et færdigt produkt.

- **Platform:** iPhone, iOS 26 eller nyere, SwiftUI (Xcode 27).
- **Sprog:** fransk og dansk. Man vælger sprog i spørgeskemaet eller i menuen ••• på forsiden, uafhængigt af telefonens sprog. Teksterne ligger i `fr.lproj/` og `da.lproj/` (én fil pr. sprog), og stederne har `description_fr` og `description_da`.
- **Ingen backend.** Al data ligger i JSON-filer i appen, og dagens ture gemmes lokalt på telefonen. Det eneste, appen henter live, er cykel- og gåruter fra OSRM, og den har en reserve, hvis tjenesten ikke svarer.

## Webudgave – til alle telefoner

**https://agg3mam.github.io/aarhus-togo/**

Webudgaven gør det samme som iPhone-appen og kræver hverken App Store eller Apple Developer-medlemskab. Den virker på iPhone og Android:

- **iPhone (Safari):** åbn linket › Del-knappen › *Føj til hjemmeskærm*.
- **Android (Chrome):** åbn linket › menuen ⋮ › *Installer app* / *Føj til startskærm*.

Den åbner så i fuld skærm med eget ikon og virker offline efter første besøg (kortfliser dog kun for områder, man har set). Data, fotos og tekster kommer fra `ios/HyggeVert/` via `web/scripts/sync-data.mjs`, så app og web altid er ens. Kortet bruger OpenStreetMaps egne fliser (gratis, uden nøgle) i stedet for Apple Maps.

Webudgaven bygges og lægges op automatisk af GitHub Actions (`.github/workflows/pages.yml`) ved hvert push til `main`. Lokalt:

```bash
cd web && npm install && npm run dev
```

## Start appen

1. Åbn `ios/HyggeVert.xcodeproj` i Xcode.
2. Vælg skemaet **HyggeVert** og en simulator, fx *iPhone 18 Pro*.
3. Tryk ⌘R.

Fra Terminal:

```bash
cd ios && xcodebuild -project HyggeVert.xcodeproj -scheme HyggeVert -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath build build
```

**Placering i simulatoren:** simulatoren står normalt i Californien, så appen regner fra **Aarhus H** som reserve (det står "position de démo" i appen). Vil du vise en rigtig placering i Aarhus, så vælg *Features › Location › Custom Location…* i Simulator, eller kør:

```bash
xcrun simctl location booted set 56.1567,10.2108
```

## Vis appen på din egen iPhone

Appen kan ikke lægges i Expo Go eller App Store. Den installeres direkte fra Xcode. Fra Terminal, når telefonen er tilsluttet (find id'et med `xcrun devicectl list devices`):

```bash
cd ios && xcodebuild -project HyggeVert.xcodeproj -scheme HyggeVert -destination 'id=<iphone-id>' -derivedDataPath build -allowProvisioningUpdates build && xcrun devicectl device install app --device <iphone-id> build/Build/Products/Debug-iphoneos/HyggeVert.app
```

Eller i Xcode:

1. Slut iPhonen til Mac'en med kabel (eller brug samme wifi efter første gang), og slå **Udviklertilstand** til på telefonen (*Indstillinger › Anonymitet og sikkerhed › Udviklertilstand*).
2. I Xcode: *Settings › Accounts* → tilføj dit Apple-id.
3. Vælg målet **HyggeVert** › *Signing & Capabilities* › vælg dit team.
4. Vælg din iPhone øverst i Xcode, og tryk ⌘R.
5. Første gang: på telefonen *Indstillinger › Generelt › VPN og enhedsadministration* → stol på udvikleren.

Med et gratis Apple-id virker installationen i 7 dage, og så skal den installeres igen fra Xcode. Skal andre (fx læreren) installere appen på deres egen telefon, kræver det TestFlight og et betalt Apple Developer-medlemskab.

## Spørgeskema ved første start

Første gang appen åbnes, vælger man sprog og skriver sit navn. Derefter kommer fire spørgsmål: hvad man vil lave (mad, shopping, museer, natur, oplevelser), budget (0–5 000 €), alder (15–70) og hvem man rejser med. Svarene gemmes på telefonen og bruges sådan:

- **"Pour toi" / "Til dig"** på forsiden og som filter i Explorer: steder, der passer til interesserne. Børnefamilier får fx Tivoli Friheden, Den Gamle By og Naturhistorisk Museum, og soloturister får de lokale hemmeligheder.
- **Budget:** under 300 € prioriteres natur og parker (gratis), over 2 000 € udflugter og økologiske restauranter. Appen viser ingen priser, fordi de ikke kunne tjekkes.
- **Alder:** fra 65 år foreslås gang kun op til ca. 1,6 km i stedet for 3,2 km.
- **Navn:** hilsenen på forsiden ("Bonjour …" / "Hej …").

Man kan tage spørgeskemaet igen fra menuen •••.

## Skærme

| Fane | Indhold |
|---|---|
| **Accueil** | "Bonjour Camille" og en ring med dagens CO₂ mod budgettet på 8 kg. Ringens spor er delt i de tre rabatzoner (Forêt 0–2 kg, Prairie 2–5 kg, Ville 5–8 kg), og ved siden af står rabatten og afstanden til næste grænse. Derunder dagens ture og fire tips (postevand, pant, cykel, det røde Ø-mærke). Menuen (•••) kan indlæse en eksempeldag eller nulstille dagen. |
| **Carte** | Fuldskærmskort med to lag, der kan slås til og fra: *Lieux* (farvet efter kategori) og *Transports* (letbane altid; busstoppesteder og Donkey-hubs, når man zoomer ind; Lime-zoner). Tryk på en markør for at åbne bundarket med "Y aller". |
| **Explorer** | Alle steder med filtrene Tout, Nature, Musées, Secrets locaux, Excursions og Partenaires, sorteret efter afstand, og med "Voir sur la carte". |
| **Trajet** | CO₂-beregner: vælg rejseform og distance, se udledningen mod bilen og rabatniveauet bagefter, og tryk "Ajouter à ma journée". |
| **Remises** | QR-kupon med dagens rabat, de tre niveauer og partnerlisten. Kuponen låses op ved dagens første tur. |

**"Y aller":** appen spørger om placering (med Aarhus H som reserve), viser 2–4 grønne forslag sorteret efter CO₂ og bilen nedtonet til sidst. Når man vælger et forslag, tegnes ruten på kortet med én farve pr. ben: gå (blå prikker), cykel (grøn) og bus/letbane (mørk stiplet linje). Bagefter vises knapper til Donkey Republic, Lime, Midttrafik, billet og Google Maps / Plans, og til sidst "J'y suis !".

## Hvad er rigtige data, og hvad er demo?

| Data | Fil | Status | Kilde |
|---|---|---|---|
| Steder (75) | `Data/places.json` | **Rigtige koordinater** | OpenStreetMap via Nominatim (ODbL), hentet 28.10.2026 med `scripts/geocode.mjs` (slår kun nye steder op; `--all` slår alle op igen). Beskrivelserne er skrevet til appen på fransk og dansk. |
| Økologiske spisesteder (8) | `Data/places.json` (`"organic": true`) | **Rigtige** | VisitAarhus' liste over restauranter med Det Økologiske Spisemærke ([visitaarhus.com](https://www.visitaarhus.com/aarhus-region/sustainable-travel/organic-restaurants)), 28.10.2026. Siden oplyser ikke guld/sølv/bronze, så appen skriver kun "mindst 30 % økologisk" (bronzekravet). |
| Restauranter og caféer (24) | `Data/places.json` | **Rigtige** | VisitAarhus' lister over restauranter ([visitaarhus.com](https://www.visitaarhus.com/aarhus-region/plan-your-trip/eat-and-drink-aarhus-region/restaurants)) og caféer ([visitaarhus.com](https://www.visitaarhus.com/aarhus/eat-and-drink/cafes-aarhus)), 28.10.2026. Beskrivelserne bygger kun på det, VisitAarhus skriver. Caféer har kategorien `cafe`. |
| Fotos (38) | `Images/<id>.jpg`, `Data/photo-credits.json` | **Rigtige, frie licenser** | Wikimedia Commons via OpenStreetMap-taggen `wikidata` → Wikidata (P18), hentet med `scripts/fetch-photos.mjs`. Licenserne er CC BY, CC BY-SA, CC0 eller public domain. Fotograf og licens står under hvert foto og linker til fotoets side på Commons, som licenserne kræver. Steder uden foto på Commons (de fleste restauranter og caféer) viser kategoriens farve og ikon. Fotos fra VisitAarhus og restauranternes egne billeder er ikke brugt, fordi de er beskyttet af ophavsret. `scripts/photo-overrides.json` styrer undtagelser (fx ARoS-caféen og Substans, hvor fotoet ikke passede). |
| Oplevelser (9) | `Data/places.json` | **Rigtige** | Udvalgt fra VisitAarhus' "The big things to see and do in Aarhus" ([visitaarhus.com](https://www.visitaarhus.com/node/1064)), fx Tivoli Friheden, Musikhuset, Aarhus Øje, Salling Rooftop og Domkirken. |
| Bus- og letbanestoppesteder (600, heraf 12 letbane) | `Data/stops.json` | **Rigtige** | OpenStreetMap via Overpass API for Aarhus Kommune, hentet én gang med `scripts/fetch-stops.mjs`. Ingen live-kald. |
| Donkey Republic-hubs (471) | `Data/donkey-hubs.json` | **Rigtige** | Donkey Republics offentlige GBFS-feed `donkey_aarhus/station_information` (licens CC0-1.0), hentet med `scripts/fetch-donkey.mjs`. Hver hub har sit eget deep link fra feedet. |
| Lime-zoner (11) | `Data/lime-zones.json` | **DEMO** (`"demo": true`, "Exemple" i appen) | Lime har intet offentligt GBFS-feed for Aarhus (tjekket i MobilityData's `systems.csv`). Zonerne ligger ved rigtige stoppesteder, men er opdigtede. |
| Partnere (5) | `Data/partners.json` | **DEMO** (pladsholdere i [klammer]) | Ingen rigtige virksomheder. Positionerne er eksempler ved stoppesteder. |
| CO₂-faktorer | `Data/co2-factors.json` | **Pladsholdere** (`"verified": false`) | Værdierne fra projektoplægget: gang 0, cykel/Donkey 0, Lime 20, letbane 35, tog 35, bus 80, bil 170 g CO₂e/personkm. De er ikke tjekket mod en kilde endnu (fx Transportministeriets TEMA-model, Miljøstyrelsen eller Climatiq). |
| Ruter | live | **Rigtige** | Offentlig OSRM på `routing.openstreetmap.de` (profilerne foot og bike). Svarer den ikke inden for 8 sekunder, tegnes en lige linje, og Google Maps / Plans-knappen virker stadig. |
| Bus/letbane-strækninger | beregnet | **Overslag** | Appen kender ikke køreplanen. Turen tegnes som en lige stiplet linje ("tracé indicatif"), og tiden er et overslag. "Itinéraire en transports" åbner Google Maps med `travelmode=transit`. |
| Tider | beregnet | **Overslag** | Gang fra OSRM; cykel 15 km/t, Lime 18 km/t, bus 20 km/t, letbane 22 km/t, tog 65 km/t, plus ventetid. |

**Steder, der ikke kunne findes:** *Aarhus Central Food Market*, *Restaurant St. Pauls Apothek*, *Mas Vino Vinbodega*, *Stillers Coffee*, *Resonans Bistro og Bar* og *Boardgame Cafe* fandtes ikke i OpenStreetMap og er udeladt. *Evald Brasserie* og *Pica Pica* er også udeladt, fordi OpenStreetMap-hittet ikke passede (en gade og et sted på Museumsgade i stedet for ved åen). Alle andre steder blev fundet. Tre caféer ligger samme sted som deres museum (ARoS, Moesgaard, Den Gamle By). På kortet vises de i museets bundark under "Aussi sur place" i stedet for som en ekstra markør. Tre opslag måtte gøres mere præcise: Moesgaard Museum (adressen Moesgård Allé 15), Naturhistorisk Museum og Godsbanen. Nogle steder fra oplægget er slået sammen til ét punkt: *Marselisborgskovene og Dyrehaven*, *Aarhus Ø og Havnebadet*, *Brabrand Sø og Årslev Engsø* samt *Fløjstrup Skov og Ørnereden*. Ebeltoft og Silkeborg er delt op i hvert sit museum.

**Ingen åbningstider eller priser** er med, fordi de ikke kunne tjekkes.

## Bevidste valg og afvigelser fra oplægget

- **SwiftUI i stedet for Expo/React Native.** Oplægget lagde op til Expo, men appen skulle være en rigtig iPhone-app ligesom Vinyl Shelf. Derfor er den bygget i Xcode.
- **Apple MapKit i stedet for MapLibre/Leaflet.** MapKit er indbygget i iOS, gratis og kræver ingen nøgle. Ruterne kommer stadig fra OSRM (OpenStreetMap-data).
- **SwiftUI-animationer i stedet for Reanimated/Lottie.** Bladet, der vokser, når man vælger en cykel, er lavet med en indbygget SwiftUI-animation, så der ikke skal bruges et ekstra bibliotek. SF Symbols bruges som stregikoner i stedet for Lucide.
- **Midttrafik-billetter.** Midttrafiks billetter sælges i dag i appen **Rejsebillet** (Rejsekort A/S). "Midttrafik live" bruges kun til at følge bussen. Appen linker til begge og nævner Rejsekort.
- **Rabatten afhænger også af rejseformen.** Ud over CO₂-grænserne sætter dagens ture et loft: til fods eller på cykel kan man nå Niveau Forêt (−20 %), med Lime eller offentlig transport højst Niveau Prairie (−10 %), og en tur i bil fjerner rabatten for hele dagen. Det er et valg i appen, ikke en del af oplægget.
- **Rabatten låses op ved første tur.** Uden ture ville man ellers have −20 % fra morgenstunden. Derfor "stiger" rabatten i demoen fra 0 % til −20 %.
- **Design:** ringen er det ene markante element og viser selve rabatsystemet. Resten holdes roligt: radier i et hierarki (hovedkort 28, kort 20, indre flader 14), tipsene samlet i ét kort, og "Secrets locaux" på mørke kort i Explorer, så de skiller sig ud som lokale tips.
- **Partnere** har en okkerfarve (`#87631A`), fordi paletten ikke havde en femte kategorifarve. Kontrasten mod hvid er 5,5:1.
- **Kontrast:** alle tekstfarver er tjekket til mindst 4,5:1. Bil-kortet i "Y aller" er bevidst nedtonet og kan ikke vælges.

## Mapper

```
HyggeVert/
  ios/
    HyggeVert.xcodeproj
    Info.plist                 skrifttyper (UIAppFonts)
    HyggeVert/
      HyggeVertApp.swift       app, faner, banner efter "J'y suis !"
      Theme.swift              farver, skrifter, kort og knapper
      Models.swift             rejseformer, steder, transport, sprog-hjælper L()
      AppData.swift            indlæser JSON, afstand, rabatniveauer
      DayModel.swift           dagens ture (gemt lokalt)
      LocationProvider.swift   placering med Aarhus H som reserve
      Planner.swift            rejseforslag og OSRM-ruter
      Links.swift              deep links (Donkey, Lime, Midttrafik, Google Maps, Plans)
      HomeView / MapScreen / GoFlow / ExploreView / TripCalculatorView / DiscountsView
      Data/                    places, stops, donkey-hubs, lime-zones, partners, co2-factors
      Fonts/                   Bricolage Grotesque + DM Sans (SIL Open Font License)
      fr.lproj/                franske tekster
  scripts/                     henter og genererer data (Node 18+ og Python 3)
```

Sådan opdaterer du data:

```bash
node scripts/fetch-stops.mjs
```

```bash
node scripts/fetch-donkey.mjs
```

```bash
node scripts/geocode.mjs
```

```bash
python3 scripts/make-demo-data.py
```

## Tilføj et sprog

Dansk er tilføjet. Engelsk tilføjes på samme måde:

1. Kopiér `fr.lproj/Localizable.strings` til `en.lproj/`, og oversæt værdierne. Nøglerne skal være de samme.
2. Tilføj `en` i `AppLanguage` (`Models.swift`) og under *Project › Info › Localizations* i Xcode.
3. Tilføj `description_en` i `scripts/places-src.json`, og lad `Place.summary` vælge efter sprog.

## Idéer til næste version

- Rigtige CO₂-faktorer med kilder (TEMA-modellen, Miljøstyrelsen), markeret `verified: true`.
- Rigtige partnere og en kupon, der kan scannes og kun bruges én gang (kræver en backend).
- Live-køreplaner fra Rejseplanen API, så bus- og letbaneruter tegnes rigtigt.
- Ledige Donkey-cykler pr. hub fra `station_status` i GBFS-feedet.
- Lime-data, hvis Lime åbner et feed for Aarhus, eller en aftale om at få det.
- Automatisk registrering af ture (Core Motion), så man ikke selv skal trykke "J'y suis !".
- Engelsk udgave, Dynamic Island og en widget med dagens CO₂.
- Ugeoversigt med CO₂ pr. dag og små udfordringer ("3 dage i træk under 2 kg").
- Offline-kort til udflugter uden for byen.
