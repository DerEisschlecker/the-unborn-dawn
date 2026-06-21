# Purpose: Two-sided trader screen with player inventory, merchant stock, drag-and-drop carts, values, and no scrolling.
# Public API: Opened from the world map trader location.
# Dependencies: GameplayScreen, InventorySystem, DataCatalog, TimeSystem, UiFactory.
extends GameplayScreen

const TradeItemCardScript := preload("res://scripts/ui/trade_item_card.gd")
const TradeDropZoneScript := preload("res://scripts/ui/trade_drop_zone.gd")
const ITEMS_PER_PAGE := 12

const BASE_STOCK := {
	"clean_water": 5,
	"rainwater": 4,
	"canned_beans": 4,
	"dried_meat": 3,
	"bandage": 4,
	"painkillers": 2,
	"antiseptic": 2,
	"antibiotics": 1,
	"cloth": 8,
	"wood": 6,
	"metal": 5,
	"nails": 8,
	"electronics": 2,
	"fuel": 2,
	"revolver_ammo": 10,
	"rifle_ammo": 5,
	"shotgun_shell": 4,
	"rusty_knife": 1,
	"machete": 1,
	"service_pistol": 1,
	"patched_jacket": 1,
	"leather_vest": 1,
	"small_backpack": 1,
	"field_backpack": 1,
	"wire_ring": 2,
	"leather_belt": 2,
	"salt_amulet": 1,
	"scrap_shield": 1
}

var player_grid: GridContainer
var trader_grid: GridContainer
var buy_zone: PanelContainer
var sell_zone: PanelContainer
var money_label: Label
var trade_total_label: Label
var feedback_label: Label
var player_page_label: Label
var trader_page_label: Label
var player_page := 0
var trader_page := 0
var trader_stock: Dictionary = {}
var buy_cart: Dictionary = {}
var sell_cart: Dictionary = {}


func _ready() -> void:
	var root := setup_gameplay("ASCHEMARKT", "Kaufen, verkaufen, sparen. Ziehe Items in die Mitte oder klicke sie an.")
	var layout := HBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 12)
	root.add_child(layout)
	_build_side(layout, "MEIN RUCKSACK", true)
	_build_center(layout)
	_build_side(layout, "HAENDLER", false)
	_build_stock()
	EventBus.inventory_changed.connect(_refresh)
	_refresh()


func _build_side(parent: HBoxContainer, title: String, player_side: bool) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 360
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UiFactory._panel_style())
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(UiFactory.title_label(title, 24))
	if player_side:
		money_label = UiFactory.body_label("", 16, UiFactory.COLOR_GOLD)
		box.add_child(money_label)
	else:
		box.add_child(UiFactory.body_label("Tagesbestand: Preise steigen mit Seltenheit und Nutzen.", 14, UiFactory.COLOR_MUTED))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	var pager := HBoxContainer.new()
	pager.add_theme_constant_override("separation", 8)
	box.add_child(pager)
	var previous := UiFactory.button("<", func() -> void: _change_page(player_side, -1), 58)
	previous.custom_minimum_size = Vector2(58, 36)
	pager.add_child(previous)
	var page_label := UiFactory.body_label("", 14, Color("#d8dde8"))
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pager.add_child(page_label)
	var next := UiFactory.button(">", func() -> void: _change_page(player_side, 1), 58)
	next.custom_minimum_size = Vector2(58, 36)
	pager.add_child(next)
	if player_side:
		player_grid = grid
		player_page_label = page_label
	else:
		trader_grid = grid
		trader_page_label = page_label


func _build_center(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 420
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UiFactory._panel_style())
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(UiFactory.title_label("HANDEL", 24))
	buy_zone = TradeDropZoneScript.new()
	buy_zone.configure("buy", ["trader"], _handle_drop)
	buy_zone.custom_minimum_size.y = 190
	box.add_child(buy_zone)
	sell_zone = TradeDropZoneScript.new()
	sell_zone.configure("sell", ["player"], _handle_drop)
	sell_zone.custom_minimum_size.y = 190
	box.add_child(sell_zone)
	trade_total_label = UiFactory.body_label("", 16, UiFactory.COLOR_GOLD)
	trade_total_label.custom_minimum_size.y = 44
	box.add_child(trade_total_label)
	var actions := GridContainer.new()
	actions.columns = 2
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	box.add_child(actions)
	var confirm := UiFactory.button("Handel bestaetigen", _confirm_trade, 184)
	confirm.custom_minimum_size = Vector2(184, 40)
	actions.add_child(confirm)
	var clear := UiFactory.button("Auswahl leeren", _clear_carts, 184)
	clear.custom_minimum_size = Vector2(184, 40)
	actions.add_child(clear)
	var back := UiFactory.button("Zurueck", _return, 184)
	back.custom_minimum_size = Vector2(184, 40)
	actions.add_child(back)
	var restock := UiFactory.button("Preise pruefen", _refresh, 184)
	restock.custom_minimum_size = Vector2(184, 40)
	actions.add_child(restock)
	feedback_label = UiFactory.body_label("", 14, UiFactory.COLOR_MUTED)
	feedback_label.custom_minimum_size.y = 42
	box.add_child(feedback_label)


func _build_stock() -> void:
	trader_stock.clear()
	for item_id in BASE_STOCK:
		if DataCatalog.item(str(item_id)).is_empty():
			continue
		trader_stock[str(item_id)] = int(BASE_STOCK[item_id])
	if TimeSystem.current_day >= 3 and not DataCatalog.item("old_revolver").is_empty():
		trader_stock["old_revolver"] = 1
	if TimeSystem.current_day >= 5 and not DataCatalog.item("hunting_rifle").is_empty():
		trader_stock["hunting_rifle"] = 1


func _refresh() -> void:
	_refresh_player_side()
	_refresh_trader_side()
	_refresh_carts()
	_refresh_totals()


func _refresh_player_side() -> void:
	UiFactory.clear_container(player_grid)
	money_label.text = "Dawn-Credits: %d   Platz: %d/%d   %.1f/%.1f kg" % [
		InventorySystem.money,
		InventorySystem.used_slots(),
		InventorySystem.slot_capacity,
		InventorySystem.current_weight(),
		InventorySystem.max_weight
	]
	var ids := InventorySystem.ordered_items()
	ids.sort_custom(func(a: String, b: String) -> bool:
		return DataCatalog.item(a).get("name", a) < DataCatalog.item(b).get("name", b)
	)
	var pages := maxi(1, ceili(float(ids.size()) / float(ITEMS_PER_PAGE)))
	player_page = clampi(player_page, 0, pages - 1)
	player_page_label.text = "%d / %d" % [player_page + 1, pages]
	var start := player_page * ITEMS_PER_PAGE
	for index in range(start, mini(start + ITEMS_PER_PAGE, ids.size())):
		var item_id := str(ids[index])
		var available := int(InventorySystem.items.get(item_id, 0)) - int(sell_cart.get(item_id, 0))
		if available <= 0:
			continue
		player_grid.add_child(_item_card(item_id, available, "player", DataCatalog.item_sell_price(item_id)))
	_fill_empty_slots(player_grid)


func _refresh_trader_side() -> void:
	UiFactory.clear_container(trader_grid)
	var ids: Array[String] = []
	for item_id in trader_stock:
		if int(trader_stock[item_id]) - int(buy_cart.get(item_id, 0)) > 0:
			ids.append(str(item_id))
	ids.sort_custom(func(a: String, b: String) -> bool:
		var rarity := int(DataCatalog.item(b).get("rarity_rank", 1)) - int(DataCatalog.item(a).get("rarity_rank", 1))
		return rarity < 0 if rarity != 0 else DataCatalog.item(a).get("name", a) < DataCatalog.item(b).get("name", b)
	)
	var pages := maxi(1, ceili(float(ids.size()) / float(ITEMS_PER_PAGE)))
	trader_page = clampi(trader_page, 0, pages - 1)
	trader_page_label.text = "%d / %d" % [trader_page + 1, pages]
	var start := trader_page * ITEMS_PER_PAGE
	for index in range(start, mini(start + ITEMS_PER_PAGE, ids.size())):
		var item_id := str(ids[index])
		var available := int(trader_stock.get(item_id, 0)) - int(buy_cart.get(item_id, 0))
		trader_grid.add_child(_item_card(item_id, available, "trader", DataCatalog.item_buy_price(item_id)))
	_fill_empty_slots(trader_grid)


func _refresh_carts() -> void:
	buy_zone.set_title("KAUFEN")
	sell_zone.set_title("VERKAUFEN")
	UiFactory.clear_container(buy_zone.grid)
	UiFactory.clear_container(sell_zone.grid)
	for item_id in _sorted_cart_ids(buy_cart):
		buy_zone.grid.add_child(_item_card(item_id, int(buy_cart[item_id]), "buy", DataCatalog.item_buy_price(item_id)))
	for item_id in _sorted_cart_ids(sell_cart):
		sell_zone.grid.add_child(_item_card(item_id, int(sell_cart[item_id]), "sell", DataCatalog.item_sell_price(item_id)))
	_fill_empty_slots(buy_zone.grid, 6)
	_fill_empty_slots(sell_zone.grid, 6)


func _refresh_totals() -> void:
	var buy_total := _cart_total(buy_cart, true)
	var sell_total := _cart_total(sell_cart, false)
	var net := buy_total - sell_total
	var carry_text := "passt"
	if not _cart_fits_after_trade():
		carry_text = "zu schwer/kein Platz"
	if net > 0:
		trade_total_label.text = "Kaufen: %d DC   Verkaufen: %d DC\nZu bezahlen: %d DC   Inventar: %s" % [buy_total, sell_total, net, carry_text]
	elif net < 0:
		trade_total_label.text = "Kaufen: %d DC   Verkaufen: %d DC\nDu erhaeltst: %d DC   Inventar: %s" % [buy_total, sell_total, abs(net), carry_text]
	else:
		trade_total_label.text = "Kaufen: %d DC   Verkaufen: %d DC\nAusgeglichen   Inventar: %s" % [buy_total, sell_total, carry_text]


func _item_card(item_id: String, amount: int, source: String, price: int) -> PanelContainer:
	var card := TradeItemCardScript.new()
	card.configure(item_id, amount, source, price, _card_clicked)
	return card


func _card_clicked(item_id: String, source: String) -> void:
	match source:
		"player":
			_add_to_sell(item_id)
		"trader":
			_add_to_buy(item_id)
		"buy":
			_remove_from_cart(buy_cart, item_id)
		"sell":
			_remove_from_cart(sell_cart, item_id)
	_refresh()


func _handle_drop(zone: String, item_id: String, source: String) -> void:
	if zone == "buy" and source == "trader":
		_add_to_buy(item_id)
	elif zone == "sell" and source == "player":
		_add_to_sell(item_id)
	_refresh()


func _add_to_buy(item_id: String) -> void:
	if int(trader_stock.get(item_id, 0)) - int(buy_cart.get(item_id, 0)) <= 0:
		feedback_label.text = "Davon hat der Haendler nichts mehr."
		return
	buy_cart[item_id] = int(buy_cart.get(item_id, 0)) + 1
	feedback_label.text = "%s zum Einkauf gelegt." % DataCatalog.item(item_id).get("name", item_id)


func _add_to_sell(item_id: String) -> void:
	if int(InventorySystem.items.get(item_id, 0)) - int(sell_cart.get(item_id, 0)) <= 0:
		feedback_label.text = "Davon liegt nichts mehr im Rucksack."
		return
	sell_cart[item_id] = int(sell_cart.get(item_id, 0)) + 1
	feedback_label.text = "%s zum Verkauf gelegt." % DataCatalog.item(item_id).get("name", item_id)


func _remove_from_cart(cart: Dictionary, item_id: String) -> void:
	if int(cart.get(item_id, 0)) <= 0:
		return
	cart[item_id] = int(cart[item_id]) - 1
	if int(cart[item_id]) <= 0:
		cart.erase(item_id)
	feedback_label.text = "%s aus der Auswahl entfernt." % DataCatalog.item(item_id).get("name", item_id)


func _confirm_trade() -> void:
	if buy_cart.is_empty() and sell_cart.is_empty():
		feedback_label.text = "Lege zuerst Items in Kaufen oder Verkaufen."
		return
	var buy_total := _cart_total(buy_cart, true)
	var sell_total := _cart_total(sell_cart, false)
	var net := buy_total - sell_total
	if net > InventorySystem.money:
		feedback_label.text = "Nicht genug Dawn-Credits."
		return
	if not _cart_fits_after_trade():
		feedback_label.text = "Nach dem Handel fehlt Platz oder Traglast."
		return
	for item_id in sell_cart:
		InventorySystem.remove_item(str(item_id), int(sell_cart[item_id]))
		trader_stock[str(item_id)] = int(trader_stock.get(str(item_id), 0)) + int(sell_cart[item_id])
	for item_id in buy_cart:
		trader_stock[str(item_id)] = maxi(0, int(trader_stock.get(str(item_id), 0)) - int(buy_cart[item_id]))
		InventorySystem.add_item(str(item_id), int(buy_cart[item_id]))
	if net > 0:
		InventorySystem.spend_money(net)
	elif net < 0:
		InventorySystem.add_money(abs(net))
	buy_cart.clear()
	sell_cart.clear()
	TimeSystem.advance(1, "Handel am Aschemarkt.")
	feedback_label.text = "Handel abgeschlossen."
	_refresh()


func _clear_carts() -> void:
	buy_cart.clear()
	sell_cart.clear()
	feedback_label.text = "Auswahl geleert."
	_refresh()


func _cart_fits_after_trade() -> bool:
	var future_counts := InventorySystem.items.duplicate(true)
	for item_id in sell_cart:
		future_counts[str(item_id)] = int(future_counts.get(str(item_id), 0)) - int(sell_cart[item_id])
		if int(future_counts[str(item_id)]) <= 0:
			future_counts.erase(str(item_id))
	for item_id in buy_cart:
		if not future_counts.has(str(item_id)) and future_counts.size() >= InventorySystem.slot_capacity:
			return false
		future_counts[str(item_id)] = int(future_counts.get(str(item_id), 0)) + int(buy_cart[item_id])
	var weight := 0.0
	for item_id in future_counts:
		weight += float(DataCatalog.item(str(item_id)).get("weight", 0.0)) * int(future_counts[item_id])
	for slot in InventorySystem.equipment:
		var equipped_id := str(InventorySystem.equipment[slot])
		if not equipped_id.is_empty():
			weight += float(DataCatalog.item(equipped_id).get("weight", 0.0))
	return weight <= InventorySystem.max_weight


func _cart_total(cart: Dictionary, buying: bool) -> int:
	var total := 0
	for item_id in cart:
		var price := DataCatalog.item_buy_price(str(item_id)) if buying else DataCatalog.item_sell_price(str(item_id))
		total += price * int(cart[item_id])
	return total


func _sorted_cart_ids(cart: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for item_id in cart:
		ids.append(str(item_id))
	ids.sort_custom(func(a: String, b: String) -> bool:
		return DataCatalog.item(a).get("name", a) < DataCatalog.item(b).get("name", b)
	)
	return ids


func _fill_empty_slots(grid: GridContainer, target_count: int = ITEMS_PER_PAGE) -> void:
	while grid.get_child_count() < target_count:
		var empty := PanelContainer.new()
		empty.custom_minimum_size = Vector2(96, 70)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.02, 0.024, 0.03, 0.58)
		style.border_color = Color(0.28, 0.30, 0.35, 0.55)
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		empty.add_theme_stylebox_override("panel", style)
		grid.add_child(empty)


func _change_page(player_side: bool, direction: int) -> void:
	if player_side:
		player_page = maxi(0, player_page + direction)
	else:
		trader_page = maxi(0, trader_page + direction)
	_refresh()


func _return() -> void:
	go_to(GameState.return_scene if not GameState.return_scene.is_empty() else "res://scenes/world_map/world_map.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			accept_event()
			_return()
