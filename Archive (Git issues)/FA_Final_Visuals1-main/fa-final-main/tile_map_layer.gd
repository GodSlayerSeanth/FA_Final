extends TileMapLayer
#as of now
#1 = all
#2 = down left
#3 = right
@export var Input_Grid  = []

# Declaring these as Global now
var backtrack_steps = 0
const MAX_BACKTRACK_STEPS = 1500


# - - - - - - - - - - - - - - - - - - - - - - - - -
func read_grid_from_tilemap() -> Array:
	var custom_grid = []
	
	var used_cells = get_used_cells()
	if used_cells.is_empty():
		print("Warning: No hand-drawn tiles found on this layer to read from!")
		return []
		
	var min_x = used_cells[0].x
	var max_x = used_cells[0].x
	var min_y = used_cells[0].y
	var max_y = used_cells[0].y
	
	for cell in used_cells:
		min_x = min(min_x, cell.x)
		max_x = max(max_x, cell.x)
		min_y = min(min_y, cell.y)
		max_y = max(max_y, cell.y)
		
	var width = max_x - min_x + 1
	var height = max_y - min_y + 1
	
	var custom_data_layer_name = "tile_type"
	var layer_index = tile_set.get_custom_data_layer_by_name(custom_data_layer_name)
	if layer_index == -1:
		print("ERROR: Could not find Custom Data Layer named '", custom_data_layer_name, "'")
		return []


	for y in range(height):
		var row = []
		for x in range(width):
			var map_pos = Vector2i(min_x + x, min_y + y)
			var tile_data = get_cell_tile_data(map_pos)
			
			if tile_data != null:
				var tile_type = tile_data.get_custom_data_by_layer_id(layer_index)
				if tile_type != null:
					row.append(tile_type)
				else:
					row.append(0) 
			else:
				row.append(0)
		custom_grid.append(row)
		
	print("Successfully read Input_Grid from editor layout! Grid size: ", width, "x", height)
	return custom_grid


var tile_type_to_coords: Dictionary = {}
func build_tile_type_lookup():
	var tileset = tile_set
	if tileset == null:
		print("Error: TileSet is null!")
		return
		
	tile_type_to_coords.clear()
	
	# 1. Find the internal index of our custom data layer
	var custom_data_layer_name = "tile_type"
	var layer_index = tileset.get_custom_data_layer_by_name(custom_data_layer_name)
	if layer_index == -1:
		print("ERROR: Could not find Custom Data Layer named '", custom_data_layer_name, "' in your TileSet!")
		print("Please check your TileSet inspector settings and ensure a Custom Data Layer is created and named exactly 'tile_type'.")
		return
	
	var target_source_id = 3 
	if not tileset.has_source(target_source_id):
		print("Error: TileSet does not contain a source with ID ", target_source_id)
		return
		
	var source = tileset.get_source(target_source_id)
	if not source is TileSetAtlasSource:
		print("Error: Source ID ", target_source_id, " is not an Atlas Source")
		return
		
	# 2. Iterate and fetch tile data using the resolved index
	for i in range(source.get_tiles_count()):
		var coords = source.get_tile_id(i)
		var tile_data = source.get_tile_data(coords, 0)
		
		if tile_data == null:
			continue
			
		# Query using the integer layer_index instead of the string name
		var tile_type = tile_data.get_custom_data_by_layer_id(layer_index)
		
		if tile_type != null:
			tile_type_to_coords[tile_type] = {
				"source_id": target_source_id,
				"coords": coords
			}
			
	print("Tile lookup successfully built! Mapped types: ", tile_type_to_coords.keys())
	
# - - - - - - - - - - - - - - - -

# GENERATE TILE SET: These store all valid pattern variations used for generation
var Seg_w_Ref: Array = [] # segments + reflections
var Seg_w_Rots: Array = [] # segments + reflections + rotations

# CHUNK GENERATION: Tracks generation state of each chunk in the world
# 0 = not generated
# 1 = generated but at least one neighbor is not
# 2 = itself and neighbors are fully generated
var chunk_states = {} # Dictionary: Vector2i -> int (0,1,2)
var chunk_data = {} # Dictionary: Vector2i -> the actual generated grid (2D array)
var chunk_size = 10
var last_chunk = Vector2i(-99999, 99999)

# PLAYER REFERENCE
@export var player: Node2D

# STARTUP: Called when the node enters the scene tree for the first time.
func _ready() -> void:
	build_tile_type_lookup()
	Input_Grid = read_grid_from_tilemap()
	clear()
	
	if Input_Grid.is_empty():
		print("Error: Input_Grid is empty. Cannot proceed with generation.")
		return

	print("|")
	print("--- Step 1: intital Grid  ---")
	print("|")
	print_grid(Input_Grid)
	print("--- Step 2: Segmentation  ---")
	# Break input grid into small NxN segments (here N = 2)
	var Segs = split_grid(Input_Grid, 2)
	Seg_w_Ref = Add_reflections(Segs)
	Seg_w_Rots = Add_rotations(Seg_w_Ref)
	
	print("|")
	print("--- Step 3: Building go ---")
	print("|")
	var spawn_chunk_pos = Vector2i(0, 0)
	var result = generate_map(chunk_size)
	
	if result != null:
		chunk_data[spawn_chunk_pos] = result
		chunk_states[spawn_chunk_pos] = 2 # Mark as fully generated
		draw_chunk(spawn_chunk_pos, result)
		print("Painted spawn chunk successfully!")
	else:
		print("Failed to generate spawn chunk.")
	

func _process(_delta: float) -> void:
	if player == null: 
		return
	# Safety Guard: Do not run chunk generation if we haven't loaded our rotation patterns yet
	if Seg_w_Rots.is_empty(): 
		return
	# ___STILL NEED PLAYER NODE___
	update_chunks(player.global_position)

# DRAW A GENERATED CHUNK
func draw_chunk(chunk_pos: Vector2i, grid: Array):
	var world_x = chunk_pos.x * chunk_size
	var world_y = chunk_pos.y * chunk_size

	for y in range(grid.size()):
		for x in range(grid[y].size()):
			var val = grid[y][x]
			if val == -1:
				continue

			var map_pos = Vector2i(world_x + x, world_y + y)

			if tile_type_to_coords.has(val):
				var entry = tile_type_to_coords[val]
				set_cell(map_pos, entry["source_id"], entry["coords"])
			else:
				print("Warning: no tile found for tile_type ", val)

func generate_map(size: int = 5) -> Variant:
	var attempts = 0
	var max_attempts = 15
	
	# Pre-build our positions list
	var positions = []
	for y in range(size - 1):
		for x in range(size - 1):
			positions.append(Vector2i(x, y))
	
	while attempts < max_attempts:
		var grid = generate_grid(size)
		
		if not tile_type_to_coords.is_empty():
			var available_types = tile_type_to_coords.keys()
			grid[0][0] = available_types[randi() % available_types.size()]
		else:
			grid[0][0] = 1
			
		backtrack_steps = 0
		var success = backtrack(grid, 0, positions)
		if success:
			print("--Final Grid Generated Successfully on attempt ", attempts + 1, "--")
			return grid
			
		attempts += 1
	
	print("--Backtrack Failed: Generating fallback safe grid--")
	var fallback_grid = generate_grid(size)
	for y in range(size):
		fallback_grid[y].fill(1) 
	return fallback_grid

# This just lets us print the array
func print_grid(grid_to_print: Array):
	for i in grid_to_print.size():
		var row_str = "" 
		for y in grid_to_print[i].size():
			row_str += (str(grid_to_print[i][y]) + " ")
		print(row_str)

# I assume we'll allways use n=2 but just in case 
# Currently each segment is stored as a 2d array
# So it stores it as Var[i][x][y] where I is the 2d array index
func split_grid(grid: Array, n: int):
	var all_segments = []
	var rows = grid.size()
	var cols = grid[0].size()
	for y in range(rows - n + 1):
		for x in range(cols - n + 1):
			var segment = []
			# Build the n x n array
			for i in range(n):
				var row_data = []
				for j in range(n):
					row_data.append(grid[y + i][x + j])
				segment.append(row_data)
			all_segments.append(segment)
	return all_segments

#Stolen from Online <3
func rotate_90(Array_2d: Array):
	var n = Array_2d.size()
	var rotated = []
	for x in range(n):
		var col = []
		col.resize(n)
		rotated.append(col)
	for x in range(n):
		for y in range(n):
			rotated[n - 1 - y][x] = Array_2d[x][y]
	return rotated

# REFLECTION: Flip rows
func reflect(Array_2d: Array) -> Array:
	# Flip grid vertically (top <=> bottom)
	var reflected = Array_2d.duplicate()
	reflected.reverse()
	return reflected

func Array_Dupe_Check(target_2d: Array, list_3d: Array):
	for existing in list_3d:
		if existing == target_2d: return true
	return false


func Add_rotations(segments_3d: Array):
	var Grid_Post_Rotates = []
	# We only need to look at the original tiles
	for segment in segments_3d:
		var current_rotation = segment
		# We are just going to rotate and check. If it's new we add it 
		for r in range(4):
			if not Array_Dupe_Check(current_rotation, Grid_Post_Rotates):
				Grid_Post_Rotates.append(current_rotation)
			current_rotation = rotate_90(current_rotation)
	return Grid_Post_Rotates

# ADD REFLECTIONS
func Add_reflections(segments_3d: Array):
	var Transformed_Grid = []
	# Only reflect original segments
	for segment in segments_3d:
		if not Array_Dupe_Check(segment, Transformed_Grid):
			Transformed_Grid.append(segment)
		var current = reflect(segment)
		if not Array_Dupe_Check(current, Transformed_Grid):
			Transformed_Grid.append(current)
	return Transformed_Grid



#- - - - - - - - - - - - - - - - 
## Returns an array of all slices from [source_3d_array] that match [pattern_2d_array].
## 0 in [pattern_2d_array] acts as a wildcard.
func get_valids(source_3d_array: Array, pattern_2d_array: Array) -> Array:
	var matches := []
	var height = pattern_2d_array.size()
	if height == 0: return []
	var width = pattern_2d_array[0].size()
	for slice in source_3d_array:
		if _is_match(slice, pattern_2d_array, height, width):
			matches.append(slice)
	return matches

## Helper function to compare a single 2D slice against the pattern
func _is_match(slice: Array, pattern: Array, height: int, width: int) -> bool:
	for y in range(height):
		for x in range(width):
			var p_val = pattern[y][x]
			# If pattern value is -1, it's a wildcard; skip comparison
			if p_val == -1:
				continue
			# If values don't match, this slice is invalid
			if slice[y][x] != p_val:
				return false
	return true


# This kept getting caught in an infinate loop. Asking Claude to help with the loop it cleaned the code and produced this function
# it removed the recursive call anb now works on a stack array. This is done to stop it from crashing like it was before
 
func backtrack(arr: Array, pos_index: int, positions: Array) -> bool:
	backtrack_steps += 1
	if backtrack_steps > MAX_BACKTRACK_STEPS:
		return false # Hard stop to prevent freezes/crashes on impossible border layouts

	# If we successfully resolved every single 2x2 position, we are done!
	if pos_index >= positions.size():
		return true

	var pos = positions[pos_index]
	var x = pos.x
	var y = pos.y

	# Capture the original state of this 2x2 window before making modifications
	var snapshot = [
		arr[y][x], arr[y][x+1],
		arr[y+1][x], arr[y+1][x+1]
	]

	# Extract what is currently written on the board in this 2x2 space
	var curr_vals = [
		[snapshot[0], snapshot[1]],
		[snapshot[2], snapshot[3]]
	]

	# Find patterns from our database that match the current tiles (and respect wildcards)
	var options = get_valids(Seg_w_Rots, curr_vals)
	options.shuffle()

	# Try every valid option
	for choice in options:
		# Apply the choice, making sure we don't overwrite pre-seeded borders
		arr[y][x]     = choice[0][0] if snapshot[0] == -1 else snapshot[0]
		arr[y][x+1]   = choice[0][1] if snapshot[1] == -1 else snapshot[1]
		arr[y+1][x]   = choice[1][0] if snapshot[2] == -1 else snapshot[2]
		arr[y+1][x+1] = choice[1][1] if snapshot[3] == -1 else snapshot[3]

		# Recursively try to solve the next position
		if backtrack(arr, pos_index + 1, positions):
			return true # Solved! Pass success back up the chain

		# If the choice led to a dead end, undo it (restore snapshot) and try next option
		arr[y][x]     = snapshot[0]
		arr[y][x+1]   = snapshot[1]
		arr[y+1][x]   = snapshot[2]
		arr[y+1][x+1] = snapshot[3]

	return false #if nothing in loop worked, start func again
# - - - - - - - - - - - - -
func generate_grid(n: int):
	var grid = []
	grid.resize(n)
	for i in range(n):
		var row = []
		row.resize(n)
		row.fill(-1) #Switching to using 100 as the wildcard
		grid[i] = row
	return grid

# GET WHAT CHUNK THE PLAYER IS IN
func get_player_chunk(player_pos: Vector2) -> Vector2i:
	# Convert world position into chuck coordinates
	# Factoring in tile size (16) and chunk size
	return Vector2i(floor(player_pos.x / (16 * chunk_size)), floor(player_pos.y / (16 * chunk_size)))

# CHUNK STREAMING
func update_chunks(player_pos: Vector2):
	var current_chunk = get_player_chunk(player_pos)
	if current_chunk == last_chunk: 
		return
	last_chunk = current_chunk

	var current_state = chunk_states.get(current_chunk, 0)
	if current_state == 2: 
		return

	# Step 1: Generate missing chunks the area around the player
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var chunk_pos = current_chunk + Vector2i(dx, dy)
			if not chunk_states.has(chunk_pos):
				generate_chunk(chunk_pos)  

	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var chunk_pos = current_chunk + Vector2i(dx, dy)
			var dist = maxi(absi(dx), absi(dy))
			if dist == 0:
				chunk_states[chunk_pos] = 2
			elif dist == 1:
				chunk_states[chunk_pos] = 1
			else:
				if chunk_states.get(chunk_pos, 0) == 0:
					chunk_states[chunk_pos] = 1

# GENERATE A SINGLE CHUNK
# I am going to edit this because I don't unde
func generate_chunk(chunk_pos: Vector2i):
	# If this chunk already exists, do nothing
	if chunk_states.has(chunk_pos): return
	
	
	# STEP 1: Create an empty chunk grid (all 0s)
#	var grid = generate_grid(chunk_size)
	# STEP 3: Seed the chunk with a random starting tile
#	grid[0][0] = randi_range(1, 3)
	
	# Simplified chunk fill for testing
	# STEP 4: Fill chunk using sliding 2x2 window approach
#	for y in range(chunk_size - 1):
#		for x in range(chunk_size - 1):
			# BUILD CURRENT 2x2 WINDOW
#			var window = [[grid[y][x], grid[y][x+1]], [grid[y+1][x], grid[y+1][x+1]]]
#			var options = get_valids(Seg_w_Rots, window)
#			if not options.is_empty():
				# PICK A RANDOM VALID TILE OPTION
#				var chosen = options[randi() % options.size()]
				# APPLY CHOSEN TILE: Overwrites the 2x2 region in the grid
#				grid[y][x] = chosen[0][0]; grid[y][x+1] = chosen[0][1]
#				grid[y+1][x] = chosen[1][0]; grid[y+1][x+1] = chosen[1][1]
	
	# STEP 5: Store generated chunk
#	chunk_data[chunk_pos] = grid
	# STEP 6: Mark chunk state as generated
#	chunk_states[chunk_pos] = 1
	# STEP 7: Draw to TileMap
#	draw_chunk(chunk_pos, grid)
	
	# I am going to overwrite your function to properly grab the sides
	# Additonally If this chunk is already generated, skip it
	chunk_states[chunk_pos] = 1 
	var grid = generate_grid(chunk_size)
	
	var north_neighbor = chunk_data.get(chunk_pos + Vector2i.UP)
	var south_neighbor = chunk_data.get(chunk_pos + Vector2i.DOWN)
	var west_neighbor  = chunk_data.get(chunk_pos + Vector2i.LEFT)
	var east_neighbor  = chunk_data.get(chunk_pos + Vector2i.RIGHT)
	
	# Seed borders from generated neighbors
	if north_neighbor != null:
		for x in range(chunk_size):
			grid[0][x] = north_neighbor[chunk_size - 1][x]
	if west_neighbor != null:
		for y in range(chunk_size):
			grid[y][0] = west_neighbor[y][chunk_size - 1]
	if south_neighbor != null:
		for x in range(chunk_size):
			grid[chunk_size - 1][x] = south_neighbor[0][x]
	if east_neighbor != null:
		for y in range(chunk_size):
			grid[y][chunk_size - 1] = east_neighbor[y][0]
			
	# If completely isolated, seed a random starting block
	if north_neighbor == null and south_neighbor == null and west_neighbor == null and east_neighbor == null:
		if not tile_type_to_coords.is_empty():
			var available_types = tile_type_to_coords.keys()
			grid[0][0] = available_types[randi() % available_types.size()]
		else:
			grid[0][0] = 1 # Grass fallback
		
	# Build the list of 2x2 windows we need to solve
	var positions = []
	for y in range(chunk_size - 1):
		for x in range(chunk_size - 1):
			positions.append(Vector2i(x, y))
			
	# Reset step counter before solving
	backtrack_steps = 0
	
	# Try to solve the grid using recursive backtracking
	var success = backtrack(grid, 0, positions)
	
	if success:
		chunk_data[chunk_pos] = grid
		draw_chunk(chunk_pos, grid)
		print("Chunk successfully generated at: ", chunk_pos)
	else:
		# Fallback handling to prevent freezes/crashes from conflicting neighbor borders
		print("Warning: Chunk at ", chunk_pos, " was unsolvable within limits. Using safe fallback.")
		var fallback_grid = generate_grid(chunk_size)
		for y in range(chunk_size):
			for x in range(chunk_size):
				if grid[y][x] != -1:
					fallback_grid[y][x] = grid[y][x]
				else:
					# Default to your safe grass/ground tile (type 1)
					fallback_grid[y][x] = 1 
					
		chunk_data[chunk_pos] = fallback_grid
		draw_chunk(chunk_pos, fallback_grid)
