# Laver de filer, der IKKE kommer fra en rigtig kilde: CO2-faktorer (pladsholdere),
# Lime-demozoner og partner-pladsholdere. Alt demo er markeret "demo": true.
# Kør: python3 scripts/make-demo-data.py
import json, pathlib
root = pathlib.Path(__file__).resolve().parent.parent / 'ios' / 'HyggeVert' / 'Data'
stops = {s['name']: s for s in json.load(open(root / 'stops.json'))['stops']}

PLACEHOLDER = 'Pladsholder fra projektoplægget. Skal tjekkes mod fx Transportministeriets TEMA-model, Miljøstyrelsen eller Climatiq.'
co2 = {
  'unit': 'g CO2e pr. personkilometer',
  'note': 'Ingen af værdierne er tjekket endnu (verified: false). Se README.',
  'factors': {
    'walk':  {'g_per_km': 0,   'verified': False, 'source': 'Ingen direkte udledning ved gang.'},
    'bike':  {'g_per_km': 0,   'verified': False, 'source': 'Ingen direkte udledning ved almindelig cykel (også Donkey Republic).'},
    'donkey':{'g_per_km': 0,   'verified': False, 'source': 'Som almindelig cykel. Kørsel med servicevogne er ikke medregnet.'},
    'lime':  {'g_per_km': 20,  'verified': False, 'source': PLACEHOLDER},
    'tram':  {'g_per_km': 35,  'verified': False, 'source': PLACEHOLDER},
    'train': {'g_per_km': 35,  'verified': False, 'source': PLACEHOLDER},
    'bus':   {'g_per_km': 80,  'verified': False, 'source': PLACEHOLDER},
    'car':   {'g_per_km': 170, 'verified': False, 'source': PLACEHOLDER},
  },
}
json.dump(co2, open(root / 'co2-factors.json', 'w'), ensure_ascii=False, indent=1)

# Lime har intet offentligt GBFS-feed for Aarhus (tjekket 2026-10-28 i MobilityData/gbfs systems.csv).
# Zonerne er lagt ved kendte stoppesteder og er KUN eksempler.
lime_at = ['Banegårdspladsen', 'Park Allé', 'Nørreport', 'Dokk1', 'Universitetsparken', 'Trøjborg Centret/Nordre Ringgade',
           'Østbanetorvet', 'Skolebakken', 'Stjernepladsen', 'Vesterbrogade', 'Aarhus Universitet (Ringgaden)']
lime = {'source': 'DEMO – opdigtede eksempelzoner (Lime har intet offentligt GBFS-feed for Aarhus).', 'zones': [
  {'id': f'lime-demo-{i+1}', 'name': n.split('/')[0].split(' (')[0], 'lat': stops[n]['lat'], 'lng': stops[n]['lng'], 'radius_m': 250, 'demo': True}
  for i, n in enumerate(lime_at)]}
json.dump(lime, open(root / 'lime-zones.json', 'w'), ensure_ascii=False, indent=1)

# Partnere er pladsholdere i [klammer]; positionerne er eksempler ved stoppesteder.
partners = {'source': 'DEMO – pladsholdere, ingen rigtige virksomheder.', 'partners': [
  {'id': 'p-cafe', 'name': '[Café bio partenaire]', 'kind': 'cafe', 'offer_fr': 'Café, pâtisseries et déjeuner bio.', 'offer_da': 'Café, kager og frokost, alt økologisk.', 'at': 'Nørreport'},
  {'id': 'p-velo', 'name': '[Location de vélos partenaire]', 'kind': 'bike', 'offer_fr': 'Location de vélos à la journée.', 'offer_da': 'Cykeludlejning for en dag ad gangen.', 'at': 'Banegårdspladsen'},
  {'id': 'p-hotel', 'name': '[Hébergement éco partenaire]', 'kind': 'hotel', 'offer_fr': 'Chambres dans un hébergement écolabellisé.', 'offer_da': 'Værelser på et miljømærket overnatningssted.', 'at': 'Park Allé'},
  {'id': 'p-epicerie', 'name': '[Épicerie bio partenaire]', 'kind': 'shop', 'offer_fr': 'Produits danois locaux et bio (label Ø rouge).', 'offer_da': 'Lokale danske og økologiske varer (det røde Ø-mærke).', 'at': 'Vesterbrogade'},
  {'id': 'p-resto', 'name': '[Restaurant local partenaire]', 'kind': 'restaurant', 'offer_fr': 'Cuisine nordique de saison.', 'offer_da': 'Nordisk mad efter årstiden.', 'at': 'Østbanetorvet'},
]}
for p in partners['partners']:
  s = stops[p.pop('at')]
  p.update(lat=s['lat'], lng=s['lng'], demo=True)
json.dump(partners, open(root / 'partners.json', 'w'), ensure_ascii=False, indent=1)
print('ok', len(lime['zones']), 'Lime-zoner,', len(partners['partners']), 'partnere')
