extends TileMapLayer

@export var Input_Grid = [
[1, 1, 1 ,1, 1], # Row 0
[2, 2, 2, 1, 1], # Row 1
[3, 3, 2, 2, 1],  # Row 2
[3, 3, 3, 2, 1]
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
	
	# generate_chunk(Vector2i(0,0)) # This *should* create the initial 10x10 chunk that the player starts in


# This just lets us print the array
func print_grid(grid_to_print : Array):
	for i in grid_to_print.size():
		var Row = "" 
		for y in grid_to_print[i].size():
			Row +=(str(grid_to_print[i][y]) + " ")
		print(Row)



# I assume we'll allways use n=2 but just in case 
# Currently each segment is stored as a 2d array
# So it stores it as Var[i][x][y] where I is the 2d array index
func split_grid(grid : Array, n : int):
	var all_segments = []

	for start_y in range((grid[0].size() - n) + 1):
		for start_x in range((grid.size()- n) + 1):
			var segment = []
			
			# Build the n x n array
			for x in range(n):
				var column = []
				for y in range(n):
					column.append(grid[start_x + x][start_y + y])
					
				segment.append(column)
				
			
			all_segments.append(segment)
			
			
	return all_segments

#Stolen from Online <3
func rotate_90(Array_2d : Array):
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

func Array_Dupe_Check(target_2d : Array, list_3d : Array):
	for existing in list_3d:
		if existing == target_2d: 
			return true
	return false


# If we want we can add reflection and flipping but I am to lazy to do that right now 
func Add_rotations(segments_3d : Array):
	var Grid_Post_Rotates = []
	
	# We only need to look at the orgional tiles
	for segment in segments_3d:
		var current_rotation = segment
		
		#We are just going to rotate and check. If it's new we add it 
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
		var current = segment
		current = reflect(current)
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
	if x>= size - 1: #move on once x is out of bounds
		x = 0
		y += 1
	
	#BASE CASE: once there are no y's to read, the grid is done
	if y >= size - 1:
		return arr
		
	#store current grid
	var curr_vals = [
		[arr[y][x], arr[y][x+1]],
		[arr[y+1][x], arr[y+1][x+1]]
	]
	#get valid segment options
	var options = get_valids(Seg_w_Rots, curr_vals)
	options.shuffle() #randomize
	#save current state so we can "undo" or backtrack when we fail
	var backup_grid = [
		arr[y][x], arr[y][x+1],
		arr[y+1][x], arr[y+1][x+1]
	]
	
	for choice in options:
		arr[y][x] = choice[0][0] #top left
		arr[y][x+1] = choice[0][1] #top right - moves one step to the right
		arr[y+1][x] = choice[1][0] #bottom left - moves one step down
		arr[y+1][x+1] = choice[1][1] #bottom right - moves one step down and right
		
		#RECURSIVE STEP: call backtrack
		#move to the next cell
		var result = backtrack(arr, x+1, y)
		
		#If there were valid options:
		if result !=null:
			return result
		#BACKTRACK: if we got to a dead end, reset grid:
		arr[y][x] = backup_grid[0]
		arr[y][x+1] = backup_grid[1]
		arr[y+1][x] = backup_grid[2]
		arr[y+1][x+1] = backup_grid[3]
		
	return null; #if nothing in loop worked, start func again
		
	
	
	
func generate_grid(n : int):
	var size = n
	var grid = []
	grid.resize(size)
	for i in range(size):
		var row = []
		row.resize(size)
		row.fill(0)
		grid[i] = row
	return grid

	
func generate_map():
	# 1. Initialize the 20x20 grid with 0s
	var grid = generate_grid(5)
	
	# Set a random seed at [0,0]
	grid[0][0] = randi_range(1, 3)
	
	var result = backtrack(grid, 0, 0) #start at top left
	if result != null:
		print("--Final Grid--")
		print_grid(result)
		return result
	else:
		print("--Failure: No valid configuration possible--")
		return null
		
	return grid
	
	"""
	# 2. Define sliding window traversal
	for y in range(grid.size()-1):
		for x in range(grid.size()-1):
			print("------")
			print_grid(grid) #This way we can see it build
			var window = [
				[grid[y][x], grid[y][x+1]],
				[grid[y+1][x], grid[y+1][x+1]]
			]
			
			# 3. Get valid options based on the window
			var options = get_valids(Seg_w_Rots, window)
			
			# --- ABORT CLAUSE ---
			if options.is_empty():
				print("Aborting: No valid patterns found for window at: ", Vector2(x, y))
				return null # Exits the function and returns nothing
			# --------------------
			
			# 4. Pick one randomly and overwrite the window
			var chosen_replacement = options[randi() % options.size()]
			
			grid[y][x]     = chosen_replacement[0][0]
			grid[y][x+1]   = chosen_replacement[0][1]
			grid[y+1][x]   = chosen_replacement[1][0]
			grid[y+1][x+1] = chosen_replacement[1][1]
			
	return grid
	"""
#- - - - - - - - - - - - - - - - 



# PLAYER REFERENCE
@export var player: Node2D

func _process(delta: float) -> void:
	if player == null:
		return
	
	var chunk = get_player_chunk(player.global_position)
	print("Player chunk = ", chunk)
	
	update_chunks(player.global_position) # ___STILL NEED PLAYER NODE___
	update_chunk_states()



# CHUNK SYSTEM OVERVIEW:
	# The world is divided into "chunks" (10x10 tile grids).
	# Each chunk is generated independently but tries to:
	# 1. Match its neighbors at edges.
	# 2. Stay consistent using our pattern system (Seg_w_Rots).
	# 3. Only generate when the player gets close.
	

# GET WHAT CHUNK THE PLAYER IS IN
func get_player_chunk(player_pos: Vector2) -> Vector2i:
	# Convert world position into chuck coordinates
		# Ex. world x=15, chunk_size=10 => chunk_pos.x=1
	return Vector2i(
		floor(player_pos.x / chunk_size), # Might need to factor in tile sizes here...
		floor(player_pos.y / chunk_size)
	)

# DRAW A GENERATED CHUNK
func draw_chunk(chunk_pos: Vector2i, grid: Array): # ___CHECK ME___
	# Convert chunk coordinate into world tile position
		# Ex. chunk(2,3) => world(20,30) if chunk_size=10
	var world_x = chunk_pos.x * chunk_size
	var world_y = chunk_pos.y * chunk_size
	
	# Loop through every tile in the chunk grid
	for y in range(grid.size()):
		for x in range(grid.size()):
			# Get tile value from generated chunk
			var tile_value = grid[y][x]
			
			# Place tile into TileMap at correct world position
			set_cell(Vector2i(world_x + x, world_y + y), tile_value)

# GENERATE A SINGLE CHUNK
func generate_chunk(chunk_pos: Vector2i):
	# If this chunk already exists, do nothing
	if chunk_states.has(chunk_pos):
		return
	
	# STEP 1: Create an empty chunk grid (all 0s)
	var grid = generate_grid(chunk_size)
	
	# STEP 2: Force edge matching with already-existing neighbors
	# This ensures that chunk borders align seamlessly
	apply_neighbor_constraints(grid, chunk_pos)
	
	# STEP 3: Seed the chunk with a random starting tile
	# This prevents fully deterministic generation
	grid[0][0] = randi_range(1,3)
	
	# STEP 4: Fill chunk using sliding 2x2 window approach
	# Moves across the grid and fill based on local tile constraints
	for y in range(grid.size() - 1):
		for x in range(grid.size() - 1):
			# BUILD CURRENT 2x2 WINDOW: This is the known area that has already been generated that we use to decide what tile comes next
			var window = [
				[grid[y][x], grid[y][x+1]],
				[grid[y+1][x], grid[y+1][x+1]]
			]
			
			# GET VALID TILE OPTIONS: Compare current 2x2 window against all known options
			# Seg_w_Rots is all the valid rotated/reflected tiles
			var options = get_valids(Seg_w_Rots, window)
			
			# SAFETY CHECK: If no pattern match, generation is impossible
			# Will hopefully be delt with eventually with back-tracking
			if options.is_empty():
				print("FAILED CHUNK at", chunk_pos)
				return # abort chunk generation for right now
			
			# PICK A RANDOM VALID TILE OPTION: Right now uses randomness while still respecting valid tile options
			# This is where I am not sure what we want to do when it comes to gaurenteeing a valid route
			var chosen = options[randi() % options.size()]
			
			# APPLY CHOSEN TILE: Overwrites the 2x2 region in the grid
			# Essentially "locks in" the tile decisions
			grid[y][x] = chosen[0][0]
			grid[y][x+1] = chosen[0][1]
			grid[y+1][x] = chosen[1][0]
			grid[y+1][x+1] = chosen[1][1]
	
	# STEP 5: Store generated chunk
	chunk_data[chunk_pos] = grid
	
	# STEP 6: Mark chunk state as generated but not fully surrounded yet
	chunk_states[chunk_pos] = 1
	
	# STEP 7: Draw to TileMap
	draw_chunk(chunk_pos, grid)

# CHUNK STREAMING
var last_chunk = Vector2i(-99999,99999)

func update_chunks(player_pos: Vector2):
	var current_chunk = get_player_chunk(player_pos)
	var chunk_radius = 1 # _____CHANGE THIS LATER ONCE WE KNOW IT WORKS_______
	
	if current_chunk == last_chunk:
		return
	
	for x in range(current_chunk.x - chunk_radius, current_chunk.x + chunk_radius + 1):
		for y in range(current_chunk.y - chunk_radius, current_chunk.y + chunk_radius + 1):
			var pos = Vector2i(x, y)
			
			if not chunk_states.has(pos):
				generate_chunk(pos)
	
	last_chunk = current_chunk

func update_chunk_states():
	# Marks chunks as fully surrounded or not
	for chunk_pos in chunk_states.keys():
		if chunk_states[chunk_pos] == 2:
			continue
		
		var full = true
		
		for offset in [
			Vector2i(1,0),
			Vector2i(-1,0),
			Vector2i(0,1),
			Vector2i(0,-1)
		]: 
			if not chunk_states.has(chunk_pos + offset):
				full = false
				break
		
		chunk_states[chunk_pos] = 2 if full else 1

# NEIGHBOR ALIGNMENT
func apply_neighbor_constraints(grid, chunk_pos):
	var neighbors = [
		Vector2i(-1, 0), # Left neighbor
		Vector2i(1, 0), # Right neighbor
		Vector2i(0, -1), # Top neighbor
		Vector2i(0, 1) # Bottom neighbor
	]
	
	for offset in neighbors:
		var neighbor_pos = chunk_pos + offset
		var neighbor = chunk_data.get(neighbor_pos, null)
		
		if neighbor == null:
			continue
		
		# LEFT Neighbor: Matches right edge
		if offset == Vector2i(-1, 0):
			for y in range(chunk_size):
				grid[y][0] = neighbor[y][chunk_size - 1]
		
		# RIGHT Neighbor: Matches left edge
		elif offset == Vector2i(1, 0):
			for y in range(chunk_size):
				grid[y][chunk_size - 1] = neighbor[y][0]
		
		# TOP Neighbor: Matches bottom edge
		elif offset == Vector2i(0, -1):
			for x in range(chunk_size):
				grid[0][x] = neighbor[chunk_size - 1][x]
		
		# BOTTOM Neighbor: Matches top edge
		elif offset == Vector2i(0, 1):
			for x in range(chunk_size):
				grid[chunk_size - 1][x] = neighbor[0][x]
