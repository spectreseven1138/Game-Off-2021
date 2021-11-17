extends Reference
class_name SimpleScriptType

var type: int
func _init(_type: int):
	type = _type
	return self

func get_as_string():
	match type:
		TYPE_INT:
			return "int"
		TYPE_STRING:
			return "str"
		TYPE_ARRAY:
			return "array"
		TYPE_DICTIONARY:
			return "dict"
		_:
			push_error("Unhandled type: " + str(type))
			return "Unhandled type (" + str(type) + ")"
