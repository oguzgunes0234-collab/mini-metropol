extends TestCase
## Birleşme kararları: her bina en fazla bir birleşmeye girer, sonuç
## girdinin sırasından bağımsızdır.

const K := MergeResolver.Kind


func _pair(a: int, b: int, level: int) -> Dictionary:
	return {"a": a, "b": b, "level": level}


func test_single_pair_upgrades() -> void:
	var ops := MergeResolver.resolve([_pair(1, 2, 3)], 9, "landmark")
	assert_eq(ops.size(), 1)
	assert_eq(ops[0].kind, K.UPGRADE)
	assert_eq(ops[0].level, 3)


func test_same_pair_from_both_sides_merges_once() -> void:
	var ops := MergeResolver.resolve([_pair(5, 2, 1), _pair(2, 5, 1), _pair(5, 2, 1)], 9, "landmark")
	assert_eq(ops.size(), 1)
	assert_eq([ops[0].a, ops[0].b], [2, 5])


func test_three_touching_buildings_make_one_merge() -> void:
	var ops := MergeResolver.resolve([_pair(1, 2, 1), _pair(2, 3, 1), _pair(1, 3, 1)], 9, "landmark")
	assert_eq(ops.size(), 1)
	assert_eq([ops[0].a, ops[0].b], [1, 2], "en eski çift önce birleşmeli")


func test_disjoint_pairs_both_merge() -> void:
	var ops := MergeResolver.resolve([_pair(1, 2, 1), _pair(3, 4, 2)], 9, "landmark")
	assert_eq(ops.size(), 2)


func test_no_building_used_twice() -> void:
	var cands := []
	for a in range(1, 12):
		for b in range(1, 12):
			if a != b:
				cands.append(_pair(a, b, 2))
	var ops := MergeResolver.resolve(cands, 9, "landmark")
	var used := {}
	for op in ops:
		assert_false(used.has(op.a) or used.has(op.b), "kimlik tekrar kullanıldı")
		used[op.a] = true
		used[op.b] = true
	assert_eq(ops.size(), 5, "11 binadan en fazla 5 çift")


func test_result_independent_of_input_order() -> void:
	var cands := [_pair(4, 7, 2), _pair(1, 4, 2), _pair(7, 9, 2), _pair(2, 3, 1), _pair(1, 9, 2)]
	var expected := MergeResolver.resolve(cands, 9, "landmark")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 50:
		var shuffled := cands.duplicate()
		for j in range(shuffled.size() - 1, 0, -1):
			var k := rng.randi_range(0, j)
			var tmp = shuffled[j]
			shuffled[j] = shuffled[k]
			shuffled[k] = tmp
		assert_eq(MergeResolver.resolve(shuffled, 9, "landmark"), expected)


func test_max_level_becomes_landmark() -> void:
	var ops := MergeResolver.resolve([_pair(1, 2, 9)], 9, "landmark")
	assert_eq(ops.size(), 1)
	assert_eq(ops[0].kind, K.LANDMARK)


func test_max_level_with_none_rule_does_not_merge() -> void:
	assert_eq(MergeResolver.resolve([_pair(1, 2, 9)], 9, "none").size(), 0)


func test_self_pair_is_ignored() -> void:
	assert_eq(MergeResolver.resolve([_pair(3, 3, 1)], 9, "landmark").size(), 0)
