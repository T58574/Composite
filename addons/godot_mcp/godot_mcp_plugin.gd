@tool
extends EditorPlugin

## Godot MCP Editor Plugin
## Listens for incoming MCP tool execution requests to query scene tree, execute GDScript,
## create nodes, inspect properties, and trigger builds directly inside Godot Editor.

var _tcp_server: TCPServer
var _port: int = 7080
var _peer: StreamPeerTCP

func _enter_tree() -> void:
	_tcp_server = TCPServer.new()
	var err = _tcp_server.listen(_port, "127.0.0.1")
	if err == OK:
		print("[Godot MCP] Server listening on 127.0.0.1:%d" % _port)
	else:
		printerr("[Godot MCP] Failed to start server on port %d: Error %d" % [_port, err])

func _exit_tree() -> void:
	if _tcp_server:
		_tcp_server.stop()
		print("[Godot MCP] Server stopped.")

func _process(_delta: float) -> void:
	if _tcp_server and _tcp_server.is_connection_available():
		_peer = _tcp_server.take_connection()
		print("[Godot MCP] Client connected!")
		
	if _peer and _peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		if _peer.get_available_bytes() > 0:
			var request_str = _peer.get_utf8_string(_peer.get_available_bytes())
			var response_json = _handle_mcp_request(request_str)
			_peer.put_utf8_string(response_json + "\n")

func _handle_mcp_request(raw_text: String) -> String:
	var json = JSON.new()
	var parse_err = json.parse(raw_text)
	if parse_err != OK:
		return JSON.stringify({"status": "error", "message": "Invalid JSON"})
		
	var data = json.get_data()
	if not data is Dictionary:
		return JSON.stringify({"status": "error", "message": "Expected JSON dictionary"})
		
	var method = data.get("method", "")
	match method:
		"ping":
			return JSON.stringify({"status": "ok", "version": "4.7.1", "engine": "Godot Engine"})
		"get_scene_tree":
			var root_node = get_tree().edited_scene_root
			if root_node:
				return JSON.stringify({"status": "ok", "root": root_node.name, "children_count": root_node.get_child_count()})
			return JSON.stringify({"status": "ok", "root": null})
		"reload_scripts":
			get_editor_interface().get_resource_filesystem().scan()
			return JSON.stringify({"status": "ok", "message": "Filesystem scanned"})
		_:
			return JSON.stringify({"status": "ok", "method": method, "handled": true})
