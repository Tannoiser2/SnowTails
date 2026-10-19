# Snow Tails — versione digitale (uso personale)

Progetto Godot 4.3 (va bene anche una 4.x successiva), renderer Compatibility. Le immagini delle tessere
vengono dalle tue scansioni: il progetto è per uso personale e non va distribuito.

## Avvio
1. Apri Godot, «Importa», scegli `project.godot`. Al primo avvio importa le immagini.
2. Premi Play (F5). Si apre il menu: percorso, numero di slitte, persona o CPU.

Il percorso **Rettilineo di prova** funziona subito. **The Nutcracker** diventa
disponibile dopo aver mappato due facce (vedi sotto).

## Gioco online
Si gioca a distanza dal menu, riquadro **Online** (anche dalla versione web su GitHub Pages:
https://tannoiser2.github.io/SnowTails/). Usa lo stesso progetto Firebase di Ultimo chilometro
(Realtime Database, piano gratuito), con le stanze sotto `snowtails/rooms`.

- **Chi crea la stanza** sceglie percorso e slitte come al solito: le slitte su *Persona* diventano i
  posti per gli amici (la prima è la sua). Scrive il nome, preme *Crea una stanza* e comunica il codice
  di 4 lettere. Quando ci sono tutti preme *Inizia la gara*: i posti rimasti liberi li guida la CPU.
- **Gli amici** scrivono il nome e il codice e premono *Entra*.
- Ognuno muove la sua slitta quando tocca a lui e vede solo la propria mano. Le slitte della CPU le
  guida il dispositivo di chi ha creato la stanza, che deve restare collegato.
- **Come funziona.** La partita è un registro di mosse numerate (`acts/0`, `acts/1`, …): partenza
  scelta, carte giocate con la casella d'arrivo, carte scartate. Tutti i dispositivi applicano le stesse
  mosse nello stesso ordine e, partendo dallo stesso seme casuale, mescolano i mazzi allo stesso modo:
  sul database non passano mai le mani.
- **Se cade la linea** si rientra con lo stesso codice e *Entra*: il gioco recupera velocemente le
  mosse già giocate e riprende. Se un giocatore tace per un minuto, al suo posto guida il computer
  finché non rientra.

**Configurazione Firebase.** Le regole di sicurezza sono in `firebase/database.rules.json` e
comprendono anche quelle di Ultimo chilometro (`rooms`) e di STATUS (`status/rooms`): vanno pubblicate nella
console di Firebase (Realtime Database → Regole) al posto delle precedenti. L'accesso *Anonimo* in
Authentication è già attivo.

**Prove senza Firebase.** `tests/firebase_mock.py` è un finto Firebase locale. Con `ST_DB_URL`,
`ST_AUTH_URL` e `ST_REFRESH_URL` che puntano lì, `tests/online_play.gd` fa giocare una gara intera a
due istanze del gioco (`ST_ROLE=host` e `guest`; con `ST_PHASE=drop` e poi `back` l'ospite esce a metà
e rientra) e alla fine ognuna stampa l'impronta della gara, che deve coincidere.

## Icona
L'icona dell'app (il muso dell'husky dalla copertina) è in `assets/icon/`:
- `icona.png` (1024×1024): icona del progetto, già impostata; va bene anche per macOS e per
  tutti i campi «Icone» del preset iOS (App Store 1024×1024 compreso);
- `icona.icns`: per il campo Icona del preset macOS, se lo vuoi indicare esplicitamente;
- `icona.ico`: per il preset Windows (serve rcedit per inserirla nell'.exe).

## Menu
La copertina fa da schermata d'avvio e da sfondo del menu. Scegliendo un percorso, o
generando una pista casuale, il menu mostra l'anteprima della pista intera vista dall'alto
(punto verde = partenza, linea scura = traguardo).

## Plance, carte e gettoni originali
Ogni giocatore ha la sua plancia della slitta (rossa, blu, gialla, verde, nera: i colori
della scatola), con i cani verso l'alto, la bandierina gialla a sinistra e la rossa a destra.
Le carte giocate si appoggiano sui cani stampati, il gettone freno sta nella finestra della
plancia, e la mano mostra le carte vere (anche la carta ammaccatura). Una carta messa sulla
plancia e non ancora confermata ha il bordo verde.
Immagini in `assets/mats/` e `assets/cards/` (script: `tools/build_mats.py`).

## Schermi
L'interfaccia si adatta da sola alla forma dello schermo, anche quando ruoti il dispositivo
o ridimensioni la finestra:
- verticale (telefono, iPad in verticale): pannelli sopra e sotto la pista;
- orizzontale (computer, iPad e telefono, che si apre sempre in orizzontale): pista a
  sinistra con la barra della classifica in alto, colonna stretta a destra con la plancia,
  le carte in mano e i pulsanti.
Anche la grandezza dell'interfaccia si adatta: grande sul telefono, più compatta su tablet
e computer (in base al lato corto della finestra), così resta spazio per la pista.
Sul computer la finestra si apre ingrandita; il pulsante «Schermo intero» nel menu passa
allo schermo intero (e «Finestra» torna indietro). L'interfaccia è proporzionata all'altezza della finestra e tiene conto della densità dello
schermo (Retina); le carte in mano riempiono la larghezza della colonna.

Tastiera sul computer: 1–5 sceglie una carta di quel valore; A, S, D (o frecce sinistra,
giù, destra) la mettono su cane sinistro, freno, cane destro; Invio muove; Backspace
riprende le carte; Esc torna indietro o apre il menu.

## Comandi
- La pista è in 3D: le tessere sono tavole appoggiate sulla neve. Le mute usano il modello
  `assets/models/team.glb` (generato con Meshy, alleggerito a 20.000 triangoli e texture 1024)
  su una basetta nel colore della squadra. Se il file manca, il gioco usa le mute low-poly
  costruite in codice (`scripts/team_model.gd`). Per cambiare modello basta sostituire il
  file: cani verso −Z, lunghezza circa 1 unità, appoggiato a quota 0.
  Gli alberelli alternano `assets/models/sapling.glb` e `sapling_2.glb` (se ne aggiungi altri, `sapling_3.glb`… vengono usati da soli) (anche questo da Meshy, ridotto a 4.000
  triangoli con i colori sui vertici); se manca, il gioco usa gli alberelli fatti in codice.
- Un dito trascina la pista. Due dita: pizzica per lo zoom, ruota per girare la vista,
  spostale insieme in su o in giù per cambiare l'inclinazione.
  Col mouse: rotellina per lo zoom, tasto destro per ruotare e inclinare.
- «Segui» fa seguire alla telecamera la slitta di turno (e nel replay tutte le slitte).
  Se sposti, ruoti o avvicini la telecamera, «Segui» si spegne e la telecamera resta dove
  l'hai messa; riattivandolo riprende a seguire la corsa.
- Tocca una carta, poi uno spazio della plancia (cane sinistro, freno, cane destro).
  Con una carta già piazzata, toccare un altro spazio ci mette un'altra carta dello stesso valore.
- «Muovi la slitta», poi tocca sulla pista la casella d'arrivo.
  `−n` = ammaccature, `+B` = bonus di equilibrio, `urto` = tamponamento.

## Mappare curve e inversioni
Rettilinei, partenza e arrivo sono griglie regolari e sono già mappati.
Sulle curve non ci sono corsie fisse: ogni tessera è una **rete di caselle**.

1. Menu → «Mappa le tessere», scegli la faccia (• = da mappare, ✓ = fatta).
2. Modalità **Catena**: tocca le caselle una dopo l'altra nel senso di marcia,
   dalla freccia verde (ingresso) verso la rossa (uscita). Ogni passo va nella
   casella **davanti**, quella che ha un lato in comune oltre una linea blu.
   Toccando vicino a un puntino grigio ci si aggancia al centro riconosciuto.
3. Tocca due volte la stessa casella (o «Nuova catena») per chiudere la catena e
   iniziarne un'altra. Le catene possono incrociarsi e condividere caselle:
   copri tutte le caselle, comprese quelle in più all'esterno della curva.
4. **Derive**: mostra le diagonali calcolate dal gioco (blu = a sinistra, viola =
   a destra). La deriva va avanti in diagonale oltre una linea nera, anche quando
   la casella tocca la tua solo nello spigolo. Controlla che le frecce tratteggiate
   siano quelle che useresti al tavolo.
5. **Cancella** toglie una casella (o un collegamento toccando il centro della freccia);
   **Annulla** torna indietro; **Salva** scrive la faccia.

Per The Nutcracker servono **Curva a sinistra (p.7)** e **Inversione a destra (p.2)**.
**Editor delle tessere.** Tre modalità, sempre con due tocchi:
- «Avanti»: tocca la casella di partenza e poi quella davanti; se il passo in avanti c'è
  sparisce, se non c'è compare.
- «Deriva»: lo stesso per le diagonali (blu = a sinistra, viola = a destra). La freccia
  punta sempre verso la seconda casella toccata; se c'era la diagonale al contrario, viene
  girata.
- «Caselle»: un punto vuoto aggiunge una casella, una casella esistente viene tolta con i
  suoi collegamenti.
«Mostra avanti» e «Mostra derive» accendono e spengono le frecce; «Annulla» torna indietro
di un passo. Sotto: Salva, Incorpora nel progetto, Ripristina originale, Apri cartella.

**Dove finiscono le correzioni.** Si salvano sempre nella cartella dati utente di Godot
(`user://faces/`), fuori dal progetto, e hanno la precedenza sulle facce del progetto:
aggiornare o sostituire il progetto non le cancella. Contengono solo la rete corretta e il
punto d'ingresso della tessera, così restano allineate anche se le immagini vengono rifatte.
- macOS: `~/Library/Application Support/Godot/app_userdata/Snow Tails - versione digitale (uso personale)/faces/`
- Windows: `%APPDATA%\Godot\app_userdata\Snow Tails - versione digitale (uso personale)\faces\`
- Linux: `~/.local/share/godot/app_userdata/Snow Tails - versione digitale (uso personale)/faces/`
Nell'editor: «Incorpora nel progetto» scrive la faccia corretta in `data/faces/` (solo
avviando il gioco dall'editor di Godot): da quel momento è la versione di base, inclusa
nelle esportazioni per iPhone e iPad. «Apri cartella correzioni» apre la cartella;
«Ripristina originale» cancella la correzione di quella faccia.
Le tue correzioni di p.1, p.2, p.7 e p.8 sono già incorporate; una copia sta in
`tools/corrections/` e `tools/apply_corrections.py` le riapplica se le facce vengono rigenerate. Le facce corrette hanno il simbolo ✎ nell'elenco.
Una mappatura vecchia (anche nel formato a corsie) copiata in quella cartella viene letta.

## Percorsi
In `data/courses/` ci sono i sette percorsi del regolamento: The Nutcracker,
The Hobbit's Breakfast, Yquem Inspired, Treemendous, The Riddler, Bruce's Nightmare,
Dagger of the Mountain Troll, più il Rettilineo di prova (con alberelli e cumulo di neve,
giocabile subito). Le sequenze sono ricavate dai disegni delle pp.10-11: controllale sul
tavolo e correggi l'elenco se serve.

Per giocarli vanno mappate quattro facce: **Curva a sinistra (p.7)**, **Curva a destra
(p.8)**, **Inversione a sinistra (p.1)** e **Inversione a destra (p.2)**. Tutti i percorsi
usano queste quattro.

Regole di montaggio: bandierine gialle sempre a sinistra e rosse a destra (i rettilinei
si percorrono di conseguenza); la partenza va con la posizione 1 all'interno della prima
curva: `start_p21` se la prima curva è a sinistra, `start_p22` se è a destra.

Facce disponibili:
- partenza/arrivo: `start_p21`, `start_p22`, `finish_p21`, `finish_p22`
- rettilinei: `straight_p13a`, `p14a`, `p14b`, `p16a`, `p16b`, `p18a`, `p18b`, `p19b`, `p20a`, `p20b`
- alberelli: `saplings_p13b`, `saplings_p17a`
- cumulo di neve: `snowdrift_p15a`, `snowdrift_p15b`
- crepaccio: `chasm_p17b`, `chasm_p19a`
- curve e inversioni: `corner_L_p07`, `corner_R_p08`, `uturn_L_p01`, `uturn_R_p02`

Tessere speciali: sul cumulo e sul crepaccio le caselle impraticabili non esistono, quindi
entrarci è come urtare il bordo (la deriva in diagonale fra caselle libere resta possibile).
Gli alberelli: chi li colpisce prende un'ammaccatura, l'alberello viene tolto e il movimento
continua. Le caselle bloccate le ho lette dalle scansioni: se qualcosa non torna, le facce si
possono correggere nell'editor come le altre.

## Anteprima dei percorsi
Nella barra di stato, il riquadro «Percorsi» (sotto le ammaccature) accende o spegne
l'anteprima: mentre metti le carte sulla plancia, prima di muovere, la pista mostra tutti i
percorsi possibili nel colore della tua slitta, come linee: i passi in avanti sono sottili,
i passi di deriva (in diagonale) più spessi, più chiari e bordati di bianco; poi le caselle
d'arrivo e le eventuali ammaccature (−n). La telecamera inquadra i percorsi. L'impostazione resta per tutta la partita.

## Incidenti
- Alberello travolto: cade nella direzione della slitta in una nuvola di neve e sparisce
  (si può sempre passare: costa un'ammaccatura, come da regolamento).
- Urto contro il bordo o contro un'altra slitta: nuvola di neve nel punto dell'urto e le
  slitte coinvolte sobbalzano.
- Curva presa troppo forte o salto troppo lento: piccola sbandata nella neve.
Gli stessi effetti compaiono nel replay.

## Replay
Alla fine della gara, «Rivedi la gara» riproduce tutti i giri con le mosse in contemporanea:
in ogni giro tutte le slitte partono insieme dalla casella in cui erano e arrivano insieme
alla casella d'arrivo, a velocità costante, quindi chi ha fatto più strada va più veloce;
il giro successivo parte subito, senza pause. Ammaccature, slitte distrutte e alberelli
travolti si aggiornano al passaggio da un giro all'altro. Pausa, velocità ×1/×2/×4,
Esc o «Esci dal replay» per tornare alla classifica.

## Editor dei percorsi
Dal menu, «Crea percorso» apre l'editor: a destra scegli i pezzi (partenza con il 1° a
sinistra o a destra, rettilinei, alberelli, cumulo, crepaccio, Leap of Death, curve,
inversioni, arrivo), a sinistra la pista cresce. Toccando un pezzo nella sequenza, i nuovi
pezzi si inseriscono dopo di lui, oppure lo togli con «Togli selezionato». «Parti da» carica
un percorso esistente da modificare. I pezzi che si sovrappongono diventano rossi; il
riepilogo conta rettilinei, curve e inversioni rispetto alla scatola. «Salva percorso»
controlla che la pista sia valida (partenza, arrivo con un rettilineo dopo, traguardo
raggiungibile) e la salva nella cartella dati (`user://courses/`): compare nel menu con ✎.

## Pista casuale
Nel menu, «Pista casuale» crea un percorso scegliendo solo difficoltà (bassa, media, alta)
e lunghezza (corta, media, lunga); «Genera un'altra pista» ne crea una nuova.
Il generatore rispetta i pezzi della scatola (al massimo 8 rettilinei comprese le facce
speciali, 4 curve, 2 inversioni, una Leap of Death), posa davvero le tessere scartando le
piste che si sovrappongono, e controlla che il traguardo sia raggiungibile.
Con la difficoltà crescono curve e inversioni e le tessere speciali (bassa: alberelli;
media: anche cumuli; alta: anche crepacci e Leap of Death), mentre diminuiscono i rettilinei
fra una svolta e l'altra.

## Regole implementate
Mazzo da 20 carte (quattro per valore 1–5), mano di 5; 1–3 carte dello stesso valore
su cane sinistro / freno / cane destro; velocità = cani − freno; deriva verso il cane più
forte, nei passi scelti; bonus di equilibrio pari alla posizione (non al primo turno);
ammaccature per curve oltre il limite (bonus compreso), bordo, tamponamento senza
pesca; quinta ammaccatura = slitta distrutta; partenza 4ª e 5ª con 1 e 2 carte extra;
ordine di gioco per posizione, a pari livello avanti chi è all'interno della prossima curva;
la gara continua finché tutte le slitte rimaste hanno tagliato il traguardo (chi arriva
smette di muovere e non ostacola più gli altri); in classifica conta prima il giro in cui si
taglia il traguardo, poi, a parità di giro, chi è andato più lontano oltre la linea.

Limiti letti sui cartelli delle scansioni: curve 4, inversioni 3.

## Variante simultanea (personale)
Nel menu, «Movimento: Simultaneo». A ogni giro tutti programmano la mossa (carte e casella
d'arrivo): le CPU subito, le persone una alla volta, con una copertina fra l'una e l'altra
se sullo stesso dispositivo ce n'è più d'una. Poi le slitte partono e arrivano insieme, in
modo fluido: chi ha più caselle da fare va più veloce (entra nella casella k al tempo k/n).
Due slitte non stanno mai nella stessa casella nello stesso momento. Si decide in
quest'ordine: chi resta ferma, poi chi va più veloce, a parità chi era più avanti a inizio
giro. Ognuna, se può, prende una rotta equivalente (stesso arrivo, stessa velocità, non più
ammaccature) che evita il contatto; se non può, si ferma prima e prende mezza ammaccatura
(due mezze fanno un'ammaccatura) e pesca normalmente. Gli alberelli li travolge chi ci passa
per primo. Per ora solo nelle partite su un dispositivo, non online.

## Come funziona il movimento
Ogni passo è «avanti» (un collegamento della rete) oppure «deriva» (una diagonale
calcolata: circa una casella avanti e una corsia di lato rispetto alla direzione di
marcia locale). Dove la rete offre più caselle il gioco le esplora tutte e mostra ogni
arrivo possibile.

## Test senza grafica
    godot --headless --path . -s res://tests/run_ai.gd -- res://data/courses/prova.json
    godot --headless --path . -s res://tests/sim_ai.gd      # variante simultanea, sole CPU

## Non ancora fatto
- Le altre facce delle curve (pp.3-6, 9-12): i percorsi usano solo p.1, 2, 7, 8.
- Editor di percorsi dentro il gioco, stagione a punti.

`tools/build_faces.py` è lo script Python che ha estratto le facce dalle scansioni.

## Font
Titoli e pulsanti principali: Luckiest Guy (Apache 2.0). Testo: Nunito (SIL Open Font
License). Le licenze sono in `assets/fonts/`.

## Segmenti fanmade (anteprima grafica)
`tools/make_fan_tiles.py` crea i segmenti partendo dai rettilinei scansionati: cartelli
all'ingresso nello stile delle curve (disco bordato di rosso, doppia linea rossa) e ritocchi
dipinti (ghiaccio, tracce in salita, solchi in discesa, sastrugi del vento). Il resto è 3D:
salite e discese alzano davvero la pista (le slitte si inclinano), vento con scie e neve
sollevata e una manica a vento animata, neve fresca con nevicata e cumuli, ghiaccio lucido
con luccichii, baita (modello Meshy) con il fumo dal camino. Pista di prova: «Fanmade:
vento, ghiaccio e pendii». Per ora è solo l'aspetto: le regole dei segmenti verranno dopo.
