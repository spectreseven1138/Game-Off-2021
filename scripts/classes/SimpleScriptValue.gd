extends Reference
class_name SimpleScriptValue

enum TYPES {NONE, PROPERTY, FUNCTION, VALUE}
var type: int = TYPES.NONE

var simplescript
var data: Dictionary

func _init(script):
	simplescript = script

func init_property(property_name: String) -> SimpleScriptValue:
	type = TYPES.PROPERTY
	data = {
		"property_name": property_name
	}
	return self


func init_value(value) -> SimpleScriptValue:
	type = TYPES.VALUE
	data = {
		"value": value
	}
	return self

func init_function(name: String, args: Array) -> SimpleScriptValue:
	type = TYPES.FUNCTION
	data = {
		"name": name,
		"args": args
	}
	return self

func get_value():
	
	match type:
		TYPES.NONE:
			push_error("SimpleScriptValue was asked for a value, but wasn't initialised")
			return null
		TYPES.PROPERTY:
			return simplescript.get_property(data["property_name"])
		TYPES.VALUE:
			return data["value"]
		TYPES.FUNCTION:
			# TODO
			return
