extends TileMapLayer
#Globals
#	Chunking
var guidebook = []
const Chunk_Size = 10

#	Dict Building
var n = 2 #Size of Segments
const target_source_id = 3 #Sorce ID of the Tilemap
var tile_type_to_coords: Dictionary = {}
var tile_dict: Dictionary = {}
#==============================
#======= Chunk Gen ============
#==============================
#Input:
#	12x12 Grid 
#		The rim of this Grid should be provided by the side chunks
#		For the first tile we will simply generate it with the rim as -1's (Wildcard)
#OutPut:
#	10x10 Grid -> A tile
#		This is the tile that should be drawn by Draw_Chunk
#Logic:
#
func Generate_Chunk(grid: Array) -> Array:
	var stack = []
	var working_grid = grid.duplicate(true)
	
	_clear_guidebook()
	
	# Read the entire 12x12 (Chunk_Size + 2) input grid buffer
	for x in range(Chunk_Size + 2):
		for y in range(Chunk_Size + 2):
			if working_grid[x][y] != -1:
				_update_guidebook(x, y)
	
	var offsets = [[0,0], [-1,0], [0,-1], [-1,-1]]
	var steps = 0
	
	while true:
		var result = Find_Lowest(working_grid)
		
		# If no more valid empty cells with neighbors are found, we're done
		if result == null:
			print("Find_Lowest returned null after ", steps, " steps — done.")
			break
		
		var tx = result.x
		var ty = result.y
		var window_pos = result.z
		
		var wx = tx + offsets[window_pos][0]
		var wy = ty + offsets[window_pos][1]
		var local_x = tx - wx
		var local_y = ty - wy
		
		var window = [
			[working_grid[wx][wy],   working_grid[wx+1][wy]],
			[working_grid[wx][wy+1], working_grid[wx+1][wy+1]]
		]
		
		var valids = Get_Valids(window)
		print("Step ", steps, " | Cell (", tx, ",", ty, ") | Valids: ", valids.size())
		
		if valids.is_empty():
			print("No valids at (", tx, ",", ty, ") — backtracking. Stack size: ", stack.size())
			var success = _backtrack(stack, working_grid, offsets)
			if not success:
				print("Backtrack failed completely — returning empty.")
				return [] # Complete generation failure 
		else:
			var chosen_idx = randi() % valids.size()
			var chosen = valids[chosen_idx]
			var final_tile_value = chosen[local_x][local_y]
			
			print("  Chose tile value: ", final_tile_value)
			stack.push_back({
				"pos": [tx, ty],
				"window_pos": window_pos,
				"tried": [final_tile_value]
			})
			
			working_grid[tx][ty] = final_tile_value
			_update_guidebook(tx, ty)
		steps += 1  # <-- ADD
	# Extract core chunk (dropping the 1-tile wide buffer rim)
	var result_grid = []
	for i in range(1, Chunk_Size + 1):
		var row = []
		for j in range(1, Chunk_Size + 1):
			row.append(working_grid[i][j])
		result_grid.append(row)
	
	return result_grid


func _backtrack(stack: Array, working_grid: Array, offsets: Array) -> bool:
	while not stack.is_empty():
		var entry = stack.back()
		var tx = entry["pos"][0]
		var ty = entry["pos"][1]
		var window_pos = entry["window_pos"]
		
		# Restore this specific target cell back to uncollapsed status
		_undo_guidebook(tx, ty)
		working_grid[tx][ty] = -1
		
		# Rebuild the local sliding context window
		var wx = tx + offsets[window_pos][0]
		var wy = ty + offsets[window_pos][1]
		var local_x = tx - wx
		var local_y = ty - wy
		
		var window = [
			[working_grid[wx][wy],   working_grid[wx+1][wy]],
			[working_grid[wx][wy+1], working_grid[wx+1][wy+1]]
		]
		
		var valids = Get_Valids(window)
		
		var possible_values = []
		for v in valids:
			var val = v[local_x][local_y]
			if val not in possible_values:
				possible_values.append(val)
		
		# Filter out tile IDs we've already tried and failed with at this exact cell
		var untried = possible_values.filter(func(val): return val not in entry["tried"])
		
		if untried.is_empty():
			# All local single-tile options exhausted for this context path, pop and step further back
			stack.pop_back()
			continue
		
		# Pull a fresh scalar option
		var chosen_value = untried[randi() % untried.size()]
		entry["tried"].append(chosen_value)
		
		# Apply the choice and refresh your entropy tracking maps
		working_grid[tx][ty] = chosen_value
		_update_guidebook(tx, ty)
		return true
	
	return false


#==============================
#===== Entropy Checker ========
#==============================
func Find_Lowest(working_grid: Array) -> Variant:
	var best_score = 0
	var best_candidates = []

	for x in range(1, Chunk_Size + 1):
		for y in range(1, Chunk_Size + 1):
			if working_grid[x][y] != -1:
				continue

			var score = guidebook[x][y]

			if score == 0 or score >= 8:
				continue

			if score > best_score:
				best_score = score
				best_candidates = [[x, y]]
			elif score == best_score:
				best_candidates.append([x, y])

	if best_candidates.is_empty():
		return null

	var target = best_candidates[randi() % best_candidates.size()]
	var window_pos = _best_window_pos(target[0], target[1])

	return Vector3i(target[0], target[1], window_pos)


func _best_window_pos(tx: int, ty: int) -> int:
	var offsets = [[0, 0], [-1, 0], [0, -1], [-1, -1]]
	var best_pos = -1
	var best_entropy = -1

	for pos in range(4):
		var wx = tx + offsets[pos][0]
		var wy = ty + offsets[pos][1]

		# Ensure the entire 2x2 window fits inside the 0-10 index space (12x12 grid)
		if wx < 0 or wy < 0 or wx + 1 >= Chunk_Size + 2 or wy + 1 >= Chunk_Size + 2:
			continue

		var entropy_sum = 0
		for dx in range(2):
			for dy in range(2):
				var cx = wx + dx
				var cy = wy + dy
				if cx == tx and cy == ty:
					continue
				entropy_sum += guidebook[cx][cy]

		if entropy_sum > best_entropy:
			best_entropy = entropy_sum
			best_pos = pos

	return best_pos

#==============================
#======= Guide Book ===========
#==============================
# The Guidebook is an Entropy guide
# Since all positions can have a max of 8 neighbors we tack entropy from 0-8 
# Where we care about the highest non 8 value 

#Updating the Entropy Values in the Guidebook
func _update_guidebook(x: int, y: int):
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx = x + dx
			var ny = y + dy
			if nx >= 0 and nx < Chunk_Size+2 and ny >= 0 and ny < Chunk_Size+2:
				guidebook[nx][ny] += 1

func _undo_guidebook(x: int, y: int):
	# Subtract 1 from all 8 neighbors of (x, y)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx = x + dx
			var ny = y + dy
			if nx >= 0 and nx < Chunk_Size+2 and ny >= 0 and ny < Chunk_Size+2:
				guidebook[nx][ny] -= 1


#Clear it before every use
func _clear_guidebook():
	for i in range(Chunk_Size+2):
		for j in range(Chunk_Size+2):
			guidebook[i][j] = 0

#==============================
#===== Dict Sec Builder =======
#==============================
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


func build_tile_type_lookup():
	var tileset = tile_set
	if tileset == null:
		print("Error: TileSet is null!")
		return
		
	tile_type_to_coords.clear()
	
	var custom_data_layer_name = "tile_type"
	var layer_index = tileset.get_custom_data_layer_by_name(custom_data_layer_name)
	if layer_index == -1:
		print("ERROR: Could not find Custom Data Layer named '", custom_data_layer_name, "' in your TileSet!")
		print("Please check your TileSet inspector settings and ensure a Custom Data Layer is created and named exactly 'tile_type'.")
		return
	
	if not tileset.has_source(target_source_id):
		print("Error: TileSet does not contain a source with ID ", target_source_id)
		return
		
	var source = tileset.get_source(target_source_id)
	if not source is TileSetAtlasSource:
		print("Error: Source ID ", target_source_id, " is not an Atlas Source")
		return
		
	for i in range(source.get_tiles_count()):
		var coords = source.get_tile_id(i)
		var tile_data = source.get_tile_data(coords, 0)
		
		if tile_data == null:
			continue
			
		var tile_type = tile_data.get_custom_data_by_layer_id(layer_index)
		
		if tile_type != null:
			tile_type_to_coords[tile_type] = {
				"source_id": target_source_id,
				"coords": coords
			}
			
	print("Tile lookup successfully built! Mapped types: ", tile_type_to_coords.keys())


func split_grid(grid: Array, n: int):
	var all_segments = []
	var rows = grid.size()
	var cols = grid[0].size()
	for y in range(rows - n + 1):
		for x in range(cols - n + 1):
			var segment = []
			for i in range(n):
				var row_data = []
				for j in range(n):
					row_data.append(grid[y + i][x + j])
				segment.append(row_data)
			all_segments.append(segment)
	return all_segments


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


func reflect(Array_2d: Array) -> Array:
	var reflected = Array_2d.duplicate()
	reflected.reverse()
	return reflected


func Array_Dupe_Check(target_2d: Array, list_3d: Array):
	for existing in list_3d:
		if existing == target_2d: return true
	return false


func Add_rotations(segments_3d: Array):
	var Grid_Post_Rotates = []
	for segment in segments_3d:
		var current_rotation = segment
		for r in range(4):
			if not Array_Dupe_Check(current_rotation, Grid_Post_Rotates):
				Grid_Post_Rotates.append(current_rotation)
			current_rotation = rotate_90(current_rotation)
	return Grid_Post_Rotates


func Add_reflections(segments_3d: Array):
	var Transformed_Grid = []
	for segment in segments_3d:
		if not Array_Dupe_Check(segment, Transformed_Grid):
			Transformed_Grid.append(segment)
		var current = reflect(segment)
		if not Array_Dupe_Check(current, Transformed_Grid):
			Transformed_Grid.append(current)
	return Transformed_Grid


func segments_to_dict(segments_3d: Array) -> Dictionary:
	var result = {}
	for i in range(segments_3d.size()):
		result[i] = segments_3d[i]
	return result

func Get_Valids(pattern: Array) -> Array:
	var valid_keys = []
	
	for key in tile_dict.keys():
		var tile = tile_dict[key]
		var is_match = true
		
		for y in range(pattern.size()):
			for x in range(pattern[y].size()):
				if pattern[y][x] == -1:
					continue
				if tile[y][x] != pattern[y][x]:
					is_match = false
					break
			if not is_match:
				break
		
		if is_match:
			valid_keys.append(key)
	
	return valid_keys

#==============================
#========== Main ==============
#==============================
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	var grid = read_grid_from_tilemap()
	var segments = split_grid(grid, n)
	segments = Add_reflections(segments)
	segments = Add_rotations(segments)
	tile_dict = segments_to_dict(segments)
	
	
	#When we're ready we need to build the guidebook 
	guidebook.clear()
	for i in range(Chunk_Size+2): # Give it a slight padding buffer of 12x12 to completely prevent edge crashes
		var row = []
		for j in range(Chunk_Size+2):
			row.append(0)
		guidebook.append(row)
	
	print("tile_dict size: ", tile_dict.size())
	print("Generating test chunk...")
	var test_input = []
	for i in range(Chunk_Size + 2):
		var row = []
		for j in range(Chunk_Size + 2):
			row.append(-1)
			test_input.append(row)
	var test_result = Generate_Chunk(test_input)
	print("Chunk generation complete. Result size: ", test_result.size())
	print("Result: ", test_result)



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
