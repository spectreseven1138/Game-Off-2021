extends Reference
class_name SimpleScriptPointer

var simplescript #: SimpleScript
var property_name: String

func _init(_simplescript, _property_name: String):
	simplescript = _simplescript
	property_name = _property_name

func get_class() -> String:
	return "Pointer"

#extends Reference
#class_name SimpleScriptValue

#enum TYPES {NONE, VALUE, FUNCTION_CALL, PROPERTY}
#var type: int = TYPES.NONE
#
#var data: Dictionary
#
#func assign_value(value) -> SimpleScriptValue:
#	type = TYPES.VALUE
#	data.clear()
#	data["value"] = value
#	return self
#
#func assign_property(script, property_name: String) -> SimpleScriptValue:
#	type = TYPES.PROPERTY
#	data.clear()
#	data["script"] = script # SimpleScript
#	data["property_name"] = property_name
#	return self
#
#func assign_function_call(function, args: Array) -> SimpleScriptValue:
#	type = TYPES.FUNCTION_CALL
#	data.clear()
#	data["function"] = function # SimpleScriptFunction
#	data["args"] = args
#	data["value"] = function.call_func(args)
#	return self
#
#func get_value():
#
#	match type:
#		TYPES.NONE:
#			push_error("SimpleScriptValue was asked for its value, but wasn't initialised")
#			return null
#		TYPES.VALUE, TYPES.FUNCTION_CALL:
#			return data["value"]
#		TYPES.PROPERTY:
#			return data["script"].global_properties[data["property_name"]]
