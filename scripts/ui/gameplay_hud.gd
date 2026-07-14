extends Control

signal pause_requested

const LockMeter = preload("res://scripts/ui/lock_meter.gd")

var _score_label: Label
var _lock_meter: Control

func setup() -> void:
	position=Vector2.ZERO
	size=Vector2(540,104)
	mouse_filter=Control.MOUSE_FILTER_IGNORE

	var top_band:=ColorRect.new()
	top_band.color=Color("#6ca9d6bd")
	top_band.size=Vector2(540,96)
	top_band.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(top_band)
	_add_line(Vector2.ZERO,Color("#62ddc9b0"))
	_add_line(Vector2(0,92),Color("#62ddc975"))

	_score_label=Label.new()
	_score_label.text="0"
	_score_label.position=Vector2(16,14)
	_score_label.add_theme_font_size_override("font_size",48)
	_score_label.add_theme_color_override("font_color",Color.WHITE)
	_score_label.add_theme_constant_override("outline_size",3)
	_score_label.add_theme_color_override("font_outline_color",Color("#43516a"))
	add_child(_score_label)

	_lock_meter=LockMeter.new()
	add_child(_lock_meter)
	_lock_meter.setup()
	_add_pause_button()

func _add_line(line_position:Vector2,color:Color)->void:
	var line:=ColorRect.new()
	line.position=line_position
	line.size=Vector2(540,4)
	line.color=color
	line.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(line)

func _add_pause_button()->void:
	var button:=Button.new()
	button.position=Vector2(470,18)
	button.size=Vector2(52,52)
	button.focus_mode=Control.FOCUS_NONE
	button.process_mode=Node.PROCESS_MODE_ALWAYS
	var normal:=StyleBoxFlat.new()
	normal.bg_color=Color(0,0,0,0)
	normal.border_color=Color.WHITE
	normal.set_border_width_all(4)
	var pressed:=normal.duplicate()
	pressed.bg_color=Color(1,1,1,.16)
	button.add_theme_stylebox_override("normal",normal)
	button.add_theme_stylebox_override("hover",normal)
	button.add_theme_stylebox_override("pressed",pressed)
	_add_rect(button,Vector2(14,11),Vector2(7,24),Color.WHITE)
	_add_rect(button,Vector2(29,11),Vector2(7,24),Color.WHITE)
	button.button_down.connect(_press_button.bind(button,Vector2(470,18)))
	button.button_up.connect(_release_button.bind(button,Vector2(470,18)))
	button.pressed.connect(func(): pause_requested.emit())
	add_child(button)

func _add_rect(parent:Node,rect_position:Vector2,rect_size:Vector2,color:Color)->void:
	var rect:=ColorRect.new()
	rect.position=rect_position
	rect.size=rect_size
	rect.color=color
	rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)

func _press_button(button:Button,rest_position:Vector2)->void:
	button.position=rest_position+Vector2(0,7)
	button.scale=Vector2(1.0,.97)

func _release_button(button:Button,rest_position:Vector2)->void:
	var tween:=button.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(button,"position",rest_position,.10)
	tween.tween_property(button,"scale",Vector2.ONE,.10)

func reset_hidden() -> void:
	visible=false
	position=Vector2(0,-108)
	modulate.a=0.0

func animate_in() -> void:
	visible=true
	position=Vector2(0,-108)
	modulate.a=0.0
	var enter:=create_tween().set_parallel(true)
	enter.tween_property(self,"position:y",0.0,.24).set_delay(.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	enter.tween_property(self,"modulate:a",1.0,.16).set_delay(.10)

func set_score(value:int)->void:
	_score_label.text=str(value)

func set_level_progress(current_points:int,goal_points:int)->void:
	_lock_meter.set_progress(current_points,goal_points)
