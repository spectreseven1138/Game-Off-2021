extends Control

signal script_resumed

const text_h_offset: float = 60.0

const error_text_colour: Color = Color.red
onready var console: RichTextLabel = $VBoxContainer/HSplitContainer/PanelContainer/RichTextLabel
onready var save_button: Button = $VBoxContainer/TopBar/SaveButton
onready var script_textedit: TextEdit = $VBoxContainer/HSplitContainer/TextEdit

const error_highlight_size_offset: float = 4.0
const error_colour: Color = Color.red
var error_arrow: TextureRect = TextureRect.new()
var error_highlight: ColorRect = ColorRect.new()
var highlighted_error: SimpleScriptError

var loaded_file: String = "res://script.ss"
var file_original_text: String
var run_script: SimpleScript

func _input(event: InputEvent):
	if event is InputEventKey and event.pressed and event.scancode == KEY_F11:
		OS.window_fullscreen = !OS.window_fullscreen

func _ready():
	
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
	
	for keyword_set in [SimpleScript.highlight_keywords, SimpleScript.BUILTIN_PROPERTIES, SimpleScriptFunction.BUILTIN_FUNCTIONS]:
		for keyword in keyword_set:
			script_textedit.add_keyword_color(keyword, Color.orangered)
		script_textedit.add_color_region(SimpleScript.string_char, SimpleScript.string_char, Color.yellow)
	
	var file: File = File.new()
	file.open(loaded_file, File.READ)
	file_original_text = file.get_as_text()
	file.close()
	script_textedit.text = file_original_text
	_on_TextEdit_text_changed()

func _on_Button_pressed():
	
	if $VBoxContainer/HBoxContainer/ClearOnRunCheckBox.pressed:
		_on_ClearButton_pressed()
	
	console.scroll_following = true
	run_script = SimpleScript.new(script_textedit.text, funcref(self, "stdout"), funcref(self, "stderr"))
	run_script.run()

func stdout(msg: String):
	console.bbcode_text += "\n" + msg

func stderr(error: SimpleScriptError):
	# Todo
#	run_script.paused = true
	var message: String = error.get_message()
	stdout(Utils.bbcode_colour_text(message, error_text_colour))
	highlight_error(error, true)
	
#	while true:
#		yield(get_tree(), "idle_frame")

func highlight_error(error: SimpleScriptError, jump_to_line: bool = false):
	highlighted_error = error
	
	var font: Font = script_textedit.get_font("font")
	var line_height: float = font.get_height() + script_textedit.get("custom_constants/line_spacing")
	var h_pos: float = font.get_string_size(run_script.source_code_lines[error.line].left(error.position_in_line)).x
	
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
	var file: File = File.new()
	file.open(loaded_file, File.WRITE)
	file.store_string(script_textedit.text)
	file.close()
	file_original_text = script_textedit.text
	_on_TextEdit_text_changed()

func _on_TextEdit_text_changed():
	save_button.text = "Save" if script_textedit.text == file_original_text else "Save *"

func _on_TextEdit_draw():
	if highlighted_error:
		highlight_error(highlighted_error)
