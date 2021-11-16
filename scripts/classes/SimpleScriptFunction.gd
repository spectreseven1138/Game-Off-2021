class_name SimpleScriptFunction
extends Reference

const BUILTIN_FUNCTIONS: Dictionary = {
	"print": {"method": "builtin_print", "args": null}, # null: no argument restrictions
	"sprint": {"method": "builtin_sprint", "args": null}
}

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
			if i >= len(args) and not func_args[i]["optional"]:
				return simplescript.get_error("Required argument '" + func_args[i]["name"] + "' was not passed")
			elif func_args[i]["type"] != null and typeof(args[i]) != func_args[i]["type"].type:
				return simplescript.get_error("The value passed for argument '" + func_args[i]["name"] + "' is of type " + simplescript.Type.new(typeof(args[i])).get_as_string() + ", but needs to be of type " + func_args[i]["type"].get_as_string())
		
		if len(args) > len(func_args):
			return simplescript.get_error(str(len(args)) + " were passed, but only " + str(len(func_args)) + " are needed")
	
	return SimpleScriptError.new(null, 0, 0)

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
		print("KWARGS: ", kwargs)
		return simplescript.execute_function(line, kwargs)

func builtin_print(args: Array):
	var msg: String = ""
	for arg in args:
		msg += str(arg)
	print("BUILTIN PRINT: ", msg)
	stdout.call_func(msg)
	return null

func builtin_sprint(args: Array):
	var msg: String = ""
	for i in len(args):
		if i + 1 == len(args): # Last argument
			msg += str(args[i])
		else:
			msg += str(args[i]) + " | "
	print("BUILTIN SPRINT: ", msg)
	stdout.call_func(msg)
	return null
