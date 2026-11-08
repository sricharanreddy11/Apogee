@tool
extends Control


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var steel := Color("#202b35")
	var rim := Color("#52626f")
	draw_rect(Rect2(Vector2(3, 3), size - Vector2(6, 6)), Color("#0b1218"), false, 5.0)
	draw_rect(Rect2(Vector2(9, 9), size - Vector2(18, 18)), rim, false, 1.5)
	for corner: Vector2 in [Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]:
		var inset := Vector2(-1.0 if corner.x > 0.0 else 1.0, -1.0 if corner.y > 0.0 else 1.0)
		var a := corner + Vector2(60, 0) * inset
		var b := corner + Vector2(0, 51) * inset
		draw_colored_polygon(PackedVector2Array([corner, a, b]), steel)
		draw_line(a, b, rim, 2.0, true)
		var bolt := corner + Vector2(15, 14) * inset
		draw_circle(bolt, 4.7, Color("#111820"), true, -1.0, true)
		draw_line(bolt - Vector2(2, 1), bolt + Vector2(2, 1), rim, 1.3, true)
