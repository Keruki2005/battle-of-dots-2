extends Node
class_name GameManager

var world: World
var current_player: int = 0
var game_speed: float = 1.0
var is_paused: bool = false
var game_time: float = 0.0
var frame_count: int = 0

func _ready() -> void:
	world = World.new(Constants.PLAYERS)
	get_tree().root.add_child.call_deferred(world)

func _process(delta: float) -> void:
	if is_paused:
		return
	
	game_time += delta
	frame_count += 1
	
	# Run game logic at server FPS
	var target_frame_time = 1.0 / Constants.SERVER_FPS
	if game_time >= target_frame_time:
		update_game_logic()
		game_time = 0.0

func update_game_logic() -> void:
	if world == null:
		return
	
	# Update troops
	for player_idx in range(Constants.PLAYERS):
		if player_idx < world.players.size():
			var player = world.players[player_idx]
			var troops_to_remove = []
			
			for troop in player["troops"]:
				update_troop(troop, player_idx)
				if troop.health <= 0:
					troops_to_remove.append(troop)
			
			for troop in troops_to_remove:
				player["troops"].erase(troop)
	
	# Update cities
	update_cities()

func update_troop(troop: Troop, player_idx: int) -> void:
	var terrain = world.get_terrain_at(troop.position)
	
	# Update health based on distance from city
	update_troop_health(troop, player_idx, terrain)
	
	# Move troop
	if troop.path.size() > 0:
		move_troop_to_target(troop, terrain)
	
	# Handle combat
	check_combat(troop, player_idx, terrain)

func update_troop_health(troop: Troop, player_idx: int, terrain: Constants.TerrainType) -> void:
	var owned_cities = []
	for city in world.cities:
		if city.owner == player_idx:
			owned_cities.append(city)
	
	var healing_power = Constants.NO_CITY_HEALING
	
	if owned_cities.size() > 0:
		var closest_city = owned_cities[0]
		var min_dist = troop.position.distance_to(closest_city.position)
		for city in owned_cities:
			var dist = troop.position.distance_to(city.position)
			if dist < min_dist:
				closest_city = city
				min_dist = dist
		
		var city_dist = troop.position.distance_to(closest_city.position)
		var dist_penal = max(
			((city_dist + Constants.CITY_DIST_PENAL_START) / Constants.CITY_DIST_PENAL_FULL),
			Constants.MIN_CITY_DIST_PENAL
		)
		healing_power = 1.0 - dist_penal
	
	troop.health += healing_power / Constants.HEALING_DIVISOR
	if troop.health > Constants.TROOP_HEALTH:
		troop.health = Constants.TROOP_HEALTH

func move_troop_to_target(troop: Troop, terrain: Constants.TerrainType) -> void:
	if troop.path.size() == 0:
		return
	
	var target = Vector2(troop.path[0])
	var direction = troop.position.direction_to(target)
	var distance = terrain.speed_mod * Constants.TERRAIN_SPEED_MOD
	
	var new_pos = troop.position + direction * distance
	
	# Check if reached waypoint
	if troop.position.distance_to(target) < (terrain.speed_mod * Constants.TERRAIN_SPEED_MOD * 2):
		troop.path.remove_at(0)
	
	# Check collisions and terrain
	var final_terrain = world.get_terrain_at(new_pos)
	if final_terrain != Constants.MOUNTAIN:
		if new_pos.x >= 0 and new_pos.x <= world.world_width and new_pos.y >= 0 and new_pos.y <= world.world_height:
			troop.position = new_pos

func check_combat(troop: Troop, player_idx: int, terrain: Constants.TerrainType) -> void:
	troop.attacking = false
	
	for other_player_idx in range(world.players.size()):
		if other_player_idx == player_idx:
			continue
		
		var other_player = world.players[other_player_idx]
		for other_troop in other_player["troops"]:
			var dist = troop.position.distance_to(other_troop.position)
			if dist < Constants.ATTACK_DIST:
				troop.attacking = true
				var attack_power = terrain.attack_mod / 25.0
				other_troop.health -= attack_power

func update_cities() -> void:
	for city in world.cities:
		var players_in_city = []
		
		# Check which players have troops in this city
		for player_idx in range(world.players.size()):
			var player = world.players[player_idx]
			for troop in player["troops"]:
				if troop.position.distance_to(city.position) < Constants.CITY_R:
					if player_idx not in players_in_city:
						players_in_city.append(player_idx)
		
		var last_owner = city.owner
		if players_in_city.size() == 1:
			city.owner = players_in_city[0]
		elif players_in_city.size() == 0:
			# City ownership doesn't change
			pass
		else:
			# Multiple players in city, no one owns it
			city.owner = -1
		
		if last_owner != city.owner:
			city.timer = 0
			city.path = []
		
		# Produce troops
		if city.owner >= 0:
			city.timer += 1
			var owned_city_count = 0
			for c in world.cities:
				if c.owner == city.owner:
					owned_city_count += 1
			
			var troops_per_city = float(world.players[city.owner]["troops"].size()) / float(owned_city_count)
			
			if city.timer >= (Constants.SERVER_FPS * (Constants.CITY_TROOP_GEN_RATE * max(1, troops_per_city))) and troops_per_city < Constants.CITY_TROOP_CAPACITY:
				var new_troop = Troop.new(city.position + Vector2(randf_range(-6, 6), randf_range(-6, 6)), city.owner)
				world.players[city.owner]["troops"].append(new_troop)
				city.timer = 0

func pause() -> void:
	is_paused = true

func unpause() -> void:
	is_paused = false

func set_troop_path(troop: Troop, path: Array) -> void:
	troop.path = path
