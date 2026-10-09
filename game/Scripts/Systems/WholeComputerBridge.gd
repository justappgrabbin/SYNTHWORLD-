extends Node

const BASE_URL := "http://127.0.0.1:43121"
const BUILD_QUEUE := "user://build.json"
const POLL_SECONDS := 1.0

var _poll: HTTPRequest
var _ack: HTTPRequest
var _timer := 0.0

func _ready() -> void:
    _poll = HTTPRequest.new()
    _ack = HTTPRequest.new()
    add_child(_poll)
    add_child(_ack)
    _poll.request_completed.connect(_on_poll_completed)
    _send_ack({"event":"synthworld.bridge.ready"})

func _process(delta: float) -> void:
    _timer += delta
    if _timer < POLL_SECONDS:
        return
    _timer = 0.0
    if _poll.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
        _poll.request(BASE_URL + "/api/world/next")

func _on_poll_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    if response_code != 200:
        return
    var decoded = JSON.parse_string(body.get_string_from_utf8())
    if typeof(decoded) != TYPE_DICTIONARY:
        return
    var command = decoded.get("command")
    if typeof(command) != TYPE_DICTIONARY:
        _send_ack({"event":"synthworld.heartbeat"})
        return
    var kind := String(command.get("kind", ""))
    var payload = command.get("payload", {})
    var applied := false
    if kind == "build-order" and typeof(payload) == TYPE_DICTIONARY:
        var order = payload.get("order", payload)
        if typeof(order) == TYPE_DICTIONARY:
            applied = _append_build_order(order)
    elif kind == "sentence" and typeof(payload) == TYPE_DICTIONARY:
        applied = _execute_sentence(String(payload.get("sentence", "")))
    _send_ack({"event":"synthworld.command", "commandId":command.get("id"), "kind":kind, "applied":applied})

func _append_build_order(order: Dictionary) -> bool:
    var arr: Array = []
    if FileAccess.file_exists(BUILD_QUEUE):
        var current = JSON.parse_string(FileAccess.get_file_as_string(BUILD_QUEUE))
        if typeof(current) == TYPE_ARRAY:
            arr = current
    arr.append(order)
    var f := FileAccess.open(BUILD_QUEUE, FileAccess.WRITE)
    if not f:
        return false
    f.store_string(JSON.stringify(arr, "  "))
    f.close()
    return true

func _execute_sentence(sentence: String) -> bool:
    if sentence.strip_edges().is_empty():
        return false
    var parsed := SentenceParser.parse_line(sentence)
    if not parsed.ok:
        return false
    var world := get_tree().current_scene
    if not world or not world.has_method("place_tree") or not world.has_method("set_world_state"):
        return false
    return SentenceExecutor.execute(parsed.ast, world)

func _send_ack(payload: Dictionary) -> void:
    if _ack.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
        return
    var headers := PackedStringArray(["Content-Type: application/json"])
    _ack.request(BASE_URL + "/api/world/ack", headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
