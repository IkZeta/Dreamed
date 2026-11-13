class_name CityProps
extends RefCounted
## Lo que se levanta sobre el suelo de la ciudad, cada cosa con su nodo para ordenarse con los
## personajes: árboles, setos, farolas, bancos, coches aparcados, edificios con sus jardineras y,
## en el sueño 20, las vallas de Evil Ad. También busca farolas para la telaraña larga del
## Atrapasueños.
## What stands on the city floor, each with its own node so it sorts with the characters: trees,
## hedges, lamps, benches, parked cars, buildings with their planters and, in dream 20, Evil Ad's
## billboards. It also finds lamp posts for the Dreamcatcher's long web.


## Edificios, árboles, setos, farolas y bancos, cada uno con su nodo (se ordenan por altura con los personajes)
## Buildings, trees, hedges, lamps and benches, each with its own node (sorted by height with the characters)
static func build(room: Act4Room, run_node: Node) -> Array[Node2D]:
	var out: Array[Node2D] = []
	for r in CityLayout.ROWS:
		var row: String = CityLayout.MAP[r]
		for c in CityLayout.COLS:
			var sprite := ""
			var base := Vector2(0.5, 0.85)
			match row[c]:
				"T": sprite = "tree"
				"h": sprite = "hedge"; base = Vector2(0.5, 0.8)
				"l": sprite = "lamp"; base = Vector2(0.5, 0.75)
				"b": sprite = "bench"; base = Vector2(0.5, 0.7)
			if sprite == "":
				continue
			var p := CityProp.new()
			p.sprite = room._tile(sprite)
			var at := (Vector2(c, r) + base) * Act4Room.T
			if sprite == "tree":
				# Árboles algo movidos, de tamaños distintos y unos girados: que no parezcan una fila
				# Trees a bit offset, of different sizes and some flipped: so they don't look like a row
				var h := Act4Room._hash(c, r)
				at += Vector2(float(h % 41) - 20.0, float((h / 41) % 21) - 10.0)
				p.size = 0.85 + float(h % 7) * 0.06
				p.flip = h % 2 == 0
			p.position = Bedroom.to_world(at)
			p.sway = sprite == "tree"
			out.append(p)
	for car: Array in room.parked:
		var p := CityProp.new()
		p.sprite = room._tile("car%d" % car[2])
		var row: int = Act4Room.ROAD_H.position.y + (0 if car[1] == 0 else Act4Room.ROAD_H.size.y - 1)
		p.position = Bedroom.to_world(Vector2(float(car[0]) * Act4Room.T, (row + (0.62 if car[1] == 0 else 0.78)) * Act4Room.T))
		p.flip = car[1] == 1
		out.append(p)
	for i in CityLayout.BUILDINGS.size():
		var b: Array = CityLayout.BUILDINGS[i]
		var bl := CityBuilding.new()
		bl.room = room
		bl.run = run_node
		bl.style = room.style
		bl.rect = Rect2(Vector2(b[0], b[1]) * Act4Room.T, Vector2(b[2], b[3]) * Act4Room.T)
		bl.kind = b[4]
		bl.seed = i
		bl.position = Bedroom.to_world(Vector2(bl.rect.position.x, bl.rect.end.y))
		out.append(bl)
		# Delante de cada edificio: jardineras en las esquinas y una papelera o máquina junto a la puerta
		# In front of each building: planters at the corners and a bin or vending machine by the door
		var front := bl.rect.end.y + 34.0
		var door := bl.rect.get_center().x
		var deco := [["planter", Vector2(bl.rect.position.x + 50, front)], ["planter", Vector2(bl.rect.end.x - 50, front)],
				["vending" if i % 2 else "bin", Vector2(door + 120.0 * (1 if i % 3 else -1), front - 6.0)]]
		for d: Array in deco:
			var pr := CityProp.new()
			pr.sprite = room._tile(d[0])
			pr.position = Bedroom.to_world(d[1])
			out.append(pr)
	# Último sueño: la ciudad está llena de vallas publicitarias / Last dream: the city is full of billboards
	if room.style == "noir":
		var spots: Array[Vector2] = []
		for r in range(1, CityLayout.ROWS - 1):
			for c in range(1, CityLayout.COLS - 1):
				if not CityLayout.MAP[r][c] in [".", ":", ","] or room.is_road(c, r):
					continue
				var p := (Vector2(c, r) + Vector2(0.5, 0.6)) * Act4Room.T
				if Act4Room.FOUNTAIN.grow(120.0).has_point(p) or p.distance_to(room.start_point()) < 260.0:
					continue
				if not room._free(Rect2(p - Vector2(90, 30), Vector2(180, 40))):
					continue
				var ok := true
				for q in spots:
					if q.distance_to(p) < 430.0:
						ok = false
						break
				if ok:
					spots.append(p)
		var k := 0
		for p in spots:
			var bb := CityBillboard.new()
			bb.room = room
			bb.ad = k % CityBillboard.ADS
			bb.position = Bedroom.to_world(p)
			out.append(bb)
			k += 1
	# Los adornos lejos de la cámara se esconden (cuestan aunque no se vean) / Props far from the camera get hidden (they cost even off-screen)
	room._cull.clear()
	for n in out:
		if n is CityProp:
			room._cull.append(n)
	return out


## Los extremos de la telaraña larga del Atrapasueños: la farola más cercana a él (a menos de
## 800 px) y un punto al otro lado de la calle (otra farola o el bordillo), pasando por asfalto y
## sin un edificio en medio. Vacío si no hay.
## The ends of the Dreamcatcher's long web: the lamp post nearest to it (within 800 px) and a spot
## across the street (another lamp or the far kerb), over asphalt and with no building in between.
## Empty if there are none.
static func lamp_pair(room: Act4Room, near: Vector2) -> Array:
	# Todo en coordenadas del plano; se pasa al mundo al final / All in map coordinates; converted to the world at the end
	if room._lamps.is_empty():
		for r in CityLayout.ROWS:
			for c in CityLayout.COLS:
				if CityLayout.MAP[r][c] == "l":
					room._lamps.append((Vector2(c, r) + Vector2(0.5, 0.9)) * Act4Room.T)
	var here := (near - Bedroom.OFFSET) / Bedroom.S
	var reach := 800.0 / Bedroom.S
	var a := Vector2.INF
	for p: Vector2 in room._lamps:
		if p.distance_to(here) < reach and (a == Vector2.INF or p.distance_to(here) < a.distance_to(here)):
			a = p
	if a == Vector2.INF:
		return []
	# Que cruce la calle: otra farola o, si no hay, el bordillo de enfrente; y que pase por asfalto
	# It must cross the street: another lamp or, failing that, the far kerb; and go over asphalt
	var cands: Array = []
	for p: Vector2 in room._lamps:
		if p.distance_to(a) > Act4Room.T * 1.8 and p.distance_to(a) < Act4Room.T * 5.8:
			cands.append(p)
	for off: Vector2 in [Vector2(0, 4), Vector2(0, -4), Vector2(0, 5), Vector2(0, -5), Vector2(4, 0), Vector2(-4, 0)]:
		cands.append(a + off * Act4Room.T)
	var opts: Array = []
	for b: Vector2 in cands:
		if room.walkable().has_point(b) and not _wall_between(room, a, b) and _road_samples(room, a, b) >= 3:
			opts.append(b)
	if opts.is_empty():
		return []
	return [Bedroom.to_world(a), Bedroom.to_world(opts.pick_random())]


## a y b en coordenadas del plano / a and b in map coordinates
static func _wall_between(room: Act4Room, a: Vector2, b: Vector2) -> bool:
	for i in 9:
		var q := Bedroom.to_world(a.lerp(b, (i + 1) / 10.0))
		for r in room.blockers_near(q):
			if Bedroom.rect_world(r).has_point(q):
				return true
	return false


static func _road_samples(room: Act4Room, a: Vector2, b: Vector2) -> int:
	var n := 0
	for i in 9:
		var q := a.lerp(b, (i + 1) / 10.0)
		if room.is_road(floori(q.x / Act4Room.T), floori(q.y / Act4Room.T)):
			n += 1
	return n
