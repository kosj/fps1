extends RefCounted
## 한 사람의 경험치를 경기 중에 쌓는다. 킬과 판 결과를 받아 화면에 알리고 저장한다.
## 경기 화면(game/net/match_view.gd)이 킬 알림과 판 종료를 넘겨준다.

const Progression := preload("res://game/core/progression.gd")
const XpFeed := preload("res://game/ui/xp_feed.gd")
const Armory := preload("res://game/weapons/armory.gd")
const Settings := preload("res://game/core/settings.gd")

var xp := 0
## 이번 경기(접속)에서 얻은 경험치와 이번 판에서 얻은 경험치.
var earned := 0
var earned_this_match := 0
## 꺼 두면 저장하지 않는다(자동 테스트).
var persist := true

var _feed: XpFeed
var _match_over := false


## hud가 있으면 그 위에 경험치 알림을 띄운다.
func _init(hud: Node, keep: bool) -> void:
	persist = keep
	xp = Progression.saved_xp() if keep else 0
	if hud != null:
		_feed = XpFeed.new()
		hud.add_child(_feed)


func level() -> int:
	return Progression.level_for(xp)


func on_kill(headshot: bool) -> void:
	_add(Progression.KILL_XP, "KILL")
	if headshot:
		_add(Progression.HEADSHOT_XP, "HEADSHOT")


## 판 상태를 받는다. 판이 끝나는 순간 한 번만 결과 경험치를 준다.
func on_match_state(over: bool, own_score: int, other_score: int) -> void:
	if over and not _match_over:
		var reward := Progression.match_xp(own_score, other_score)
		var reason := "VICTORY" if reward == Progression.WIN_XP else "MATCH"
		_add(reward, reason)
	elif not over and _match_over:
		earned_this_match = 0
	_match_over = over


## 결과 화면에 붙일 한 줄: 이번 판 경험치와 레벨 진행.
func summary() -> String:
	var progress := Progression.progress_in_level(xp)
	var line := "+%d XP    LEVEL %d" % [earned_this_match, level()]
	if int(progress[1]) > 0:
		line += "  (%d / %d)" % [progress[0], progress[1]]
	return line


func _add(amount: int, reason: String) -> void:
	var before := level()
	xp += amount
	earned += amount
	earned_this_match += amount
	if persist:
		Settings.write(Progression.XP_KEY, xp)
	if _feed == null:
		return
	_feed.show_award("+%d  %s" % [amount, reason])
	for reached in range(before + 1, level() + 1):
		var names: Array = Progression.unlocked_at(reached).map(
			func(weapon_id: int) -> String: return Armory.title(weapon_id)
		)
		_feed.show_level_up(reached, names)
