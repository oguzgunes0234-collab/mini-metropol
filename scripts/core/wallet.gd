class_name Wallet
extends RefCounted
## Oyuncunun kaynakları: madeni para ve elmas. Bakiye asla negatif olmaz;
## yetersiz bakiyeyle harcama yapılamaz. Son işlemler kayıt altında tutulur
## (hata ayıklama ve çift ödül kontrolü için).

const KINDS: Array[String] = ["coins", "diamonds"]
const LEDGER_SIZE := 50

var _balances := {"coins": 0, "diamonds": 0}
var ledger: Array[Dictionary] = []


func balance(kind: String) -> int:
	return int(_balances.get(kind, 0))


func add(kind: String, amount: int, reason: String) -> void:
	if not KINDS.has(kind) or amount <= 0:
		push_warning("Geçersiz kazanç: %s %d (%s)" % [kind, amount, reason])
		return
	_balances[kind] = balance(kind) + amount
	_log(kind, amount, reason)


func can_spend(kind: String, amount: int) -> bool:
	return KINDS.has(kind) and amount >= 0 and balance(kind) >= amount


## Yeterli bakiye varsa harcar ve true döner; yoksa hiçbir şey değişmez.
func spend(kind: String, amount: int, reason: String) -> bool:
	if not can_spend(kind, amount):
		return false
	_balances[kind] = balance(kind) - amount
	_log(kind, -amount, reason)
	return true


func get_state() -> Dictionary:
	return {"balances": _balances.duplicate(), "ledger": ledger.duplicate(true)}


## Bozuk/eksik değerler güvenli varsayılana döner (negatif bakiye olmaz).
func set_state(s: Dictionary) -> void:
	var b = s.get("balances", {})
	for kind in KINDS:
		var v = b.get(kind, 0) if typeof(b) == TYPE_DICTIONARY else 0
		_balances[kind] = maxi(0, int(v)) if GameData._is_number(v) else 0
	ledger.clear()
	var l = s.get("ledger", [])
	if typeof(l) == TYPE_ARRAY:
		for e in l.slice(maxi(0, l.size() - LEDGER_SIZE)):
			if typeof(e) == TYPE_DICTIONARY:
				ledger.append(e)


func _log(kind: String, delta: int, reason: String) -> void:
	ledger.append({"kind": kind, "delta": delta, "reason": reason, "t": int(Time.get_unix_time_from_system())})
	if ledger.size() > LEDGER_SIZE:
		ledger.pop_front()
