extends TileMapLayer
#Globals
@export var Seed: int = 1
@export var player: Node2D
var neighbors = []


const max_Steps = 100000
const RIM_SIZE = 1 
const TOTAL_GRID_SIZE = Chunk_Size + (RIM_SIZE * 2) 
#	Chunking
var guidebook = []
const Chunk_Size = 10

#	Dict Building
var n = 3 #Size of Segments THIS HAS TO BE 3
const target_source_id = 0 #Sorce ID of the Tilemap
var tile_type_to_coords: Dictionary = {}
var tile_dict: Dictionary = {}

#	Tracking Chunks
var chunk_states = {}
var chunk_data = {}

var generation_queue: Array = []
var last_chunk = Vector2i(-99999, 99999)
var frame_counter = 0
const GENERATE_INTERVAL = 20

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
	
	# Initial entropy pass: Count neighbors for pre-set rim tiles
	for x in range(TOTAL_GRID_SIZE):
		for y in range(TOTAL_GRID_SIZE):
			if working_grid[x][y] != -1:
				_update_guidebook(x, y)
	var steps = 0

	while true:
		steps += 1
		if steps > max_Steps:
			print("Step Limit")
			break
		var pos = Find_Lowest(working_grid) 
		if pos == null: break # Success! Grid is full.
		
		
		
		var valids = Get_3x3_Valids(_get_neighbors(pos.x, pos.y, working_grid))
		
		if valids.is_empty():
			# --- Backtracking Logic ---
			if stack.is_empty(): 
				print("Contradiction reached with no stack. Generation impossible.")
				return [] 
			var last = stack.pop_back()
			_undo_guidebook(last.pos.x, last.pos.y)
			working_grid[last.pos.x][last.pos.y] = -1
			last.valids.erase(last.chosen)
			
			if not last.valids.is_empty():
				var next_choice = last.valids[randi() % last.valids.size()]
				working_grid[last.pos.x][last.pos.y] = next_choice
				_update_guidebook(last.pos.x, last.pos.y)
				stack.push_back({"pos": last.pos, "valids": last.valids, "chosen": next_choice})
			continue 
		else:
			
			# --- Collapse Tile ---
			var chosen = valids[randi() % valids.size()]
			working_grid[pos.x][pos.y] = chosen
			_update_guidebook(pos.x, pos.y)
			stack.push_back({"pos": pos, "valids": valids, "chosen": chosen})
			
	var Export = _extract_core(working_grid)
	print_grid(Export)
	return Export

func _extract_core(working_grid: Array) -> Array:
	var result_grid = []
	for x in range(RIM_SIZE, Chunk_Size + RIM_SIZE):
		var col = []
		for y in range(RIM_SIZE, Chunk_Size + RIM_SIZE):
			col.append(working_grid[x][y])
		result_grid.append(col)
	return result_grid


func _Generate(chunk_pos: Vector2i) -> void:
	# Initialize 12x12 grid with -1 (wildcards)
	var input_grid = []
	for i in range(TOTAL_GRID_SIZE):
		var col = []
		for j in range(TOTAL_GRID_SIZE):
			col.append(-1)
		input_grid.append(col)

	# Fetch all 8 neighboring chunks
	var n_chunk  = chunk_data.get(chunk_pos + Vector2i( 0, -1))
	var s_chunk  = chunk_data.get(chunk_pos + Vector2i( 0,  1))
	var w_chunk  = chunk_data.get(chunk_pos + Vector2i(-1,  0))
	var e_chunk  = chunk_data.get(chunk_pos + Vector2i( 1,  0))
	var nw_chunk = chunk_data.get(chunk_pos + Vector2i(-1, -1))
	var ne_chunk = chunk_data.get(chunk_pos + Vector2i( 1, -1))
	var sw_chunk = chunk_data.get(chunk_pos + Vector2i(-1,  1))
	var se_chunk = chunk_data.get(chunk_pos + Vector2i( 1,  1))

	# Cardinal Rims
	for i in range(Chunk_Size):
		if n_chunk: input_grid[i + RIM_SIZE][0]                  = n_chunk[i][Chunk_Size - 1]
		if s_chunk: input_grid[i + RIM_SIZE][TOTAL_GRID_SIZE - 1] = s_chunk[i][0]
		if w_chunk: input_grid[0][i + RIM_SIZE]                  = w_chunk[Chunk_Size - 1][i]
		if e_chunk: input_grid[TOTAL_GRID_SIZE - 1][i + RIM_SIZE] = e_chunk[0][i]

	# Corner Rims
	if nw_chunk: input_grid[0][0]                                    = nw_chunk[Chunk_Size - 1][Chunk_Size - 1]
	if ne_chunk: input_grid[TOTAL_GRID_SIZE - 1][0]                  = ne_chunk[0][Chunk_Size - 1]
	if sw_chunk: input_grid[0][TOTAL_GRID_SIZE - 1]                  = sw_chunk[Chunk_Size - 1][0]
	if se_chunk: input_grid[TOTAL_GRID_SIZE - 1][TOTAL_GRID_SIZE - 1] = se_chunk[0][0]

	var result = Generate_Chunk(input_grid)

	if result.is_empty():
		result = []
		for x in range(Chunk_Size):
			var col = []
			for y in range(Chunk_Size):
				col.append(0)
			result.append(col)

	chunk_data[chunk_pos] = result
	chunk_states[chunk_pos] = 2
	draw_chunk(chunk_pos, result)

#==============================
#===== Entropy Checker ========
#==============================

func Find_Lowest(working_grid: Array) -> Variant:
	if guidebook.is_empty() or guidebook.size() < TOTAL_GRID_SIZE:
		_clear_guidebook()

	var best_score = -1
	var best_candidates = []

	for x in range(RIM_SIZE, TOTAL_GRID_SIZE - RIM_SIZE):
		for y in range(RIM_SIZE, TOTAL_GRID_SIZE - RIM_SIZE):
			if working_grid[x][y] != -1:
				continue

			var score = guidebook[x][y]
			if score == 8:
				continue

			if score > best_score:
				best_score = score
				best_candidates = [Vector2i(x, y)]
			elif score == best_score:
				best_candidates.append(Vector2i(x, y))

	if best_candidates.is_empty():
		return null
	return best_candidates[randi() % best_candidates.size()]



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
			if dx == 0 and dy == 0: continue
			var nx = x + dx
			var ny = y + dy
			if nx >= 0 and nx < TOTAL_GRID_SIZE and ny >= 0 and ny < TOTAL_GRID_SIZE:
				guidebook[nx][ny] += 1

func _undo_guidebook(x: int, y: int):
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0: continue
			var nx = x + dx
			var ny = y + dy
			if nx >= 0 and nx < TOTAL_GRID_SIZE and ny >= 0 and ny < TOTAL_GRID_SIZE:
				guidebook[nx][ny] -= 1

func _clear_guidebook():
	guidebook.clear()
	for i in range(TOTAL_GRID_SIZE):
		var col = []
		for j in range(TOTAL_GRID_SIZE): col.append(0)
		guidebook.append(col)

# ==============================
# ========= Draw Chunk =========
# ==============================

func draw_chunk(chunk_pos: Vector2i, grid: Array) -> void:
	# grid is column-major: grid[x][y]
	var world_x = chunk_pos.x * Chunk_Size
	var world_y = chunk_pos.y * Chunk_Size

	for x in range(grid.size()):
		for y in range(grid[x].size()):
			var val = grid[x][y]
			if val == -1:
				continue
			var map_pos = Vector2i(world_x + x, world_y + y)
			if tile_type_to_coords.has(val):
				var entry = tile_type_to_coords[val]
				set_cell(map_pos, entry["source_id"], entry["coords"])
			else:
				print("Warning: no tile found for tile_type ", val)

# ==============================
# ======= Chunk Streaming ======
# ==============================

func _update_player_chunk() -> void:
	var current_chunk = _get_player_chunk(player.global_position)
	if current_chunk == last_chunk:
		return
	last_chunk = current_chunk

	var state = chunk_states.get(current_chunk, 0)

	# Only act if player is on an un-activated chunk or newly generated space
	if state != 1 and state != 2:
		# If the spawn chunk or current chunk isn't initialized, track it
		chunk_states[current_chunk] = 2
	elif state == 1:
		# Promote self from queued/generating to active player chunk
		chunk_states[current_chunk] = 2

	var cardinal_offsets = [
		Vector2i(0, -1), # North
		Vector2i(0, 1),  # South
		Vector2i(-1, 0), # West
		Vector2i(1, 0)   # East
	]

	# Enqueue only cardinal neighbors
	for offset in cardinal_offsets:
		var neighbor = current_chunk + offset
		if chunk_states.get(neighbor, 0) == 0:
			chunk_states[neighbor] = 1
			generation_queue.append(neighbor)

func _process_queue() -> void:
	while not generation_queue.is_empty():
		var next = generation_queue.pop_front()
		if not chunk_data.has(next):
			print("Generating: ", next, " Current Q: ", generation_queue)
			_Generate(next)
			break 

func _get_player_chunk(player_pos: Vector2) -> Vector2i:
	return Vector2i(
		floor(player_pos.x / (16 * Chunk_Size)),
		floor(player_pos.y / (16 * Chunk_Size))
	)

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

	for x in range(width):        # Outer loop handles X (Columns)
		var column = []
		for y in range(height):   # Inner loop handles Y (Rows)
			var map_pos = Vector2i(min_x + x, min_y + y)
			var tile_data = get_cell_tile_data(map_pos)
		
			if tile_data != null:
				var tile_type = tile_data.get_custom_data_by_layer_id(layer_index)
				column.append(tile_type if tile_type != null else 0)
			else:
				column.append(0)
		custom_grid.append(column) # Appending columns! Now it is safely [x][y]
		
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


func split_grid(grid: Array):
	var all_segments = []
	var cols = grid.size()
	var rows = grid[0].size()
	
	# Loop stops early enough to fit a 3x3 window
	for x in range(cols - n + 1):
		for y in range(rows - n + 1):
			var segment = []
			for i in range(n):
				var col_data = []
				for j in range(n):
					col_data.append(grid[x + i][y + j])
				segment.append(col_data)
			all_segments.append(segment)
	return all_segments


func rotate_90(Array_2d: Array):
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
	var reflected = Array_2d.duplicate(true) 
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

func Get_3x3_Valids(neighbors: Array) -> Array:
	var valid_tile_ids = []
	
	for key in tile_dict.keys():
		var template = tile_dict[key]
		var is_match = true
		
		for x in range(3):
			for y in range(3):
				var grid_val = neighbors[x][y]
				var tmpl_val = template[x][y]
				if grid_val != -1 and grid_val != tmpl_val:
					is_match = false
					break
			if not is_match: break
		
		if is_match:
			var center_tile_id = template[1][1]
			if not valid_tile_ids.has(center_tile_id):
				valid_tile_ids.append(center_tile_id)
			
	return valid_tile_ids

func _get_neighbors(tx: int, ty: int, working_grid: Array) -> Array:
	neighbors = []
	for x in range(3):
		var col = []
		for y in range(3):
			var gx = tx - 1 + x
			var gy = ty - 1 + y
			if gx < 0 or gx >= TOTAL_GRID_SIZE or gy < 0 or gy >= TOTAL_GRID_SIZE:
				col.append(-1)
			else:
				col.append(working_grid[gx][gy])
		neighbors.append(col)
	return neighbors
#==============================
#========== Util ==============
#==============================

func print_grid(grid_to_print: Array):
	for i in grid_to_print.size():
		var row_str = "" 
		for y in grid_to_print[i].size():
			row_str += (str(grid_to_print[i][y]) + " ")
		print(row_str)



# ==============================
# ======= Main =======
# ==============================
func _test_generate() -> void:
	var test_grid = []
	for x in range(TOTAL_GRID_SIZE):
		var col = []
		for y in range(TOTAL_GRID_SIZE):
			col.append(-1)
		test_grid.append(col)
	
	test_grid[1][0] = 1
	
	print("--- Input Grid ---")
	print_grid(test_grid)
	
	var result = Generate_Chunk(test_grid)
	
	print("--- Output Grid ---")
	print_grid(result)


func _ready() -> void:
	build_tile_type_lookup()
	var input_patterns = read_grid_from_tilemap()
	if input_patterns.is_empty(): return
	
	# Build patterns from existing map
	var segments = split_grid(input_patterns)
	
	#!!! BROKEN NOW AND DON'T WORK ON THE MAZE !!!
	#segments = Add_rotations(segments)
	#segments = Add_reflections(segments)
	
	tile_dict = segments_to_dict(segments)
	print("tile_dict size: ", tile_dict.size())
	
	var spawn_pos = Vector2i(0, 0)
	_Generate(spawn_pos)

func _process(_delta: float) -> void:
	if player == null or tile_dict.is_empty(): return
	
	frame_counter += 1
	if frame_counter % GENERATE_INTERVAL == 0:
		_update_player_chunk()
		_process_queue()
