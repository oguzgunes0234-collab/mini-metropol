class_name BoosterManager
extends RefCounted
## Güçlendiricilerin kullanım kuralları. Etkilerin kendisi GameSession'dadır;
## bu sınıf "şu an kullanılabilir mi?" sorusunu yanıtlar, kullanımı sayar ve
## envanterden (PlayerProfile) düşer.
##
## Kurallar:
## - Yalnızca bölüm kipinde ve bölüm sürerken kullanılır (serbest oyunda yok).
## - Güçlendirici açılmış olmalı (economy.json: unlock_after).
## - Bir bölüm denemesinde en fazla per_level kez kullanılır. Yeniden
##   denemede sayaç sıfırlanır; geri al sayaçları geri getirmez.
## - Envanterden yalnızca etki gerçekten uygulandıysa düşülür.
## - Satın alma oyun içi parayla ve tek adet olarak yapılır; gerçek para yok.

## Envanter veya kullanım değişti: arayüz tazelenmeli, kayıt yazılmalı.
signal changed

var session: GameSession
var profile: PlayerProfile
## Bu denemede kullanım sayıları: id -> adet.
var used := {}


func setup(p_session: GameSession, p_profile: PlayerProfile) -> void:
	session = p_session
	profile = p_profile


## Yeni deneme (bölüm başı veya yeniden dene).
func reset_attempt() -> void:
	used.clear()
	changed.emit()


func def(id: String) -> Dictionary:
	return profile.economy.boosters.get(id, {})


func uses_left(id: String) -> int:
	return maxi(0, int(def(id).get("per_level", 0)) - int(used.get(id, 0)))


## Bu bölümde gösterilecek güçlendiriciler (açılmış olanlar, sırasıyla).
func visible_ids() -> Array[String]:
	var out: Array[String] = []
	if not session.is_level_mode():
		return out
	for id in EconomyData.BOOSTER_IDS:
		if profile.is_booster_unlocked(id):
			out.append(id)
	return out


## "" ise şimdi kullanılabilir. Değilse neden:
## free_play, finished, locked, limit, not_now (etki şu an uygulanamaz),
## none_owned (envanterde yok; satın alınabilir).
func check(id: String) -> String:
	if def(id).is_empty():
		return "locked"
	if not session.is_level_mode():
		return "free_play"
	if session.is_finished():
		return "finished"
	if not profile.is_booster_unlocked(id):
		return "locked"
	if uses_left(id) <= 0:
		return "limit"
	if not _possible(id):
		return "not_now"
	if profile.booster_count(id) <= 0:
		return "none_owned"
	return ""


## Güçlendiriciyi kullanır. Vinç için target: alınacak bina.
func use(id: String, target: Building = null) -> bool:
	if check(id) != "":
		return false
	var d := def(id)
	var ok := false
	match id:
		"undo":
			ok = session.undo()
		"swap":
			ok = session.swap()
		"crane":
			ok = session.lift(target, int(d.max_level))
		"relieve":
			ok = not session.clear_small(int(d.max_level)).is_empty()
		"extra_moves":
			ok = session.add_moves(int(d.amount))
	if not ok:
		return false
	profile.use_booster(id)
	used[id] = int(used.get(id, 0)) + 1
	changed.emit()
	return true


## Vinç için: bu bina alınabilir mi?
func can_lift(b: Building) -> bool:
	return check("crane") == "" and session.can_lift(b, int(def("crane").max_level))


## Bir adet satın alır. Dönüş: "" (başarılı) veya PlayerProfile.buy_booster nedeni.
func buy(id: String) -> String:
	var reason := profile.buy_booster(id)
	if reason == "":
		changed.emit()
	return reason


func _possible(id: String) -> bool:
	match id:
		"undo":
			return session.can_undo()
		"swap":
			return session.can_swap()
		"crane":
			return session.can_lift_any(int(def(id).max_level))
		"relieve":
			return session.can_clear(int(def(id).max_level))
		"extra_moves":
			return session.can_add_moves()
	return false
