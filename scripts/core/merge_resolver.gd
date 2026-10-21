class_name MergeResolver
extends RefCounted
## Aynı fizik karesinde birbirine değen aynı seviyedeki bina çiftlerinden
## hangilerinin birleşeceğine karar verir.
##
## Kurallar:
## - Bir bina bir karede en fazla bir birleşmeye katılır (çift bina/puan olmaz).
## - Sonuç, adayların geliş sırasından bağımsızdır: çiftler kimlik numarasına
##   göre sıralanır, eski binalar önce birleşir.
## - Son seviyedeki iki bina "landmark" kuralında Anıt olarak tamamlanır
##   (ikisi de kaldırılır, bonus verilir); "none" kuralında birleşmez.

enum Kind { UPGRADE, LANDMARK }


## candidates: {"a": uid, "b": uid, "level": int} sözlüklerinden oluşan liste.
## Aynı çift birden fazla kez (iki yönden) gelebilir.
## Dönüş: {"kind": Kind, "a": uid, "b": uid, "level": int} işlem listesi.
static func resolve(candidates: Array, max_level: int, final_rule: String) -> Array[Dictionary]:
	var pairs: Array[Dictionary] = []
	for c in candidates:
		var a: int = mini(c.a, c.b)
		var b: int = maxi(c.a, c.b)
		if a == b:
			continue
		pairs.append({"a": a, "b": b, "level": c.level})
	pairs.sort_custom(func(x, y): return x.a < y.a or (x.a == y.a and x.b < y.b))

	var used := {}
	var ops: Array[Dictionary] = []
	for p in pairs:
		if used.has(p.a) or used.has(p.b):
			continue
		var kind: Kind
		if p.level < max_level:
			kind = Kind.UPGRADE
		elif p.level == max_level and final_rule == "landmark":
			kind = Kind.LANDMARK
		else:
			continue
		used[p.a] = true
		used[p.b] = true
		ops.append({"kind": kind, "a": p.a, "b": p.b, "level": p.level})
	return ops
