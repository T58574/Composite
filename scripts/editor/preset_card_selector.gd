class_name PresetCardSelector
extends HFlowContainer

## Visual Card-based Preset Selector for Hull and Turret shapes.
## Renders interactive cards with custom 2D vector schematic previews, titles, descriptions, and active state highlights.

signal preset_selected(index: int)

@export var is_turret_presets: bool = false
@export var card_width: float = 125.0
@export var card_height: float = 110.0

var selected_index: int = 0
var _card_nodes: Array[Control] = []

class PresetItemData extends RefCounted:
	var title: String = ""
	var subtitle: String = ""
	var preset_id: int = 0
	var style_enum: int = 0

	func _init(p_title: String, p_subtitle: String, p_id: int, p_style: int = 0) -> void:
		title = p_title
		subtitle = p_subtitle
		preset_id = p_id
		style_enum = p_style

class ThumbnailDrawControl extends Control:
	var preset_id: int = 0
	var is_turret: bool = false
	var is_selected: bool = false

	func _draw() -> void:
		var size_rect = get_size()
		var center = size_rect * 0.5
		var w = size_rect.x * 0.75
		var h = size_rect.y * 0.55

		var main_color = Color(1.0, 0.78, 0.25) if is_selected else Color(0.35, 0.75, 0.95)
		var fill_color = Color(1.0, 0.78, 0.25, 0.18) if is_selected else Color(0.2, 0.6, 0.8, 0.12)
		var line_width = 2.5 if is_selected else 1.8

		var points: PackedVector2Array = PackedVector2Array()

		if not is_turret:
			# Hull Schematics
			match preset_id:
				0: # Sloped Wedge
					points.append(Vector2(-w*0.5, h*0.3) + center)
					points.append(Vector2(w*0.1, h*0.3) + center)
					points.append(Vector2(w*0.5, -h*0.3) + center)
					points.append(Vector2(-w*0.3, -h*0.3) + center)
				1: # Heavy Box
					points.append(Vector2(-w*0.45, h*0.35) + center)
					points.append(Vector2(w*0.45, h*0.35) + center)
					points.append(Vector2(w*0.45, -h*0.35) + center)
					points.append(Vector2(-w*0.45, -h*0.35) + center)
				2: # Pike Nose
					points.append(Vector2(-w*0.5, h*0.25) + center)
					points.append(Vector2(0, h*0.25) + center)
					points.append(Vector2(w*0.55, 0) + center)
					points.append(Vector2(-w*0.4, -h*0.3) + center)
				3: # Modern MBT
					points.append(Vector2(-w*0.5, h*0.25) + center)
					points.append(Vector2(w*0.15, h*0.25) + center)
					points.append(Vector2(w*0.5, -h*0.15) + center)
					points.append(Vector2(w*0.3, -h*0.35) + center)
					points.append(Vector2(-w*0.45, -h*0.35) + center)
				_: # Default Compact
					points.append(Vector2(-w*0.4, h*0.25) + center)
					points.append(Vector2(w*0.4, h*0.25) + center)
					points.append(Vector2(w*0.2, -h*0.25) + center)
					points.append(Vector2(-w*0.4, -h*0.25) + center)
		else:
			# Turret Schematics
			match preset_id:
				0: # Wedge Cheeks
					points.append(Vector2(-w*0.45, h*0.3) + center)
					points.append(Vector2(0, h*0.3) + center)
					points.append(Vector2(w*0.45, -h*0.1) + center)
					points.append(Vector2(w*0.1, -h*0.3) + center)
					points.append(Vector2(-w*0.45, -h*0.3) + center)
				1: # Cast Dome
					# Curve points for dome
					for k in range(9):
						var a = (float(k) / 8.0) * PI
						var cx = -cos(a) * w * 0.45
						var cy = -sin(a) * h * 0.55
						points.append(Vector2(cx, cy) + center)
					points.append(Vector2(-w*0.45, h*0.2) + center)
				2: # Box Bustle
					points.append(Vector2(-w*0.55, h*0.3) + center)
					points.append(Vector2(w*0.35, h*0.3) + center)
					points.append(Vector2(w*0.35, -h*0.3) + center)
					points.append(Vector2(-w*0.55, -h*0.1) + center)
				3: # Angular MBT
					points.append(Vector2(-w*0.5, h*0.25) + center)
					points.append(Vector2(w*0.2, h*0.25) + center)
					points.append(Vector2(w*0.5, -h*0.2) + center)
					points.append(Vector2(-w*0.3, -h*0.35) + center)
				_: # Compact
					points.append(Vector2(-w*0.35, h*0.25) + center)
					points.append(Vector2(w*0.35, h*0.25) + center)
					points.append(Vector2(w*0.25, -h*0.25) + center)
					points.append(Vector2(-w*0.35, -h*0.25) + center)

		if points.size() >= 3:
			draw_colored_polygon(points, fill_color)
			for i in range(points.size()):
				var p1 = points[i]
				var p2 = points[(i + 1) % points.size()]
				draw_line(p1, p2, main_color, line_width, true)

func _ready() -> void:
	add_theme_constant_override("h_separation", 8)
	add_theme_constant_override("v_separation", 8)
	build_cards()

func build_cards() -> void:
	for child in get_children():
		child.queue_free()
	_card_nodes.clear()

	var presets: Array[PresetItemData] = []

	if not is_turret_presets:
		presets.append(PresetItemData.new(tr("PRESET_HULL_WEDGE_TITLE"), tr("PRESET_HULL_WEDGE_SUB"), 0))
		presets.append(PresetItemData.new(tr("PRESET_HULL_BOX_TITLE"), tr("PRESET_HULL_BOX_SUB"), 1))
		presets.append(PresetItemData.new(tr("PRESET_HULL_PIKE_TITLE"), tr("PRESET_HULL_PIKE_SUB"), 2))
		presets.append(PresetItemData.new(tr("PRESET_HULL_MODERN_TITLE"), tr("PRESET_HULL_MODERN_SUB"), 3))
		presets.append(PresetItemData.new(tr("PRESET_HULL_COMPACT_TITLE"), tr("PRESET_HULL_COMPACT_SUB"), 4))
	else:
		presets.append(PresetItemData.new(tr("PRESET_TURRET_WEDGE_TITLE"), tr("PRESET_TURRET_WEDGE_SUB"), 0))
		presets.append(PresetItemData.new(tr("PRESET_TURRET_DOME_TITLE"), tr("PRESET_TURRET_DOME_SUB"), 1))
		presets.append(PresetItemData.new(tr("PRESET_TURRET_BOX_TITLE"), tr("PRESET_TURRET_BOX_SUB"), 2))
		presets.append(PresetItemData.new(tr("PRESET_TURRET_ANGULAR_TITLE"), tr("PRESET_TURRET_ANGULAR_SUB"), 3))
		presets.append(PresetItemData.new(tr("PRESET_TURRET_COMPACT_TITLE"), tr("PRESET_TURRET_COMPACT_SUB"), 4))

	for data in presets:
		var card = _create_card_button(data)
		add_child(card)
		_card_nodes.append(card)

	select_card(selected_index, false)

func _create_card_button(data: PresetItemData) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(card_width, card_height)
	btn.clip_contents = true

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	btn.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 2)
	margin.add_child(vbox)

	# 2D Vector Schematic Preview
	var draw_ctrl = ThumbnailDrawControl.new()
	draw_ctrl.custom_minimum_size = Vector2(card_width - 12.0, 52.0)
	draw_ctrl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	draw_ctrl.preset_id = data.preset_id
	draw_ctrl.is_turret = is_turret_presets
	draw_ctrl.is_selected = (data.preset_id == selected_index)
	draw_ctrl.name = "Thumbnail"
	vbox.add_child(draw_ctrl)

	# Title Label
	var title_lbl = Label.new()
	title_lbl.text = data.title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))
	vbox.add_child(title_lbl)

	# Subtitle Label
	var sub_lbl = Label.new()
	sub_lbl.text = data.subtitle
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 10)
	sub_lbl.add_theme_color_override("font_color", Color(0.65, 0.72, 0.82))
	vbox.add_child(sub_lbl)

	btn.pressed.connect(func():
		select_card(data.preset_id, true)
	)

	return btn

func select_card(idx: int, emit_event: bool = true) -> void:
	selected_index = idx
	for i in range(_card_nodes.size()):
		var btn = _card_nodes[i] as Button
		if btn:
			var is_sel = (i == selected_index)
			
			# StyleBox highlight
			var sb = StyleBoxFlat.new()
			sb.corner_radius_top_left = 6
			sb.corner_radius_top_right = 6
			sb.corner_radius_bottom_left = 6
			sb.corner_radius_bottom_right = 6
			if is_sel:
				sb.bg_color = Color(0.18, 0.22, 0.3, 0.95)
				sb.border_color = Color(1.0, 0.78, 0.25, 0.95)
				sb.border_width_left = 2
				sb.border_width_top = 2
				sb.border_width_right = 2
				sb.border_width_bottom = 2
			else:
				sb.bg_color = Color(0.1, 0.12, 0.16, 0.85)
				sb.border_color = Color(0.22, 0.26, 0.34, 0.6)
				sb.border_width_left = 1
				sb.border_width_top = 1
				sb.border_width_right = 1
				sb.border_width_bottom = 1

			btn.add_theme_stylebox_override("normal", sb)
			btn.add_theme_stylebox_override("hover", sb)
			btn.add_theme_stylebox_override("pressed", sb)

			var thumb = btn.find_child("Thumbnail", true, false) as ThumbnailDrawControl
			if thumb:
				thumb.is_selected = is_sel
				thumb.queue_redraw()

	if emit_event:
		preset_selected.emit(selected_index)
