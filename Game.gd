extends Control

var screen = DisplayServer.window_get_size()
var screenx= screen.x
var screeny= screen.y
var score = 121310
var add = 1
var addpersec = 0
var combo = 0
var costcreep = 1.5 #increases cost after purchase
var costcostcreep = 1.3 #Increases costcreep on every purchase
var seconds = 0

func _on_Timer_timeout():
	score += addpersec #After the Timer resets, add the add per second to the score.
	seconds+=1
	ready()
	
	#if(seconds ==3):
		#seconds =0
		#$Timeout.start()
		#$Label4.text = str("New button now: ",score) #THIS IS FOR DEBUGGING
		#var oddoreven =RandomNumberGenerator.new()
		#var oddoreven2 = oddoreven.randi_range(0,1)
		#randomize()
		#$Node/Specialbutton.disabled=false
		#$Node/Specialbutton.visible=true 
		#$Node/Specialbutton2.disabled=false
		#$Node/Specialbutton2.visible=true
	

#func _on_Tcostcreep_timeout():
	#costcreep = costcreep* .9
	#if costcreep <1:
		#costcreep = costcreep+1
	#elif costcreep==1:
		#costcreep=1.01
	##Supposed to decrease the costcreep with eggs that comes out at some point basically a war between raising and cutting costs.

#func _on_SpecialTimer_timeout(): #THis is AIDS AND NEED WORK ON
	#$Timeout.start()
	#$Label4.text = str("New button now"+score) #THIS IS FOR DEBUGGING
	#var oddoreven =RandomNumberGenerator.new()
	#var oddoreven2 = oddoreven%2
	#var startx = oddoreven.randf_range(0,screenx)
	#var starty = oddoreven.randf_range(0,screeny)
	#if oddoreven2==0:
		#$Node/Specialbutton.position(startx,starty)
		#$Node/Specialbutton.disabled=false
		#$Node/Specialbutton.visible=true 
	#else:
		#$Node/Specialbutton2.position(startx,starty)
		#$Node/Specialbutton2.disabled=false
		#$Node/Specialbutton2.visible=true
		##Supposed to show some buttoms that gives some type of rewards later on. As well as tell the rewards that come with this click of this button

func _on_Timeout_timeout():
	if $Node/Specialbutton.visible==true:
		$Node/Specialbutton.disabled=true
		$Node/Specialbutton.visible=false
	elif $Node/Specialbutton2.visible==true:
		$Node/Specialbutton2.disabled=true
		$Node/Specialbutton2.visible=false
	#Needs to disable button


#func hsv_to_rgb(h, s, v, a = 1):
	##based on code at
	##http://stackoverflow.com/questions/51203917/math-behind-hsv-to-rgb-conversion-of-colors
	#var r
	#var g
	#var b
	#var i = floor(h * 6)
	#var f = h * 6 - i
	#var p = v * (1 - s)
	#var q = v * (1 - f * s)
	#var t = v * (1 - (1 - f) * s)
	#match (int(i) % 6):
		#0:
			#r = v
			#g = t
			#b = p
		#1:
			#r = v
			#g = t
			#b = p
		#2:
			#r = v
			#g = t
			#b = p
		#3:
			#r = v
			#g = t
			#b = p
		#4:
			#r = v
			#g = t
			#b = p
		#5:
			#r = v
			#g = t
			#b = p
	#return Color(r, g, b, a)
	
func ready():
	var random_color = Color(randf(), randf(), randf(), 1.0)
	$Score.modulate = random_color  # Apply to text label   

func _process(_delta):
	
	$Score.text = str("Moneys: ",score) #Change the text to the current score every frame.
	

var CPSRequirement = 20 #Clicks required to upgrade Clicks Per Second
var CPCRequirement = 20 #Clicks required to upgrade Clicks Per Click
var CPSRequirement2 = 150 #Clicks required to upgrade Clicks Per Second #2
var CPCRequirement2 = 150 #Clicks required to upgrade Clicks Per Click #2
var CPSRequirement3 = 1400 #Clicks required to upgrade Clicks Per Second #3
var CPCRequirement3 = 1400 #Clicks required to upgrade Clicks Per Click #3
var CPSRequirement4 = 12000 #Clicks required to upgrade Clicks Per Second #4
var CPCRequirement4 = 12000 #Clicks required to upgrade Clicks Per Click #4
var CPSRequirement5 = 200000 #Clicks required to upgrade Clicks Per Second #5
var CPCRequirement5 = 200000 #Clicks required to upgrade Clicks Per Click #5
var string = "Total Wutux slaves production as "
var string2 = "Your production of clicks as "

func _on_CPC1_pressed():
	if score >= CPCRequirement:
		score -= CPCRequirement
		CPCRequirement = round(CPCRequirement * costcreep)
		costcreep = costcreep*costcostcreep
		add = add + 1 #Add CPC
		$VBoxContainer/CPC1.text = str("+1 CPC [", CPCRequirement, "]") #Combine multiple strings to show the required clicks.
		$Label3.text = str(string2,"CPC:", add)


func _on_Click_pressed():
	$ClickTimer.start()
	if combo < 25: # Make sure combo doesn't get too high
		combo += 1
	if combo >= 25: # Enable the other sparks when combo is over 25
		$ComboEffect3.emitting = true # More Sparks
	if combo > 15: # Enable the sparks when combo is over 15
		$ComboEffect2.emitting = true # Sparks
	if combo > 10: # Enable the effects when combo is over 10
		@warning_ignore("integer_division")
		score += round(add * (combo / 10))
		$ComboEffect.emitting = true
	if combo <= 10: # No combo
		score += add



func _on_CPS1_pressed():
	if score >= CPSRequirement:
		score -= CPSRequirement
		CPSRequirement = round(CPSRequirement *costcreep)
		addpersec = addpersec + 1 #Add CPS.
		costcreep = costcreep*costcostcreep
		$VBoxContainer/CPS1.text = str("Wutux slaves 1: +1 CPS [", CPSRequirement, "]") #Combine multiple strings to show the required clicks.
		$Label2.text = str(string,"CPS:", addpersec)


func _on_ClickTimer_timeout():
	combo = 0
	$ComboEffect.emitting = false # Effects
	$ComboEffect2.emitting = false # Sparks
	$ComboEffect3.emitting = false # More Sparks


func _on_CPS2_pressed():
	if score >= CPSRequirement2:
		score -= CPSRequirement2
		CPSRequirement2 = round(CPSRequirement2 * costcreep)
		addpersec = addpersec + 5 #Add CPS.
		costcreep = costcreep*costcostcreep
		$VBoxContainer/CPS2.text = str("Wutux miner slaves: +5 CPS [", CPSRequirement2, "]") #Combine multiple strings to show the required clicks.
		$Label2.text = str(string,"CPS:", addpersec)


func _on_CPC2_pressed():
	if score >= CPCRequirement2:
		score -= CPCRequirement2
		CPCRequirement2 = round(CPCRequirement2 * costcreep)
		add = add + 5 #Add CPC
		costcreep = costcreep*costcostcreep
		$VBoxContainer/CPC2.text = str("+5 CPC [", CPCRequirement2, "]") #Combine multiple strings to show the required clicks.
		$Label3.text = str(string2,"CPC:", add)


func _on_CPS3_pressed():
	if score >= CPSRequirement3:
		score -= CPSRequirement3
		CPSRequirement3 = round(CPSRequirement3 * costcreep)
		addpersec = addpersec + 20 #Add CPS.
		costcreep = costcreep*costcostcreep
		$VBoxContainer/CPS3.text = str("+20 CPS [", CPSRequirement3, "]") #Combine multiple strings to show the required clicks.
		$Label2.text = str(string,"CPS:", addpersec)


func _on_CPC3_pressed():
	if score >= CPCRequirement3:
		score -= CPCRequirement3
		CPCRequirement3 = round(CPCRequirement3 * costcreep)
		add = add + 20 #Add CPC
		costcreep = costcreep*costcostcreep
		$VBoxContainer/CPC3.text = str("+20 CPC [", CPCRequirement3, "]") #Combine multiple strings to show the required clicks.
		$Label3.text = str(string2,"CPC:", add)


func _on_CPS4_pressed():
	if score >= CPSRequirement4:
		score -= CPSRequirement4
		CPSRequirement4 = round(CPSRequirement4 * costcreep)
		addpersec = addpersec + 125 #Add CPS.
		costcreep = costcreep*costcostcreep
		$VBoxContainer/CPS4.text = str("+125 CPS [", CPSRequirement4, "]") #Combine multiple strings to show the required clicks.
		$Label2.text = str(string,"CPS:", addpersec)


func _on_CPC4_pressed():
	if score >= CPCRequirement4:
		score -= CPCRequirement4
		CPCRequirement4 = round(CPCRequirement4 * costcreep)
		add = add + 125 #Add CPC
		costcreep = costcreep*costcostcreep
		$VBoxContainer/CPC4.text = str("+125 CPC [", CPCRequirement4, "]") #Combine multiple strings to show the required clicks.
		$Label3.text = str(string2,"CPC:", add)


func _on_CPS5_pressed():
	if score >= CPSRequirement5:
		score -= CPSRequirement5
		CPSRequirement5 = round(CPSRequirement5*costcreep)
		addpersec = addpersec + 500 #Add CPS.
		costcreep = costcreep*costcostcreep
		$VBoxContainer/CPS5.text = str("+500 CPS [", CPSRequirement5, "]") #Combine multiple strings to show the required clicks.
		$Label2.text = str(string,"CPS:", addpersec)


func _on_CPC5_pressed():
	if score >= CPCRequirement5:
		score -= CPCRequirement5
		CPCRequirement5 = round(CPCRequirement5*costcreep)
		add = add + 500 #Add CPC
		costcreep = costcreep*costcostcreep
		$VBoxContainer/CPC5.text = str("+500 CPC [", CPCRequirement5, "]") #Combine multiple strings to show the required clicks.
		$Label3.text = str(string2,"CPC:", add)
