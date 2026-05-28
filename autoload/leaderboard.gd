# Leaderboard.gd — Autoload
# Wraps HTTP client for the /api/paydirt/scores endpoint.
# Offline fallback: web → localStorage via JavaScriptBridge, desktop → ConfigFile.

extends Node

signal scores_loaded(scores: Array)
signal submit_done(ok: bool)

var _cached_top: Array = []


func fetch_top() -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_fetch_done.bind(http))
	http.timeout = 5.0  # Don't hang forever
	var url := GameState.API_BASE + "/scores"
	var err := http.request(url)
	if err != OK:
		scores_loaded.emit(_local_top())
		http.queue_free()


func _on_fetch_done(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	if code == 200:
		var json: Variant = JSON.parse_string(body.get_string_from_utf8())
		if json is Array:
			_cached_top.assign(json)
			scores_loaded.emit(_cached_top)
		else:
			scores_loaded.emit(_local_top())
	else:
		scores_loaded.emit(_local_top())
	http.queue_free()


func submit(initials: String, score: int, depth: int) -> void:
	_local_save(initials, score, depth)
	var http := HTTPRequest.new()
	add_child(http)
	var payload := JSON.stringify({"initials": initials, "score": score, "depth": depth})
	http.request_completed.connect(_on_submit_done.bind(http))
	http.timeout = 5.0
	var err := http.request(GameState.API_BASE + "/scores",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST, payload)
	if err != OK:
		submit_done.emit(false)
		http.queue_free()


func _on_submit_done(_result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray, http: HTTPRequest) -> void:
	submit_done.emit(code == 201 or code == 200)
	http.queue_free()


func _local_top() -> Array:
	_load_local()
	return _cached_top


func _local_save(initials: String, score: int, depth: int) -> void:
	var entry: Dictionary = {"initials": initials, "score": score, "depth": depth}
	_cached_top.append(entry)
	_cached_top.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.score > b.score)
	if _cached_top.size() > 10: _cached_top.resize(10)
	_flush_local()


func _load_local() -> void:
	if OS.has_feature("web"):
		var raw: String = JavaScriptBridge.eval("localStorage.getItem('paydirt_scores')")
		if raw and raw != "null" and raw != "":
			var parsed: Variant = JSON.parse_string(raw)
			if parsed is Array: _cached_top.assign(parsed)
	else:
		var cfg := ConfigFile.new()
		if cfg.load("user://paydirt_scores.cfg") == OK:
			var data: Variant = cfg.get_value("scores", "entries", [])
			if data is Array: _cached_top.assign(data)


func _flush_local() -> void:
	if OS.has_feature("web"):
		var json_str: String = JSON.stringify(_cached_top)
		json_str = json_str.replace("\\", "\\\\").replace("'", "\\'")
		JavaScriptBridge.eval("localStorage.setItem('paydirt_scores', '%s')" % json_str)
	else:
		var cfg := ConfigFile.new()
		cfg.set_value("scores", "entries", _cached_top)
		cfg.save("user://paydirt_scores.cfg")
