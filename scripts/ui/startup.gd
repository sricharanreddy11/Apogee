extends Control

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const TITLE_DURATION := 3.0
const GODOT_DURATION := 1.8
const TITLE_FADE := 0.3

@onready var _title_card: Control = $TitleCard
@onready var _credit: Control = $TitleCard/Credit
@onready var _caption: Label = $TitleCard/Credit/Caption
@onready var _names: HBoxContainer = $TitleCard/Credit/Names
@onready var _godot_card: Control = $GodotCard


func _ready() -> void:
	_caption.modulate.a = 0.0
	var credit_top := _credit.offset_top
	_credit.offset_top += 22.0
	var reveal := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	reveal.tween_property(_credit, "offset_top", credit_top, 1.15).set_delay(0.18)
	reveal.tween_property(_caption, "modulate:a", 1.0, 0.48).set_delay(0.18)

	var delay := 0.43
	for item: Label in _names.get_children():
		item.modulate.a = 0.0
		reveal.tween_property(item, "modulate:a", 1.0, 0.48).set_delay(delay)
		delay += 0.16

	await get_tree().create_timer(TITLE_DURATION - TITLE_FADE).timeout
	var fade := create_tween()
	fade.tween_property(_title_card, "modulate:a", 0.0, TITLE_FADE)
	await fade.finished

	_title_card.hide()
	_godot_card.show()
	await get_tree().create_timer(GODOT_DURATION).timeout
	get_tree().change_scene_to_file(MAIN_MENU)
