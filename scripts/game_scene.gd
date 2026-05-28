extends Node2D

var game_manager: GameManager
var selected_troop: Troop = null
var current_path: Array = []
var camera_zoom: float = 1.0
var camera_pan: Vector2 = Vector2.ZERO
const MIN_ZOOM: float = 0.5
const MAX_ZOOM: float = 10.0
const ZOOM_SPEED: float = 0.1

func _ready() -> void:
	game_manager = GameManager.new()
	add_child(game_manager)
	await get_tree().process_frame

func _process(_delta: float) -> void:
	handle_input()
	queue_redraw()

func handle_input() -> void:
	# Camera pan with right click
	if Input.is_action_pressed("ui_right"):
		camera_pan.x -= 10
	if Input.is_action_pressed("ui_left"):
		camera_pan.x += 10
	if Input.is_action_pressed("ui_down"):
		camera_pan.y -= 10
	if Input.is_action_pressed("ui_up"):
		camera_pan.y += 10
	
	# Zoom with scroll wheel
	if Input.is_action_just_released("ui_scroll_up"):
		camera_zoom = min(camera_zoom + ZOOM_SPEED, MAX_ZOOM)
	if Input.is_action_just_released("ui_scroll_down"):
		camera_zoom = max(camera_zoom - ZOOM_SPEED, MIN_ZOOM)
	
	# Left click to select troop and draw path
	if Input.is_action_just_pressed("ui_accept"):
		handle_troop_selection()
	
	# Release to confirm path
	if Input.is_action_just_released("ui_accept"):
		if selected_troop != null and current_path.size() > 0:
			game_manager.set_troop_path(selected_troop, current_path)
			selected_troop = null
			current_path = []
	
	# Cancel path
	if Input.is_action_just_pressed("ui_cancel"):
		selected_troop = null
		current_path = []
	
	# Pause
	if Input.is_action_just_pressed("ui_focus_next"):  # Tab key
		if game_manager.is_paused:
			game_manager.unpause()
		else:
			game_manager.pause()

func handle_troop_selection() -> void:
	var mouse_pos = get_global_mouse_position() + camera_pan
	
	# Check if clicking on a troop
	for player_idx in range(game_manager.world.players.size()):
		var player = game_manager.world.players[player_idx]
		for troop in player["troops"]:
			if troop.position.distance_to(mouse_pos) < Constants.TROOP_R:
				if player_idx == 0:  # Only allow selecting player 1's troops for now
					selected_troop = troop
					current_path = []
					return
	
	# If dragging, add waypoint
	if selected_troop != null:
		current_path.append(mouse_pos)

func _draw() -> void:
	if game_manager == null or game_manager.world == null:
		return
	
	var offset = -camera_pan
	
	# Draw terrain
	draw_terrain(offset)
	
	# Draw cities
	draw_cities(offset)
	
	# Draw troops
	draw_troops(offset)
	
	# Draw current path being drawn
	if selected_troop != null:
		draw_set_transform(offset, 0, Vector2.ONE)
		draw_polyline(PackedVector2Array(current_path), Color.WHITE)
		for point in current_path:
			draw_circle(point, 3, Color.WHITE)

func draw_terrain(offset: Vector2) -> void:
	var world = game_manager.world
	var cell_size = Constants.CELL_SIZE
	
	for y in range(0, world.cols, 5):
		for x in range(0, world.rows, 5):
			var terrain_value = world.terrain_grid[y * (world.rows + 1) + x]
			var forest_value = world.forest_grid[y * (world.rows + 1) + x]
			
			var terrain = world.get_terrain_at(Vector2(x * cell_size, y * cell_size))
			var pos = Vector2(x * cell_size, y * cell_size) + offset
			draw_rect(Rect2(pos, Vector2(cell_size * 5, cell_size * 5)), terrain.color)

func draw_cities(offset: Vector2) -> void:
	for city in game_manager.world.cities:
		var pos = city.position + offset
		draw_circle(pos, Constants.CITY_R, Constants.CITY_COLOR)
		
		if city.owner >= 0:
			draw_circle(pos, Constants.CITY_R - 3, Constants.COLORS[city.owner])

func draw_troops(offset: Vector2) -> void:
	for player_idx in range(game_manager.world.players.size()):
		var player = game_manager.world.players[player_idx]
		var color = Constants.COLORS[player_idx]
		
		for troop in player["troops"]:
			var pos = troop.position + offset
			var health_ratio = troop.health / float(Constants.TROOP_HEALTH)
			
			draw_circle(pos, Constants.TROOP_R, color)
			
			# Draw health indicator
			var health_color = Color.GREEN.lerp(Color.RED, 1.0 - health_ratio)
			draw_circle(pos, Constants.TROOP_R * health_ratio, health_color)
			
			# Highlight selected troop
			if troop == selected_troop:
				draw_circle(pos, Constants.TROOP_R + 2, Color.WHITE)
			
			# Draw attack indicator
			if troop.attacking:
				draw_arc(pos, Constants.TROOP_R + 5, 0, TAU, 16, Color.YELLOW, 2.0)
