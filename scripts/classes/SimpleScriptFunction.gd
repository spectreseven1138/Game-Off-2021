class_name SimpleScriptFunction
extends Reference

const BUILTIN_FUNCTIONS: Dictionary = {
	"print": {"method": "builtin_print", "args": null} # null: no argument restrictions
}

var simplescript: GDScript = load("res://scripts/classes/SimpleScript.gd")

var builtin: bool = false
var name: String
var args: Array
var source_code: String
var stdout: FuncRef
var stderr: FuncRef

func _init(_stdout: FuncRef, _stderr: FuncRef):
	stdout = _stdout
	stderr = _stderr

func init_code(func_name: String, _args: Array, _source_code: String):
	name = func_name
	args = _args
	source_code = _source_code
	
	# TODO: Validate source code and return error
	print("FUNCTION SOURCE: ", source_code)

func init_builtin(func_name: String) -> SimpleScriptFunction:
	builtin = true
	name = func_name
	args = BUILTIN_FUNCTIONS[name]["args"]
	return self

func validate_arguments(args: Array):
	pass

func call_func(args: Array, line: int) -> SimpleScriptError:
	if builtin:
		var err: SimpleScriptError = call(BUILTIN_FUNCTIONS[name]["method"], args)
		err.line += line
		return err
	else:
		return SimpleScriptError.new(null, line, 0) # Temp

func builtin_print(args: Array):
	print(args)
	var msg: String = ""
	for arg in args:
		msg += str(arg)
	print("BUILTIN PRINT: ", msg)
	stdout.call_func(msg)
	return SimpleScriptError.new(null, 0, 0)
