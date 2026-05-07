extends TileMapLayer
#as of now
#1 = all
#2 = down left
#3 = right
@export var Input_Grid = [
	[3, 1, 2, 1, 2], # Row 0
	[3, 1, 1, 1, 1], # Row 1
	[3, 2, 1, 2, 1], # Row 2
	[3, 1, 1, 1, 1]
]

# GENERATE TILE SET: These store all valid pattern variations used for generation
var Seg_w_Ref # segments + reflections
var Seg_w_Rots # segments + reflections + rotations

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
	print("|")
	print("--- Step 1: intital Grid  ---")
	print("|")
	print_grid(Input_Grid)
	# Break input grid into small NxN segments (here N = 2)
	var Segs = split_grid(Input_Grid, 2)
	print("|")
	print("--- Step 2: Segment into 2x2 Windows ---")
	print("|")
	for i in range(Segs.size()):
		print("--- Segment ", i, " ---")
		print_grid(Segs[i])
	print("|")
	print("--- Step 3: Add reflections ---") 
	print("|")
	# Add mirrored version of segments
	Seg_w_Ref = Add_reflections(Segs) # ___Not sure if it is adding the original segments in with the reflections or only the reflections___
	for j in range(Seg_w_Ref.size()):
		print("--- Segment ", j, " ---")
		print_grid(Seg_w_Ref[j])
	print("|")
	print("--- Step 4: Add rotations ---")
	print("|")
	# Add rotated version of original and reflected segments
	Seg_w_Rots = Add_rotations(Seg_w_Ref)
	for k in range(Seg_w_Rots.size()):
		print("--- Segment ", k, " ---")
		print_grid(Seg_w_Rots[k])
	print("|")
	print("--- Step 5: Building go ---")
	print("|")
	generate_map()

func _process(_delta: float) -> void:
	if player == null: return
	# ___STILL NEED PLAYER NODE___
	update_chunks(player.global_position)

# DRAW A GENERATED CHUNK
func draw_chunk(chunk_pos: Vector2i, grid: Array): # ___CHECK ME___
	# Convert chunk coordinate into world tile position
	# Ex. chunk(2,3) => world(20,30) if chunk_size=10
	var world_x = chunk_pos.x * chunk_size
	var world_y = chunk_pos.y * chunk_size
	
	# Loop through every tile in the chunk grid
	for y in range(grid.size()):
		for x in range(grid[y].size()):
			# Get tile value from generated chunk
			var val = grid[y][x]
			if val <= 0: continue
			
			# Use the value to pick the ATLAS SOURCE ID
			# Mapping 1, 2, 3 logic values to Atlas Source IDs 0, 1, 2
			var source_id = val - 1 
			var map_pos = Vector2i(world_x + x, world_y + y)
			
			# Place tile into TileMap at correct world position
			set_cell(map_pos, source_id, Vector2i(0, 0))

func generate_map():
	# 1. Initialize the 5x5 grid with 0s
	var grid = generate_grid(5)
	# Set a random seed at [0,0]
	grid[0][0] = randi_range(1, 3)
	var result = backtrack(grid, 0, 0) # start at top left
	if result != null:
		print("--Final Grid Generated--")
		print_grid(result)
		draw_chunk(Vector2i(0,0), result)
		return result
	print("--Backtrack Failed: No valid configuration possible--")
	return null

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

# If we want we can add reflection and flipping but I am to lazy to do that right now 
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

# I was getting lazy and I let Gemini write this section. All it does
# Is that it takes an input 2d segment X and the dictionary Y of valid tiles
# then it returns a dictionary Z of possible states that X could turn into
# It does this by treating all 0's as wildcards 
 
#- - - - - - - - - - - - - - - - 
# Ai Code plz check
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
			# If pattern value is 0, it's a wildcard; skip comparison
			if p_val == 0:
				continue
			# If values don't match, this slice is invalid
			if slice[y][x] != p_val:
				return false
	return true

#basic backtracking algorithm for if there are no valid matches
func backtrack(arr: Array, x: int, y: int) -> Variant:
	var size = arr.size()
	#move down row by row
	if x >= size - 1: #move on once x is out of bounds
		x = 0
		y += 1
	#BASE CASE: once there are no y's to read, the grid is done
	if y >= size - 1:
		return arr
	#store current grid
	var curr_vals = [[arr[y][x], arr[y][x+1]], [arr[y+1][x], arr[y+1][x+1]]]
	#get valid segment options
	var options = get_valids(Seg_w_Rots, curr_vals)
	options.shuffle() #randomize
	#save current state so we can "undo" or backtrack when we fail
	var backup_grid = [arr[y][x], arr[y][x+1], arr[y+1][x], arr[y+1][x+1]]
	for choice in options:
		arr[y][x] = choice[0][0]; arr[y][x+1] = choice[0][1]
		arr[y+1][x] = choice[1][0]; arr[y+1][x+1] = choice[1][1]
		#RECURSIVE STEP: call backtrack
		#move to the next cell
		var result = backtrack(arr, x + 1, y)
		#If there were valid options:
		if result != null: return result
		#BACKTRACK: if we got to a dead end, reset grid:
		arr[y][x] = backup_grid[0]; arr[y][x+1] = backup_grid[1]
		arr[y+1][x] = backup_grid[2]; arr[y+1][x+1] = backup_grid[3]
	return null #if nothing in loop worked, start func again

func generate_grid(n: int):
	var grid = []
	grid.resize(n)
	for i in range(n):
		var row = []
		row.resize(n)
		row.fill(0)
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
	if current_chunk == last_chunk: return
	generate_chunk(current_chunk)
	last_chunk = current_chunk

# GENERATE A SINGLE CHUNK
func generate_chunk(chunk_pos: Vector2i):
	# If this chunk already exists, do nothing
	if chunk_states.has(chunk_pos): return
	# STEP 1: Create an empty chunk grid (all 0s)
	var grid = generate_grid(chunk_size)
	# STEP 3: Seed the chunk with a random starting tile
	grid[0][0] = randi_range(1, 3)
	
	# Simplified chunk fill for testing
	# STEP 4: Fill chunk using sliding 2x2 window approach
	for y in range(chunk_size - 1):
		for x in range(chunk_size - 1):
			# BUILD CURRENT 2x2 WINDOW
			var window = [[grid[y][x], grid[y][x+1]], [grid[y+1][x], grid[y+1][x+1]]]
			var options = get_valids(Seg_w_Rots, window)
			if not options.is_empty():
				# PICK A RANDOM VALID TILE OPTION
				var chosen = options[randi() % options.size()]
				# APPLY CHOSEN TILE: Overwrites the 2x2 region in the grid
				grid[y][x] = chosen[0][0]; grid[y][x+1] = chosen[0][1]
				grid[y+1][x] = chosen[1][0]; grid[y+1][x+1] = chosen[1][1]
	
	# STEP 5: Store generated chunk
	chunk_data[chunk_pos] = grid
	# STEP 6: Mark chunk state as generated
	chunk_states[chunk_pos] = 1
	# STEP 7: Draw to TileMap
	draw_chunk(chunk_pos, grid)
