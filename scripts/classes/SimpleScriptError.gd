class_name SimpleScriptError
extends Reference

var msg: String
var line: int
var position: int
var position_in_line: int
var function: String

func _init(_msg: String, _line: int, _position: int, _position_in_line: int, _function: String = null):
	msg = _msg
	line = _line
	position = _position
	position_in_line = _position_in_line
	function = _function

func get_message() -> String:
	var ret: String = "Error occurred on line " + str(line + 1)
	if function != null:
		ret += " in function '" + function + "'"
	ret += ": " + msg
	return ret 

func is_ok() -> bool:
	return msg == null
