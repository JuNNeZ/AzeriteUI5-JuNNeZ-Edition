"""Build the local review gallery; preserve approved originals byte for byte."""
from pathlib import Path
import hashlib
import html
import json
import shutil
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'Docs/Research_Assets/ClassConceptSheets-2026-10-17'
RESEARCH = json.loads((OUT / 'research-v2.json').read_text(encoding='utf-8-sig'))
ORIGINALS = {
    'hunter': 'Docs/Research_Assets/Hunter/Production/v1/approved-concept.png',
    'mage': 'Assets_Draft/Mage-Complete-Assets-v12/References/Approved-Concept.png',
    'paladin': 'Docs/Research_Assets/Paladin/Rebuild-2026-10-14/approved-concept.png',
    'druid': 'Docs/Research_Assets/Druid/concept-sheet-v2.png',
}
ESC = html.escape
inventory = []


def card(key, name, image, caption, extra=''):
    assert (OUT / image).is_file(), image
    with Image.open(OUT / image) as im:
        width, height = im.size
    return f'<article id="{key}"><h3>{ESC(name)}</h3><p>{caption}</p><a href="{image}"><img src="{image}" width="{width}" height="{height}" alt="{ESC(name)} — {ESC(key)}" loading="lazy"></a>{extra}</article>'


old_cards = []
fit_cards = []
implemented_cards = []
for key in ('mage','paladin','druid'):
    implemented_cards.append(card(key, key.title(), key+'-implemented.png',
        'Nyt conceptark · samlet direkte af den implementerede art',
        '<p class="note">Samme fire sektioner som de nye forslag. Installerede textures, aktuelle endcaps og resource-caps. Statiske overflader med animationer slået fra; offline samling.</p>'
        + f'<p><a href="{key}-implemented-sources.json">Assets og kildehashes</a></p>'))
for key, source in ORIGINALS.items():
    name = key.title()
    destination = f'established-{key}.png'
    shutil.copyfile(ROOT / source, OUT / destination)
    digest = hashlib.sha256((OUT / destination).read_bytes()).hexdigest()
    assert digest == hashlib.sha256((ROOT / source).read_bytes()).hexdigest()
    inventory.append({'class': key, 'source': source, 'galleryCopy': destination, 'sha256': digest})
    old_cards.append(card(key if key=='hunter' else 'original-'+key, name, destination, 'Oprindeligt conceptark · etableret theme',
        '<p class="note">Historisk designreference. Den aktuelle samling med endcaps vises separat nedenfor.</p>'))
    aligned = ROOT/'Docs/Research_Assets/AlignedEndcaps-2026-10-17'/(name+'-installed.png')
    if aligned.exists():
        shutil.copyfile(aligned, OUT/f'{key}-all-aligned.png')
    fit_cards.append(card(f'fit-{key}', name, f'{key}-endcap-fit.png',
        'Faktiske assets · endcap til/fra · offline rekonstruktion',
        '<p class="note">Spillets lag, effekter og skalering kræver stadig kontrol efter /reload.</p>'
        + (f'<p><a href="{key}-all-aligned.png">Alle installerede endcaps på hele player- og targetbaren</a></p>' if aligned.exists() else '')))

new_cards = []
for brief in RESEARCH['classes']:
    key = brief['key']
    filename = f'{key}-v2.png'
    with Image.open(OUT / filename) as im:
        assert im.size == (1536, 1024), filename
    extra = '<details><summary>Inspiration og kilder</summary><dl>'
    for label, value in [('Order hall / hjemsted', brief['hall']), ('Tier set', brief['tier']),
                         ('Karakterer', ', '.join(brief['characters'])), ('Artifacts / relics', ', '.join(brief['artifacts']))]:
        extra += f'<dt>{label}</dt><dd>{ESC(value)}</dd>'
    extra += f'</dl><p><a href="{ESC(brief["article"])}">Artifact-reference</a>'
    if key == 'evoker':
        extra += ' · <a href="https://worldofwarcraft.blizzard.com/en-gb/news/23877536/dragonflight-awaken-in-the-forbidden-reach">Forbidden Reach</a>'
    extra += '</p><p class="note">Materialer og motivplacering er vores designfortolkning af referencerne.</p></details>'
    new_cards.append(card(key, brief['name'], filename, f'{ESC(brief["subtitle"])} · nyt forslag, ikke implementeret', extra))

nav = ''.join(f'<a href="#{key}">{key.replace("-", " ").title()}</a>'
              for key in ['hunter', 'mage', 'paladin', 'druid'] + [b['key'] for b in RESEARCH['classes']])
page = """<!doctype html>
<html lang="da"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>AzeriteUI — Class Concept Sheets</title>
<style>
:root{color-scheme:dark}*{box-sizing:border-box}body{margin:0;background:#14161a;color:#e3dfd4;font:16px/1.6 system-ui}
header,main,footer{max-width:1680px;margin:auto;padding:28px}header{padding-bottom:8px}
h1,h2,h3{font-family:Georgia,serif;line-height:1.2}h1{font-size:clamp(30px,4vw,48px)}h2{font-size:32px;margin-top:0}h3{font-size:27px;margin:0 0 4px}
p{color:#c1bdb4}a{color:#e5ca91}a:focus-visible,summary:focus-visible{outline:3px solid #e5ca91;outline-offset:4px}
nav{display:flex;flex-wrap:wrap;gap:8px}nav a{padding:8px 12px;background:#262a31;border-radius:3px;text-decoration:none}
section{padding-top:36px;scroll-margin-top:16px;border-top:1px solid #383c43;margin-top:28px}
.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:36px 28px}article{min-width:0;scroll-margin-top:24px}
article>p{margin:0 0 12px}img{width:100%;height:auto;display:block;border:1px solid #42474f}
.note,footer{font-size:14px;color:#b1ada5}details{margin-top:12px;border-bottom:1px solid #383c43;padding-bottom:12px}summary{cursor:pointer;color:#e5ca91}
dt{color:#a9a398;margin-top:12px}dd{margin:0}footer{padding-top:8px}
@media(max-width:850px){.grid{grid-template-columns:1fr}header,main,footer{padding:18px}section{padding-top:24px}}
</style></head><body>
<header><p>A Z E R I T E U I · 17. OKTOBER 2026</p><h1>Class Concept Sheets</h1>
<p>Tre nye conceptark for Mage, Paladin og Druid, samlet direkte af den implementerede art. Samme opbygning som de ni nye klasseforslag. De fire historiske originaler og endcap-sammenligningerne er bevaret længere nede.</p>
<nav><a href="#implemented">Implementeret art</a><a href="#new">Nye forslag</a><a href="#established">Gamle originaler</a><a href="#fitting">Endcap-samlinger</a></nav><br><nav>""" + nav + """</nav></header>
<main><section id="implemented"><h2>Nye ark med den faktiske art</h2>
<p>Mage, Paladin og Druid samlet af de installerede TGA-assets: player/target, castbar, crystal/orb, mindre frames, knapper, minimap og ornamenter. Ingen af disse tre ark er genmalet eller genereret.</p>
<div class="grid">""" + ''.join(implemented_cards) + """</div></section>
<section id="established"><h2>De oprindelige conceptark</h2>
<p>Hunter, Mage, Paladin og Druid vises med deres eksisterende designreferencer. Originalerne er kopieret uændret; de beskriver den etablerede class fantasy.</p>
<div class="grid">""" + ''.join(old_cards) + """</div></section>
<section id="new"><h2>Ni nye forslag</h2>
<p>Order halls, artifacts, tier sets og centrale karakterer danner grundlag for materialer og ornamenter. Playerens endcap dækker den dyppede afslutning; target viser den modsatte orientering med portræt ved den indre ende. Cast-head og health-endcap har hvert sit motiv.</p>
<p class="note">Conceptarkene er visuelle forslag. De ni themes er ikke installeret. Fills, åbninger og lag skal måles ved senere implementering; class-power eksempler er materialestudier. Evoker bruger Dragonflight-referencer, da klassen ikke havde et Legion order hall eller artifact. De nyere klassers anniversary sets er nyfortolkninger.</p>
<p>Kilder: <a href='""" + RESEARCH['commonSources']['halls'] + """'>Blizzards class halls</a> · <a href='""" + RESEARCH['commonSources']['sets'] + """'>Tier 2 / anniversary armor</a>. Klassernes artifact-kilder findes under hvert ark.</p>
<div class="grid">""" + ''.join(new_cards) + """</div></section>
<section id="fitting"><h2>Endcaps — aktuelle assets</h2>
<p>Alle fire etablerede temaer bruger nu endcaps placeret efter den målte spids i healthbarens dyp. Hele den oprindelige bar og dyp bevares under endcappen. Druid og Paladin har tre varianter; Hunter og Mage bevarer deres fem eksisterende valg. Endcaps skalerer omkring den fælles spids. Health og cast kan vælges uafhængigt.</p>
<p class="note">Offline rekonstruktioner, ikke screenshots fra WoW. Den endelige kontrol i Retail og Forever efter /reload mangler stadig.</p>
<div class="grid">""" + ''.join(fit_cards) + """</div></section></main>
<footer>Klik på et ark for fuld størrelse. <a href="README.md">Leverance og test</a> · <a href="research-v2.json">Research</a> · <a href="prompts-v2.json">Generering og referencer</a></footer></body></html>
"""
(OUT / 'index.html').write_text(page, encoding='utf-8')
(OUT / 'established-sources.json').write_text(json.dumps(inventory, indent=2), encoding='utf-8')
print('Gallery: 3 implemented-art sheets, 4 originals, 9 new proposals, 4 fitting boards; originals hash-verified.')
