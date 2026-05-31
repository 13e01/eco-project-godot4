extends Area2D

func _on_body_entered(_body: Node2D) -> void:
	EventBus.garbage_collected.emit()
	queue_free()