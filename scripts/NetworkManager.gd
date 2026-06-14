class_name NetworkManager
extends Node

signal status_changed(status: String)
signal room_code_changed(room_code: String)
signal online_session_started(is_host: bool, local_player_id: int)
signal game_message_received(message: Dictionary)

@export var signaling_url := "ws://127.0.0.1:8787"
@export var stun_url := "stun:stun.l.google.com:19302"

var is_online := false
var is_host := false
var local_player_id := 1
var room_code := ""

var _websocket := WebSocketPeer.new()
var _webrtc: WebRTCPeerConnection
var _channel: WebRTCDataChannel
var _pending_action := ""
var _pending_room_code := ""
var _websocket_open := false
var _channel_open := false
var _using_signaling_relay := false


func _process(_delta: float) -> void:
	_poll_signaling()
	_poll_webrtc()


func create_room() -> void:
	_start_signaling("create_room", "")


func join_room(code: String) -> void:
	_start_signaling("join_room", code.strip_edges().to_upper())


func leave_online_session() -> void:
	if _websocket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_send_signaling({"type": "leave"})
	_reset_network_state()
	status_changed.emit("已切回本地模式")


func send_game_message(message: Dictionary) -> bool:
	if _channel != null and _channel.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
		_channel.put_packet(JSON.stringify(message).to_utf8_buffer())
		return true

	if is_online and _websocket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_using_signaling_relay = true
		_send_signaling({
			"type": "game",
			"payload": message,
		})
		return true

	if _channel == null:
		status_changed.emit("P2P 未连接，且信令中继不可用")
		return false
	status_changed.emit("P2P 未连接，无法发送棋局消息")
	return false


func _start_signaling(action: String, target_room_code: String) -> void:
	_reset_network_state()
	_pending_action = action
	_pending_room_code = target_room_code

	var err := _websocket.connect_to_url(signaling_url)
	if err != OK:
		status_changed.emit("无法连接信令服务：%d" % err)
		return

	status_changed.emit("正在连接信令服务...")


func _poll_signaling() -> void:
	_websocket.poll()
	var state := _websocket.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN and not _websocket_open:
		_websocket_open = true
		_send_pending_signaling_action()

	if state == WebSocketPeer.STATE_CLOSED and _websocket_open:
		_websocket_open = false
		if is_online:
			status_changed.emit("信令服务连接已断开")

	while _websocket.get_available_packet_count() > 0:
		var text := _websocket.get_packet().get_string_from_utf8()
		var payload = JSON.parse_string(text)
		if payload is Dictionary:
			_handle_signaling_message(payload)
		else:
			status_changed.emit("收到无法解析的信令消息")


func _poll_webrtc() -> void:
	if _webrtc != null:
		_webrtc.poll()

	if _channel == null:
		return

	_channel.poll()
	if _channel.get_ready_state() == WebRTCDataChannel.STATE_OPEN and not _channel_open:
		_channel_open = true
		status_changed.emit("P2P 已连接，联机对战就绪")

	while _channel.get_available_packet_count() > 0:
		var text := _channel.get_packet().get_string_from_utf8()
		var payload = JSON.parse_string(text)
		if payload is Dictionary:
			game_message_received.emit(payload)
		else:
			status_changed.emit("收到无法解析的棋局消息")


func _send_pending_signaling_action() -> void:
	if _pending_action == "create_room":
		_send_signaling({"type": "create_room"})
		status_changed.emit("正在创建房间...")
	elif _pending_action == "join_room":
		if _pending_room_code.is_empty():
			status_changed.emit("请输入房间码")
			return
		_send_signaling({
			"type": "join_room",
			"room_code": _pending_room_code,
		})
		status_changed.emit("正在加入房间 %s..." % _pending_room_code)


func _handle_signaling_message(message: Dictionary) -> void:
	var type := String(message.get("type", ""))

	match type:
		"room_created":
			is_online = true
			is_host = true
			local_player_id = 1
			room_code = String(message.get("room_code", ""))
			room_code_changed.emit(room_code)
			online_session_started.emit(is_host, local_player_id)
			status_changed.emit("房间已创建，等待对手加入：%s" % room_code)
		"joined_room":
			is_online = true
			is_host = false
			local_player_id = 2
			room_code = String(message.get("room_code", ""))
			room_code_changed.emit(room_code)
			online_session_started.emit(is_host, local_player_id)
			_setup_webrtc(false)
			status_changed.emit("已加入房间：%s" % room_code)
		"peer_joined":
			if not is_host:
				return
			_setup_webrtc(true)
			if _webrtc != null:
				_webrtc.create_offer()
				status_changed.emit("对手已加入，正在建立 P2P 连接...")
			else:
				status_changed.emit("对手已加入，使用信令中继模式")
		"offer":
			_setup_webrtc(false)
			_webrtc.set_remote_description(String(message.get("sdp_type", "offer")), String(message.get("sdp", "")))
			_webrtc.create_answer()
		"answer":
			if _webrtc != null:
				_webrtc.set_remote_description(String(message.get("sdp_type", "answer")), String(message.get("sdp", "")))
		"ice":
			if _webrtc != null:
				_webrtc.add_ice_candidate(
					String(message.get("media", "")),
					int(message.get("index", 0)),
					String(message.get("name", ""))
				)
		"game":
			var payload: Variant = message.get("payload", {})
			if payload is Dictionary:
				game_message_received.emit(payload)
			else:
				status_changed.emit("收到无法解析的中继棋局消息")
		"peer_left":
			status_changed.emit("对手已离开")
		"error":
			status_changed.emit("联机错误：%s" % String(message.get("message", "")))
		_:
			status_changed.emit("未知信令消息：%s" % type)


func _setup_webrtc(make_offer: bool) -> void:
	if _webrtc != null:
		return

	_webrtc = WebRTCPeerConnection.new()
	_webrtc.session_description_created.connect(_on_session_description_created)
	_webrtc.ice_candidate_created.connect(_on_ice_candidate_created)

	var config := {
		"iceServers": [
			{"urls": [stun_url]},
		],
	}
	var err := _webrtc.initialize(config)
	if err != OK:
		status_changed.emit("WebRTC 初始化失败：%d" % err)
		return

	_channel = _webrtc.create_data_channel("game", {
		"negotiated": true,
		"id": 1,
	})
	_channel_open = false
	if _channel == null:
		_using_signaling_relay = true
		status_changed.emit("WebRTC 数据通道不可用，暂用信令中继模式")
		_webrtc = null
		return

	if make_offer:
		status_changed.emit("正在创建 P2P offer...")


func _on_session_description_created(sdp_type: String, sdp: String) -> void:
	if _webrtc == null:
		return
	_webrtc.set_local_description(sdp_type, sdp)
	_send_signaling({
		"type": sdp_type,
		"sdp_type": sdp_type,
		"sdp": sdp,
	})


func _on_ice_candidate_created(media: String, index: int, name: String) -> void:
	_send_signaling({
		"type": "ice",
		"media": media,
		"index": index,
		"name": name,
	})


func _send_signaling(payload: Dictionary) -> void:
	if _websocket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		status_changed.emit("信令服务未连接")
		return
	_websocket.send_text(JSON.stringify(payload))


func _reset_network_state() -> void:
	if _channel != null:
		_channel.close()
	if _webrtc != null:
		_webrtc.close()
	if _websocket.get_ready_state() == WebSocketPeer.STATE_OPEN or _websocket.get_ready_state() == WebSocketPeer.STATE_CONNECTING:
		_websocket.close()

	_websocket = WebSocketPeer.new()
	_webrtc = null
	_channel = null
	_pending_action = ""
	_pending_room_code = ""
	_websocket_open = false
	_channel_open = false
	_using_signaling_relay = false
	is_online = false
	is_host = false
	local_player_id = 1
	room_code = ""
	room_code_changed.emit("")
