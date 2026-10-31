extends RefCounted
## Estado persistente próprio da cidade (user://cidade.json), separado do GameState.

const PATH := "user://cidade.json"

var d := {}

func _init() -> void:
	reset()
	load_file()

func defaults() -> Dictionary:
	return {
		"savings": 0, "savings_day": 1, "fines_due": 0,
		"fuel": 100.0, "fuel_enabled": true, "police_enabled": true,
		"weather_mode": "auto", "fitness": 0, "items": {},
		"done_day": {}, "done_count": {}, "missions_total": 0,
		"minimap": true, "cam_zoom": 1.0, "volume": 1.0, "radio": -1,
		"fines_paid": 0, "photos": 0, "races_won": 0,
	}

func reset() -> void:
	d = defaults()

func i(k: String) -> int:
	return int(d.get(k, 0))

func f(k: String) -> float:
	return float(d.get(k, 0.0))

func b(k: String) -> bool:
	return bool(d.get(k, false))

func s(k: String) -> String:
	return str(d.get(k, ""))

func put(k: String, v: Variant) -> void:
	d[k] = v

func add_i(k: String, n: int) -> void:
	d[k] = i(k) + n

func has_item(id: String) -> bool:
	var it: Variant = d.get("items", {})
	return typeof(it) == TYPE_DICTIONARY and bool((it as Dictionary).get(id, false))

func give_item(id: String) -> void:
	var it: Dictionary = d.get("items", {})
	it[id] = true
	d["items"] = it

func done_today(id: String, today: int) -> bool:
	var dd: Dictionary = d.get("done_day", {})
	return int(dd.get(id, -1)) == today

func mark_done(id: String, today: int) -> void:
	var dd: Dictionary = d.get("done_day", {})
	dd[id] = today
	d["done_day"] = dd
	var dc: Dictionary = d.get("done_count", {})
	dc[id] = int(dc.get(id, 0)) + 1
	d["done_count"] = dc
	add_i("missions_total", 1)

func save() -> void:
	var fa := FileAccess.open(PATH, FileAccess.WRITE)
	if fa:
		fa.store_string(JSON.stringify(d))

func load_file() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var fa := FileAccess.open(PATH, FileAccess.READ)
	if not fa:
		return
	var parsed: Variant = JSON.parse_string(fa.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var src: Dictionary = parsed
	for k in src.keys():
		if d.has(k):
			d[k] = src[k]
	if typeof(d.get("items")) != TYPE_DICTIONARY:
		d["items"] = {}
	if typeof(d.get("done_day")) != TYPE_DICTIONARY:
		d["done_day"] = {}
	if typeof(d.get("done_count")) != TYPE_DICTIONARY:
		d["done_count"] = {}
