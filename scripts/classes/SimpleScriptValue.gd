extends Reference
class_name SimpleScriptValue

var value

func _init(_value):
	value = _value

static func convert_to_type(value, type: int):
	
	var cannot_convert_error: String = "Cannot convert from " + SimpleScriptType.get_as_string(get_type(value)) + "to " + SimpleScriptType.get_as_string(type)
	
	match type:
		SimpleScriptType.TYPES.STR:
			if value is Object:
				match value.get_class().to_lower():
					"type":
						return "Builtin type: " + SimpleScriptType.get_as_string(value.type)
					_:
						return "[" + value.get_class() + ":" + str(value.get_instance_id()) + "]"
			else:
				return str(value)
		SimpleScriptType.TYPES.INT:
			match get_type(value):
				SimpleScriptType.TYPES.INT, SimpleScriptType.TYPES.FLOAT:
					return int(value)
				SimpleScriptType.TYPES.STR:
					if value.is_valid_integer():
						return int(value)
					else:
						return SimpleScriptError.new(cannot_convert_error, 0, 0, 0)

static func get_type(of):
	match typeof(of):
		TYPE_NIL:
			return SimpleScriptType.TYPES.NULL
		TYPE_INT:
			return SimpleScriptType.TYPES.INT
		TYPE_REAL:
			return SimpleScriptType.TYPES.FLOAT
		TYPE_STRING:
			return SimpleScriptType.TYPES.STR
		TYPE_BOOL:
			return SimpleScriptType.TYPES.BOOL
		TYPE_ARRAY:
			return SimpleScriptType.TYPES.ARRAY
		TYPE_DICTIONARY:
			return SimpleScriptType.TYPES.DICT
		TYPE_OBJECT:
			match of.get_class():
				"Pointer":
					return SimpleScriptType.TYPES.POINTER
				"Script":
					return SimpleScriptType.TYPES.SCRIPT
				"Type":
					return SimpleScriptType.TYPES.TYPE
				_:
					assert(false, "Unhandled type: " + of.get_class())
		_:
			assert(false, "Unhandled type: " + str(typeof(of)))
	
	return SimpleScriptType.TYPES.NULL
