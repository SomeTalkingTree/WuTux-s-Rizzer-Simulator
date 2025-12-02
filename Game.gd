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

# --- NODES & SIGNALS ---
func _ready():
	screen_size = get_viewport_rect().size
	update_ui_text()
	randomize()
	
	# Connect the special button signal via code to be safe
	if has_node("Node/Specialbutton"):
		$Node/Specialbutton.pressed.connect(_on_SpecialButton_pressed)
		$Node/Specialbutton.visible = false # Start hidden

func _process(_delta):
	$Score.text = "Moneys: %s" % score

# --- TIMERS ---

func _on_Timer_timeout():
	score += cps
	
	# Spawn Floating Text for Passive Income (Wutux Slaves)
	# We check if cps > 0 to avoid spawning "0" text
	if cps > 0:
		# Randomize position slightly near the score label so it doesn't stack perfectly
		# Assuming $Score is near the top; we spawn slightly below it
		var spawn_pos = $Score.global_position + Vector2(randf_range(20, 100), randf_range(40, 80))
		spawn_floating_text(cps, spawn_pos)
	
	# Visuals
	var random_color = Color(randf(), randf(), randf(), 1.0)
	$Score.modulate = random_color
	
	# Random Chance to Spawn Special Button (10% chance per second)
	# Also ensure it isn't already visible
	if randi_range(0, 10) == 0 and not $Node/Specialbutton.visible: 
		spawn_special_button()

func _on_ClickTimer_timeout():
	combo = 0
	$ComboEffect.emitting = false
	$ComboEffect2.emitting = false
	$ComboEffect3.emitting = false

# --- GAMEPLAY MECHANICS ---

func _on_Click_pressed():
	$ClickTimer.start()
	
	# Combo Logic
	if combo < 25:
		combo += 1
	
	handle_combo_effects()
	
	# Score Calculation
	var click_value = cpc
	if combo > 10:
		var multiplier = combo / 10.0
		click_value = round(click_value * multiplier)
	
	score += click_value
	
	# SPAWN FLOATING TEXT (Manual Click)
	spawn_floating_text(click_value, get_global_mouse_position())

func handle_combo_effects():
	if combo > 25 and not $ComboEffect3.emitting:
		$ComboEffect3.emitting = true
	elif combo > 15 and not $ComboEffect2.emitting:
		$ComboEffect2.emitting = true
	elif combo > 10 and not $ComboEffect.emitting:
		$ComboEffect.emitting = true

# --- VISUALS: FLOATING TEXT ---

func spawn_floating_text(value: int, pos: Vector2):
	# Create a new label dynamically in code
	var label = Label.new()
	label.text = "+%s" % value
	label.position = pos
	
	# Set style: Gold color, disable mouse interaction
	label.modulate = Color(1, 0.8, 0.2) 
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Add to scene
	add_child(label)
	
	# Animate: Move Up and Fade Out
	var tween = create_tween()
	var target_pos = pos + Vector2(0, -100) # Float up 100 pixels
	
	# Move up with a nice "Out Cubic" ease
	tween.tween_property(label, "position", target_pos, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Fade out opacity at the same time
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	
	# Delete the label when animation is done so the game doesn't lag later
	tween.tween_callback(label.queue_free)

# --- UPGRADE SYSTEM ---

func attempt_purchase(button_node: Button, current_cost: int, power_gain: int, is_cps: bool) -> int:
	if score >= current_cost:
		score -= current_cost
		
		if is_cps:
			cps += power_gain
		else:
			cpc += power_gain
		
		var new_cost = round(current_cost * cost_growth)
		var type_str = "CPS" if is_cps else "CPC"
		button_node.text = "+%s %s [%s]" % [power_gain, type_str, new_cost]
		
		update_ui_text()
		return new_cost
	else:
		return current_cost 

func update_ui_text():
	$Label2.text = "Total Wutux Production: %s CPS" % cps
	$Label3.text = "Click Strength: %s CPC" % cpc

# --- SPECIAL BUTTON LOGIC (UPDATED) ---

func spawn_special_button():
	var special_btn = $Node/Specialbutton
	
	# 1. Randomize Position
	var rand_x = randf_range(50, screen_size.x - 150)
	var rand_y = randf_range(50, screen_size.y - 150)
	special_btn.position = Vector2(rand_x, rand_y)
	
	# 2. Randomize Size/Scale (Fun Factor)
	# Random scale between 0.8x and 2.0x normal size
	var random_scale = randf_range(0.8, 2.0)
	special_btn.scale = Vector2(random_scale, random_scale)
	
	# 3. Reset Visuals (In case it faded out previously)
	special_btn.modulate.a = 1.0 
	special_btn.disabled = false
	special_btn.visible = true
	
	# 4. Start Disappear Timer
	$Timeout.start()

func _on_SpecialButton_pressed():
	var btn = $Node/Specialbutton
	
	# 1. Prevent double clicking
	btn.disabled = true
	$Timeout.stop() 
	
	# 2. Give HUGE Bonus (10x CPS + 100x Click Power + Flat Bonus)
	var bonus = (cps * 10) + (cpc * 100) + 5000
	score += bonus
	
	# Show Floating Text for Bonus
	spawn_floating_text(bonus, btn.position + (btn.size * btn.scale / 2))
	
	# 3. FUN ACTION: Create a Tween Animation
	var tween = create_tween()
	
	# Pop up (scale) and rotate rapidly
	tween.tween_property(btn, "scale", btn.scale * 1.5, 0.2).set_trans(Tween.TRANS_ELASTIC)
	tween.parallel().tween_property(btn, "rotation", deg_to_rad(360), 0.5)
	
	# Fade out opacity
	tween.tween_property(btn, "modulate:a", 0.0, 0.3)
	
	# When animation finishes, actually hide the button
	tween.tween_callback(func(): 
		btn.visible = false
		btn.rotation = 0 # Reset rotation for next time
	)
	
	# Optional: Print to console or update a label if you had a notification label
	print("BONUS CLAIMED: ", bonus)

func _on_Timeout_timeout():
	# Hide the special button if user was too slow
	$Node/Specialbutton.visible = false
	$Node/Specialbutton.disabled = true
	# Also hide button 2 if it exists
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
