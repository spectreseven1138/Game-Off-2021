extends Control

signal script_resumed

const text_h_offset: float = 35.0

const error_text_colour: Color = Color.red
onready var console: RichTextLabel = $VBoxContainer/VSplitContainer/PanelContainer/RichTextLabel
onready var save_button: Button = $VBoxContainer/TopBar/SaveButton
onready var script_textedit: TextEdit = $VBoxContainer/VSplitContainer/HSplitContainer/TextEdit
onready var script_list: ItemList = $VBoxContainer/VSplitContainer/HSplitContainer/PanelContainer/ItemList

const error_highlight_size_offset: float = 4.0
const error_colour: Color = Color.red
var error_arrow: TextureRect = TextureRect.new()
var error_highlight: ColorRect = ColorRect.new()
var highlighted_error: SimpleScriptError

var opened_file: int = 0
var loaded_files: Array = []
var run_script: SimpleScript

func _input(event: InputEvent):
	if event is InputEventKey and event.pressed and event.scancode == KEY_F11:
		OS.window_fullscreen = !OS.window_fullscreen

func _ready():
	
	SSEngine.connect("stdout", self, "stdout")
	SSEngine.connect("stderr", self, "stderr")
	
	error_arrow.modulate = error_colour
	error_arrow.texture = preload("res://arrow.png")
	error_arrow.visible = false
	error_arrow.rect_scale = Vector2.ONE * 0.2
	script_textedit.add_child(error_arrow)
	
	error_highlight.color = error_colour
	error_highlight.color.a = 0.25
	error_highlight.visible = false
	error_highlight.rect_size.x = script_textedit.rect_size.x
	error_highlight.rect_size.y = script_textedit.get_font("font").get_height() + error_highlight_size_offset
	error_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	script_textedit.add_child(error_highlight)
	
	for keyword_set in [SimpleScript.highlight_keywords, SimpleScriptFunction.BUILTIN_FUNCTIONS]:
		for keyword in keyword_set:
			script_textedit.add_keyword_color(keyword, Color.orangered)
		script_textedit.add_color_region("'", "'", Color.yellow)
		script_textedit.add_color_region("\"", "\"", Color.yellow)
#		script_textedit.add_color_region("{", "}", Color.yellow)
#		script_textedit.add_color_region("[", "]", Color.yellow)
	
	$VBoxContainer/HBoxContainer/HaltOnErrorCheckBox.pressed = false
	_on_HaltOnErrorCheckBox_toggled(false)
	
	var result = Utils.get_dir_items(SSEngine.scripts_dir)
	assert(result is Array, "Error occurred while opening scripts dir (" + str(result) + ")")
	
	script_list.clear()
	
	var file: File = File.new()
	for path in result:
		file.open(SSEngine.scripts_dir + path, File.READ)
		loaded_files.append({"original_text": file.get_as_text(), "text": file.get_as_text(), "path": SSEngine.scripts_dir + path, "name": path})
		file.close()
		script_list.add_item(path)
	
	if not loaded_files.empty():
		open_file(0)
		script_list.select(0)

func open_file(file_index: int):
	opened_file = file_index
	script_textedit.text = loaded_files[opened_file]["text"]
	_on_TextEdit_text_changed()

func _on_Button_pressed():
	
	if $VBoxContainer/HBoxContainer/ClearOnRunCheckBox.pressed:
		_on_ClearButton_pressed()
	
	console.scroll_following = true
	_on_SaveButton_pressed()
	run_script = SSEngine.get_simplescript(loaded_files[opened_file]["name"])
	run_script.run()

func stdout(msg: String):
	console.bbcode_text += "\n" + msg

func stderr(error: SimpleScriptError):
	# Todo
	run_script.paused = true
	var message: String = error.get_message()
	stdout(Utils.bbcode_colour_text(message, error_text_colour))
	highlight_error(error, true)
	
#	while true:
#		yield(get_tree(), "idle_frame")

func highlight_error(error: SimpleScriptError, jump_to_line: bool = false):
	highlighted_error = error
	
	var font: Font = script_textedit.get_font("font")
	var line_height: float = font.get_height() + script_textedit.get("custom_constants/line_spacing")
	var h_pos: float = font.get_string_size(run_script.source_code_lines[min(error.line, len(run_script.source_code_lines) - 1)].left(error.position_in_line)).x
	
	error_arrow.rect_position = Vector2(h_pos + text_h_offset - script_textedit.scroll_horizontal, (line_height*error.line) + 6 - (script_textedit.scroll_vertical*line_height)) + (Vector2(-error_arrow.rect_size.x/2, -error_arrow.rect_size.y) * error_arrow.rect_scale)
	error_arrow.visible = true
	
	error_highlight.rect_position.y = (line_height*error.line) + 4 - (error_highlight_size_offset/2) - (script_textedit.scroll_vertical*line_height)
	error_highlight.visible = true
	
	if jump_to_line:
		script_textedit.scroll_vertical = error.line

func _on_ClearButton_pressed():
	console.clear()
	console.bbcode_text = ""

func _on_SaveButton_pressed():
	var data: Dictionary = loaded_files[opened_file]
	var file: File = File.new()
	file.open(data["path"], File.WRITE)
	file.store_string(data["text"])
	file.close()
	data["original_text"] = data["text"]
	_on_TextEdit_text_changed()

func _on_TextEdit_text_changed():
	save_button.text = "Save" if script_textedit.text == loaded_files[opened_file]["original_text"] else "Save *"
	error_arrow.visible = false
	error_highlight.visible = false
	highlighted_error = null
	loaded_files[opened_file]["text"] = script_textedit.text

func _on_TextEdit_draw():
	if highlighted_error:
		highlight_error(highlighted_error)

func _on_HaltOnErrorCheckBox_toggled(button_pressed: bool):
	SSEngine.halt_editor_on_error = button_pressed

func _on_TextEdit_gui_input(event: InputEvent):
	if event is InputEventKey and event.scancode == KEY_ENTER:
		var line: String = script_textedit.get_line(script_textedit.cursor_get_line() - 1)
		if not line.empty() and line[-1] == ":":
			script_textedit.insert_text_at_cursor("	")
		
	elif event.is_action_pressed("duplicate"):
		if script_textedit.get_selection_text().empty():
			var line: int = script_textedit.cursor_get_line()
			var column: int = script_textedit.cursor_get_column()
			script_textedit.text = script_textedit.text.insert(Utils.get_position_of_line(script_textedit.text, line + 1), script_textedit.get_line(line) + "\n")
			script_textedit.cursor_set_line(line + 1)
			script_textedit.cursor_set_column(column)
		else:
			var line: int = script_textedit.cursor_get_line()
			var column: int = script_textedit.cursor_get_column()
			var begin: Array = [script_textedit.get_selection_from_line(), script_textedit.get_selection_from_column()]
			var end: Array = [script_textedit.get_selection_to_line(), script_textedit.get_selection_to_column()]
			
			script_textedit.insert_text_at_cursor(script_textedit.get_selection_text().repeat(2))
			
			script_textedit.select(begin[0], begin[1], end[0], end[1])
			script_textedit.cursor_set_line(line)
			script_textedit.cursor_set_column(column)

func _on_ItemList_item_selected(index: int):
	open_file(index)
