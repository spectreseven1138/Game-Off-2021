extends Control

signal script_resumed

const error_text_colour: Color = Color.red
onready var console: RichTextLabel = $VBoxContainer/HSplitContainer/PanelContainer/RichTextLabel

var run_script: SimpleScript

func _on_Button_pressed():
	
	if $VBoxContainer/HBoxContainer/ClearOnRunCheckBox.pressed:
		_on_ClearButton_pressed()
	
	console.scroll_following = true
	run_script = SimpleScript.new($VBoxContainer/HSplitContainer/TextEdit.text, funcref(self, "stdout"), funcref(self, "stderr"))
	run_script.run()

func stdout(msg: String):
	console.bbcode_text += "\n" + msg

func stderr(error: SimpleScriptError):
	# Todo
#	run_script.paused = true
	stdout(Utils.bbcode_colour_text(error.get_message(), error_text_colour))
	
	while true:
		yield(get_tree(), "idle_frame")

func _on_ClearButton_pressed():
	console.clear()
	console.bbcode_text = ""
