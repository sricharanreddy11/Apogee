extends Control

signal close_requested

var _scan: Tween


func _ready() -> void:
	%Close.pressed.connect(close_requested.emit)


func open() -> void:
	show()
	%Close.grab_focus()
	%ScanLine.position.y = 12
	_scan = create_tween().set_loops()
	_scan.tween_property(%ScanLine, "position:y", 235.0, 2.3)
	_scan.tween_interval(0.5)
	_scan.tween_callback(func() -> void: %ScanLine.position.y = 12)


func dismiss() -> void:
	_scan.kill()
	hide()
