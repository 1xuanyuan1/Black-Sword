class_name StoryOverlay
extends Control

signal closed(event_id: StringName)

@onready var title_label: Label = $Dimmer/Panel/Margin/Content/Title
@onready var body_label: RichTextLabel = $Dimmer/Panel/Margin/Content/Body
@onready var continue_button: Button = $Dimmer/Panel/Margin/Content/Continue

var event_id: StringName


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	continue_button.pressed.connect(_close)


func setup(definition: StoryEventDefinition, already_read: bool = false) -> void:
	event_id = definition.id
	title_label.text = definition.title
	body_label.text = definition.body
	continue_button.text = "跳过已读" if already_read else "继续"


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_close()


func _close() -> void:
	closed.emit(event_id)
	queue_free()
