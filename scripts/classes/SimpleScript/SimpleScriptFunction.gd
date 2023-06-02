class_name SimpleScriptFunction
extends Reference

const number_types: Array = [SimpleScriptType.TYPES.FLOAT, SimpleScriptType.TYPES.INT]

const BUILTIN_FUNCTIONS: Dictionary = {
	"print": {"method": "builtin_print", "args": null}, # null: no argument restrictions
	"sprint": {"method": "builtin_sprint", "args": null},
	"typeof": {"method": "builtin_typeof", "args": [{"types": [], "optional": false, "name": "what"}]},
	"range": {"method": "builtin_range", "args": [{"types": number_types, "optional": false, "name": "A"}, {"types": number_types, "optional": true, "name": "B"}, {"types": number_types, "optional": true, "name": "C"}]},
	"bool": {"method": "builtin_convert_to_bool", "args": [{"types": [], "optional": false, "name": "what"}]},
}

var simplescript_class: GDScript = load("res://scripts/classes/SimpleScript/SimpleScript.gd")
var simplescript: Reference #: SimpleScript

var builtin: bool = false
var name: String
var func_args: Array
var line: int
var stdout: FuncRef
var stderr: FuncRef
var arguments: Array

func _init(_stdout: FuncRef, _stderr: FuncRef, script: Reference):
	stdout = _stdout
	stderr = _stderr
	simplescript = script

func init_code(func_name: String, _func_args: Array, _line: int):
	name = func_name
	func_args = _func_args
	line = _line
	
	print("FUNC ARGS: ", func_args)
	
	# TODO: Validate source code and return error
	print("FUNCTION LINE: ", line)

func init_builtin(func_name: String) -> SimpleScriptFunction:
	builtin = true
	name = func_name
	func_args = BUILTIN_FUNCTIONS[name]["args"]
	return self

func validate_arguments(args: Array) -> SimpleScriptError:
	
	if func_args != null:
		for i in len(func_args):
			if i >= len(args):
				if not func_args[i]["optional"]:
					return simplescript.get_error("Required argument '" + func_args[i]["name"] + "' was not passed")
			elif not func_args[i]["types"].empty() and not SimpleScriptValue.get_type(args[i].value) in func_args[i]["types"]:
				var type_text: String
				if len(func_args[i]["types"]) == 1:
					type_text = "of type " + SimpleScriptType.get_as_string(func_args[i]["types"][0])
				else:
					type_text = "one of the following: "
					for type_i in len(func_args[i]["types"]):
						type_text += SimpleScriptType.get_as_string(func_args[i]["types"][type_i])
						if type_i + 1 < len(func_args[i]["types"]):
							type_text += ", "
				return simplescript.get_error("The value passed for argument '" + func_args[i]["name"] + "' is of type " + SimpleScriptType.get_as_string(SimpleScriptValue.get_type(args[i].value)) + ", but needs to be " + type_text)
		
		if len(args) > len(func_args):
			return simplescript.get_error(str(len(args)) + " were passed, but only " + str(len(func_args)) + " are needed")
	
	return SimpleScriptError.new(null, 0, 0, 0, null)

var function_simplescript
func call_func(args: Array):
	if builtin:
		var result = call(BUILTIN_FUNCTIONS[name]["method"], args)
		if result is SimpleScriptError:
			result.line += line
		return result
	else:
		var kwargs: Dictionary = {}
		for i in len(args):
			kwargs[func_args[i]["name"]] = args[i]
		
		var code: String = simplescript.get_code_block(line + 1)
		function_simplescript = simplescript_class.new(code, stdout, funcref(self, "function_stderr"), simplescript.tree, name)
		function_simplescript.global_properties = simplescript.global_properties.duplicate()
		Utils.append_dictionary(function_simplescript.global_properties, kwargs)
		function_simplescript.run()
		
		if function_simplescript.function_returned:
			return function_simplescript.function_return_value
		else:
			return yield(function_simplescript, "function_returned")
		
func function_stderr(error: SimpleScriptError):
	error.line += line + 1
	error.position += Utils.get_position_of_line(simplescript.source_code, line + 1) + 1
	error.position_in_line += 1
	error.simplescript = function_simplescript
	stderr.call_func(error)

func builtin_print(args: Array):
	var msg: String = ""
	for arg in args:
		msg += SimpleScriptValue.convert_to_type(arg.value, SimpleScriptType.TYPES.STR)
	print("BUILTIN PRINT: ", msg)
	stdout.call_func(msg)
	return null

func builtin_sprint(args: Array):
	var msg: String = ""
	for i in len(args):
		if i + 1 == len(args): # Last argument
			msg += SimpleScriptValue.convert_to_type(args[i].value, SimpleScriptType.TYPES.STR)
		else:
			msg += SimpleScriptValue.convert_to_type(args[i].value, SimpleScriptType.TYPES.STR) + " | "
	print("BUILTIN SPRINT: ", msg)
	stdout.call_func(msg)
	return null

func builtin_typeof(args: Array):
	return SimpleScriptValue.new(SimpleScriptType.new(SimpleScriptValue.get_type(args[0].value)))

static func builtin_convert_to_bool(args: Array):
	var arg: SimpleScriptValue = args[0]
	if arg.value is bool:
		return arg
	elif arg.value == null:
		return SimpleScriptValue.new(false)
	elif arg.value is int or arg.value is float:
		return SimpleScriptValue.new(arg.value != 0)
	else:
		return SimpleScriptValue.new(true)

func builtin_range(args: Array):
	var ret: Array = []
	
	match len(args):
		1: ret = range(args[0].value)
		2: ret = range(args[0].value, args[1].value)
		3: ret = range(args[0].value, args[1].value, args[2].value)
	
	for i in len(ret):
		ret[i] = SimpleScriptValue.new(ret[i])
	
	return SimpleScriptValue.new(ret)
