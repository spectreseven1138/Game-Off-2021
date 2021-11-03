class_name SimpleScipt
extends Reference

const linebreak: String = "\n"
const string_char: String = '"'

var source_code: String
var stdout: FuncRef
var stderr: FuncRef

var functions: Dictionary = {}
var properties: Dictionary = {"null": null, "INF": INF, "NAN": NAN, "PI": PI, "TAU": TAU}

func _init(_source_code: String, _stdout: FuncRef = null, _stderr: FuncRef = null):
	source_code = _source_code
	stdout = _stdout
	stderr = _stderr
	
	functions = {
		"print": SimpleScriptFunction.new(stdout, stderr).init_builtin("print")
	}

func validate_source_code():
	pass

var i: int = 0
var line: int = 0
var i_in_line: int = 0
var c: String
func run():
	i = -1
	if not advance():
		return
	while true:
		
		var result = get_value(false)
		if result is SimpleScriptError and not result.is_ok():
			stderr.call_func(result)
			return
		
		if not advance():
			break

func get_value(must_be_value: bool, kw_endings: Array = []):
	var kw: String = ""
	var skip_advance: bool = false
	while true:
		
		if c in kw_endings:
			if kw in properties:
				return properties[kw]
			else:
				return SimpleScriptError.new("Property '" + kw + "' does not exist", line, i_in_line)
		
		match c:
			"(": # Call function
				var err: SimpleScriptError = call_function(kw)
				if not err.is_ok():
					return err
				kw = ""
			"=": # Assign
				
				if must_be_value:
					return SimpleScriptError.new("Unexpected assign", line, i_in_line)
				
				if not advance():
					return
				
				if c == " ": # Skip if space
					if not advance():
						return
				if c == " ":
					return SimpleScriptError.new("Unexpected space", line, i_in_line)
				
				var value_to_assign = get_value(true)
				if value_to_assign is SimpleScriptError:
					return value_to_assign
				
				properties[kw] = value_to_assign
				print("Assigned property '" + kw + "' as ", value_to_assign)
				kw = ""
				
			string_char:
				var value = create_string()
				if not value[0].is_ok():
					return value[0]
				if not advance():
					return
				return value[1]
			" ":
				if not advance():
					return
				
				if c == " ":
					return SimpleScriptError.new("Unexpected space", line, i_in_line)
				else:
					skip_advance = true
				
			_:
				if c == linebreak:
					kw = ""
				else:
					kw += c
		
		if skip_advance:
			skip_advance = false
		else:
			if not advance():
				return
	
	if kw in properties:
		return properties[kw]
	else:
		return SimpleScriptError.new("Property '" + kw + "' does not exist", line, i_in_line)


func advance() -> bool:
	i += 1
	i_in_line += 1
	if i < len(source_code):
		c = source_code[i]
		
		if c == linebreak:
			line += 1
			i_in_line = 0
		
		return true
	else:
		return false

func call_function(func_name: String) -> SimpleScriptError:
	
	if not func_name in functions:
		return SimpleScriptError.new("The function '" + func_name + "' does not exist", line, i_in_line)
	
	if not advance():
		return SimpleScriptError.new("Scipt ended unexpectedly while calling function '" + func_name + "'", line, i_in_line)
	
	var args: Array = []
	
	while true:
		
		match c:
			")":
				break
			_:
				var value = get_value(true, [",", ")"])
				if value is SimpleScriptError:
					return value
				args.append(value)
		
		if not advance():
			if c != ")":
				return SimpleScriptError.new("Scipt ended unexpectedly while calling function '" + func_name + "'", line, i_in_line)
			else:
				break
	
	print(func_name, " | ", args)
	var function: SimpleScriptFunction = functions[func_name]
	function.call_func(args, i)
	return SimpleScriptError.new(null, line, i_in_line)

func create_string() -> Array:
	if not advance():
		return [SimpleScriptError.new("", line, i_in_line)]
	
	var string: String = ""
	while true:
		if c == string_char:
			break
		else:
			string += c
		
		if not advance():
			return [SimpleScriptError.new("", line, i_in_line)]
	
	print("Created string: ", string)
	return [SimpleScriptError.new(null, line, i_in_line), string]
