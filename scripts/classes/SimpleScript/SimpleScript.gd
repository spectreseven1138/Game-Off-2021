class_name SimpleScript
extends Reference

signal function_returned(value)

var simplescript: GDScript = load("res://scripts/classes/SimpleScript/SimpleScript.gd")

const kw_function: String = "func"
const kw_return: String = "return"
const kw_pass: String = "pass"
const kw_pointer: String = "pointer"
const kw_if: String = "if"
const kw_elif: String = "elif"
const kw_else: String = "else"
const kw_while: String = "while"
const kw_for: String = "for"
const kw_for_in: String = "in"
const kw_for_alt: String = "forx"
const kw_self: String = "self"
const kw_extends: String = "extends"
const comment_string: String = "//"

const engine_variable_char: String = "@"

const highlight_keywords: Array = [
	kw_function, kw_return, kw_pass, kw_pointer, kw_if, kw_elif, kw_else, kw_while, kw_for, kw_for_alt, kw_for_in, kw_self, kw_extends,
	"null", "PI", "TAU", "INF", "NAN", "int", "float", "str", "array", "dict", "true", "false"
]

var source_code: String
var source_code_lines: Array
var function: String = null
var function_returned: bool = false
var function_return_value
var stdout: FuncRef
var stderr: FuncRef
var tree: SceneTree
var file_path: String
var extends_script: String = null

const script_ended_error: String = "Script ended unexpectedly"
var functions: Dictionary = {}
var global_properties: Dictionary = {}

var parser: SimpleScriptParser = SimpleScriptParser.new(self)

func _init(_source_code: String, _stdout: FuncRef, _stderr: FuncRef, _tree: SceneTree, function_name: String = null, _file_path: String = null):
	source_code = _source_code
	source_code_lines = source_code.split("\n")
	stdout = _stdout
	stderr = _stderr
	tree = _tree
	function = function_name
	file_path = _file_path
	
	for func_name in SimpleScriptFunction.BUILTIN_FUNCTIONS:
		functions[func_name] = SimpleScriptFunction.new(stdout, stderr, self).init_builtin(func_name)
	
	for type in SimpleScriptType.TYPES.values():
		global_properties[SimpleScriptType.get_as_string(type)] = SimpleScriptValue.new(SimpleScriptType.new(type))
	
	global_properties["null"] = SimpleScriptValue.new(null)
	global_properties["PI"] = SimpleScriptValue.new(PI)
	global_properties["TAU"] = SimpleScriptValue.new(TAU)
	global_properties["INF"] = SimpleScriptValue.new(INF)
	global_properties["NAN"] = SimpleScriptValue.new(NAN)
	global_properties["true"] = SimpleScriptValue.new(true)
	global_properties["false"] = SimpleScriptValue.new(false)

func get_property(property_name: String):
	if property_name in global_properties:
		return global_properties[property_name]["value"]
	else:
		return null

signal resume
var paused: bool = false
var iter: int = 0
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
		var returnobject = get_value(false, properties, [])
		if returnobject is GDScriptFunctionState:
			returnobject = yield(returnobject, "completed")
		
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
		
		iter += 1
	
	# If this is a function and no value was returned in code, return null
	if function != null and not function_returned:
		emit_signal("function_returned", null)

# Object returned by get_value() containing metadata
class GVReturnObject:
	extends Reference
	
	var value setget set_value
	enum SOURCE_TYPES {ERROR, VALUE, PROPERTY, FUNCTION}
	var source_type: int
	var data: Dictionary = {}
	
	func _init(_value):
		value = _value
		if value is SimpleScriptError:
			source_type = SOURCE_TYPES.ERROR
		else:
			source_type = SOURCE_TYPES.VALUE
	
	func init_property(script: SimpleScript, property_name: String):
		source_type = SOURCE_TYPES.PROPERTY
		data = {"script": script, "property_name": property_name}
		return self
	
	func init_function(script: SimpleScript, function_name: String, arguments: Array):
		source_type = SOURCE_TYPES.FUNCTION
		data = {"script": script, "function_name": function_name, "arguments": arguments}
		return self
	
	func set_value(_value):
		value = _value

func get_value(must_be_value: bool, properties: Dictionary, kw_endings: Array = []) -> GVReturnObject:
	var kw: String = ""
	var skip_advance: bool = false
	var ret: GVReturnObject = null
	if not "\n" in kw_endings:
		kw_endings.append("\n")
	var value_line: int = line
	while line == value_line:
		match c:
			"	":
				if not (yield(advance(), "completed") if paused else advance()):
					
					if kw.strip_edges().empty():
						if must_be_value:
							return GVReturnObject.new(get_error("Expected value"))
						else:
							return GVReturnObject.new(get_error(null))
					
					var result = parse_kw(kw, properties)
					yield(advance(), "completed") if paused else advance()
					if result is GVReturnObject:
						return result
					else:
						return GVReturnObject.new(get_error(script_ended_error if must_be_value else "Property '" + kw + "' does not exist in this scope"))
				
				break
			"(": # Call function
				var returnobject = call_function(kw, properties)
				if returnobject is GDScriptFunctionState:
					returnobject = yield(returnobject, "completed")
				if returnobject.value is SimpleScriptError:
					return returnobject
				ret = GVReturnObject.new(returnobject.value).init_function(self, kw, returnobject.data["arguments"])
				kw = ""
				if c in kw_endings or (c != "\n" and (not (yield(advance(), "completed") if paused else advance()))):
					return ret
			"+", "-": # ++ and --
				
				var operation: String = c
				
				if not (yield(advance(), "completed") if paused else advance()):
					return GVReturnObject.new(get_error(script_ended_error))
				
				if c == operation: # ++ or --
					operation += c
					
					# Can't assign if a value is required
					if must_be_value:
						return GVReturnObject.new(get_error("Unexpected assign"))
					
					# Skip if space
					if c == " ":
						if not (yield(advance(), "completed") if paused else advance()):
							return GVReturnObject.new(get_error(script_ended_error))
					if c == " ":
						return GVReturnObject.new(get_error("Unexpected space"))
					
					var property: SimpleScriptValue
					
					if kw in properties:
						property = properties[kw]
					elif kw in global_properties:
						property = global_properties[kw]
					else:
						return GVReturnObject.new(get_error("Property '" + kw + "' does not exist in this scope"))
					
					# Can't modify if property is a constant
					if property.constant:
						return GVReturnObject.new(get_error("Cannot modify constant property '" + kw + "'"))
					
					if not (property.value is int or property.value is float):
						return GVReturnObject.new(get_error("'" + operation + "' was used with " + SimpleScriptType.get_as_string(property.type) + ", but requires " + SimpleScriptType.get_as_string(SimpleScriptType.TYPES.FLOAT) + " or " + SimpleScriptType.get_as_string(SimpleScriptType.TYPES.INT)))
					
					match operation:
						"++": property.value += 1
						"--": property.value -= 1
					
					yield(advance(), "completed") if paused else advance()
					
					return GVReturnObject.new(get_error(null))
				else: # Math operation
					var returnobject = operation(operation, ret, properties, kw, kw_endings)
					if returnobject is GDScriptFunctionState:
						returnobject = yield(returnobject, "completed")
					ret = returnobject
					if c in kw_endings or ret.value is SimpleScriptError:
						return ret
				
			"!": # Invert bool
				
				if not (yield(advance(), "completed") if paused else advance()):
					return GVReturnObject.new(get_error(script_ended_error))
				
				if c == "=":
					var returnobject = operation("!=", ret, properties, kw, kw_endings)
					if returnobject is GDScriptFunctionState:
						returnobject = yield(returnobject, "completed")
					ret = returnobject
					if c in kw_endings or ret.value is SimpleScriptError:
						return ret
				else:
					
					var returnobject = get_value(true, properties, kw_endings)
					if returnobject is GDScriptFunctionState:
						returnobject = yield(returnobject, "completed")
					
					if returnobject.value is SimpleScriptError:
						return returnobject
					
					if returnobject.value.value is bool:
						returnobject.value.value = !returnobject.value.value
						ret = GVReturnObject.new(returnobject.value)
					else:
						return GVReturnObject.new(get_error("'!' was used with " + SimpleScriptType.get_as_string(returnobject.value.type) + ", but requires " + SimpleScriptType.get_as_string(SimpleScriptType.TYPES.BOOL)))
				
			"=": # Assign
				
				if not (yield(advance(), "completed") if paused else advance()):
					return GVReturnObject.new(get_error(script_ended_error))
				
				if c == "=":
					var returnobject = operation("==", ret, properties, kw, kw_endings)
					if returnobject is GDScriptFunctionState:
						returnobject = yield(returnobject, "completed")
					ret = returnobject
					if c in kw_endings or ret.value is SimpleScriptError:
						return ret
				else:
					
					# Can't assign to engine variable
					if kw.begins_with(engine_variable_char):
						return GVReturnObject.new(get_error("Cannot assign to engine variable"))
					
					# Can't assign to 'self'
					if kw == kw_self:
						return GVReturnObject.new(get_error("Cannot assign to '" + kw_self + "'"))
					
					# Can't assign if a value is required
					if must_be_value:
						return GVReturnObject.new(get_error("Unexpected assign"))
					
					# Skip if space
					if c == " ":
						if not (yield(advance(), "completed") if paused else advance()):
							return GVReturnObject.new(get_error(script_ended_error))
					if c == " ":
						return GVReturnObject.new(get_error("Unexpected space"))
					
					# Can't assign is property already exists and is a constant
					if (kw in properties and properties[kw].constant) or (kw in global_properties and global_properties[kw].constant):
						return GVReturnObject.new(get_error("Cannot assign value to constant property '" + kw + "'"))
					
					var returnobject = get_value(true, properties)
					if returnobject is GDScriptFunctionState:
						returnobject = yield(returnobject, "completed")
					
					# Return if error occurred
					if returnobject.value is SimpleScriptError:
						return returnobject
					
					properties[kw] = returnobject.value
					
					print("Assigned property '" + kw + "' as ", returnobject.value)
					return GVReturnObject.new(get_error(null))
			"+", "-", "*", "/", "<", ">", "!":
				var returnobject = operation(c, ret, properties, kw, kw_endings)
				if returnobject is GDScriptFunctionState:
					returnobject = yield(returnobject, "completed")
				ret = returnobject
				if c in kw_endings or ret.value is SimpleScriptError:
					return ret
			
			"'", "\"", "{": # Initialise string or dictionary
				var returnobject = create_dictionary(properties) if c == "{" else create_string(c)
				if returnobject is GDScriptFunctionState:
					returnobject = yield(returnobject, "completed")
				if returnobject.value is SimpleScriptError:
					return returnobject
#				yield(advance(), "completed") if paused else advance()
				ret = returnobject
				
				if c in kw_endings:
					return ret
			"[": # Initialise array or get value at index/key
				
				if kw.strip_edges().empty() and ret == null: # Initialise array
					var returnobject = create_array(properties)
					if returnobject is GDScriptFunctionState:
						returnobject = yield(returnobject, "completed")
					if returnobject.value is SimpleScriptError:
						return returnobject
					ret = returnobject
					
				else: # Get value at index or key
					var base
					if ret == null:
						base = parse_kw(kw, properties)
						if base == null:
							return GVReturnObject.new(get_error("Property '" + kw + "' does not exist in this scope"))
					else:
						base = ret
					
					if not base.value.can_get_index():
						return GVReturnObject.new(get_error("Can't get key or index from value of type " + SimpleScriptType.get_as_string(base.value.type)))
					
					if not (yield(advance(), "completed") if paused else advance()):
						return GVReturnObject.new(get_error("Script ended unexpectedly while getting index or key from value"))
					
					var index = get_value(true, properties, ["]"])
					if index is GDScriptFunctionState:
						index = yield(index, "completed")
					if index.value is SimpleScriptError:
						return index
					index = index.value
					
					if not base.value.is_index_type_valid(index.value):
						return GVReturnObject.new(get_error("The passed index or key of type " + SimpleScriptType.get_as_string(index.type) + " is incombatible with base value of type " + SimpleScriptType.get_as_string(base.value.type)))
					
					if not base.value.is_index_value_valid(index.value):
						return GVReturnObject.new(get_error("Invalid index or key '" + SimpleScriptValue.convert_to_type(index.value, SimpleScriptType.TYPES.STR) + "' on base value of type " + SimpleScriptType.get_as_string(base.value.type)))
					
					ret = GVReturnObject.new(base.value.get_index_value(index.value))
					kw = ""
				
				if c in kw_endings:
					return ret
				
			" ": # Check for keyword before space
				var returnobject = check_kw(kw, properties, must_be_value, kw_endings)
				if returnobject != null:
					if returnobject is GDScriptFunctionState:
						returnobject = yield(returnobject, "completed")
					return returnobject
				skip_advance = true
			_:
				# If new line, reset keyword
				if c == "\n":
					kw = ""
				else:
					kw += c
		
		if (i + 1 < len(source_code) and (source_code[i + 1] in kw_endings or (source_code[i + 1] == "\n"))):
			
			if ret != null:
				return ret
			
			if kw.strip_edges().empty() or kw in kw_endings:
				kw = c
			
			var result = parse_kw(kw, properties)
			if result is GVReturnObject:
				yield(advance(), "completed") if paused else advance()
				return result
			elif kw == kw_pass:
				if must_be_value:
					return GVReturnObject.new(get_error("The '" + kw_pass + "' keyword has no value"))
			else:
				if kw.strip_edges().empty():
					if must_be_value:
						return GVReturnObject.new(get_error("Expected expression"))
				else:
					return check_kw(kw, properties, must_be_value, kw_endings)
#					return GVReturnObject.new(get_error("Property '" + kw + "' does not exist in this scope"))
		
		if skip_advance:
			skip_advance = false
		else:
			if not (yield(advance(), "completed") if paused else advance()):
				
				if kw.strip_edges().empty():
					return GVReturnObject.new(get_error(null))
				
				var result = parse_kw(kw, properties)
				if result is GVReturnObject:
					return result
				else:
					return GVReturnObject.new(get_error(script_ended_error if must_be_value else "Property '" + kw + "' does not exist in this scope"))
	
	return ret if ret != null else GVReturnObject.new(get_error(null))

func check_kw(kw: String, properties: Dictionary, must_be_value: bool, kw_endings: Array) -> GVReturnObject:
	match kw:
		kw_extends: # Inherit other script
			
			if function != null:
				return GVReturnObject.new(get_error("Cannot extend script within function"))
			if must_be_value:
				return GVReturnObject.new(get_error("Unexpected script extension"))
			if iter != 0:
				return GVReturnObject.new(get_error("The '" + kw_extends + "' keyword must be used at the beginning of a script"))
			if extends_script != null:
				return GVReturnObject.new(get_error("This script already extends another script"))
			
			var returnobject = get_value(true, properties, kw_endings)
			if returnobject is GDScriptFunctionState:
				returnobject = yield(returnobject, "completed")
			if returnobject.value is SimpleScriptError:
				return returnobject
			
			var type: int = SimpleScriptValue.get_type(returnobject.value.value)
			match type:
				SimpleScriptType.TYPES.STR:
					extends_script = returnobject.value.value
				SimpleScriptType.TYPES.SCRIPT:
					extends_script = returnobject.value.value.file_path
				_:
					return GVReturnObject.new(get_error("Expected value of type " + SimpleScriptType.get_as_string(SimpleScriptType.TYPES.STR) + " or " + SimpleScriptType.get_as_string(SimpleScriptType.TYPES.SCRIPT) + ", but got " + SimpleScriptType.get_as_string(type)))
			
			var script = SSEngine.get_simplescript(extends_script)
			if script is String: # Error
				return GVReturnObject.new(get_error(script))
			
			var run = script.run()
			if run is GDScriptFunctionState:
				run = yield(run, "completed")
			
			for property in script.global_properties:
				global_properties[property] = script.global_properties[property]
			for function in script.functions:
				functions[function] = script.functions[function]
			
			return GVReturnObject.new(get_error(null))
			
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
				error = yield(error, "completed")
			
			return GVReturnObject.new(error)
		kw_if, kw_while, kw_for, kw_for_alt: # If statement and loops
			
			# TODO: Ternary If statement
			if must_be_value:
				return GVReturnObject.new(get_error("Unexpected '" + kw_if + "' statement"))
			
			if not (yield(advance(), "completed") if paused else advance()):
				return GVReturnObject.new(get_error(script_ended_error))
			
			if c == " ":
				return GVReturnObject.new(get_error("Unexpected space"))
			
			var error
			match kw:
				kw_if: error = if_statement(properties)
				kw_while: error = while_loop(properties)
				kw_for: error = for_loop(properties, false)
				kw_for_alt: error = for_loop(properties, true)
			
			if error is GDScriptFunctionState:
				error = yield(error, "completed")
			
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
				function_return_value = SimpleScriptValue.new(null)
			# Get return value
			else:
				var returnobject = get_value(true, properties)
				if returnobject is GDScriptFunctionState:
					returnobject = yield(returnobject, "completed")
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
			
			var returnobject = get_value(true, properties, kw_endings)
			if returnobject is GDScriptFunctionState:
				returnobject = yield(returnobject, "completed")
			if returnobject.value is SimpleScriptError:
				return returnobject
			
			if returnobject.source_type != GVReturnObject.SOURCE_TYPES.PROPERTY:
				if i < len(source_code):
					go_to_position(i)
				return GVReturnObject.new(get_error("The '" + kw_pointer + "' keyword must be followed by a property"))
			
			return GVReturnObject.new(SimpleScriptPointer.new(self, returnobject.data["property_name"]))
		_:
			if not (yield(advance(), "completed") if paused else advance()):
				return GVReturnObject.new(get_error(script_ended_error))
			
			if c == " ":
				return GVReturnObject.new(get_error("Unexpected space"))
#			else:
#				skip_advance = true
	return GVReturnObject.new(get_error(null))

func parse_kw(kw: String, properties: Dictionary):
	
	match kw:
		kw_self: return GVReturnObject.new(SimpleScriptValue.new(self))
	
	if kw.is_valid_integer():
		return GVReturnObject.new(SimpleScriptValue.new(kw.to_int()))
	elif kw.is_valid_float():
		return GVReturnObject.new(SimpleScriptValue.new(kw.to_float()))
	elif kw in properties:
		return GVReturnObject.new(properties[kw]).init_property(self, kw)
	elif kw in global_properties:
		return GVReturnObject.new(global_properties[kw]).init_property(self, kw)
	else:
		return null

# Moves the head to the given position index
func go_to_position(position: int):
	i = position
	c = source_code[min(i, len(source_code) - 1)]
	line = Utils.get_line_of_position(source_code, position)
	
	if c == "\n":
		line += 1
	
	indent = 0
	var line_i: int = min(Utils.get_position_of_line(source_code, line), len(source_code) - 1)
	while source_code[line_i + indent] == "	":
		indent += 1
	
	i_in_line = position - line_i

# Advances c by 1
# Handles indentation, linebreaks, and comments
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
				if c == "\n":
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
		elif c == "\n" and not ignore_linebreaks:
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
			
		elif source_code[i - 1] == "\n" and ignore_linebreaks:
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

func call_function(func_name: String, properties: Dictionary) -> GVReturnObject:
	
	var script_ended_error: String = "Script ended unexpectedly while calling function '" + func_name + "'"
	
	if not func_name in functions:
		return GVReturnObject.new(get_error("Function '" + func_name + "' does not exist in this scope"))
	
	if not (yield(advance(), "completed") if paused else advance()):
		return GVReturnObject.new(get_error(script_ended_error))
	
	var args: Array = []
	
	while true:
		match c:
			")":
				break
			_:
				var returnobject = get_value(true, properties, [",", ")"])
				if returnobject is GDScriptFunctionState:
					returnobject = yield(returnobject, "completed")
				if returnobject.value is SimpleScriptError:
					return returnobject
				args.append(returnobject.value)
				
				if c == ")":
					break
				
				if not (yield(advance(), "completed") if paused else advance()):
					return GVReturnObject.new(get_error(script_ended_error))
				
				if c == ")":
					break
				
		if not (yield(advance(), "completed") if paused else advance()):
			if c != ")":
				return GVReturnObject.new(get_error(script_ended_error))
			else:
				break
	
	var function: SimpleScriptFunction = functions[func_name]
	yield(advance(), "completed") if paused else advance()
	
	var error: SimpleScriptError = function.validate_arguments(args)
	if not error.is_ok():
		error.position = i
		error.position_in_line = i_in_line
		error.line = line
		error.simplescript = self
		return GVReturnObject.new(error)
	
	var call = function.call_func(args)
	if call is GDScriptFunctionState:
		call = yield(call, "completed")
	return GVReturnObject.new(call).init_function(self, func_name, args)

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
	var end_args: bool = false
	while true:
		var arg: Dictionary = {"name": "", "types": [], "optional": false}
		var skip_advance: bool = false
		while arg != null:
			
			while c == " ":
				if not (yield(advance(), "completed") if paused else advance()):
					return get_error(script_end_error)
			
			match c:
				")": # End argument parsing
					args.append(arg)
					arg = null
					end_args = true
				",": 
					args.append(arg)
					arg = null
				":": # Get argument type
					
					if not (yield(advance(), "completed") if paused else advance()):
						return get_error(script_end_error)
					
					var returnobject = get_value(true, {}, [",", ")"])
					if returnobject is GDScriptFunctionState:
						returnobject = yield(returnobject, "completed")
					if returnobject.value is SimpleScriptError:
						return returnobject
					
					if not returnobject.value.value is SimpleScriptType:
						return get_error("Unexpected value of type " + SimpleScriptType.get_as_string(SimpleScriptValue.get_type(returnobject.value.value)) + " as argument type (must be a builtin type)")
					
					arg["types"].append(returnobject.value.value.type)
					
					skip_advance = true
					
				"=": # Get default value
					pass
				_:
					if not c.is_valid_identifier():
						return get_error("Invalid character used in function argument name")
					
					arg["name"] += c
			
			if skip_advance:
				skip_advance = false
			else:
				if not (yield(advance(), "completed") if paused else advance()):
					return get_error(script_end_error)
			
			if arg == null:
				break
			
		
		if end_args:
			break
		
		if c == ")":
			break
			if skip_advance:
				skip_advance = false
			elif not (yield(advance(), "completed") if paused else advance()):
				return get_error(script_end_error)
		
	
#	if c == ")":
#		break
	
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
	
	go_to_position(i + len(get_code_block(line, false)))
	
	return get_error(null)

func if_statement(properties: Dictionary) -> SimpleScriptError:
	
	var condition = get_value(true, properties, [":"])
	if condition is GDScriptFunctionState:
		condition = yield(condition, "completed")
	
	if condition.value is SimpleScriptError:
		return condition.value
	
	if not (yield(advance(), "completed") if paused else advance()):
		return get_error(script_ended_error)
	if not (yield(advance(), "completed") if paused else advance()):
		return get_error(script_ended_error)
	
	var execute: bool = SimpleScriptFunction.builtin_convert_to_bool([condition.value]).value
	
	var block_indent: int = indent
	while indent >= block_indent:
		
		if execute:
			var returnobject: GVReturnObject = get_value(false, properties)
			
			# If get_value() returned an error, display it
			if returnobject.value is SimpleScriptError and not returnobject.value.is_ok():
				return returnobject.value
			
			if i > len(source_code):
				return get_error(null)
			
		else:
			if not (yield(advance(), "completed") if paused else advance()):
				return get_error(null)
	
	while true:
	
		while c.strip_edges().empty():
			if not (yield(advance(), "completed") if paused else advance()):
				return get_error(null)

		var line_code: String = source_code_lines[line]

		# elif
		if line_code.begins_with(kw_elif + " "):
			go_to_position(i + len(kw_elif) + 1)
			if execute: # Skip code block
				block_indent = indent
				while indent >= block_indent:
					if not (yield(advance(), "completed") if paused else advance()):
						return get_error(null)
			else: # Process elif statement
				if_statement(properties)
		# else
		elif line_code.begins_with(kw_else + ":"):
			go_to_position(Utils.get_position_of_line(source_code, line + 1))
			block_indent = indent
			while indent >= block_indent:
				
				if execute: # Skip code block
					if not (yield(advance(), "completed") if paused else advance()):
						return get_error(null)
				else: # Execute code block
					var returnobject: GVReturnObject = get_value(false, properties)
					# get_value() returned an error, so display it
					if returnobject.value is SimpleScriptError and not returnobject.value.is_ok():
						return returnobject.value
			break
	
	return get_error(null)

func while_loop(properties: Dictionary) -> SimpleScriptError:
	var condition = get_value(true, properties, [":"])
	if condition is GDScriptFunctionState:
		condition = yield(condition, "completed")
	
	if condition.value is SimpleScriptError:
		return condition.value
	
	if not (yield(advance(), "completed") if paused else advance()):
		return get_error(script_ended_error)
	if not (yield(advance(), "completed") if paused else advance()):
		return get_error(script_ended_error)
	
	var execute: bool = SimpleScriptValue.convert_to_type(condition.value.value, SimpleScriptType.TYPES.BOOL)
	var block_indent: int = indent
	var initial_i: int = i
	
	# Main loop
	while true:
		
		# Execute or skip code block
		while indent >= block_indent:
			
			if execute:
				var returnobject: GVReturnObject = get_value(false, properties)
				
				# If get_value() returned an error, display it
				if returnobject.value is SimpleScriptError and not returnobject.value.is_ok():
					return returnobject.value
				
				if i > len(source_code):
					return get_error(null)
				
			else:
				if not (yield(advance(), "completed") if paused else advance()):
					return get_error(null)
		
		if not execute:
			break
		
		var ret = condition.data["script"].functions[condition.data["function_name"]].call_func(condition.data["arguments"]).value
		
		# Reassign execute property if condition is a property or function
		match condition.source_type:
			GVReturnObject.SOURCE_TYPES.PROPERTY: execute = SimpleScriptValue.convert_to_type(condition.data["script"].global_properties[condition.data["property_name"]].value, SimpleScriptType.TYPES.BOOL)
			GVReturnObject.SOURCE_TYPES.FUNCTION: execute = SimpleScriptValue.convert_to_type(ret, SimpleScriptType.TYPES.BOOL)
		
		# Return head to beginning of code block
		if execute:
			go_to_position(initial_i)
			yield(tree, "idle_frame")
		else:
			break
	
	return get_error(null)

func for_loop(properties: Dictionary, alt: bool) -> SimpleScriptError:
	
	var iter_variable: String = ""
	while true:
		
		if c == " ":
			if not (yield(advance(), "completed") if paused else advance()):
				return get_error(script_ended_error)
			break
		
		iter_variable += c
		
		if not (yield(advance(), "completed") if paused else advance()):
			return get_error(script_ended_error)
	
	if iter_variable in properties or iter_variable in global_properties:
		return get_error("Property '" + iter_variable + "' has already been defined")
	
	var kw: String = ""
	while true:
		
		if c == " ":
			if not (yield(advance(), "completed") if paused else advance()):
				return get_error(script_ended_error)
			break
		
		kw += c
		
		if not (yield(advance(), "completed") if paused else advance()):
			return get_error(script_ended_error)
	
	if kw != kw_for_in:
		return get_error("Expected '" + kw_for_in + "'")
	
	var iterable = get_value(true, properties, [":"])
	if iterable is GDScriptFunctionState:
		iterable = yield(iterable, "completed")
	iterable = iterable.value
	if iterable is SimpleScriptError:
		return iterable
	if not iterable.can_iterate():
		return get_error("Cannot iterate value of type " + SimpleScriptType.get_as_string(iterable.type))
	
	while c == " ":
		if not (yield(advance(), "completed") if paused else advance()):
			return get_error(script_ended_error)
	
	if c != ":":
		return get_error("Expected ':'")
	
	if not (yield(advance(), "completed") if paused else advance()):
		return get_error(script_ended_error)
	
	# For loop
	var initial_i: int = i
	var block_indent: int = indent
	while true:
		
		properties[iter_variable] = SimpleScriptValue.new(iterable.iterate())
		var last: bool = iterable.is_last_iteration()
		properties["@last_" + iter_variable] = SimpleScriptValue.new(last)
		
		while indent >= block_indent:
			
			var returnobject = get_value(false, properties)
			if returnobject is GDScriptFunctionState:
				returnobject = yield(returnobject, "completed")
			
			# If get_value() returned an error, display it
			if returnobject.value is SimpleScriptError and not returnobject.value.is_ok():
				return returnobject.value
			
			if i > len(source_code):
				break
		
		if last:
			iterable.end_iteration()
			properties.erase(iter_variable)
			properties.erase("@last_" + iter_variable)
			break
		
		go_to_position(initial_i)
	
	return get_error(null)

func operation(operation: String, ret: GVReturnObject, properties: Dictionary, kw: String, kw_endings: Array) -> GVReturnObject:
	
	if not (yield(advance(), "completed") if paused else advance()):
		return GVReturnObject.new(get_error(script_ended_error))
	
	if operation in ["<", ">"] and c == "=":
		operation += "="
		if not (yield(advance(), "completed") if paused else advance()):
			return GVReturnObject.new(get_error(script_ended_error))
	
	var A: SimpleScriptValue
	if ret == null:
		var result = parse_kw(kw, properties)
		if result == null:
			return GVReturnObject.new(get_error("The " + operation + " operation requires a value before the operation"))
		A = result.value
	else:
		A = ret.value
	
	var B = get_value(true, properties, kw_endings)
	if B is GDScriptFunctionState:
		B = yield(B, "completed")
	if B.value is SimpleScriptError:
		return B
	B = B.value
	
	if ((A.value is int or A.value is float) and (B.value is int or B.value is float)) or (A.value is String and B.value is String and operation == "+") or operation in ["==", "!="]:
		var result
		match operation:
			"+": result = A.value + B.value
			"-": result = A.value - B.value
			"*": result = A.value * B.value
			"/": result = A.value / B.value
			"<": result = A.value < B.value
			"<=": result = A.value <= B.value
			">": result = A.value > B.value
			">=": result = A.value >= B.value
			"==": result = A.value == B.value
			"!=": result = A.value != B.value
		
		ret = GVReturnObject.new(SimpleScriptValue.new(result))
	else:
		return GVReturnObject.new(get_error("Invalid types for " + operation + " operation (" + SimpleScriptType.get_as_string(A.type) + " and " + SimpleScriptType.get_as_string(B.type) + ")"))
	
	return ret

func create_string(trigger_char: String) -> GVReturnObject:
	if not (yield(advance(), "completed") if paused else advance()):
		return GVReturnObject.new(get_error("Script ended unexpectedly while creating string"))
	
	var string: String = ""
	while true:
		if c == trigger_char:
			break
		else:
			string += c
		
		if not (yield(advance(), "completed") if paused else advance()):
			return GVReturnObject.new(get_error("Script ended unexpectedly while creating string"))
	
	yield(advance(), "completed") if paused else advance()
	
	print("Created string: ", string)
	return GVReturnObject.new(SimpleScriptValue.new(string))

func create_array(properties: Dictionary):
	
	var array: Array = []
	var script_ended_error: String = "Script ended unexpectedly while creating array"
	
	if not (yield(advance(), "completed") if paused else advance()):
		return GVReturnObject.new(get_error(script_ended_error))
	
	while c != "]":
		
		if c == ",":
			if not (yield(advance(), "completed") if paused else advance()):
				return GVReturnObject.new(get_error(script_ended_error))
		
		while c == " ":
			if not (yield(advance(), "completed") if paused else advance()):
				return GVReturnObject.new(get_error(script_ended_error))
		
		var returnobject = get_value(true, properties, [",", "]"])
		if returnobject is GDScriptFunctionState:
			returnobject = yield(returnobject, "completed")
		if returnobject.value is SimpleScriptError:
			return returnobject
		array.append(returnobject.value.value)

	yield(advance(), "completed") if paused else advance()
	
	return GVReturnObject.new(SimpleScriptValue.new(array))

func create_dictionary(properties: Dictionary):
	pass

func get_error(message: String) -> SimpleScriptError:
	return SimpleScriptError.new(message, line, i, i_in_line, self)

func get_code_block(from_line: int = line, flatten_indentation: bool = true):
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
	if flatten_indentation:
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
