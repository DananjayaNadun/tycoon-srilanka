extends Node3D

const SAVE_PATH := "user://save.json"

var money: int = 100000
# Per-car state (key = NodePath string like "/root/Main/Car")
var owned: Dictionary = {}
var repaired: Dictionary = {}
var slot_used := {}   # slot_path -> car_path
var car_near_garage: bool = false

var selected_car: Node3D = null
var income_timer: float = 0.0

# --- PRICES ---
var car_buy_price := {
	"Car": 50000,
	"Car2": 80000
}
var car_sell_price_broken := {
	"Car": 30000,
	"Car2": 50000
}
var car_sell_price_repaired := {
	"Car": 45000,
	"Car2": 75000
}
var repair_cost := {
	"Car": 10000,
	"Car2": 15000
}

@onready var car_panel := $UI/CarPanel as Control
@onready var money_label := $UI/MoneyLabel as Label
@onready var car_name_label := $UI/CarPanel/CarNameLabel as Label

@onready var buy_btn := $UI/CarPanel/BuyButton as Button
@onready var repair_btn := $UI/CarPanel/RepairButton as Button
@onready var sell_btn := $UI/CarPanel/SellButton as Button
@onready var close_btn := $UI/CarPanel/CloseButton as Button
@onready var save_btn: Button = $UI/CarPanel/SaveButton
@onready var reset_btn: Button = $UI/CarPanel/ResetButton
@onready var toast: Label = $UI/ToastLabel
@onready var stats_label: Label = $UI/CarPanel/StatsLabel
var toast_timer := 0.0
var condition := {}  # key -> int (0..100)
var mileage := {}    # key -> int



func _ready() -> void:
	load_game() # ✅ THIS WAS MISSING (caused reset)

	car_panel.visible = false
	selected_car = null
	_update_ui()

	buy_btn.pressed.connect(_on_buy_pressed)
	repair_btn.pressed.connect(_on_repair_pressed)
	sell_btn.pressed.connect(_on_sell_pressed)
	close_btn.pressed.connect(_on_close_pressed)

	save_btn.pressed.connect(save_game)
	reset_btn.pressed.connect(_on_reset_pressed)


func _process(delta: float) -> void:
	income_timer += delta
	if income_timer >= 2.0:
		income_timer = 0.0
		_generate_income()
	# Toast auto hide
	if toast_timer > 0:
		toast_timer -= delta
		if toast_timer <= 0:
			toast.visible = false

func _get_free_slot() -> Node3D:
	for slot in $Slots.get_children():
		var key := str(slot.get_path())
		if not slot_used.has(key):
			return slot
	return null


func open_car_panel(car: Node3D) -> void:
	selected_car = car
	var key := str(car.get_path())

	if not owned.has(key): owned[key] = false
	if not repaired.has(key): repaired[key] = false

	if not condition.has(key): condition[key] = 60
	if not mileage.has(key): mileage[key] = 0

	car_panel.visible = true
	_update_ui()


func _on_close_pressed() -> void:
	car_panel.visible = false

func _on_buy_pressed() -> void:
	if selected_car == null:
		show_toast("Select a car first")
		return

	var key := str(selected_car.get_path())
	if owned.get(key, false):
		show_toast("Already owned")
		return

	var price := int(car_buy_price.get(selected_car.name, 50000))
	if money < price:
		show_toast("Not enough money")
		return

	money -= price
	owned[key] = true
	repaired[key] = false
	var slot := _get_free_slot()
	
	if slot == null:
		show_toast("No free parking slots!")
		return

	selected_car.global_position = slot.global_position
	slot_used[str(slot.get_path())] = str(selected_car.get_path())

	show_toast("Bought!")
	_update_ui()
	save_game()


func _on_repair_pressed() -> void:
	if selected_car == null:
		show_toast("Select a car first")
		return

	var key := str(selected_car.get_path())
	if not owned.get(key, false):
		show_toast("Buy it first")
		return

	if repaired.get(key, false):
		show_toast("Already repaired")
		return

	# If you are using the Garage rule:
	# (only keep this line if you already made car_near_garage)
	if "car_near_garage" in self and not car_near_garage:
		show_toast("Move car to garage area")
		return

	var cost := int(repair_cost.get(selected_car.name, 10000))
	if money < cost:
		show_toast("Not enough money")
		return

	money -= cost
	repaired[key] = true

	# Only if you already created 'condition' dictionary:
	if "condition" in self:
		condition[key] = 100

	show_toast("Repaired!")
	_update_ui()
	save_game()




func show_toast(message: String) -> void:
	toast.text = message
	toast.visible = true
	toast_timer = 2.0


func _on_sell_pressed() -> void:
	if selected_car == null:
		show_toast("Select a car first")
		return

	var key := str(selected_car.get_path())
	if not owned.get(key, false):
		show_toast("Nothing to sell")
		return

	var value := int(car_sell_price_broken.get(selected_car.name, 30000))
	if repaired.get(key, false):
		value = car_sell_price_repaired.get(selected_car.name, 45000)

	money += value

	# -------------------------
	# FREE SLOT HERE
	# -------------------------
	for s in slot_used.keys():
		if slot_used[s] == str(selected_car.get_path()):
			slot_used.erase(s)
			break
	# -------------------------

	owned[key] = false
	repaired[key] = false

	show_toast("Sold for %d" % value)
	_update_ui()
	save_game()

func perform_action(action:String) -> void:
	match action:
		"buy":
			_on_buy_pressed()
		"repair":
			_on_repair_pressed()
		"sell":
			_on_sell_pressed()


func _update_ui() -> void:
	if money_label:
		money_label.text = "Money: %d" % money

	if selected_car == null:
		if car_name_label:
			car_name_label.text = "Selected: None"
			stats_label.text = "Cond: --   Miles: --"
		buy_btn.disabled = true
		repair_btn.disabled = true
		sell_btn.disabled = true
		return

	if car_name_label:
		car_name_label.text = "Selected: %s" % selected_car.name

	var key := str(selected_car.get_path())
	stats_label.text = "Cond: %d%%   Miles: %d" % [
	condition.get(key, 0),
	mileage.get(key, 0)
]

	var has_car := bool(owned.get(key, false))
	var car_rep := bool(repaired.get(key, false))

	# Visual color
	var mesh := selected_car.get_node_or_null("CarMesh") as MeshInstance3D
	if mesh:
		var mat := mesh.get_active_material(0) as StandardMaterial3D
		if mat:
			if not has_car:
				mat.albedo_color = Color(1, 1, 1)
			elif has_car and not car_rep:
				mat.albedo_color = Color(0.8, 0.2, 0.2)
			else:
				mat.albedo_color = Color(0.2, 0.8, 0.2)

	# Button states (use per-car prices)
	var buy_price := int(car_buy_price.get(selected_car.name, 50000))
	var rep_cost := int(repair_cost.get(selected_car.name, 10000))

	buy_btn.disabled = has_car or money < buy_price
	repair_btn.disabled = (not has_car) or car_rep or money < rep_cost
	sell_btn.disabled = not has_car

func _generate_income() -> void:
	for key in owned.keys():
		if owned.get(key, false):
			# car exists and is owned → it "runs"
			mileage[key] = int(mileage.get(key, 0)) + 1
			condition[key] = maxi(0, int(condition.get(key, 60)) - 1)

			# only repaired cars make income
			if repaired.get(key, false):
				money += 1000

	save_game()
	_update_ui()


func _on_reset_pressed() -> void:
	money = 100000
	owned.clear()
	repaired.clear()
	save_game()
	_update_ui()

func save_game() -> void:
	var data := {
		"money": money,
		"owned": owned,
		"repaired": repaired,
		"condition": condition,   
		"mileage": mileage        
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func _unhandled_input(event):
	if event.is_action_pressed("repair_action"):
		if selected_car == null:
			return

		if not car_near_garage:
			show_toast("Move car near garage!")
			return

		_on_repair_pressed()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return

	var text := file.get_as_text()
	file.close()

	var parsed :Variant= JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	money = int(parsed.get("money", money))
	owned = parsed.get("owned", owned)
	repaired = parsed.get("repaired", repaired)
	condition = parsed.get("condition", condition)
	mileage = parsed.get("mileage", mileage)


func _on_repair_area_body_entered(body):
	if body.name.begins_with("Car"):
		car_near_garage = true

func _on_repair_area_body_exited(body):
	if body.name.begins_with("Car"):
		car_near_garage = false
