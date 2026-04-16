extends TileMapLayer
@export var Input_Grid = [
[1, 1, 1 ,1, 1], # Row 0
[2, 2, 2, 1, 1], # Row 1
[3, 3, 2, 2, 1],  # Row 2
[3, 3, 3, 2, 1]
]

var Seg_w_Rots

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("|")
	print("--- Step 1: intital Grid  ---")
	print("|")
	print_grid(Input_Grid)
	var Segs = split_grid(Input_Grid ,2)
	print("|")
	print("--- Step 2: Segmentate into 2x2 Windows ---")
	print("|")
	for i in range(Segs.size()):
		print("--- Segment ", i, " ---")
		print_grid(Segs[i])
	print("|")
	print("--- Step 3: Add All rottaions for Semments ---")
	print("|")
	Seg_w_Rots = Add_rotations(Segs)
	for j in range(Seg_w_Rots.size()):
		print("--- Segment ", j, " ---")
		print_grid(Seg_w_Rots[j])
	print("|")
	print("--- Step 4: Building go ---")
	print("|")
	generate_map()


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
#- - - - - - - - - - - - - - - - 




# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
