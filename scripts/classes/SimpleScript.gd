class_name SimpleScript
extends Reference

signal function_returned(value)

const linebreak: String = "\n"
const string_char: String = '"'
const kw_function: String = "func"
const kw_return: String = "return"
const kw_pass: String = "pass"
const kw_pointer: String = "pointer"
const comment_string: String = "//"

const highlight_keywords: Array = [
	kw_function, kw_return, kw_pass, kw_pointer
]

var source_code: String
var source_code_lines: Array
var function: String = null
var function_returned: bool = false
var function_return_value
var stdout: FuncRef
var stderr: FuncRef

const BUILTIN_PROPERTIES: Array = ["null", "PI", "TAU", "INF", "NAN", "int", "str", "array", "dict"]
var functions: Dictionary = {}
var global_properties: Dictionary = {}

var parser: SimpleScriptParser = SimpleScriptParser.new(self)

func _init(_source_code: String, _stdout: FuncRef, _stderr: FuncRef, function_name: String = null):
	source_code = _source_code
	source_code_lines = source_code.split("\n")
	stdout = _stdout
	stderr = _stderr
	function = function_name
	
	for func_name in SimpleScriptFunction.BUILTIN_FUNCTIONS:
		functions[func_name] = SimpleScriptFunction.new(stdout, stderr, self).init_builtin(func_name)
	
	for type in SimpleScriptType.TYPES.values():
		global_properties[SimpleScriptType.get_as_string(type)] = SimpleScriptValue.new(SimpleScriptType.new(type))
	
	for property in ["null", "PI", "TAU", "INF", "NAN"]:
		global_properties[property] = SimpleScriptValue.new(get(property))

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
	
	function_returned = false
	
	i = -1
	if not (yield(advance(), "completed") if paused else advance()):
		return
	while true:
		var properties: Dictionary = {}
		var returnobject: GVReturnObject = get_value(false, properties)
		
		# get_value() returned an error, so display iy
		if returnobject.value is SimpleScriptError and not returnobject.value.is_ok():
			stderr.call_func(returnobject.value)
		
		# A value was returned during get_value(), so stop execution
		if function_return_value != null:
			return
		
		# Add properties created during get_value() to the global_properties list
		Utils.append_dictionary(global_properties, properties)
		
		if not (yield(advance(), "completed") if paused else advance()):
			break
	
	# If this is a function and no value was returned in code, return null
	if function != null and not function_returned:
		emit_signal("function_returned", null)

# Object returned by get_value() containing metadata
class GVReturnObject:
	extends Reference
	
	var value
	enum SOURCE_TYPES {ERROR, VALUE, PROPERTY, FUNCTION}
	var source_type: int
	var data: Dictionary = {}
	
	func _init(_value, _source_type: int = null, property_name: String = null):
		value = _value
		
		if _source_type == null:
			if value is SimpleScriptError:
				source_type = SOURCE_TYPES.ERROR
			else:
				push_error("Cannot infer source type")
				assert(false, "Cannot infer source type")
		else:
			source_type = _source_type
			
			if source_type == SOURCE_TYPES.PROPERTY:
				assert(property_name != null, "The property type requires the property name")
				data["property_name"] = property_name
			

func get_value(must_be_value: bool, properties: Dictionary, kw_endings: Array = []) -> GVReturnObject:
	var kw: String = ""
	var skip_advance: bool = false
	var script_ended_error: String = "Script ended unexpectedly"
	while true:
		
		match c:
			"(": # Call function
				return GVReturnObject.new(call_function(kw, properties), GVReturnObject.SOURCE_TYPES.FUNCTION)
			"=": # Assign
				
				# Can't assign if a value is required
				if must_be_value:
					return GVReturnObject.new(get_error("Unexpected assign"))
				
				if not (yield(advance(), "completed") if paused else advance()):
					return GVReturnObject.new(get_error(script_ended_error))
				
				# Skip if space
				if c == " ":
					if not (yield(advance(), "completed") if paused else advance()):
						return GVReturnObject.new(get_error(script_ended_error))
				if c == " ":
					return GVReturnObject.new(get_error("Unexpected space"))
				
				# Can't assign is property already exists and is a constant
				if (kw in properties and properties[kw].constant) or (kw in global_properties and global_properties[kw].constant):
					return GVReturnObject.new(get_error("Cannot assign value to constant property '" + kw + "'"))
				
				var value_to_assign: GVReturnObject = get_value(true, properties)
				if value_to_assign.value is GDScriptFunctionState:
					value_to_assign.value = yield(value_to_assign, "completed")
				
				# Return if error occurred
				if value_to_assign.value is SimpleScriptError:
					return value_to_assign
				
#				if kw in global_properties:
#					global_properties[kw].set_value(value_to_assign)
#				elif kw in properties: # Property already exists, so overwrite
#					properties[kw].set_value(value_to_assign)
#				else: # Create new value
#				properties[kw] = SimpleScriptValue.new().assign_value(value_to_assign)
				
				
				properties[kw] = SimpleScriptValue.new(value_to_assign.value)
				
				print("Assigned property '" + kw + "' as ", value_to_assign)
				kw = ""
				
			string_char: # Initialise string
				var result = create_string()
				if result is SimpleScriptError:
					return GVReturnObject.new(result)
				yield(advance(), "completed") if paused else advance()
				return GVReturnObject.new(result, GVReturnObject.SOURCE_TYPES.VALUE)
			" ": # Check for keyword before space
				
				match kw:
					kw_function: # Declare function
						
						# Can't declare if a value is required
						if must_be_value:
							return GVReturnObject.new(get_error("Unexpected function declaration"))
						
						if not (yield(advance(), "completed") if paused else advance()):
							return GVReturnObject.new(get_error(script_ended_error))
						
						if c == " ":
							return GVReturnObject.new(get_error("Unexpected space"))
						
						# Declare the function
						var error = declare_function()
						if error is GDScriptFunctionState:
							yield(error, "completed")
						
						# Return error if not OK
						if not error.is_ok():
							return GVReturnObject.new(error)
						
					kw_return: # Return value
						
						# Can't return if not a function
						if function == null:
							return GVReturnObject.new(get_error("The '" + kw_return + "' keyword can only be used within functions"))
						
						if not (yield(advance(), "completed") if paused else advance()):
							return GVReturnObject.new(get_error(script_ended_error))
						if c == " ":
							return GVReturnObject.new(get_error("Unexpected space"))
						
						# No value provided, so return null
						if c == "\n":
							function_return_value = null
						# Get return value
						else:
							var returnobject: GVReturnObject = get_value(true, properties)
							if returnobject.value is GDScriptFunctionState:
								returnobject.value = yield(returnobject.value, "completed")
							# If an error occurred, raise the error and return null
							if returnobject.value is SimpleScriptError:
								function_return_value = null
								function_returned = true
								emit_signal("function_returned", function_return_value)
								return returnobject
							function_return_value = returnobject.value
						
						function_returned = true
						emit_signal("function_returned", function_return_value)
						return GVReturnObject.new(get_error(null))
					kw_pointer:
						if not (yield(advance(), "completed") if paused else advance()):
							return GVReturnObject.new(get_error(script_ended_error))
						
						var returnobject = get_value(true, properties)
						if returnobject.value is SimpleScriptError:
							return returnobject
						
						if returnobject.source_type != GVReturnObject.SOURCE_TYPES.PROPERTY:
							return GVReturnObject.new(get_error("The '" + kw_pointer + "' keyword must be followed by a property"))
						
						return GVReturnObject.new(SimpleScriptPointer.new(self, returnobject.data["property_name"]), GVReturnObject.SOURCE_TYPES.VALUE)
					_:
						if not (yield(advance(), "completed") if paused else advance()):
							return GVReturnObject.new(get_error(script_ended_error))
						
						if c == " ":
							return GVReturnObject.new(get_error("Unexpected space"))
						else:
							skip_advance = true
			_:
				# If new line, reset keyword
				if c == linebreak:
					kw = ""
				else:
					kw += c
		
		if i + 1 < len(source_code) and (source_code[i + 1] in kw_endings or (source_code[i + 1] == "\n" and must_be_value)):
			var result = parse_kw(kw, properties)
			if result is GVReturnObject:
				return result
			else:
				return GVReturnObject.new(get_error("Expected expression" if kw.strip_edges().empty() else "Property '" + kw + "' does not exist in this scope"))
		
		if skip_advance:
			skip_advance = false
		else:
			if not (yield(advance(), "completed") if paused else advance()):
				var result = parse_kw(kw, properties)
				if result is GVReturnObject:
					return result
				else:
					return GVReturnObject.new(get_error(script_ended_error))
	
	var result = parse_kw(kw, properties)
	if result is GVReturnObject:
		return result
	else:
		return GVReturnObject.new(get_error("Property '" + kw + "' does not exist in this scope"))

func parse_kw(kw: String, properties: Dictionary):
	if kw.is_valid_integer():
		return GVReturnObject.new(SimpleScriptValue.new(kw.to_int()), GVReturnObject.SOURCE_TYPES.VALUE)
	elif kw.is_valid_float():
		return GVReturnObject.new(SimpleScriptValue.new(kw.to_float()), GVReturnObject.SOURCE_TYPES.VALUE)
	elif kw in properties:
		return GVReturnObject.new(properties[kw], GVReturnObject.SOURCE_TYPES.PROPERTY, kw)
	elif kw in global_properties:
		return GVReturnObject.new(global_properties[kw], GVReturnObject.SOURCE_TYPES.PROPERTY, kw)
	else:
		return null

# Moves the header to the given position index
func go_to_position(position: int):
	i = position
	c = source_code[i]
	i_in_line = position - Utils.get_position_of_line(source_code, position)
	
	indent = 0
	var line_i: int = Utils.get_position_of_line(source_code, Utils.get_line_of_position(source_code, position))
	while source_code[line_i + indent] == "	":
		indent += 1

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
			
			if i + indent_i < len(source_code):
				while source_code[i + indent_i] == "	":
					indent += 1
					indent_i += 1
					
					if i + indent_i >= len(source_code):
						break
			
		elif source_code[i - 1] == linebreak and ignore_linebreaks:
			print("WAS LINEBREAK ", c == "	")
			line += 1
			i_in_line = 0

			# Set indent to indent of current line
			var indent_i: int = 0
			indent = 0
			while source_code[i + indent_i] == "	":
				indent += 1
				indent_i += 1
				if i + indent_i >= len(source_code):
					break
		
		return true
	else:
		return false

func call_function(func_name: String, properties: Dictionary):
	
	if not func_name in functions:
		return get_error("Function '" + func_name + "' does not exist in this scope")
	
	if not (yield(advance(), "completed") if paused else advance()):
		return get_error("Script ended unexpectedly while calling function '" + func_name + "'")
	
	var args: Array = []
	
	while true:
		match c:
			")":
				break
			_:
				var returnobject: GVReturnObject = get_value(true, properties, [",", ")"])
				if returnobject.value is GDScriptFunctionState:
					returnobject.value = yield(returnobject.value, "completed")
				if returnobject.value is SimpleScriptError:
					return returnobject.value
				args.append(returnobject.value)
				
				if c == ")":
					break
				
		if not (yield(advance(), "completed") if paused else advance()):
			if c != ")":
				return get_error("Script ended unexpectedly while calling function '" + func_name + "'")
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
					
					elif not result.get_value() is SimpleScriptType:
						return get_error("Unexpected value of type " + SimpleScriptType.get_as_string(typeof(result)) + " as argument type (must be a builtin type)")
					
					arg["type"] = result.get_value().type
					
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
	function.init_code(func_name, args, line - 1)
	functions[func_name] = function
	
	go_to_position(i + len(get_code_block()))
	
	return get_error(null)

func create_string():
	if not (yield(advance(), "completed") if paused else advance()):
		return get_error("Script ended unexpectedly while creating string")
	
	var string: String = ""
	while true:
		if c == string_char:
			break
		else:
			string += c
		
		if not (yield(advance(), "completed") if paused else advance()):
			return get_error("Script ended unexpectedly while creating string")
	
	print("Created string: ", string)
	return string

func get_error(message: String) -> SimpleScriptError:
	return SimpleScriptError.new(message, line, i, i_in_line)

func get_code_block(from_line: int = line):
	var ret: String = ""
	
	var line: int = from_line
	var i: int = Utils.get_position_of_line(source_code, line)
	var base_indent: int = get_indent_of_line(line)
	while i < len(source_code):
		if source_code[i] == "\n":
			line += 1
			if get_indent_of_line(line) < base_indent and not source_code_lines[line].strip_edges().empty():
				break
		ret += source_code[i]
		i += 1
	
	# Flatten indentation
	var lines: Array = ret.split("\n")
	ret = ""
	for j in len(lines):
		var line_str: String = lines[j]
		line_str.erase(0, base_indent)
		ret += line_str
		if j + 1 != len(lines):
			ret += "\n"
	
	return ret

func get_indent_of_line(line: int) -> int:
	var i: int = Utils.get_position_of_line(source_code, line)
	var indent: int = 0
	while i + indent < len(source_code) and source_code[i + indent] == "	":
		indent += 1
	return indent

func get_class() -> String:
	return "Script"
