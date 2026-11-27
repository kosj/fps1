extends RefCounted
## 자동 테스트용 검증. 세션 통계가 명령줄의 --expect 조건을 만족하는지 확인한다.


## 만족하지 못한 조건의 설명 목록을 돌려준다. 비어 있으면 통과.
static func check(is_client: bool, args: Dictionary, stats: Dictionary) -> PackedStringArray:
	var failures := PackedStringArray()
	if is_client:
		if not stats["connected"]:
			failures.append("never connected")
		if int(stats["snapshots"]) < 30:
			failures.append("received only %d snapshots" % int(stats["snapshots"]))
		# 들어오자마자 점수판을 받아야 한다(첫 킬을 기다리지 않는다).
		if int(stats["score_rows"]) < 1:
			failures.append("never received the scoreboard")
	_at_least(failures, args, stats, "expect-players", "peak_players", "players")
	_at_least(failures, args, stats, "expect-kills", "total_kills", "kills")
	_at_least(failures, args, stats, "expect-zone-captures", "zone_captures", "zone captures")
	if args.has("max-corrections"):
		var allowed := int(args["max-corrections"])
		if int(stats["corrections"]) > allowed:
			failures.append(
				"%d prediction corrections (limit %d)" % [int(stats["corrections"]), allowed]
			)
	var shots := int(stats["shots"])
	var ratio := float(stats["hits"]) / maxf(float(shots), 1.0)
	if args.has("expect-hit-ratio"):
		var wanted_ratio := float(args["expect-hit-ratio"])
		if shots < 10 or ratio < wanted_ratio:
			failures.append(
				"hit ratio %.2f over %d shots (wanted %.2f)" % [ratio, shots, wanted_ratio]
			)
	if args.has("max-hit-ratio") and ratio > float(args["max-hit-ratio"]):
		failures.append("hit ratio %.2f is above %.2f" % [ratio, float(args["max-hit-ratio"])])
	if args.has("expect-remote-moving") and float(stats["remote_travel"]) < 2.0:
		failures.append(
			"remote player moved only %.2f m on screen" % float(stats["remote_travel"])
		)
	return failures


static func _at_least(
	failures: PackedStringArray, args: Dictionary, stats: Dictionary,
	arg: String, stat: String, what: String
) -> void:
	if not args.has(arg):
		return
	var wanted := int(args[arg])
	var seen := int(stats[stat])
	if seen < wanted:
		failures.append("expected %d %s, saw %d" % [wanted, what, seen])
