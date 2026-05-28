extends Node
class_name World

var terrain_grid: PackedFloat32Array
var forest_grid: PackedFloat32Array
var world_width: int
var world_height: int
var rows: int
var cols: int
var cities: Array[City] = []
var players: Array = []
var player_count: int = 2

func _init(p_player_count: int = 2):
	player_count = p_player_count
	calculate_size()
	generate_terrain()

func calculate_size() -> void:
	var area: float = player_count * Constants.CITIES_PER_PLAYER * Constants.AREA_PER_CITIES
	world_width = int(sqrt(area / Constants.RATIO))
	world_height = int(world_width * Constants.RATIO)
	rows = int(world_width / Constants.CELL_SIZE)
	cols = int(world_height / Constants.CELL_SIZE)
	world_width = rows * Constants.CELL_SIZE
	world_height = cols * Constants.CELL_SIZE
	
	terrain_grid = PackedFloat32Array()
	terrain_grid.resize((rows + 1) * (cols + 1))
	for i in range((rows + 1) * (cols + 1)):
		terrain_grid[i] = 0.0
	
	forest_grid = PackedFloat32Array()
	forest_grid.resize((rows + 1) * (cols + 1))
	for i in range((rows + 1) * (cols + 1)):
		forest_grid[i] = 0.0

func generate_terrain() -> void:
	# Generate basic terrain using simple noise
	var noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.05
	noise.fractal_octaves = 3
	
	# Generate terrain
	for y in range(cols + 1):
		for x in range(rows + 1):
			var value = noise.get_noise_2d(x, y)
			value = clamp((value - 0.2) + (coastal_elevation_bias(x, y) * 1.2 - 0.2), 0.0, 1.0)
			terrain_grid[y * (rows + 1) + x] = value
	
	# Generate forests
	var forest_noise = FastNoiseLite.new()
	forest_noise.seed = randi()
	forest_noise.frequency = 0.033
	forest_noise.fractal_octaves = 1
	
	for y in range(cols + 1):
		for x in range(rows + 1):
			var terrain_value = terrain_grid[y * (rows + 1) + x]
			var value = min(0.6, forest_noise.get_noise_2d(x, y)) * 2.0 + 0.3
			var plains_diff = max(0.0, (Constants.PLAINS.threshold + 0.1) - terrain_value)
			var hill_diff = max(0.0, terrain_value - (Constants.HILL.threshold - 0.1))
			var diff_mult = 10.0
			value = (value - (plains_diff * diff_mult)) - (hill_diff * diff_mult)
			forest_grid[y * (rows + 1) + x] = value
	
	place_cities()

func coastal_elevation_bias(x: float, y: float) -> float:
	var cx = rows / 2.0
	var cy = cols / 2.0
	var dx = abs(x - cx)
	var dy = abs(y - cy)
	var dist = sqrt(dx * dx + dy * dy)
	var max_dist = sqrt(cx * cx + cy * cy)
	var normalized_dist = dist / max_dist
	
	if normalized_dist <= 0.5:
		return 0.5 + max(normalized_dist, 0.25)
	else:
		return 1.0 - ((normalized_dist - 0.5) * 2.0)

func place_cities() -> void:
	cities.clear()
	var tries = 0
	var distance = Constants.CITY_DISTANCE
	
	while cities.size() < player_count * Constants.CITIES_PER_PLAYER:
		var cx = randi() % (rows + 1)
		var cy = randi() % (cols + 1)
		var terrain_value = terrain_grid[cy * (rows + 1) + cx]
		
		var valid = true
		if terrain_value <= Constants.PLAINS.threshold or terrain_value >= Constants.HILL.threshold:
			valid = false
		if forest_grid[cy * (rows + 1) + cx] >= Constants.THRESHOLD:
			valid = false
		
		for city in cities:
			var city_cx = int(city.position.x / Constants.CELL_SIZE)
			var city_cy = int(city.position.y / Constants.CELL_SIZE)
			var dist = abs(cx * Constants.CELL_SIZE - city.position.x) + abs(cy * Constants.CELL_SIZE - city.position.y)
			if dist < Constants.CELL_SIZE * distance:
				valid = false
				break
		
		if cx < 1 or cx > rows - 1 or cy < 1 or cy > cols - 1:
			valid = false
		
		if valid:
			cities.append(City.new(Vector2(cx * Constants.CELL_SIZE, cy * Constants.CELL_SIZE)))
			distance = Constants.CITY_DISTANCE
			tries = 0
		else:
			tries += 1
			if tries >= 100:
				distance = max(1, distance - 1)
				tries = 0
	
	setup_players()

func setup_players() -> void:
	players.clear()
	for i in range(player_count):
		players.append({"troops": [Troop.new(cities[i].position, i)], "border": [], "vision": []})
		cities[i].owner = i

func get_terrain_at(pos: Vector2) -> Constants.TerrainType:
	var gx = int(pos.x / Constants.CELL_SIZE)
	var gy = int(pos.y / Constants.CELL_SIZE)
	gx = clampi(gx, 0, rows)
	gy = clampi(gy, 0, cols)
	
	var terrain_value = terrain_grid[gy * (rows + 1) + gx]
	var forest_value = forest_grid[gy * (rows + 1) + gx]
	
	if forest_value > Constants.FOREST.threshold:
		return Constants.FOREST
	
	for terrain_type in Constants.TERRAIN_TYPES:
		if terrain_value > terrain_type.threshold and terrain_type != Constants.FOREST:
			return terrain_type
	
	return Constants.PLAINS

func get_grid_value(grid: PackedFloat32Array, x: float, y: float) -> float:
	var x1 = int(x)
	var y1 = int(y)
	var x2 = mini(x1 + 1, rows)
	var y2 = mini(y1 + 1, cols)
	
	var dx = x - x1
	var dy = y - y1
	
	var p11 = grid[y1 * (rows + 1) + x1]
	var p21 = grid[y1 * (rows + 1) + x2]
	var p12 = grid[y2 * (rows + 1) + x1]
	var p22 = grid[y2 * (rows + 1) + x2]
	
	var val = (p11 * (1.0 - dx) * (1.0 - dy) +
			   p21 * dx * (1.0 - dy) +
			   p12 * (1.0 - dx) * dy +
			   p22 * dx * dy)
	return val
