extends Control

signal pilots_requested
signal research_requested

var _tutorial: Control
var _overlay: Control

func setup() -> void:
	position=Vector2.ZERO
	size=Vector2(540,960)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	_tutorial=Control.new()
	_tutorial.size=Vector2(540,960)
	_tutorial.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(_tutorial)
	_build_tutorial()
	_overlay=Control.new()
	_overlay.size=Vector2(540,960)
	_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_build_logo()
	_build_shortcuts()
	reset_hidden()

func _build_logo()->void:
	var logo:=TextureRect.new()
	logo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode=TextureRect.STRETCH_SCALE
	logo.texture=load("res://assets/branding/suck-it-up-title-logo.png")
	logo.position=Vector2(24,34)
	logo.size=Vector2(492,162)
	logo.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(logo)

func _build_tutorial()->void:
	var condensed:=FontVariation.new()
	condensed.base_font=ThemeDB.fallback_font
	condensed.variation_transform=Transform2D(Vector2(.58,0),Vector2(0,1),Vector2.ZERO)
	condensed.variation_embolden=1.0
	var instruction:=_label(_tutorial,"SLIDE TO SUCK",Vector2(0,625),56,540,HORIZONTAL_ALIGNMENT_CENTER)
	instruction.add_theme_font_override("font",condensed)
	instruction.add_theme_color_override("font_outline_color",Color(0.32,.39,.40,.68))
	instruction.add_theme_constant_override("outline_size",2)
	instruction.add_theme_color_override("font_shadow_color",Color(0.18,0.22,0.25,.48))
	instruction.add_theme_constant_override("shadow_offset_x",1)
	instruction.add_theme_constant_override("shadow_offset_y",2)
	_add_arrow(Vector2(270,731),0.0)
	_add_arrow(Vector2(157,805),-PI/2.0)
	_add_arrow(Vector2(383,805),PI/2.0)

	var finger:=Control.new()
	finger.position=Vector2(270,798)
	finger.scale=Vector2(.74,.74)
	finger.rotation_degrees=-22
	finger.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_tutorial.add_child(finger)
	var shadow:=Panel.new()
	shadow.position=Vector2(-29,6)
	shadow.size=Vector2(70,170)
	var shadow_style:=StyleBoxFlat.new()
	shadow_style.bg_color=Color(0.22,0.29,0.34,.28)
	_set_finger_corners(shadow_style)
	shadow.add_theme_stylebox_override("panel",shadow_style)
	finger.add_child(shadow)
	var body:=Panel.new()
	body.position=Vector2(-35,0)
	body.size=Vector2(70,170)
	var body_style:=StyleBoxFlat.new()
	body_style.bg_color=Color("#f8fbfb")
	_set_finger_corners(body_style)
	body.add_theme_stylebox_override("panel",body_style)
	finger.add_child(body)
	var crease:=Panel.new()
	crease.position=Vector2(-28,18)
	crease.size=Vector2(56,48)
	var crease_style:=StyleBoxFlat.new()
	crease_style.bg_color=Color(0,0,0,0)
	crease_style.border_color=Color("#8a969b")
	crease_style.border_width_left=6
	crease_style.border_width_top=6
	crease_style.border_width_right=6
	crease_style.corner_radius_top_left=28
	crease_style.corner_radius_top_right=28
	crease.add_theme_stylebox_override("panel",crease_style)
	finger.add_child(crease)

func _set_finger_corners(style:StyleBoxFlat)->void:
	style.corner_radius_top_left=35
	style.corner_radius_top_right=35
	style.corner_radius_bottom_left=6
	style.corner_radius_bottom_right=6

func _add_arrow(center:Vector2,angle:float)->void:
	var points:=PackedVector2Array([Vector2(0,-42),Vector2(33,-5),Vector2(20,-5),Vector2(20,37),Vector2(-20,37),Vector2(-20,-5),Vector2(-33,-5)])
	var shadow:=Polygon2D.new()
	shadow.polygon=points
	shadow.position=center+Vector2(3,4)
	shadow.rotation=angle
	shadow.scale=Vector2(.78,.78)
	shadow.color=Color(0.18,0.24,0.28,.38)
	_tutorial.add_child(shadow)
	var arrow:=Polygon2D.new()
	arrow.polygon=points
	arrow.position=center
	arrow.rotation=angle
	arrow.scale=Vector2(.78,.78)
	arrow.color=Color("#f8fbfb")
	_tutorial.add_child(arrow)

func _build_shortcuts()->void:
	var pilots:=_nav_button(Vector2(8,822),Color("#eb9e00"),Color("#ffde04"),Color("#d45d00"))
	pilots.tooltip_text="Space Pilots"
	pilots.pressed.connect(func(): pilots_requested.emit())
	_add_shortcut_icon(pilots,"res://assets/ui/nav-icons/nav-astronaut-icon.png",Vector2(9,8),Vector2(96,80))
	var research:=_nav_button(Vector2(407,822),Color("#af47d0"),Color("#ebb6fc"),Color("#7d27b1"))
	research.tooltip_text="Research Lab"
	research.pressed.connect(func(): research_requested.emit())
	_add_shortcut_icon(research,"res://assets/ui/nav-icons/nav-research-icon.png",Vector2(15,4),Vector2(84,88))

func _nav_button(button_position:Vector2,face_color:Color,rim_color:Color,step_color:Color)->Button:
	var button:=Button.new()
	button.position=button_position
	button.size=Vector2(126,130)
	button.focus_mode=Control.FOCUS_NONE
	var clear:=StyleBoxFlat.new()
	clear.bg_color=Color(0,0,0,0)
	button.add_theme_stylebox_override("normal",clear)
	button.add_theme_stylebox_override("hover",clear)
	button.add_theme_stylebox_override("pressed",clear)
	var step:=ColorRect.new()
	step.size=Vector2(126,130)
	step.color=step_color
	step.mouse_filter=Control.MOUSE_FILTER_IGNORE
	button.add_child(step)
	var face:=Panel.new()
	face.size=Vector2(126,108)
	face.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var face_style:=StyleBoxFlat.new()
	face_style.bg_color=face_color
	face_style.border_color=rim_color
	face_style.set_border_width_all(6)
	face.add_theme_stylebox_override("panel",face_style)
	button.add_child(face)
	var icon_host:=Control.new()
	icon_host.position=Vector2(6,6)
	icon_host.size=Vector2(114,96)
	icon_host.clip_contents=true
	icon_host.mouse_filter=Control.MOUSE_FILTER_IGNORE
	button.add_child(icon_host)
	button.set_meta("icon_host",icon_host)
	button.button_down.connect(_press_button.bind(button,button_position))
	button.button_up.connect(_release_button.bind(button,button_position))
	button.mouse_exited.connect(_release_button.bind(button,button_position))
	_overlay.add_child(button)
	return button

func _add_shortcut_icon(button:Button,path:String,icon_position:Vector2,icon_size:Vector2)->void:
	var icon:=TextureRect.new()
	icon.texture=load(path)
	icon.position=icon_position
	icon.size=icon_size
	icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
	(button.get_meta("icon_host") as Control).add_child(icon)

func _press_button(button:Button,rest_position:Vector2)->void:
	button.position=rest_position+Vector2(0,7)
	button.scale=Vector2(1.0,.97)

func _release_button(button:Button,rest_position:Vector2)->void:
	var old_tween:Tween=button.get_meta("release_tween") as Tween if button.has_meta("release_tween") else null
	if old_tween and old_tween.is_valid():
		old_tween.kill()
	var tween:=button.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(button,"position",rest_position,.10)
	tween.tween_property(button,"scale",Vector2.ONE,.10)
	button.set_meta("release_tween",tween)

func _label(parent:Node,text:String,label_position:Vector2,font_size:int,width:float,alignment:HorizontalAlignment)->Label:
	var label:=Label.new()
	label.text=text
	label.position=label_position
	label.size=Vector2(width,font_size*1.55)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color.WHITE)
	label.horizontal_alignment=alignment
	parent.add_child(label)
	return label

func reset_hidden()->void:
	visible=false
	_overlay.position=Vector2.ZERO
	_overlay.modulate.a=1.0
	_tutorial.position=Vector2.ZERO
	_tutorial.modulate.a=1.0

func reveal()->void:
	visible=true
	_overlay.position=Vector2(540,0)
	_overlay.modulate.a=1.0
	_tutorial.position=Vector2.ZERO
	_tutorial.modulate.a=0.0
	var tween:=create_tween().set_parallel(true)
	tween.tween_property(_overlay,"position",Vector2.ZERO,.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_tutorial,"modulate:a",1.0,.28).set_delay(.08)

func animate_out()->void:
	var tween:=create_tween().set_parallel(true)
	tween.tween_property(_overlay,"position:y",-205.0,.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_overlay,"modulate:a",0.0,.18).set_delay(.05)
	tween.tween_property(_tutorial,"position:y",-72.0,.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_tutorial,"modulate:a",0.0,.16)
	tween.chain().tween_callback(reset_hidden)

func has_shortcut_at(screen_position:Vector2)->bool:
	return Rect2(8,822,126,130).has_point(screen_position) or Rect2(407,822,126,130).has_point(screen_position)
