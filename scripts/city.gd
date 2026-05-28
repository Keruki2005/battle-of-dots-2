extends Node
class_name City

var position: Vector2
var owner: int = -1  # -1 means unclaimed
var timer: int = 0
var path: Array = []

func _init(p_position: Vector2):
	position = p_position
