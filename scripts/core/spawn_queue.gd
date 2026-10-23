class_name SpawnQueue
extends RefCounted
## Oyuncunun bırakacağı binaların sırası. Tohumlu (seed) rastgelelik kullanır:
## aynı tohum her zaman aynı sırayı üretir. Durumu kaydedilip geri
## yüklenebilir (geri al ve testler için).

var _rng := RandomNumberGenerator.new()
var _levels: PackedInt32Array
var _weights: PackedFloat32Array
var _preview_count: int
var _queue: Array[int] = []
## Öğretici bölümler için: rastgele sıradan önce bu seviyeler sırayla gelir.
var _scripted: Array[int] = []


func _init(levels: Array, weights: Array, seed_value: int, preview_count: int = 1, scripted: Array = []) -> void:
	for l in levels:
		_levels.append(int(l))
	for w in weights:
		_weights.append(float(w))
	for l in scripted:
		_scripted.append(int(l))
	_preview_count = preview_count
	_rng.seed = seed_value
	_fill()


static func from_data(data: GameData, seed_value: int, scripted: Array = []) -> SpawnQueue:
	var drop := data.section("drop")
	return SpawnQueue.new(drop.spawn_levels, drop.spawn_weights, seed_value, int(drop.preview_count), scripted)


## Şu an bırakılacak bina seviyesi.
func current() -> int:
	return _queue[0]


## Önizlemede gösterilecek sonraki seviyeler (current hariç).
func upcoming() -> Array[int]:
	return _queue.slice(1)


## Sıradaki binayı tüketir ve seviyesini döndürür.
func advance() -> int:
	var level: int = _queue.pop_front()
	_fill()
	return level


## Şimdiki binayla sıradakinin yerini değiştirir (güçlendirici "Değiştir").
func swap_next() -> void:
	var t := _queue[0]
	_queue[0] = _queue[1]
	_queue[1] = t


func get_state() -> Dictionary:
	# 64 bit RNG durumu JSON'da hassasiyet kaybetmesin diye metin olarak tutulur.
	return {"seed": str(_rng.seed), "state": str(_rng.state), "queue": _queue.duplicate(), "scripted": _scripted.duplicate()}


func set_state(s: Dictionary) -> void:
	_rng.seed = String(s.seed).to_int()
	_rng.state = String(s.state).to_int()
	_queue.clear()
	for l in s.queue:
		_queue.append(int(l))
	_scripted.clear()
	for l in s.get("scripted", []):
		_scripted.append(int(l))
	_fill()


func _fill() -> void:
	while _queue.size() < 1 + _preview_count:
		if not _scripted.is_empty():
			_queue.append(_scripted.pop_front())
		else:
			_queue.append(_levels[_rng.rand_weighted(_weights)])
