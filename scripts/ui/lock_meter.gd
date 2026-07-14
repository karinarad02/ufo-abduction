extends Control

var _fill_segments: Array[Polygon2D] = []
var _shackle: Panel
var _unlocked := false
var _unlock_tween: Tween

func setup() -> void:
	position=Vector2(232,8)
	size=Vector2(76,76)
	pivot_offset=Vector2(38,38)
	mouse_filter=Control.MOUSE_FILTER_IGNORE

	_add_half(PI/2.0,Color("#43516a"))
	_add_half(-PI/2.0,Color("#43516a"))
	for i in 32:
		var a0:=-PI/2.0+TAU*i/32.0
		var a1:=-PI/2.0+TAU*(i+1)/32.0+.012
		var wedge:=Polygon2D.new()
		wedge.polygon=PackedVector2Array([Vector2(38,38),Vector2(38+cos(a0)*36,38+sin(a0)*36),Vector2(38+cos(a1)*36,38+sin(a1)*36)])
		wedge.color=Color("#f29b18")
		wedge.visible=false
		add_child(wedge)
		_fill_segments.append(wedge)

	_shackle=Panel.new()
	_shackle.position=Vector2(27,19)
	_shackle.size=Vector2(22,25)
	_shackle.pivot_offset=Vector2(11,12)
	var shackle_style:=StyleBoxFlat.new()
	shackle_style.bg_color=Color(0,0,0,0)
	shackle_style.border_color=Color.WHITE
	shackle_style.border_width_left=5
	shackle_style.border_width_right=5
	shackle_style.border_width_top=5
	shackle_style.corner_radius_top_left=10
	shackle_style.corner_radius_top_right=10
	_shackle.add_theme_stylebox_override("panel",shackle_style)
	add_child(_shackle)

	var lock_body:=ColorRect.new()
	lock_body.position=Vector2(24,37)
	lock_body.size=Vector2(28,22)
	lock_body.color=Color.WHITE
	lock_body.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(lock_body)
	var keyhole:=ColorRect.new()
	keyhole.position=Vector2(36,44)
	keyhole.size=Vector2(4,9)
	keyhole.color=Color("#d3aa20")
	keyhole.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(keyhole)

func _add_half(start_angle:float,color:Color)->void:
	var points:=PackedVector2Array([Vector2(38,38)])
	for i in 17:
		var angle:=start_angle+PI*i/16.0
		points.append(Vector2(38+cos(angle)*36,38+sin(angle)*36))
	var half:=Polygon2D.new()
	half.polygon=points
	half.color=color
	add_child(half)

func set_progress(current_points:int,goal_points:int)->void:
	var progress:=clampf(float(current_points)/maxf(1.0,float(goal_points)),0.0,1.0)
	var fill_color:=Color("#f08b1d").lerp(Color("#f5c51e"),clampf((progress-.25)/.55,0.0,1.0))
	if progress>=1.0:
		fill_color=Color("#13bd50")
	for i in _fill_segments.size():
		_fill_segments[i].visible=float(i+1)/_fill_segments.size()<=progress+.012
		_fill_segments[i].color=fill_color
	if progress>=1.0 and not _unlocked:
		_play_unlock()
	elif progress<1.0 and _unlocked:
		reset_lock()

func reset_lock()->void:
	if _unlock_tween and _unlock_tween.is_valid():
		_unlock_tween.kill()
	_unlocked=false
	_shackle.rotation=0.0
	_shackle.position=Vector2(27,19)
	scale=Vector2.ONE

func _play_unlock()->void:
	_unlocked=true
	var unlock:=create_tween().set_parallel(true)
	_unlock_tween=unlock
	unlock.tween_property(_shackle,"rotation",-.52,.18).set_delay(.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	unlock.tween_property(_shackle,"position",Vector2(31,15),.18).set_delay(.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	unlock.tween_property(self,"scale",Vector2(1.14,1.14),.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	unlock.chain().tween_property(self,"scale",Vector2.ONE,.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
