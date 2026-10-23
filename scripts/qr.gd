class_name QR
extends RefCounted
## Codice QR (modalità byte, correzione M, versioni 1–6): basta per un indirizzo con il codice della stanza.
## Segue l'algoritmo standard (ISO 18004), come nella libreria di riferimento di Nayuki.

# versione -> [codewords di correzione per blocco, numero di blocchi, codewords di dati per blocco]
const BLOCKS := {1: [10, 1, 16], 2: [16, 1, 28], 3: [26, 1, 44], 4: [18, 2, 32], 5: [24, 2, 43], 6: [16, 4, 27]}
const ALIGN := {1: [], 2: [6, 18], 3: [6, 22], 4: [6, 26], 5: [6, 30], 6: [6, 34]}

var size := 0
var modules: Array = []     # [riga][colonna] -> bool (scuro)
var _func: Array = []

## Matrice del codice per il testo, oppure null se troppo lungo.
static func make(text: String) -> QR:
	var data := text.to_utf8_buffer()
	for v in range(1, 7):
		var b: Array = BLOCKS[v]
		if data.size() + 2 <= int(b[1]) * int(b[2]):
			var q := QR.new()
			q._build(v, data)
			return q
	return null

## Immagine bianca e nera (con il margine di 4 moduli), scala = pixel per modulo.
func image(scale := 8, dark := Color.BLACK, light := Color.WHITE) -> Image:
	var n := (size + 8) * scale
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(light)
	for y in size:
		for x in size:
			if modules[y][x]:
				img.fill_rect(Rect2i((x + 4) * scale, (y + 4) * scale, scale, scale), dark)
	return img

func _build(ver: int, data: PackedByteArray) -> void:
	size = ver * 4 + 17
	modules = []
	_func = []
	for y in size:
		var r := []
		var f := []
		r.resize(size)
		f.resize(size)
		r.fill(false)
		f.fill(false)
		modules.append(r)
		_func.append(f)
	_draw_function(ver)
	var cw := _codewords(ver, data)
	_draw_codewords(cw)
	# maschera con la penalità più bassa
	var best := 0
	var best_pen := -1
	for m in 8:
		_apply_mask(m)
		_draw_format(m)
		var pen := _penalty()
		if best_pen < 0 or pen < best_pen:
			best_pen = pen
			best = m
		_apply_mask(m)
	_apply_mask(best)
	_draw_format(best)

# ---------- parti fisse ----------
func _set_f(x: int, y: int, dark: bool) -> void:
	modules[y][x] = dark
	_func[y][x] = true

func _draw_function(ver: int) -> void:
	for i in size:
		_set_f(6, i, i % 2 == 0)
		_set_f(i, 6, i % 2 == 0)
	_finder(3, 3)
	_finder(size - 4, 3)
	_finder(3, size - 4)
	var al: Array = ALIGN[ver]
	var na := al.size()
	for i in na:
		for j in na:
			if (i == 0 and j == 0) or (i == 0 and j == na - 1) or (i == na - 1 and j == 0):
				continue
			_align(int(al[i]), int(al[j]))
	_draw_format(0)   # riserva le zone del formato

func _finder(cx: int, cy: int) -> void:
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var d: int = max(abs(dx), abs(dy))
			var x := cx + dx
			var y := cy + dy
			if x >= 0 and x < size and y >= 0 and y < size:
				_set_f(x, y, d != 2 and d != 4)

func _align(cx: int, cy: int) -> void:
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			_set_f(cx + dx, cy + dy, max(abs(dx), abs(dy)) != 1)

func _draw_format(mask: int) -> void:
	var data := (0 << 3) | mask        # livello M = 00
	var rem := data
	for i in 10:
		rem = (rem << 1) ^ ((rem >> 9) * 0x537)
	var bits := ((data << 10) | rem) ^ 0x5412
	for i in range(0, 6):
		_set_f(8, i, (bits >> i) & 1 == 1)
	_set_f(8, 7, (bits >> 6) & 1 == 1)
	_set_f(8, 8, (bits >> 7) & 1 == 1)
	_set_f(7, 8, (bits >> 8) & 1 == 1)
	for i in range(9, 15):
		_set_f(14 - i, 8, (bits >> i) & 1 == 1)
	for i in range(0, 8):
		_set_f(size - 1 - i, 8, (bits >> i) & 1 == 1)
	for i in range(8, 15):
		_set_f(8, size - 15 + i, (bits >> i) & 1 == 1)
	_set_f(8, size - 8, true)

# ---------- dati ----------
func _codewords(ver: int, data: PackedByteArray) -> PackedByteArray:
	var b: Array = BLOCKS[ver]
	var ecl: int = b[0]
	var nb: int = b[1]
	var dl: int = b[2]
	var cap := nb * dl
	var bits: Array = []
	var push := func(val: int, n: int):
		for i in range(n - 1, -1, -1):
			bits.append((val >> i) & 1)
	push.call(0b0100, 4)
	push.call(data.size(), 8)
	for x in data:
		push.call(x, 8)
	push.call(0, min(4, cap * 8 - bits.size()))
	while bits.size() % 8 != 0:
		bits.append(0)
	var bytes := PackedByteArray()
	for i in range(0, bits.size(), 8):
		var v := 0
		for k in 8:
			v = (v << 1) | int(bits[i + k])
		bytes.append(v)
	var pad := 0xEC
	while bytes.size() < cap:
		bytes.append(pad)
		pad = 0x11 if pad == 0xEC else 0xEC
	var div := _rs_divisor(ecl)
	var dblocks := []
	var eblocks := []
	for k in nb:
		var blk := bytes.slice(k * dl, (k + 1) * dl)
		dblocks.append(blk)
		eblocks.append(_rs_remainder(blk, div))
	var out := PackedByteArray()
	for i in dl:
		for k in nb:
			out.append(dblocks[k][i])
	for i in ecl:
		for k in nb:
			out.append(eblocks[k][i])
	return out

static func _gmul(x: int, y: int) -> int:
	var z := 0
	for i in range(7, -1, -1):
		z = ((z << 1) ^ ((z >> 7) * 0x11D)) & 0xFF
		if (y >> i) & 1:
			z ^= x
	return z

static func _rs_divisor(degree: int) -> PackedByteArray:
	var r := PackedByteArray()
	r.resize(degree)
	r.fill(0)
	r[degree - 1] = 1
	var root := 1
	for i in degree:
		for j in degree:
			r[j] = _gmul(r[j], root)
			if j + 1 < degree:
				r[j] ^= r[j + 1]
		root = _gmul(root, 0x02)
	return r

static func _rs_remainder(data: PackedByteArray, div: PackedByteArray) -> PackedByteArray:
	var r := PackedByteArray()
	r.resize(div.size())
	r.fill(0)
	for b in data:
		var factor := b ^ r[0]
		r.remove_at(0)
		r.append(0)
		for i in div.size():
			r[i] ^= _gmul(div[i], factor)
	return r

func _draw_codewords(cw: PackedByteArray) -> void:
	var i := 0
	var right := size - 1
	while right >= 1:
		if right == 6:
			right = 5
		for vert in size:
			for j in 2:
				var x := right - j
				var upward := ((right + 1) & 2) == 0
				var y: int = size - 1 - vert if upward else vert
				if not _func[y][x] and i < cw.size() * 8:
					modules[y][x] = (cw[i >> 3] >> (7 - (i & 7))) & 1 == 1
					i += 1
		right -= 2

func _apply_mask(m: int) -> void:
	for y in size:
		for x in size:
			if _func[y][x]:
				continue
			var inv := false
			match m:
				0: inv = (x + y) % 2 == 0
				1: inv = y % 2 == 0
				2: inv = x % 3 == 0
				3: inv = (x + y) % 3 == 0
				4: inv = (x / 3 + y / 2) % 2 == 0
				5: inv = x * y % 2 + x * y % 3 == 0
				6: inv = (x * y % 2 + x * y % 3) % 2 == 0
				7: inv = ((x + y) % 2 + x * y % 3) % 2 == 0
			if inv:
				modules[y][x] = not modules[y][x]

func _penalty() -> int:
	var pen := 0
	var dark := 0
	for pass_ in 2:
		for a in size:
			var run := 0
			var prev := false
			var line := ""
			for b in size:
				var v: bool = modules[a][b] if pass_ == 0 else modules[b][a]
				line += "1" if v else "0"
				if b > 0 and v == prev:
					run += 1
				else:
					if run >= 5:
						pen += 3 + run - 5
					run = 1
				prev = v
			if run >= 5:
				pen += 3 + run - 5
			pen += 40 * (line.count("10111010000") + line.count("00001011101"))
	for y in size - 1:
		for x in size - 1:
			var c: bool = modules[y][x]
			if c == modules[y][x + 1] and c == modules[y + 1][x] and c == modules[y + 1][x + 1]:
				pen += 3
	for y in size:
		for x in size:
			if modules[y][x]:
				dark += 1
	var total := size * size
	var k := int(abs(dark * 20 - total * 10) / total)
	pen += k * 10
	return pen
