extends Node

signal stdout(msg)
signal stderr(error)

var simplescript: GDScript = load("res://scripts/classes/SimpleScript/SimpleScript.gd")
const scripts_dir: String = "res://temp/scripts/"
var halt_editor_on_error: bool = true

var stdout: FuncRef = funcref(self, "stdout")
var stderr: FuncRef = funcref(self, "stderr")

func get_simplescript(script_name: String): # -> SimpleScript or String (error)
	
	var file: File = File.new()
	var path: String = scripts_dir.plus_file(script_name)
	
	if not file.file_exists(path):
		return "File '" + path + "' doesn't exist"
	
	var error: int = file.open(path, File.READ)
	if error != OK:
		assert(false, "Unhandled error")
	
	return simplescript.new(file.get_as_text(), stdout, stderr, get_tree())

func stdout(msg: String):
	emit_signal("stdout", msg)

func stderr(error: SimpleScriptError):
	emit_signal("stderr", error)
