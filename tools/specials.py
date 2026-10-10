# Facce speciali dei rettilinei. Coordinate (colonna, riga) nell'immagine della scansione:
# colonna 0 = a sinistra, riga 0 = in alto (lato delle bandierine rosse).
KINDS={
 'p13b':('saplings','Rettilineo con alberelli','saplings'),
 'p17a':('saplings','Rettilineo con alberelli','saplings'),
 'p15a':('snowdrift','Cumulo di neve','snowdrift'),
 'p15b':('snowdrift','Cumulo di neve','snowdrift'),
 'p17b':('chasm','Crepaccio','chasm'),
 'p19a':('chasm','Crepaccio','chasm'),
 'p22a':('leap','Leap of Death','leap'),
}
SPECIAL.update({
 # Leap of Death: la spaccatura occupa la colonna 3; la linea viola è sul suo lato d'ingresso
 'leap_p22a':dict(crevasse=[(3,0),(3,1),(3,2),(3,3),(3,4)],leap_min=5),
 'saplings_p13b':dict(saplings=[(2,0),(5,0),(1,1),(3,1),(2,2),(4,2),(0,3),(4,3),(2,4),(5,4)]),
 'saplings_p17a':dict(saplings=[(1,0),(1,1),(4,1),(0,2),(2,2),(4,2),(1,3),(4,3),(2,4),(5,4)]),
 'snowdrift_p15a':dict(blocked=[(2,2),(1,3),(1,4),(2,3),(2,4),(3,3),(3,4),(4,4)]),
 'snowdrift_p15b':dict(blocked=[(1,0),(2,0),(3,0),(2,1)]),
 'chasm_p17b':dict(blocked=[(2,0),(3,0),(2,1),(3,1),(2,3),(3,3),(2,4),(3,4),(0,2),(5,2)]),   # colonne centrali + prima e ultima casella della corsia centrale
 'chasm_p19a':dict(blocked=[(2,0),(3,0),(2,1),(3,1),(2,3),(3,3),(2,4),(3,4),(0,2),(5,2)]),
})
