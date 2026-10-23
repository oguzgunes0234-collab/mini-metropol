class_name Invariants
extends RefCounted
## Her fizik karesinden sonra çağrılabilen tutarlılık denetimi. Stres
## testleri ve simülasyon, oyunun "hiç bozulmaması gereken" kurallarını
## bununla kontrol eder:
## 1. Değer korunumu: iki seviye-n bina = bir seviye-(n+1). Toplam değer
##    bırakılan binaların değerine eşit kalmalı (çift ya da kayıp bina yok).
##    Güçlendiricilerle kaldırılan ("Temizle") ve alınan ("Vinç") binalar
##    ayrı sayaçlarda tutulur.
## 2. Bir bina en fazla bir kez birleşmeye girer; kaldırılan bina geri gelmez.
## 3. Puan, birleşme olaylarının puanlarının toplamına eşittir ve her olayın
##    puanı veriden hesaplanan değerle aynıdır (çift puan yok).
## 4. Hiçbir bina alan dışına çıkmaz.
## 5. Sahnedeki gövde sayısı, Board'un listesiyle aynıdır (artık nesne yok).

const MAX_REPORTED := 25

## Board.spawn ile doğrudan eklenen (bırakılmayan) binaların toplam değeri.
var extra_value := 0
var violations: PackedStringArray = []
var checks := 0

var _consumed := {}
var _events_seen := 0
var _points_sum := 0
var _out_of_bounds_seen := 0
var _epoch := 0


## Yeni oyuna geçerken sayaçları sıfırlar. Bulunan ihlaller, clear_violations
## verilmedikçe korunur (test sonunda raporlanabilsin diye).
func reset(clear_violations: bool = false) -> void:
	extra_value = 0
	_consumed.clear()
	_events_seen = 0
	_points_sum = 0
	_out_of_bounds_seen = 0
	_epoch = 0
	if clear_violations:
		violations.clear()


func check(session: GameSession) -> void:
	checks += 1
	var board := session.board

	var held := board.total_value() + int(board.stats.landmark_value) + int(board.stats.lost_value) \
		+ int(board.stats.cleared_value) + int(board.stats.lifted_value)
	var expected := int(board.stats.dropped_value) + int(board.stats.placed_value) + extra_value
	if held != expected:
		_violation("değer korunumu bozuldu: alandaki+anıt+kayıp=%d, beklenen=%d" % [held, expected])

	if int(board.stats.out_of_bounds) > _out_of_bounds_seen:
		_violation("alan dışına çıkan bina (toplam %d)" % board.stats.out_of_bounds)
		_out_of_bounds_seen = int(board.stats.out_of_bounds)

	# Geri yükleme (geri al) olay kaydını kısaltır: kayıt baştan okunur.
	if session.log_epoch != _epoch:
		_epoch = session.log_epoch
		_consumed.clear()
		_events_seen = 0
		_points_sum = 0
	for i in range(_events_seen, session.event_log.size()):
		var e: Dictionary = session.event_log[i]
		for key in ["a", "b"]:
			var uid: int = e[key]
			if _consumed.has(uid):
				_violation("bina %d ikinci kez birleşmeye girdi" % uid)
			_consumed[uid] = true
		if e.kind == MergeResolver.Kind.UPGRADE:
			if _consumed.has(e.uid):
				_violation("yeni bina kimliği %d daha önce kullanılmış" % e.uid)
			var want := session.score.points_for(e.level, e.chain)
			if e.points != want:
				_violation("olay puanı %d, beklenen %d (seviye %d, zincir %d)" % [e.points, want, e.level, e.chain])
		else:
			var bonus := int(session.data.section("final_level").bonus_score)
			if e.points != bonus:
				_violation("anıt puanı %d, beklenen %d" % [e.points, bonus])
		_points_sum += int(e.points)
	_events_seen = session.event_log.size()

	if session.score.score != _points_sum:
		_violation("puan %d, olayların toplamı %d" % [session.score.score, _points_sum])

	var live := 0
	for b in board.buildings:
		if not is_instance_valid(b) or b.consumed or not b.is_inside_tree():
			_violation("listede geçersiz/tüketilmiş bina")
			continue
		if _consumed.has(b.uid):
			_violation("birleşmede kullanılmış bina %d hâlâ alanda" % b.uid)
		if b.level < 1 or b.level > session.data.max_level:
			_violation("geçersiz seviye %d" % b.level)
		# Merkezi duvar çizgisini kısa süre geçen bina Board tarafından geri
		# konur (stats.rescues). Binanın tamamı duvarın içindeyse gerçek hata.
		var p := b.position
		var r := b.current_radius()
		if p.x < -r or p.x > board.width + r or p.y > board.height + r:
			_violation("bina %d alan dışında: %s" % [b.uid, p])
		live += 1

	var container := board.get_node("Buildings")
	var in_scene := 0
	for c in container.get_children():
		if not c.is_queued_for_deletion():
			in_scene += 1
	if in_scene != live:
		_violation("sahnedeki gövde sayısı %d, liste %d" % [in_scene, live])


func ok() -> bool:
	return violations.is_empty()


func _violation(msg: String) -> void:
	if violations.size() < MAX_REPORTED:
		violations.append(msg)
	elif violations.size() == MAX_REPORTED:
		violations.append("... (daha fazla ihlal kesildi)")
