extends Node


var tcp_server : TCPServer = TCPServer.new()
var tcp_connection : StreamPeerTCP = null
var tcp_connected : bool = false
var tcp_data : Array = []
var tcp_string : String = ""
var shot_data : Dictionary

var resp_200 := {"Code" : 200}
var resp_201 := {"Code": 201, "Message": "OSG Player Information"}
var resp_50x := {"Code": 501, "Message": "Failure Occured"}

signal hit_ball(data:Dictionary)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	tcp_server.listen(49152)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	# TCP Server
	if not tcp_connected:
		tcp_connection = tcp_server.take_connection()
		if tcp_connection:
			print("We have a tcp connection at " + tcp_connection.get_connected_host())
			tcp_connected = true
	else: # read from the connection
		tcp_connection.poll()
		var tcp_status : StreamPeerTCP.Status = tcp_connection.get_status()
		if tcp_status == StreamPeerTCP.STATUS_NONE: #disconnected
			tcp_connected = false
			print("tcp disconnected")
		elif tcp_status == StreamPeerTCP.STATUS_CONNECTED:
			var bytes_avail := 0
			tcp_data = []
			bytes_avail = tcp_connection.get_available_bytes()
			if bytes_avail > 0:
				tcp_data = tcp_connection.get_data(bytes_avail)
			if tcp_data:
				tcp_string = ""
				for byte in tcp_data[1]:
					tcp_string += char(byte)
				
				var json := JSON.new()
				var error := json.parse(tcp_string)
				if error == OK:
					shot_data = json.data
					if shot_data["ShotDataOptions"]["ContainsBallData"]:
						emit_signal("hit_ball", shot_data["BallData"])
				else:
					respond_error(501, "Bad JSON data")


func respond_error(code: int, message: String) -> void:
	tcp_connection.poll()
	var tcp_status : StreamPeerTCP.Status = tcp_connection.get_status()
	if tcp_status == StreamPeerTCP.STATUS_NONE: #disconnected
		tcp_connected = false
	elif tcp_status == StreamPeerTCP.STATUS_CONNECTED:
		resp_50x["Code"] = code
		resp_50x["Message"] = message
		tcp_connection.put_data(JSON.stringify(resp_50x).to_ascii_buffer())

func _on_golf_ball_good_data() -> void:
	tcp_connection.poll()
	var tcp_status : StreamPeerTCP.Status = tcp_connection.get_status()
	if tcp_status == StreamPeerTCP.STATUS_NONE: #disconnected
		tcp_connected = false
	elif tcp_status == StreamPeerTCP.STATUS_CONNECTED:
		tcp_connection.put_data(JSON.stringify(resp_200).to_ascii_buffer())


func _on_player_bad_data() -> void:
	pass # Replace with function body.
