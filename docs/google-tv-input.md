# Diagnostica input Google TV / TCL 75Q7C

Ramo: `diagnostic/google-tv-input`, base `01c504b0afb301d0ef790b120eaec91a79b180de`.
Nessuna modifica alle regole, ai dati di gioco o alla pubblicazione di `main`.

## Risultato e limiti

Riprodotto in Chromium un caso concreto: un evento DOM `click` isolato sul
pulsante «Regole» non produce `pressed` in Godot. Con il bridge di compatibilità
produce una sola attivazione e apre realmente la finestra delle regole.
Il test genera deliberatamente questo evento: **non dimostra che la TCL invii
la stessa sequenza**. La causa sul televisore resta da confermare con il trace.
Il fatto che il mouse funzioni nelle pagine web non prova che il browser invii
anche la coppia `mousedown`/`mouseup` attesa dal canvas Godot.

La correzione ascolta soltanto `click` sul canvas, senza pressione mouse/touch
recente nella stessa posizione. In quel caso invia `mousedown` e `mouseup` al
canvas, alle coordinate CSS originali. Non emette direttamente segnali dei
pulsanti: hit testing, ridimensionamento, disabilitazione e modalità restano
sotto il controllo di Godot. Non usa user-agent sniffing. I click della tastiera
senza coordinate, i tasti diversi dal sinistro e gli input HTML sono esclusi.
La finestra di correlazione mouse/touch è 1500 ms / 25 pixel CSS: sequenze
anomale molto ritardate richiedono verifica sul dispositivo reale.

## Audit del progetto

- `project.godot`: `emulate_touch_from_mouse=true`; emulazione inversa al default
  attiva. Il mouse genera anche touch sintetici. Non disabilitata: pista e mapper
  usano quei touch per selezione/trascinamento. Il test verifica una sola
  attivazione di un Button sia con mouse sia con touch.
- `ui_kit.gd`: pulsanti `Button` standard, nessun filtro hardware/touch o gestore
  globale che consumi le pressioni. `RichTextLabel` decorative su `IGNORE`.
- `main.gd`: HUD e spazi liberi su `IGNORE`; modali su CanvasLayer 5, sopra HUD 1.
  Root, oscuramento e copertina bloccano lo sfondo; pannello e pulsanti sono
  successivi e sopra lo sfondo. Non va impostato indiscriminatamente `IGNORE`:
  si rischierebbe di attivare la pista dietro una modale. Chiusura con `queue_free`
  (eliminazione a fine frame), senza pausa globale o finestre native esclusive.
- `snow_fx.gd`: SnowCap su `IGNORE`; neve come CPUParticles2D, non Control.
  Anteprime e miniature sono su `IGNORE`. Nessun overlay decorativo a pieno
  schermo sopra i pulsanti che consumi il click è emerso nell'audit/prova.
- `board_view_3d.gd` / `mapper.gd`: input in `_unhandled_input`, dopo la GUI;
  touch/drag, rotella e rotazione destra. Non intercettano in `_input` i pulsanti.
- `card_view.gd` / `mat_view.gd`: `STOP` e `accept_event()` su selezione valida;
  supportano mouse e touch. Non sono stati modificati.
- `web_text_field.gd`: veri input HTML quasi invisibili sopra i LineEdit,
  z-index 20. Vengono nascosti con il LineEdit e rimossi all'uscita dall'albero.
  Posizione calcolata includendo scala viewport/pannello. La disponibilità touch
  Godot include anche l'emulazione: possono comparire anche su desktop.
  Il test `elementFromPoint` verifica che il pulsante Regole non sia coperto,
  anche in browser con touch e in verticale. Il trace DOM consente di scoprire
  eventuali sovrapposizioni specifiche della TV (`target=INPUT#godot-text-...`).
- Non trovati `set_input_as_handled`, `mouse_mode` catturato, pause globali o
  filtri condizionali che disattivino i pulsanti sui dispositivi Google TV.

## Prova HTML5 sulla TV

Esportare il preset Web con Godot **4.7-stable**, stessa versione della CI,
con il template single-thread corrispondente. La build diagnostica è in
`build/web/`; richiede HTTPS quando viene aperta da un altro dispositivo (anche in LAN).
HTTP funziona solo su localhost del computer che esegue il browser.
Non usare il workflow Pages esistente per questa prova: pubblica il sito principale.
Caricare la build in uno spazio HTTPS di test separato. In alternativa, sul Mac:
`python3 -m http.server 8060 --directory build/web` e, in un altro terminale,
`cloudflared tunnel --url http://localhost:8060`. Aprire sulla TV il link
HTTPS trycloudflare stampato, mantenendo entrambi i processi attivi.

1. Aprire la pagina con `?input_debug=1&tv_click=0` (bridge disattivato).
2. Cliccare «Regole» e annotare il trace in basso; il pannello è `pointer-events:none`.
3. Ricaricare con `?input_debug=1` (bridge attivo), ripetere. Se appare
   `COMPAT click-only -> mouse down/up`, il caso è stato intercettato.
4. Provare chiusura modale, schede del menu, inizio gara, selezione carte,
   campo nome, tendine, scroll, trascinamento pista e passaggio a schermo intero.
   Ogni azione deve avvenire una sola volta; click fuori dalla modale non deve
   attivare elementi sottostanti. Provare anche touch su un dispositivo disponibile.
5. Senza query la correzione resta attiva e la diagnostica è completamente spenta.

Interpretazione: `DOM click` senza down/up è il caso corretto dal bridge;
`DOM mousedown/up` senza `INPUT` indica il passaggio browser → motore;
`INPUT` senza `GUI` sul pulsante indica hit testing/overlay/coordinate;
`GUI` senza `PRESSED` richiede controllare rilascio, stato disabled e uscita dal
rettangolo. `target=INPUT` identifica un campo HTML sopra il canvas.
Il trace non registra testo digitato né credenziali e non invia dati in rete.
`window.snowtailsInput` espone gli ultimi 40 eventi e i rettangoli/filtri dei
Control visibili per ispezione dalla console del browser.

## Verifiche ripetibili

```sh
godot --headless --path . --editor --import
mkdir -p build/web
GODOT=godot tools/export_web.sh
python3 -m http.server 8060 --directory build/web
# In un altro terminale, con Playwright disponibile:
node tests/input_web.cjs
godot --headless --path . -s tests/fan_rules.gd
```

`ST_WEB_URL` sceglie l'indirizzo della build, `CHROMIUM` l'eseguibile del browser;
`NODE_PATH` può indicare una installazione Playwright esistente.
Il test browser controlla baseline click-only, correzione click-only, mouse,
mouse con disponibilità touch, tap touch e layout verticale scalato. Verifica
il segnale una sola volta, l'apertura della finestra e l'assenza di errori runtime.
La baseline che non apre Regole è una riproduzione attesa del difetto, non una
funzionalità valida. La prova fisica sulla TCL non è eseguibile nell'ambiente cloud.

## Esito nell'ambiente cloud

- Godot 4.7-stable e template ufficiali: checksum SHA-512 verificati.
- Installazione/import ripetuti senza errori; esportazione Web debug riuscita.
- `tests/input_web.cjs`: 6/6 scenari riusciti in Chromium 154.
- `tests/fan_rules.gd`: 9/9; `tests/sim_rules.gd` eseguito senza errori
  (quest'ultimo stampa due casi, non fornisce un totale di asserzioni).
- HTTP 200 per HTML e WASM. Build locale in `build/web`, archivio
  `build/snowtails-google-tv-input.zip`.
- TCL fisica, Firebase online e ripristino cloud in un nuovo task non verificati.

## Build remota del ramo

Il workflow `.github/workflows/google-tv-diagnostic.yml` ripete esportazione e
verifiche, poi carica `snowtails-google-tv-html5` come artifact Actions (30 giorni).
Non effettua deploy Pages e non modifica `main`.

L'apertura automatica di una bozza PR è stata tentata: GitHub ha risposto
`GitHub Actions is not permitted to create or approve pull requests`.
Il job non autorizzato è stato rimosso; la build non dipende da quel permesso.
Il confronto è disponibile in GitHub tra `main` e `diagnostic/google-tv-input`.

## Diagnostica del blocco sulla barra piena

La nuova esportazione usa Release, come il workflow Pages del sito originale.
Non è una prova che Debug causi il blocco sulla TCL. Il nuovo script
`web/startup_diagnostics.js` parte prima del motore: con `?input_debug=1`
mostra in alto browser, secure context, errori JavaScript/WASM/WebGL e passaggi
di avvio. Rimane osservabile anche se Godot non arriva a eseguire GDScript.
Una barra piena indica download terminato, non necessariamente avvio completato.
Fotografare il riquadro superiore se il menu non appare. L'export va eseguito
con `tools/export_web.sh`, che copia anche lo script esterno nella build.
