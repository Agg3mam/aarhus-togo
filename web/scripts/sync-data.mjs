// Kopierer data, fotos og tekster fra iPhone-appen (ios/HyggeVert), så web og app deler én kilde.
// Køres automatisk før dev og build.
import { readFileSync, writeFileSync, mkdirSync, readdirSync, copyFileSync, existsSync } from 'node:fs';

const ios = new URL('../../ios/HyggeVert/', import.meta.url);
const gen = new URL('../src/generated/', import.meta.url);
const img = new URL('../public/img/', import.meta.url);
mkdirSync(gen, { recursive: true });
mkdirSync(img, { recursive: true });

for (const f of readdirSync(new URL('Data/', ios))) {
  if (f.endsWith('.json')) copyFileSync(new URL(`Data/${f}`, ios), new URL(f, gen));
}
for (const f of readdirSync(new URL('Images/', ios))) {
  if (!existsSync(new URL(f, img))) copyFileSync(new URL(`Images/${f}`, ios), new URL(f, img));
}
// Localizable.strings → JSON (nøgle → tekst). Formater som %@ og %1$@ beholdes og udfyldes i i18n.ts.
for (const lang of ['fr', 'da']) {
  const src = readFileSync(new URL(`${lang}.lproj/Localizable.strings`, ios), 'utf8');
  const out = {};
  for (const m of src.matchAll(/^"([^"]+)"\s*=\s*"((?:[^"\\]|\\.)*)";/gm)) {
    out[m[1]] = m[2].replace(/\\n/g, '\n').replace(/\\"/g, '"');
  }
  writeFileSync(new URL(`strings-${lang}.json`, gen), JSON.stringify(out));
}
console.log('Data, fotos og tekster synkroniseret fra ios/HyggeVert');
