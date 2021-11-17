extends Reference
class_name SimpleScriptType

enum TYPES {NULL, INT, FLOAT, STR, ARRAY, DICT, BOOL, POINTER, SCRIPT, TYPE}
var type: int
func _init(_type: int):
	type = _type
	return self

static func get_as_string(type: int):
	match type:
		TYPES.NULL:
			return "null"
		TYPES.INT:
			return "int"
		TYPES.FLOAT:
			return "float"
		TYPES.STR:
			return "str"
		TYPES.ARRAY:
			return "array"
		TYPES.DICT:
			return "dict"
		TYPES.POINTER:
			return "pointer"
		TYPES.SCRIPT:
			return "script"
		TYPES.TYPE:
			return "type"
		_:
			push_error("Unhandled type: " + str(type))
			return "Unhandled type (" + str(type) + ")"

func get_class():
	return "Type"
