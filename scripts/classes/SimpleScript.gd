class_name SimpleScript
extends Reference

const linebreak: String = "\n"
const string_char: String = '"'
const kw_function: String = "func"
const kw_return: String = "return"
const kw_pass: String = "pass"
const comment_string: String = "//"

var source_code: String
var stdout: FuncRef
var stderr: FuncRef

var functions: Dictionary = {}
var global_properties: Dictionary = {
	"null": {"value": null, "constant": true}, 
	"INF": {"value": INF, "constant": true},
	"NAN": {"value": NAN, "constant": true},
	"PI": {"value": PI, "constant": true},
	"TAU": {"value": TAU, "constant": true},
	"int": {"value": Type.new(TYPE_INT), "constant": true},
	"str": {"value": Type.new(TYPE_STRING), "constant": true},
	"array": {"value": Type.new(TYPE_ARRAY), "constant": true},
	"dict": {"value": Type.new(TYPE_DICTIONARY), "constant": true}
#	"int": {"value": SimpleScriptValue.new(self).init_value(Type.new(TYPE_INT)), "constant": true},
#	"str": {"value": SimpleScriptValue.new(self).init_value(Type.new(TYPE_STRING)), "constant": true},
#	"array": {"value": SimpleScriptValue.new(self).init_value(Type.new(TYPE_ARRAY)), "constant": true},
#	"dict": {"value": SimpleScriptValue.new(self).init_value(Type.new(TYPE_DICTIONARY)), "constant": true}
	}

var parser: SimpleScriptParser = SimpleScriptParser.new(self)

func _init(_source_code: String, _stdout: FuncRef, _stderr: FuncRef):
	source_code = _source_code
	stdout = _stdout
	stderr = _stderr
	
	functions = {
		"print": SimpleScriptFunction.new(stdout, stderr, self).init_builtin("print"),
		"sprint": SimpleScriptFunction.new(stdout, stderr, self).init_builtin("sprint"),
	}

func get_property(property_name: String):
	if property_name in global_properties:
		return global_properties[property_name]["value"]
	else:
		return null

signal resume
var paused: bool = false
var i: int = 0
var line: int = 0
var i_in_line: int = 0
var indent: int = 0
var c: String

func run():
	i = -1
	if not (yield(advance(), "completed") if paused else advance()):
		return
	while true:
		var properties: Dictionary = {}
		var result = get_value(false, properties)
		Utils.append_dictionary(global_properties, properties)
		if result is SimpleScriptError and not result.is_ok():
			stderr.call_func(result)
			return
		
		if not (yield(advance(), "completed") if paused else advance()):
			break

func execute_function(line: int, arguments: Dictionary):
	var properties: Dictionary = arguments
	go_to_line(line)
	print("C: ", c == "\n")
	var code: String = get_code_block()
	print("CODE: ", code)


func get_value(must_be_value: bool, properties: Dictionary, kw_endings: Array = []):
	var kw: String = ""
	var skip_advance: bool = false
	while true:
		
		if c in kw_endings:
			if kw in properties:
				return properties[kw]["value"]
			elif kw in global_properties:
				return global_properties[kw]["value"]
			else:
				return SimpleScriptError.new("Property '" + kw + "' does not exist", line, i_in_line)
		
		match c:
			"(": # Call function
				return call_function(kw)
			"=": # Assign
				
				if must_be_value:
					return SimpleScriptError.new("Unexpected assign", line, i_in_line)
				
				if not (yield(advance(), "completed") if paused else advance()):
					return
				
				if c == " ": # Skip if space
					if not (yield(advance(), "completed") if paused else advance()):
						return
				if c == " ":
					return SimpleScriptError.new("Unexpected space", line, i_in_line)
				
				# Can't assign is property already exists and is a constant
				if (kw in properties and properties[kw]["constant"]) or (kw in global_properties and global_properties[kw]["constant"]):
					return get_error("Cannot assign value to constant property '" + kw + "'")
				
				var value_to_assign = get_value(true, properties)
				if value_to_assign is GDScriptFunctionState:
					value_to_assign = yield(value_to_assign, "completed")
				if value_to_assign is SimpleScriptError:
					return value_to_assign
				
				properties[kw] = {"value": value_to_assign, "constant": false}
				print("Assigned property '" + kw + "' as ", value_to_assign)
				kw = ""
				
			string_char:
				var result = create_string()
				if result is SimpleScriptError:
					return result
				if not (yield(advance(), "completed") if paused else advance()):
					return
				return result
			" ":
				
				match kw:
					kw_function:
						if must_be_value:
							return SimpleScriptError.new("Unexpected function declaration", line, i_in_line)
						
						if not (yield(advance(), "completed") if paused else advance()):
							return SimpleScriptError.new("scipt ended unexpectedly", line, i_in_line)
						
						if c == " ":
							return SimpleScriptError.new("Unexpected space", line, i_in_line)
						
						var result = declare_function()
						if result is GDScriptFunctionState:
							yield(result, "completed")
						
						if not result.is_ok():
							return result
					_:
						if not (yield(advance(), "completed") if paused else advance()):
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
			if not (yield(advance(), "completed") if paused else advance()):
				return
	
	if kw in properties:
		return properties[kw]["value"]
	else:
		return SimpleScriptError.new("Property '" + kw + "' does not exist", line, i_in_line)

func go_to_line(target_line: int):
	i = 0
	line = 1
	i_in_line = 0
	indent = 0
	while true:
		c = source_code[i]
		if c == "\n":
			line += 1
		i += 1
		
		if i >= len(source_code):
			push_error("Script ended unexpectedly")
			return
		
		if line == target_line:
			c = source_code[i]
			
			while c == "	":
				print("ADD INDENT")
				indent += 1
				i += 1
				i_in_line += 1
				c = source_code[i]
			
			break

# Advances the current character (c) by 1. Handles indentation, linebreaks, and comments.
# Returns false if the script ended
func advance(ignore_linebreaks: bool = false) -> bool:
	if paused:
		yield(self, "resume")
	
	i += 1
	i_in_line += 1
	if i < len(source_code):
		c = source_code[i]
		
		var is_comment: bool = true
		for j in len(comment_string):
			if i + j >= len(source_code) or comment_string[j] != source_code[i + j]:
				is_comment = false
				break
		
		# Skip to next line if comment
		if is_comment:
			while true:
				i += 1
				if i >= len(source_code):
					return false
				c = source_code[i]
				if c == linebreak:
					line += 1
					i_in_line = 0
					
					# Set indent to indent of current line
					var indent_i: int = 1
					indent = 0
					while source_code[i + indent_i] == "	":
						indent += 1
						indent_i += 1
						
						if i + indent_i >= len(source_code):
							break
					break
		elif c == linebreak and not ignore_linebreaks:
			line += 1
			i_in_line = 0
			
			# Set indent to indent of current line
			var indent_i: int = 1
			indent = 0
			while source_code[i + indent_i] == "	":
				indent += 1
				indent_i += 1
				
				if i + indent_i >= len(source_code):
					break
		return true
	else:
		return false

func call_function(func_name: String):
	
	if not func_name in functions:
		return SimpleScriptError.new("The function '" + func_name + "' does not exist", line, i_in_line)
	
	if not (yield(advance(), "completed") if paused else advance()):
		return SimpleScriptError.new("scipt ended unexpectedly while calling function '" + func_name + "'", line, i_in_line)
	
	var args: Array = []
	
	while true:
		match c:
			")":
				break
			_:
				var value = get_value(true, {}, [",", ")"])
				if value is SimpleScriptError:
					return value
				args.append(value)
				
				if c == ")":
					break
				
				print("Got arg ", value)
		
		if not (yield(advance(), "completed") if paused else advance()):
			if c != ")":
				return SimpleScriptError.new("scipt ended unexpectedly while calling function '" + func_name + "'", line, i_in_line)
			else:
				break
	
	var function: SimpleScriptFunction = functions[func_name]
	
	var error: SimpleScriptError = function.validate_arguments(args)
	if not error.is_ok():
		return error
	
	return function.call_func(args)

func declare_function() -> SimpleScriptError:
	
	var script_end_error: String = "Script ended unexpectedly while declaring function"
	
	# Get function name
	var func_name: String = ""
	while true:
		
		if c == "(":
			break
		elif c == " ":
			if not (yield(advance(), "completed") if paused else advance()):
				return get_error(script_end_error)
			if c == " ":
				return get_error("Unexpected space while declaring function")
			if c != "(":
				return get_error("Expected '('")
			break
		else:
			func_name += c
		
		if not (yield(advance(), "completed") if paused else advance()):
			return get_error(script_end_error)
	
	if func_name in functions:
		return get_error("A function with name '" + func_name + "' already exists")
	
	# C is (, so advance
	if not (yield(advance(), "completed") if paused else advance()):
		return get_error(script_end_error)
	
	print("Declare function: ", func_name)
	
	var args: Array = []
	
	# Get arguments
	while true:
		
		while c == " ":
			if not (yield(advance(), "completed") if paused else advance()):
				return get_error(script_end_error)
		
		if c == ")":
			break
		
		var arg: Dictionary = {"name": "", "type": null, "optional": false}
		var skip_advance: bool = false
		while true:
			
			match c:
				")", ",": # End argument parsing
					args.append(arg)
					break
				":": # Get argument type
					
					if not (yield(advance(), "completed") if paused else advance()):
						return get_error(script_end_error)
					
					var result = get_value(true, {}, [",", ")"])
					if result is SimpleScriptError:
						return result
					
					elif not result is Type:
						return get_error("Unexpected value of type " + Type.new(typeof(result)).get_as_string() + " as argument type (must be a builtin type)")
					
					arg["type"] = result
					skip_advance = true
					
				"=": # Get default value
					pass
				_:
					if not c.is_valid_identifier():
						return get_error("Invalid character used in function argument name")
					
					arg["name"] += c
			
			if skip_advance:
				skip_advance = false
			elif not (yield(advance(), "completed") if paused else advance()):
				return get_error(script_end_error)
		
		if c == ")":
			break
		
		if not (yield(advance(), "completed") if paused else advance()):
			return get_error(script_end_error)
	
	if not (yield(advance(), "completed") if paused else advance()):
		return get_error(script_end_error)
	
	if c == ":":
		if not (yield(advance(), "completed") if paused else advance()):
			return get_error(script_end_error)
	
	if not (yield(advance(), "completed") if paused else advance()):
		return get_error(script_end_error)
	
	# Construct function object
	var function: SimpleScriptFunction = SimpleScriptFunction.new(stdout, stderr, self)
	function.init_code(func_name, args, line + 1)
	functions[func_name] = function
	
	return SimpleScriptError.new(null, line, i_in_line)

func create_string():
	if not (yield(advance(), "completed") if paused else advance()):
		return SimpleScriptError.new("", line, i_in_line)
	
	var string: String = ""
	while true:
		if c == string_char:
			break
		else:
			string += c
		
		if not (yield(advance(), "completed") if paused else advance()):
			return SimpleScriptError.new("", line, i_in_line)
	
	print("Created string: ", string)
	return string

func get_error(message: String) -> SimpleScriptError:
	return SimpleScriptError.new(message, line, i_in_line)

func get_code_block():
	
	var starting_indent: int = indent
	var ret: String = c
	
	while indent >= starting_indent:
		print(indent)
		if not advance(true):
			return ret
		
		ret += c

class Type:
	var type: int
	func _init(_type: int):
		type = _type
		return self
	
	func get_as_string():
		match type:
			TYPE_INT:
				return "int"
			TYPE_STRING:
				return "str"
			TYPE_ARRAY:
				return "array"
			TYPE_DICTIONARY:
				return "dict"
			_:
				push_error("Unhandled type: " + str(type))
				return "Unhandled type (" + str(type) + ")"
