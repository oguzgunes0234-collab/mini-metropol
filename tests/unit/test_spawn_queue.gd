extends TestCase
## Sıradaki bina kuyruğu: tohumla tekrarlanabilirlik, ağırlıklar, durum kaydı.


func _sequence(q: SpawnQueue, n: int) -> Array[int]:
	var out: Array[int] = []
	for i in n:
		out.append(q.advance())
	return out


func test_same_seed_same_sequence() -> void:
	var a := SpawnQueue.new([1, 2, 3, 4], [40, 30, 20, 10], 123)
	var b := SpawnQueue.new([1, 2, 3, 4], [40, 30, 20, 10], 123)
	assert_eq(_sequence(a, 200), _sequence(b, 200))


func test_different_seed_differs() -> void:
	var a := SpawnQueue.new([1, 2, 3, 4], [40, 30, 20, 10], 1)
	var b := SpawnQueue.new([1, 2, 3, 4], [40, 30, 20, 10], 2)
	assert_ne(_sequence(a, 50), _sequence(b, 50))


func test_only_allowed_levels_and_zero_weight_never_appears() -> void:
	var q := SpawnQueue.new([1, 2, 3], [1, 0, 1], 7)
	for l in _sequence(q, 2000):
		assert_true(l == 1 or l == 3, "beklenmeyen seviye %d" % l)


func test_weights_are_respected() -> void:
	var q := SpawnQueue.new([1, 2, 3, 4], [40, 30, 20, 10], 99)
	var counts := {1: 0, 2: 0, 3: 0, 4: 0}
	var n := 20000
	for l in _sequence(q, n):
		counts[l] += 1
	assert_between(counts[1] / float(n), 0.38, 0.42)
	assert_between(counts[2] / float(n), 0.28, 0.32)
	assert_between(counts[3] / float(n), 0.18, 0.22)
	assert_between(counts[4] / float(n), 0.08, 0.12)


func test_state_roundtrip_continues_same_sequence() -> void:
	var q := SpawnQueue.new([1, 2, 3, 4], [40, 30, 20, 10], 555, 2)
	_sequence(q, 17)
	var state := q.get_state()
	var expected := _sequence(q, 60)
	q.set_state(state)
	assert_eq(_sequence(q, 60), expected)
	# JSON üzerinden geçince de aynı kalmalı (ileride diske kayıt için).
	var copy := SpawnQueue.new([1, 2, 3, 4], [40, 30, 20, 10], 1, 2)
	copy.set_state(JSON.parse_string(JSON.stringify(state)))
	assert_eq(_sequence(copy, 60), expected)


func test_preview_count() -> void:
	var q := SpawnQueue.new([1, 2], [1, 1], 3, 2)
	assert_eq(q.upcoming().size(), 2)
	var next := q.upcoming()[0]
	q.advance()
	assert_eq(q.current(), next, "önizlemedeki bina sıradaki olmalı")
