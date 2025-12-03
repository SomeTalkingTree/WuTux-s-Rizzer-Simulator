extends Control

# --- CONFIGURATION & VARIABLES ---
var score: int = 121310 
var cpc: int = 1 
var cps: int = 0 

# Economy Settings
var cost_growth: float = 1.5 

# Building Counts (NEW: Tracks how many of each you own)
var building_counts = {
	"cpc1": 0, "cpc2": 0, "cpc3": 0, "cpc4": 0, "cpc5": 0,
	"cps1": 0, "cps2": 0, "cps3": 0, "cps4": 0, "cps5": 0
}

# Synergies (NEW: Tracks purchased upgrades)
var synergies = {
	"manager_training": false
}

# Combo System
var combo: int = 0
var max_combo_time: float = 0.5 

# Screen Size
var screen_size: Vector2

# Save System
var current_save_file_name: String = "" 
const META_PATH = "user://meta.json"
const AUTOSAVE_FILE = "autosave.json" 
var auto_save_counter: int = 0

# Menu Variables
var pause_menu_node: Control
var save_load_window: Control 
var load_autosave_btn: Button 
var synergy_container: VBoxContainer # Where we put upgrade buttons

# --- NODES & SIGNALS ---
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	if has_node("Timer"): $Timer.process_mode = Node.PROCESS_MODE_PAUSABLE
	if has_node("ClickTimer"): $ClickTimer.process_mode = Node.PROCESS_MODE_PAUSABLE
	if has_node("VBoxContainer"): $VBoxContainer.process_mode = Node.PROCESS_MODE_PAUSABLE
	if has_node("Node"): $Node.process_mode = Node.PROCESS_MODE_PAUSABLE
	
	screen_size = get_viewport_rect().size
	
	setup_pause_menu()
	load_last_played_game()
	
	# Recalculate stats immediately to ensure UI is correct after load
	recalculate_stats()
	update_ui_text()
	check_synergy_unlocks() # Check if we should show the upgrade
	
	randomize()
	
	if has_node("Node/Specialbutton"):
		$Node/Specialbutton.pressed.connect(_on_SpecialButton_pressed)
		$Node/Specialbutton.visible = false 

func _process(_delta):
	if not get_tree().paused:
		$Score.text = "Moneys: %s" % score
		# Check continuously if we can show the upgrade button
		check_synergy_unlocks()

func _input(event):
	if event.is_action_pressed("ui_cancel"): 
		toggle_pause_menu()

# --- TIMERS ---

func _on_Timer_timeout():
	score += cps
	
	if cps > 0:
		var spawn_pos = $Score.global_position + Vector2(randf_range(20, 100), randf_range(40, 80))
		spawn_floating_text(cps, spawn_pos)
	
	$Score.modulate = Color(randf(), randf(), randf(), 1.0)
	
	if randi_range(0, 10) == 0 and not $Node/Specialbutton.visible: 
		spawn_special_button()

	auto_save_counter += 1
	if auto_save_counter >= 5: 
		save_game(AUTOSAVE_FILE, false)
		auto_save_counter = 0
		spawn_floating_text("Auto-Saved", $Score.global_position + Vector2(0, 50), Color.CYAN)

func _on_ClickTimer_timeout():
	combo = 0
	$ComboEffect.emitting = false
	$ComboEffect2.emitting = false
	$ComboEffect3.emitting = false

# --- GAMEPLAY MECHANICS ---

func _on_Click_pressed():
	if get_tree().paused: return
	$ClickTimer.start()
	if combo < 25: combo += 1
	handle_combo_effects()
	
	var click_value = cpc
	if combo > 10:
		var multiplier = combo / 10.0
		click_value = round(click_value * multiplier)
	
	score += click_value
	spawn_floating_text(click_value, get_global_mouse_position())

func handle_combo_effects():
	if combo > 25 and not $ComboEffect3.emitting: $ComboEffect3.emitting = true
	elif combo > 15 and not $ComboEffect2.emitting: $ComboEffect2.emitting = true
	elif combo > 10 and not $ComboEffect.emitting: $ComboEffect.emitting = true

# --- CORE CALCULATION ENGINE (NEW) ---

func recalculate_stats():
	# 1. Calculate CPS (Passive)
	var cps1_prod = building_counts["cps1"] * 1
	# SYNERGY: Manager Training doubles CPS1
	if synergies["manager_training"]:
		cps1_prod *= 2
		
	var cps2_prod = building_counts["cps2"] * 5
	var cps3_prod = building_counts["cps3"] * 20
	var cps4_prod = building_counts["cps4"] * 125
	var cps5_prod = building_counts["cps5"] * 500
	
	cps = cps1_prod + cps2_prod + cps3_prod + cps4_prod + cps5_prod

	# 2. Calculate CPC (Active)
	# Base click is 1
	var cpc1_prod = building_counts["cpc1"] * 1
	var cpc2_prod = building_counts["cpc2"] * 5
	var cpc3_prod = building_counts["cpc3"] * 20
	var cpc4_prod = building_counts["cpc4"] * 125
	var cpc5_prod = building_counts["cpc5"] * 500
	
	cpc = 1 + cpc1_prod + cpc2_prod + cpc3_prod + cpc4_prod + cpc5_prod

# --- SYNERGY SYSTEM ---

func check_synergy_unlocks():
	# If we haven't bought Manager Training yet
	if not synergies["manager_training"]:
		# Check if the button already exists in the scene
		var btn_name = "Synergy_ManagerTraining"
		var existing_btn = $VBoxContainer.get_node_or_null(btn_name)
		
		# Condition to show button: Score > 500 OR we already have some slaves
		if score >= 500 or building_counts["cps1"] > 0:
			if not existing_btn:
				create_synergy_button(btn_name, "Manager Training [1000]", 1000, "Doubles output of Wutux Slaves", func():
					synergies["manager_training"] = true
					recalculate_stats()
					update_ui_text()
				)

func create_synergy_button(name_id: String, text: String, cost: int, tooltip: String, callback: Callable):
	var btn = Button.new()
	btn.name = name_id
	btn.text = text
	btn.tooltip_text = tooltip
	# Make it look distinct (e.g., Purple)
	btn.modulate = Color(0.8, 0.5, 1.0)
	
	btn.pressed.connect(func():
		if score >= cost:
			score -= cost
			callback.call()
			btn.queue_free() # Remove button after buying
			spawn_floating_text("UPGRADE BOUGHT!", $Score.global_position, Color.MAGENTA)
			# Save game to remember the upgrade
			if current_save_file_name != "": save_game(current_save_file_name)
	)
	
	# Add to the main list. 
	# We use move_child to put it at the top or bottom if we wanted, 
	# but appending to VBoxContainer is fine.
	$VBoxContainer.add_child(btn)

# --- SAVE / LOAD SYSTEM ---

func get_save_files() -> Array:
	var files = []
	var dir = DirAccess.open("user://")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json") and file_name != AUTOSAVE_FILE and file_name != "meta.json":
				var f = FileAccess.open("user://" + file_name, FileAccess.READ)
				var json = JSON.parse_string(f.get_as_text())
				if json:
					files.append({
						"filename": file_name,
						"score": json.get("score", 0),
						"timestamp": json.get("timestamp", "Unknown")
					})
			file_name = dir.get_next()
	return files

func save_game(filename: String, is_manual_save: bool = true):
	var time = Time.get_datetime_dict_from_system()
	var time_str = "%s-%s-%s %s:%02d" % [time.month, time.day, time.year, time.hour, time.minute]
	
	var save_data = {
		"score": score,
		"counts": building_counts, # Save the new counts
		"synergies": synergies,    # Save upgrades
		"timestamp": time_str,
		"costs": {
			"cpc1": cost_cpc1, "cpc2": cost_cpc2, "cpc3": cost_cpc3, "cpc4": cost_cpc4, "cpc5": cost_cpc5,
			"cps1": cost_cps1, "cps2": cost_cps2, "cps3": cost_cps3, "cps4": cost_cps4, "cps5": cost_cps5
		},
		"original_filename": current_save_file_name if current_save_file_name != "" else filename
	}
	
	var file = FileAccess.open("user://" + filename, FileAccess.WRITE)
	file.store_string(JSON.stringify(save_data))
	
	if is_manual_save:
		current_save_file_name = filename
		var meta = FileAccess.open(META_PATH, FileAccess.WRITE)
		meta.store_string(JSON.stringify({"last_played": filename}))

func load_game(filename: String):
	var path = "user://" + filename
	if not FileAccess.file_exists(path): return 
	
	var file = FileAccess.open(path, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	
	if data:
		score = int(data.get("score", score))
		
		# Load Synergies
		var loaded_synergies = data.get("synergies", {})
		if loaded_synergies.has("manager_training"):
			synergies["manager_training"] = loaded_synergies["manager_training"]
			
		# Load Costs
		var costs = data.get("costs", {})
		cost_cpc1 = int(costs.get("cpc1", cost_cpc1))
		cost_cpc2 = int(costs.get("cpc2", cost_cpc2))
		cost_cpc3 = int(costs.get("cpc3", cost_cpc3))
		cost_cpc4 = int(costs.get("cpc4", cost_cpc4))
		cost_cpc5 = int(costs.get("cpc5", cost_cpc5))
		
		cost_cps1 = int(costs.get("cps1", cost_cps1))
		cost_cps2 = int(costs.get("cps2", cost_cps2))
		cost_cps3 = int(costs.get("cps3", cost_cps3))
		cost_cps4 = int(costs.get("cps4", cost_cps4))
		cost_cps5 = int(costs.get("cps5", cost_cps5))
		
		# --- MIGRATION LOGIC ---
		# If the save file has counts, load them.
		# If not (Old Save), calculate them from costs!
		if data.has("counts"):
			var c = data["counts"]
			for k in building_counts.keys():
				if c.has(k): building_counts[k] = int(c[k])
		else:
			print("Old save detected. Reverse engineering counts...")
			building_counts["cpc1"] = get_count_from_cost(cost_cpc1, 20)
			building_counts["cpc2"] = get_count_from_cost(cost_cpc2, 150)
			building_counts["cpc3"] = get_count_from_cost(cost_cpc3, 1400)
			building_counts["cpc4"] = get_count_from_cost(cost_cpc4, 12000)
			building_counts["cpc5"] = get_count_from_cost(cost_cpc5, 200000)
			
			building_counts["cps1"] = get_count_from_cost(cost_cps1, 20)
			building_counts["cps2"] = get_count_from_cost(cost_cps2, 150)
			building_counts["cps3"] = get_count_from_cost(cost_cps3, 1400)
			building_counts["cps4"] = get_count_from_cost(cost_cps4, 12000)
			building_counts["cps5"] = get_count_from_cost(cost_cps5, 200000)
		
		recalculate_stats() # Update CPS/CPC based on loaded/calculated counts
		
		if filename == AUTOSAVE_FILE and data.has("original_filename"):
			current_save_file_name = data["original_filename"]
		else:
			current_save_file_name = filename
		
		if filename != AUTOSAVE_FILE:
			var meta = FileAccess.open(META_PATH, FileAccess.WRITE)
			meta.store_string(JSON.stringify({"last_played": filename}))

# Helper to reverse math: cost = base * (growth ^ count)
# so count = log(cost/base) / log(growth)
func get_count_from_cost(current: float, base: float) -> int:
	if current <= base: return 0
	# Logarithm change of base rule: log_b(x) = ln(x) / ln(b)
	var count = log(current / base) / log(cost_growth)
	return round(count)

func load_last_played_game():
	if FileAccess.file_exists(META_PATH):
		var file = FileAccess.open(META_PATH, FileAccess.READ)
		var data = JSON.parse_string(file.get_as_text())
		if data and data.has("last_played"):
			var last_file = data["last_played"]
			if FileAccess.file_exists("user://" + last_file):
				load_game(last_file)
				return
	
func spawn_floating_text(value, pos: Vector2, color_override = null):
	var label = Label.new()
	label.text = "+%s" % value if typeof(value) == TYPE_INT else str(value)
	label.position = pos
	label.modulate = color_override if color_override else Color(1, 0.8, 0.2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	var tween = create_tween()
	var target_pos = pos + Vector2(0, -100)
	tween.tween_property(label, "position", target_pos, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(label.queue_free)

# --- UI ---

func setup_pause_menu():
	pause_menu_node = Control.new()
	pause_menu_node.name = "PauseMenu"
	pause_menu_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu_node.visible = false
	pause_menu_node.z_index = 100 
	add_child(pause_menu_node)
	
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.8)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu_node.add_child(bg)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu_node.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	center.add_child(vbox)
	
	var title = Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	create_menu_button("Resume", vbox, toggle_pause_menu)
	load_autosave_btn = create_menu_button("Revert to Autosave", vbox, func():
		if FileAccess.file_exists("user://" + AUTOSAVE_FILE):
			load_game(AUTOSAVE_FILE)
			update_ui_text()
			spawn_floating_text("Autosave Loaded!", $Score.global_position, Color.GREEN)
			toggle_pause_menu()
	)
	create_menu_button("Save Game", vbox, func(): open_save_load_menu(true))
	create_menu_button("Load Game", vbox, func(): open_save_load_menu(false))
	create_menu_button("Quit", vbox, func(): get_tree().quit())

	save_load_window = Panel.new()
	save_load_window.name = "SaveLoadWindow"
	save_load_window.visible = false
	save_load_window.custom_minimum_size = Vector2(400, 500)
	save_load_window.set_anchors_preset(Control.PRESET_CENTER)
	pause_menu_node.add_child(save_load_window)

func open_save_load_menu(is_save_mode: bool):
	save_load_window.visible = true
	for child in save_load_window.get_children(): child.queue_free()
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.add_child(vbox)
	save_load_window.add_child(margin)
	
	var title = Label.new()
	title.text = "SELECT SLOT TO SAVE" if is_save_mode else "SELECT RUN TO LOAD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	var slot_container = VBoxContainer.new()
	slot_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(slot_container)
	
	if is_save_mode:
		var new_btn = Button.new()
		new_btn.text = "+ CREATE NEW SAVE"
		new_btn.modulate = Color(0.5, 1, 0.5)
		new_btn.pressed.connect(func():
			var unique_name = "save_" + str(Time.get_ticks_msec()) + ".json"
			save_game(unique_name)
			spawn_floating_text("New Save Created!", $Score.global_position, Color.GREEN)
			save_load_window.visible = false
		)
		slot_container.add_child(new_btn)
	
	var files = get_save_files()
	if files.is_empty() and not is_save_mode:
		var empty_lbl = Label.new()
		empty_lbl.text = "No saved games found."
		slot_container.add_child(empty_lbl)
	
	for file_data in files:
		var btn = Button.new()
		var fname = file_data["filename"]
		var fscore = file_data["score"]
		var ftime = file_data["timestamp"]
		btn.text = "%s\nScore: %s | %s" % [fname, fscore, ftime]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if is_save_mode:
			btn.pressed.connect(func():
				save_game(fname)
				spawn_floating_text("Overwritten!", $Score.global_position, Color.YELLOW)
				save_load_window.visible = false
			)
		else:
			btn.pressed.connect(func():
				load_game(fname)
				update_ui_text()
				spawn_floating_text("Run Loaded!", $Score.global_position, Color.GREEN)
				save_load_window.visible = false
				toggle_pause_menu()
			)
		slot_container.add_child(btn)
	
	var close_btn = Button.new()
	close_btn.text = "Cancel"
	close_btn.pressed.connect(func(): save_load_window.visible = false)
	vbox.add_child(close_btn)

func create_menu_button(text: String, parent: Node, callback: Callable):
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(200, 50)
	btn.pressed.connect(callback)
	parent.add_child(btn)
	return btn

func toggle_pause_menu():
	var is_paused = not get_tree().paused
	get_tree().paused = is_paused
	pause_menu_node.visible = is_paused
	if load_autosave_btn:
		load_autosave_btn.disabled = not FileAccess.file_exists("user://" + AUTOSAVE_FILE)
	save_load_window.visible = false

# --- UPGRADE SYSTEM (UPDATED) ---

func attempt_purchase(button_node: Button, current_cost: int, id_name: String, is_cps: bool) -> int:
	if score >= current_cost:
		score -= current_cost
		
		# NEW: Update the specific count
		if building_counts.has(id_name):
			building_counts[id_name] += 1
		
		# NEW: Recalculate global stats based on all counts
		recalculate_stats()
		
		var new_cost = round(current_cost * cost_growth)
		
		# Update Label Text
		# We need to look up power gain based on ID to keep text correct
		var power_gain = 0
		if id_name == "cpc1" or id_name == "cps1": power_gain = 1
		elif id_name == "cpc2" or id_name == "cps2": power_gain = 5
		elif id_name == "cpc3" or id_name == "cps3": power_gain = 20
		elif id_name == "cpc4" or id_name == "cps4": power_gain = 125
		elif id_name == "cpc5" or id_name == "cps5": power_gain = 500
		
		var type_str = "CPS" if is_cps else "CPC"
		button_node.text = "+%s %s [%s]" % [power_gain, type_str, new_cost]
		
		update_ui_text()
		save_game(AUTOSAVE_FILE, false)
		return new_cost
	else:
		return current_cost 

func update_ui_text():
	$Label2.text = "Total Wutux Production: %s CPS" % cps
	$Label3.text = "Click Strength: %s CPC" % cpc
	$VBoxContainer/CPC1.text = "+1 CPC [%s]" % cost_cpc1
	$VBoxContainer/CPC2.text = "+5 CPC [%s]" % cost_cpc2
	$VBoxContainer/CPC3.text = "+20 CPC [%s]" % cost_cpc3
	$VBoxContainer/CPC4.text = "+125 CPC [%s]" % cost_cpc4
	$VBoxContainer/CPC5.text = "+500 CPC [%s]" % cost_cpc5
	$VBoxContainer/CPS1.text = "+1 CPS [%s]" % cost_cps1
	$VBoxContainer/CPS2.text = "+5 CPS [%s]" % cost_cps2
	$VBoxContainer/CPS3.text = "+20 CPS [%s]" % cost_cps3
	$VBoxContainer/CPS4.text = "+125 CPS [%s]" % cost_cps4
	$VBoxContainer/CPS5.text = "+500 CPS [%s]" % cost_cps5

# --- SPECIAL BUTTON ---
func spawn_special_button():
	var special_btn = $Node/Specialbutton
	var rand_x = randf_range(50, screen_size.x - 150)
	var rand_y = randf_range(50, screen_size.y - 150)
	special_btn.position = Vector2(rand_x, rand_y)
	
	var random_scale = randf_range(0.8, 2.0)
	special_btn.scale = Vector2(random_scale, random_scale)
	
	special_btn.modulate.a = 1.0 
	special_btn.disabled = false
	special_btn.visible = true
	$Timeout.start()

func _on_SpecialButton_pressed():
	var btn = $Node/Specialbutton
	btn.disabled = true
	$Timeout.stop() 
	var bonus = (cps * 10) + (cpc * 100) + 5000
	score += bonus
	spawn_floating_text(bonus, btn.position + (btn.size * btn.scale / 2))
	var tween = create_tween()
	tween.tween_property(btn, "scale", btn.scale * 1.5, 0.2).set_trans(Tween.TRANS_ELASTIC)
	tween.parallel().tween_property(btn, "rotation", deg_to_rad(360), 0.5)
	tween.tween_property(btn, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): 
		btn.visible = false
		btn.rotation = 0
	)

func _on_Timeout_timeout():
	$Node/Specialbutton.visible = false
	$Node/Specialbutton.disabled = true
	if has_node("Node/Specialbutton2"):
		$Node/Specialbutton2.visible = false
		$Node/Specialbutton2.disabled = true

# --- BUTTON SIGNALS ---
var cost_cpc1 = 20
var cost_cpc2 = 150
var cost_cpc3 = 1400
var cost_cpc4 = 12000
var cost_cpc5 = 200000

var cost_cps1 = 20
var cost_cps2 = 150
var cost_cps3 = 1400
var cost_cps4 = 12000
var cost_cps5 = 200000

func _on_CPC1_pressed(): cost_cpc1 = attempt_purchase($VBoxContainer/CPC1, cost_cpc1, "cpc1", false)
func _on_CPC2_pressed(): cost_cpc2 = attempt_purchase($VBoxContainer/CPC2, cost_cpc2, "cpc2", false)
func _on_CPC3_pressed(): cost_cpc3 = attempt_purchase($VBoxContainer/CPC3, cost_cpc3, "cpc3", false)
func _on_CPC4_pressed(): cost_cpc4 = attempt_purchase($VBoxContainer/CPC4, cost_cpc4, "cpc4", false)
func _on_CPC5_pressed(): cost_cpc5 = attempt_purchase($VBoxContainer/CPC5, cost_cpc5, "cpc5", false)

func _on_CPS1_pressed(): cost_cps1 = attempt_purchase($VBoxContainer/CPS1, cost_cps1, "cps1", true)
func _on_CPS2_pressed(): cost_cps2 = attempt_purchase($VBoxContainer/CPS2, cost_cps2, "cps2", true)
func _on_CPS3_pressed(): cost_cps3 = attempt_purchase($VBoxContainer/CPS3, cost_cps3, "cps3", true)
func _on_CPS4_pressed(): cost_cps4 = attempt_purchase($VBoxContainer/CPS4, cost_cps4, "cps4", true)
func _on_CPS5_pressed(): cost_cps5 = attempt_purchase($VBoxContainer/CPS5, cost_cps5, "cps5", true)
