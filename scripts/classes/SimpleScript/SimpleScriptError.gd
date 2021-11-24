class_name SimpleScriptError
extends Reference

var msg: String
var line: int
var position: int
var position_in_line: int
var simplescript: Reference # SimpleScript


func _init(_msg: String, _line: int, _position: int, _position_in_line: int, _simplescript: Reference):
	msg = _msg
	line = _line
	position = _position
	position_in_line = _position_in_line
	simplescript = _simplescript
	
	if not is_ok() and SSEngine.halt_editor_on_error:
		pass # Trigger breakpoint

func get_message() -> String:
	var ret: String = "Error occurred on line " + str(line + 1)
	if simplescript.function != null:
		ret += " in function '" + simplescript.function + "'"
	ret += ": " + msg
	return ret 

func is_ok() -> bool:
	return msg == null
