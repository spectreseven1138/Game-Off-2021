class_name SimpleScriptFunction
extends Reference

const BUILTIN_FUNCTIONS: Dictionary = {
	"print": {"method": "builtin_print", "args": null}, # null: no argument restrictions
	"sprint": {"method": "builtin_sprint", "args": null},
	"typeof": {"method": "builtin_typeof", "args": [{"type": null, "optional": false, "name": "what"}]},
	"int": {"method": "builtin_convert_to_int", "args": [{"type": null, "optional": false, "name": "what"}]}
}

var simplescript_class: GDScript = load("res://scripts/classes/SimpleScript.gd")
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
			elif func_args[i]["type"] != null and SimpleScriptValue.get_type(args[i].value) != func_args[i]["type"]:
				return simplescript.get_error("The value passed for argument '" + func_args[i]["name"] + "' is of type " + SimpleScriptType.get_as_string(SimpleScriptValue.get_type(args[i].value)) + ", but needs to be of type " + SimpleScriptType.get_as_string(func_args[i]["type"]))
		
		if len(args) > len(func_args):
			return simplescript.get_error(str(len(args)) + " were passed, but only " + str(len(func_args)) + " are needed")
	
	return SimpleScriptError.new(null, 0, 0, 0)

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
		var script = simplescript_class.new(code, stdout, funcref(self, "function_stderr"), name)
		script.global_properties = simplescript.global_properties.duplicate()
		Utils.append_dictionary(script.global_properties, kwargs)
		script.run()
		
		if script.function_returned:
			return script.function_return_value
		else:
			return yield(script, "function_returned")
		
func function_stderr(error: SimpleScriptError):
	error.line += line + 1
	error.position += Utils.get_position_of_line(simplescript.source_code, line + 1) + 1
	error.position_in_line += 1
	error.function = name
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

func builtin_convert_to_int(args: Array):
	pass

