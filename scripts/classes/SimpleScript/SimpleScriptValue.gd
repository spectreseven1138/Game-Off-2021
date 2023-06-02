extends Reference
class_name SimpleScriptValue

var value
var type: int
var constant: bool = false

func _init(_value):
	value = _value
	type = get_type(value)

# -- Indices / keys --

func can_get_index() -> bool:
	return type in [SimpleScriptType.TYPES.STR, SimpleScriptType.TYPES.ARRAY, SimpleScriptType.TYPES.DICT]

func is_index_type_valid(index):
	match type:
		SimpleScriptType.TYPES.ARRAY, SimpleScriptType.TYPES.STR:
			return index is int
		SimpleScriptType.TYPES.DICT:
			return true

func is_index_value_valid(index):
	match type:
		SimpleScriptType.TYPES.ARRAY, SimpleScriptType.TYPES.STR:
			if index < 0:
				index += 1
			return abs(index) < len(value)
		SimpleScriptType.TYPES.DICT:
			return index in value

# Index can be an index (int) or key (String)
func get_index_value(index):
	return value[index]

# -------------------

# -- ITERATION --

var iter_i: int = -1

func can_iterate() -> bool:
	return type in [SimpleScriptType.TYPES.STR, SimpleScriptType.TYPES.INT, SimpleScriptType.TYPES.ARRAY, SimpleScriptType.TYPES.DICT]

func iterate(): # Returns raw value
	assert(can_iterate())
	
	iter_i += 1
	
	match type:
		SimpleScriptType.TYPES.STR, SimpleScriptType.TYPES.ARRAY:
			return value[iter_i]
		SimpleScriptType.TYPES.DICT:
			return value.keys()[iter_i]
		SimpleScriptType.TYPES.INT, SimpleScriptType.TYPES.FLOAT:
			return iter_i

func end_iteration():
	iter_i = -1

func is_last_iteration() -> bool:
	match type:
		SimpleScriptType.TYPES.STR, SimpleScriptType.TYPES.ARRAY, SimpleScriptType.TYPES.DICT:
			return iter_i + 1 == len(value)
		SimpleScriptType.TYPES.INT, SimpleScriptType.TYPES.FLOAT:
			return iter_i + 1 == int(value)
	return false

# ---------------


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
			elif value is Array:
				var ret: String = "["
				
				for i in len(value):
					ret += convert_to_type(value[i], SimpleScriptType.TYPES.STR)
					if i + 1 < len(value):
						ret += ", "
				
				return ret + "]"
				
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
						return SimpleScriptError.new(cannot_convert_error, 0, 0, 0, null)
		SimpleScriptType.TYPES.BOOL:
			if value is bool:
				return value
			elif value == null:
				return false
			elif value is int or value is float:
				return value != 0
			else:
				return true

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
