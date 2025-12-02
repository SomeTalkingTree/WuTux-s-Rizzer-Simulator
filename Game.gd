extends Control

# --- CONFIGURATION & VARIABLES ---
var score: int = 121310 
var cpc: int = 1 # Clicks Per Click
var cps: int = 0 # Clicks Per Second

# Economy Settings
var cost_growth: float = 1.5 

# Combo System
var combo: int = 0
var max_combo_time: float = 0.5 

# Screen Size
var screen_size: Vector2

# --- SAVE SYSTEM VARIABLES ---
# We no longer use a single static path. We determine it dynamically.
var current_save_file_name: String = "" 
const META_PATH = "user://meta.json" # Stores which file was last played
const AUTOSAVE_FILE = "autosave.json" # Dedicated file for autosaves
var auto_save_counter: int = 0

# --- MENU VARIABLES ---
var pause_menu_node: Control
var save_load_window: Control # The sub-menu for picking slots
var load_autosave_btn: Button # Reference to update visibility

# --- NODES & SIGNALS ---
func _ready():
	# 1. Process Modes
	process_mode = Node.PROCESS_MODE_ALWAYS
	if has_node("Timer"): $Timer.process_mode = Node.PROCESS_MODE_PAUSABLE
	if has_node("ClickTimer"): $ClickTimer.process_mode = Node.PROCESS_MODE_PAUSABLE
	if has_node("VBoxContainer"): $VBoxContainer.process_mode = Node.PROCESS_MODE_PAUSABLE
	if has_node("Node"): $Node.process_mode = Node.PROCESS_MODE_PAUSABLE
	
	screen_size = get_viewport_rect().size
	
	# 2. Build UI
	setup_pause_menu()
	
	# 3. AUTO-LOAD LOGIC
	# Check metadata to see what we played last
	load_last_played_game()
	
	update_ui_text()
	randomize()
	
	if has_node("Node/Specialbutton"):
		$Node/Specialbutton.pressed.connect(_on_SpecialButton_pressed)
		$Node/Specialbutton.visible = false 

func _process(_delta):
	if not get_tree().paused:
		$Score.text = "Moneys: %s" % score

func _input(event):
	if event.is_action_pressed("ui_cancel"): 
		toggle_pause_menu()

# --- TIMERS ---

func _on_Timer_timeout():
	score += cps
	
	if cps > 0:
		var spawn_pos = $Score.global_position + Vector2(randf_range(20, 100), randf_range(40, 80))
		spawn_floating_text(cps, spawn_pos)
	
	var random_color = Color(randf(), randf(), randf(), 1.0)
	$Score.modulate = random_color
	
	if randi_range(0, 10) == 0 and not $Node/Specialbutton.visible: 
		spawn_special_button()

	# --- AUTO SAVE LOGIC ---
	auto_save_counter += 1
	if auto_save_counter >= 5: 
		# Save to the dedicated autosave file. 
		# We pass 'false' to indicate this shouldn't change our "Current Active Manual Save"
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

# --- VISUALS ---

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

# --- ADVANCED SAVE / LOAD SYSTEM ---

# 1. Helper to find all save files
func get_save_files() -> Array:
	var files = []
	var dir = DirAccess.open("user://")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			# We list normal saves, excluding the autosave file from the general list if desired,
			# but here we can include it or filter it. 
			# Let's hide autosave from the main list so it's special.
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

# 2. Save Logic
func save_game(filename: String, is_manual_save: bool = true):
	# Generate a timestamp
	var time = Time.get_datetime_dict_from_system()
	var time_str = "%s-%s-%s %s:%02d" % [time.month, time.day, time.year, time.hour, time.minute]
	
	var save_data = {
		"score": score,
		"cpc": cpc,
		"cps": cps,
		"timestamp": time_str,
		"costs": {
			"cpc1": cost_cpc1, "cpc2": cost_cpc2, "cpc3": cost_cpc3, "cpc4": cost_cpc4, "cpc5": cost_cpc5,
			"cps1": cost_cps1, "cps2": cost_cps2, "cps3": cost_cps3, "cps4": cost_cps4, "cps5": cost_cps5
		},
		# We store which manual file this autosave corresponds to, so we can resume the "run" correctly
		"original_filename": current_save_file_name if current_save_file_name != "" else filename
	}
	
	var file = FileAccess.open("user://" + filename, FileAccess.WRITE)
	file.store_string(JSON.stringify(save_data))
	
	# Only update the "Active" file tracker if it's a manual save.
	# This prevents the "Save Game" button from overwriting 'autosave.json' later.
	if is_manual_save:
		current_save_file_name = filename
		# Update Metadata (Last Played)
		var meta = FileAccess.open(META_PATH, FileAccess.WRITE)
		meta.store_string(JSON.stringify({"last_played": filename}))

# 3. Load Logic
func load_game(filename: String):
	var path = "user://" + filename
	if not FileAccess.file_exists(path): return 
	
	var file = FileAccess.open(path, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	
	if data:
		score = int(data.get("score", score))
		cpc = int(data.get("cpc", cpc))
		cps = int(data.get("cps", cps))
		
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
		
		# If we loaded an autosave, we want to restore the "link" to the original file
		# so if the user clicks Save, it goes to "save_1.json" and not "autosave.json"
		if filename == AUTOSAVE_FILE and data.has("original_filename"):
			current_save_file_name = data["original_filename"]
		else:
			current_save_file_name = filename
		
		# Update Meta (unless it's autosave, we might want to keep the main file as last played)
		if filename != AUTOSAVE_FILE:
			var meta = FileAccess.open(META_PATH, FileAccess.WRITE)
			meta.store_string(JSON.stringify({"last_played": filename}))

# 4. Auto-Load on Startup
func load_last_played_game():
	if FileAccess.file_exists(META_PATH):
		var file = FileAccess.open(META_PATH, FileAccess.READ)
		var data = JSON.parse_string(file.get_as_text())
		if data and data.has("last_played"):
			var last_file = data["last_played"]
			if FileAccess.file_exists("user://" + last_file):
				print("Auto-loading last run: ", last_file)
				load_game(last_file)
				return
	
	print("No previous run found. Starting fresh.")

# --- UI: PAUSE & SLOT MENU ---

func setup_pause_menu():
	# Main Pause Overlay
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
	
	# NEW: Revert to Autosave Button
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

	# Save/Load Sub-Window (Hidden by default)
	save_load_window = Panel.new()
	save_load_window.name = "SaveLoadWindow"
	save_load_window.visible = false
	save_load_window.custom_minimum_size = Vector2(400, 500)
	save_load_window.set_anchors_preset(Control.PRESET_CENTER)
	pause_menu_node.add_child(save_load_window)

func open_save_load_menu(is_save_mode: bool):
	save_load_window.visible = true
	
	# Clear previous contents
	for child in save_load_window.get_children():
		child.queue_free()
		
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Add margins
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.add_child(vbox)
	save_load_window.add_child(margin)
	
	# Header
	var title = Label.new()
	title.text = "SELECT SLOT TO SAVE" if is_save_mode else "SELECT RUN TO LOAD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Scroll Container for slots
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	var slot_container = VBoxContainer.new()
	slot_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(slot_container)
	
	# 1. "New Save" Button (Only in Save Mode)
	if is_save_mode:
		var new_btn = Button.new()
		new_btn.text = "+ CREATE NEW SAVE"
		new_btn.modulate = Color(0.5, 1, 0.5) # Greenish
		new_btn.pressed.connect(func():
			# Create a unique filename based on time
			var unique_name = "save_" + str(Time.get_ticks_msec()) + ".json"
			save_game(unique_name)
			spawn_floating_text("New Save Created!", $Score.global_position, Color.GREEN)
			save_load_window.visible = false
		)
		slot_container.add_child(new_btn)
	
	# 2. Existing Slots
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
			# Overwrite logic
			btn.pressed.connect(func():
				save_game(fname)
				spawn_floating_text("Overwritten!", $Score.global_position, Color.YELLOW)
				save_load_window.visible = false
			)
		else:
			# Load Logic
			btn.pressed.connect(func():
				load_game(fname)
				update_ui_text()
				spawn_floating_text("Run Loaded!", $Score.global_position, Color.GREEN)
				save_load_window.visible = false
				toggle_pause_menu()
			)
			
		slot_container.add_child(btn)
	
	# Close Button
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
	
	# Check if autosave exists to enable/disable button
	if load_autosave_btn:
		load_autosave_btn.disabled = not FileAccess.file_exists("user://" + AUTOSAVE_FILE)
	
	save_load_window.visible = false

# --- UPGRADE SYSTEM ---
func attempt_purchase(button_node: Button, current_cost: int, power_gain: int, is_cps: bool) -> int:
	if score >= current_cost:
		score -= current_cost
		if is_cps: cps += power_gain
		else: cpc += power_gain
		
		var new_cost = round(current_cost * cost_growth)
		var type_str = "CPS" if is_cps else "CPC"
		button_node.text = "+%s %s [%s]" % [power_gain, type_str, new_cost]
		
		update_ui_text()
		# Auto-save immediately to autosave file on purchase for safety
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

# --- SPECIAL BUTTON LOGIC ---
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
	print("BONUS CLAIMED: ", bonus)

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

func _on_CPC1_pressed(): cost_cpc1 = attempt_purchase($VBoxContainer/CPC1, cost_cpc1, 1, false)
func _on_CPC2_pressed(): cost_cpc2 = attempt_purchase($VBoxContainer/CPC2, cost_cpc2, 5, false)
func _on_CPC3_pressed(): cost_cpc3 = attempt_purchase($VBoxContainer/CPC3, cost_cpc3, 20, false)
func _on_CPC4_pressed(): cost_cpc4 = attempt_purchase($VBoxContainer/CPC4, cost_cpc4, 125, false)
func _on_CPC5_pressed(): cost_cpc5 = attempt_purchase($VBoxContainer/CPC5, cost_cpc5, 500, false)

func _on_CPS1_pressed(): cost_cps1 = attempt_purchase($VBoxContainer/CPS1, cost_cps1, 1, true)
func _on_CPS2_pressed(): cost_cps2 = attempt_purchase($VBoxContainer/CPS2, cost_cps2, 5, true)
func _on_CPS3_pressed(): cost_cps3 = attempt_purchase($VBoxContainer/CPS3, cost_cps3, 20, true)
func _on_CPS4_pressed(): cost_cps4 = attempt_purchase($VBoxContainer/CPS4, cost_cps4, 125, true)
func _on_CPS5_pressed(): cost_cps5 = attempt_purchase($VBoxContainer/CPS5, cost_cps5, 500, true)
