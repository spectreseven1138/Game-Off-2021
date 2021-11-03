extends Control

const error_text_colour: Color = Color.red

onready var console: RichTextLabel = $VBoxContainer/HSplitContainer/PanelContainer/RichTextLabel

func _on_Button_pressed():
	console.scroll_following = true
	var script: SimpleScipt = SimpleScipt.new($VBoxContainer/HSplitContainer/TextEdit.text, funcref(self, "stdout"), funcref(self, "stderr"))
	script.run()

func stdout(msg: String):
	console.bbcode_text += "\n" + msg

func stderr(error: SimpleScriptError):
	stdout(colour_text(error.get_message(), error_text_colour))

func colour_text(text: String, colour: Color):
	return "[color=#" + colour.to_html() + "]" + text + "[/color]"

func _on_ClearButton_pressed():
	console.clear()
