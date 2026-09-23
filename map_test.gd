@tool
extends Control

@onready var scroll_container: ScrollContainer = $".."
@onready var v_scroll_bar = scroll_container.get_v_scroll_bar()
var default_font: Font

# Grid Dimensions
var grid_row: int = 16
var grid_col: int = 8

var sep_x: float = 60.0
var sep_y: float = 80.0

# Graph: Key: Vector2i(row, col) -> Value: Array[Vector2i] (outgoing targets)
var node_connections: Dictionary = {}
var all_nodes: Dictionary = {} 

var col_color: Dictionary = {
	0: Color.FIREBRICK,
	1: Color.FIREBRICK,
	2: Color.CORNFLOWER_BLUE,
	3: Color.CORNFLOWER_BLUE,
	4: Color.FOREST_GREEN,
	5: Color.FOREST_GREEN,
	6: Color.GOLD,
	7: Color.GOLD,
}

func _ready() -> void:
	default_font = ThemeDB.fallback_font
	custom_minimum_size = Vector2(sep_x * (grid_col + 2), sep_y * (grid_row - 1) + 120)
	randomize()
	generate_valid_map()
	queue_redraw()
	
	await get_tree().process_frame
	if v_scroll_bar:
		scroll_container.scroll_vertical = int(v_scroll_bar.max_value)

func _draw() -> void:
	var map_width: float = sep_x * (grid_col - 1)
	var start_x: float = (size.x - map_width) / 2.0
	var start_y: float = 60.0

	# 1. Draw Edges
	for from_node in node_connections.keys():
		var pos_a := Vector2(start_x + sep_x * from_node.y, start_y + sep_y * (grid_row - 1 - from_node.x))
		for to_node in node_connections[from_node]:
			var pos_b := Vector2(start_x + sep_x * to_node.y, start_y + sep_y * (grid_row - 1 - to_node.x))
			draw_line(pos_a, pos_b, Color(0.15, 0.15, 0.15, 0.85), 3.5, true)

	# 2. Draw Nodes
	for node in all_nodes.keys():
		var pos := Vector2(start_x + sep_x * node.y, start_y + sep_y * (grid_row - 1 - node.x))
		var color: Color = col_color.get(node.y, Color.WHITE)
		
		# Boss node at the very top
		if node.x == grid_row - 1:
			color = Color.PURPLE
			draw_circle(pos, 18, color)
			draw_circle(pos, 18, Color.BLACK, false, 3.0)
		else:
			draw_circle(pos, 12, color)
			draw_circle(pos, 12, Color.BLACK, false, 2.5)

		var text = "(%d,%d)" % [node.x, node.y]
		draw_string(default_font, pos + Vector2(14, 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.BLACK)

# Generates and validates until math rules are satisfied (typically 1st try)
func generate_valid_map() -> void:
	var attempts = 0
	while attempts < 20:
		attempts += 1
		generate_raw_map()
		if validate_map_health():
			print("Map successfully generated in %d attempt(s)!" % attempts)
			return
	print("Warning: Used best attempt after 20 tries.")

func generate_raw_map() -> void:
	node_connections.clear()
	all_nodes.clear()

	# STEP 1: Department Guaranteed Seeding
	# Force at least 1 path in each of the 4 department zones:
	# [0-1 Sales], [2-3 Legal], [4-5 HR], [6-7 IT]
	var starting_cols: Array[int] = [
		randi_range(0, 1),
		randi_range(2, 3),
		randi_range(4, 5),
		randi_range(6, 7)
	]
	# Add 2 more random paths for density (total: 6 paths)
	starting_cols.append(randi_range(1, 3))
	starting_cols.append(randi_range(4, 6))
	starting_cols.shuffle()

	for start_c in starting_cols:
		build_path(start_c)

	# STEP 2: StS Branch Injection Pass (Creates forks and merges)
	inject_branches()

func build_path(starting_col: int) -> void:
	var current_col: int = starting_col

	for row in range(grid_row - 1):
		var current_node = Vector2i(row, current_col)
		all_nodes[current_node] = true

		var next_row = row + 1
		var next_col: int = current_col

		# Final Row: Funnel into Central Boss
		if next_row == grid_row - 1:
			next_col = 3 # Central Boss column
		elif next_row == grid_row - 2:
			# Pre-boss row: funnel inwards
			var candidates: Array[int] = []
			for offset in [-1, 0, 1]:
				var c = current_col + offset
				if c >= 2 and c <= 5 and not would_cross(row, current_col, next_row, c):
					candidates.append(c)
			next_col = candidates.pick_random() if not candidates.is_empty() else clampi(current_col, 2, 5)
		else:
			# Normal rows
			var valid_cols: Array[int] = []
			for offset in [-1, 0, 1]:
				var c = current_col + offset
				if c >= 0 and c < grid_col:
					if not would_cross(row, current_col, next_row, c):
						valid_cols.append(c)

			if valid_cols.is_empty():
				valid_cols.append(current_col)

			# Slight merge bias (25%) so paths don't stay completely parallel
			var existing_nodes: Array[int] = []
			for c in valid_cols:
				if all_nodes.has(Vector2i(next_row, c)):
					existing_nodes.append(c)

			if not existing_nodes.is_empty() and randf() < 0.25:
				next_col = existing_nodes.pick_random()
			else:
				next_col = valid_cols.pick_random()

		var next_node = Vector2i(next_row, next_col)
		all_nodes[next_node] = true

		if not node_connections.has(current_node):
			node_connections[current_node] = []
		if not node_connections[current_node].has(next_node):
			node_connections[current_node].append(next_node)

		current_col = next_col

# THE STS SECRET SAUCE:
# Scans nodes with only 1 exit and ties them to adjacent paths
func inject_branches() -> void:
	for node in all_nodes.keys():
		# Don't inject branches into pre-boss or boss floors
		if node.x >= grid_row - 3:
			continue

		var current_exits: Array = node_connections.get(node, [])
		# If a node only has 1 outgoing path, give it a 35% chance to fork!
		if current_exits.size() == 1 and randf() < 0.35:
			var next_row = node.x + 1
			var offsets = [-1, 1]
			offsets.shuffle()

			for offset in offsets:
				var candidate_col = node.y + offset
				var candidate_node = Vector2i(next_row, candidate_col)

				# Only connect if that neighbor node already exists on the next row!
				if all_nodes.has(candidate_node):
					if not would_cross(node.x, node.y, next_row, candidate_col):
						node_connections[node].append(candidate_node)
						break # Stop after adding 1 branch

func would_cross(r1: int, c1: int, r2: int, c2: int) -> bool:
	for from_node in node_connections.keys():
		if from_node.x != r1:
			continue
		for to_node in node_connections[from_node]:
			if to_node.x != r2:
				continue
			var existing_c1 = from_node.y
			var existing_c2 = to_node.y

			# Lines cross if one steps right while the other steps left
			if existing_c1 < c1 and existing_c2 > c2:
				return true
			if existing_c1 > c1 and existing_c2 < c2:
				return true
	return false

# Validation rule: Ensures map isn't a bottleneck or ghost town
func validate_map_health() -> bool:
	var row_counts: Dictionary = {}
	for node in all_nodes.keys():
		row_counts[node.x] = row_counts.get(node.x, 0) + 1

	# Check Floors 2 through 12: must have at least 3 nodes per floor
	for r in range(2, grid_row - 3):
		if row_counts.get(r, 0) < 3:
			return false # Failed density check, regenerate!
	return true

func _on_button_pressed() -> void:
	generate_valid_map()
	queue_redraw()
