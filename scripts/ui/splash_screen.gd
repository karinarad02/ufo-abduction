extends Control

signal finished

func setup()->void:
	position=Vector2.ZERO
	size=Vector2(540,960)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var background:=ColorRect.new()
	background.color=Color("#f6f6f6")
	background.size=Vector2(540,960)
	add_child(background)

	var app_logo:=Control.new()
	app_logo.size=Vector2(540,960)
	add_child(app_logo)
	_add_logo(app_logo,"res://assets/branding/ufo-logo-generated.png",Vector2(50,245),Vector2(440,402))

	var company_logo:=Control.new()
	company_logo.size=Vector2(540,960)
	company_logo.visible=false
	add_child(company_logo)
	_add_logo(company_logo,"res://assets/branding/kiseki-logo-generated.png",Vector2(42,330),Vector2(456,289))

	var sequence:=create_tween()
	sequence.tween_interval(1.8)
	sequence.tween_callback(func(): app_logo.visible=false; company_logo.visible=true)
	sequence.tween_interval(1.8)
	sequence.tween_property(self,"modulate:a",0.0,.45)
	sequence.tween_callback(func(): finished.emit(); queue_free())

func _add_logo(parent:Control,path:String,logo_position:Vector2,logo_size:Vector2)->void:
	var logo:=TextureRect.new()
	logo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.texture=load(path)
	logo.position=logo_position
	logo.size=logo_size
	logo.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(logo)
