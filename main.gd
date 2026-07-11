extends Node3D

const KINDS := ["COW", "CHICKEN", "PIG", "SHEEP"]
const KIND_COLORS := [Color("#f4f0df"), Color("#ffd83f"), Color("#f38ca2"), Color("#d5d5d0")]
var rng := RandomNumberGenerator.new()
var ship: Node3D
var beam: MeshInstance3D
var camera: Camera3D
var target_position := Vector3(0, 2.7, 0)
var creatures: Array[Node3D] = []
var particles: Array[Dictionary] = []
var dragging := false
var game_state := "title"
var score := 0
var best := 0
var combo := 0
var target_kind := 0
var time_left := 60.0
var charge := 0.0
var frenzy := 0.0
var score_label: Label
var timer_label: Label
var target_label: Label
var combo_label: Label
var frenzy_bar: ProgressBar
var title_panel: Control
var result_panel: Control
var result_label: Label
var hud_root: Control
var pause_button: Button
var menu_root: Control
var menu_content: Control
var game_ui: Control
var gems := 55
var coins := 1195
var duck_level := 4

func _ready() -> void:
	rng.randomize()
	if FileAccess.file_exists("user://best3d.txt"):
		best = int(FileAccess.get_file_as_string("user://best3d.txt"))
	build_world()
	build_ui()
	for i in 16: spawn_creature()
	set_process(true)

func mat(color: Color, emission := Color.BLACK, transparent := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.82
	if emission != Color.BLACK:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = 1.6
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func box(parent: Node, size: Vector3, pos: Vector3, color: Color, box_rotation := Vector3.ZERO) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.position = pos
	n.rotation = box_rotation
	n.material_override = mat(color)
	parent.add_child(n)
	return n

func cylinder(parent: Node, radius: float, height: float, pos: Vector3, color: Color, sides := 8) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	n.mesh = mesh
	n.position = pos
	n.material_override = mat(color)
	parent.add_child(n)
	return n

func build_world() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#79c9f4")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#d9f3ff")
	environment.ambient_light_energy = 1.15
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = environment
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -35, 0)
	sun.light_color = Color("#fff3c4")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 15.5
	camera.position = Vector3(0, 12.5, 11)
	camera.look_at_from_position(camera.position, Vector3(0, 0, 0))
	add_child(camera)

	# Layered floating island.
	cylinder(self, 7.25, 1.25, Vector3(0,-0.85,0), Color("#8a542f"), 8)
	cylinder(self, 7.05, .72, Vector3(0,-0.22,0), Color("#b77842"), 8)
	cylinder(self, 6.95, .32, Vector3(0,.18,0), Color("#7fc948"), 8)
	cylinder(self, 6.82, .16, Vector3(0,.39,0), Color("#9ee25d"), 8)

	# Pond, well, barn, crop plot and fences.
	cylinder(self, 1.25, .06, Vector3(-3.7,.58,-2.7), Color("#47bfe4"), 12)
	for i in 10:
		var a := i*TAU/10.0
		box(self, Vector3(.42,.35,.6), Vector3(-3.7+cos(a)*1.3,.68,-2.7+sin(a)*1.3), Color("#aeb4ad"), Vector3(0,-a,0))
	box(self, Vector3(2.2,1.65,1.8), Vector3(3.8,1.2,-2.7), Color("#d34f4c"))
	var roof := box(self, Vector3(2.65,.35,2.25), Vector3(3.8,2.15,-2.7), Color("#79364e"))
	roof.rotation_degrees.z = 7
	box(self, Vector3(.75,1.25,.08), Vector3(3.8,1.0,-1.77), Color("#733848"))
	box(self, Vector3(2.4,.12,2.2), Vector3(3.3,.58,3.3), Color("#6ea943"))
	for x in 4:
		for z in 4:
			var crop := cylinder(self,.12,.65,Vector3(2.45+x*.55,.95,2.45+z*.52),Color("#f4c442"),6)
			crop.rotation_degrees.z = rng.randf_range(-12,12)
	for side in [-1,1]:
		for i in 6:
			box(self,Vector3(.15,.7,.15),Vector3(side*6.1,.9,-3.3+i*1.1),Color("#a36a39"))
			box(self,Vector3(.12,.15,1.05),Vector3(side*6.1,1.0,-3.3+i*1.1),Color("#c58a4b"))

	build_ship()

func build_ship() -> void:
	ship = Node3D.new()
	ship.position = target_position
	add_child(ship)
	var saucer := cylinder(ship, .72, .22, Vector3.ZERO, Color("#526bdd"), 16)
	saucer.scale.z = 1.25
	cylinder(ship,.48,.24,Vector3(0,.2,0),Color("#75dcf4"),16)
	cylinder(ship,.32,.2,Vector3(0,.34,0),Color("#f3a7dc"),12)
	for i in 8:
		var a:=i*TAU/8.0
		var light:=cylinder(ship,.055,.05,Vector3(cos(a)*.58,-.13,sin(a)*.73),Color("#ffe754"),8)
		light.material_override=mat(Color("#ffe754"),Color("#ffe754"))
	beam = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius=.13; cone.bottom_radius=1.0; cone.height=2.65; cone.radial_segments=20
	beam.mesh=cone
	beam.position=Vector3(0,-1.43,0)
	beam.material_override=mat(Color(0.72,0.35,0.94,.3),Color("#a252df"),true)
	beam.visible=false
	ship.add_child(beam)
	for i in 24:
		var a:=i*TAU/24.0
		var tile:=box(ship,Vector3(.18,.035,.38),Vector3(cos(a)*.92,-2.28,sin(a)*.92),Color("#743a91") if i%3 else Color("#f0c52d"))
		tile.rotation.y=-a

func spawn_creature() -> void:
	var kind:=rng.randi_range(0,3)
	var p:=Vector3(rng.randf_range(-5.2,5.2),.72,rng.randf_range(-4.7,4.7))
	while Vector2(p.x,p.z).length()>5.7 or (abs(p.x-3.8)<1.8 and abs(p.z+2.7)<1.7):
		p=Vector3(rng.randf_range(-5.2,5.2),.72,rng.randf_range(-4.7,4.7))
	var root:=Node3D.new()
	root.position=p
	root.set_meta("kind",kind)
	root.set_meta("lift",0.0)
	add_child(root)
	var c: Color = KIND_COLORS[kind]
	if kind==0:
		box(root,Vector3(.72,.62,1.0),Vector3.ZERO,c)
		box(root,Vector3(.62,.55,.52),Vector3(0,.15,-.63),c)
		for q in [Vector3(-.22,-.42,-.28),Vector3(.22,-.42,-.28),Vector3(-.22,-.42,.28),Vector3(.22,-.42,.28)]: box(root,Vector3(.16,.55,.16),q,Color("#34303a"))
		for q in [Vector3(-.23,.12,-.28),Vector3(.2,-.1,.2),Vector3(.25,.16,.38)]: box(root,Vector3(.2,.18,.22),q,Color("#2e3038"))
		box(root,Vector3(.28,.17,.12),Vector3(0,.05,-.93),Color("#ef9ca5"))
	elif kind==1:
		box(root,Vector3(.55,.52,.58),Vector3.ZERO,c)
		box(root,Vector3(.42,.42,.38),Vector3(0,.35,-.3),c)
		box(root,Vector3(.18,.14,.25),Vector3(0,.32,-.6),Color("#ed7a31"))
		for x in [-.18,.18]: box(root,Vector3(.07,.35,.07),Vector3(x,-.4,0),Color("#ed8a31"))
	elif kind==2:
		box(root,Vector3(.75,.58,.92),Vector3.ZERO,c)
		box(root,Vector3(.62,.5,.5),Vector3(0,.12,-.62),c)
		box(root,Vector3(.4,.22,.12),Vector3(0,.03,-.92),Color("#ffb0b7"))
		for x in [-.22,.22]: box(root,Vector3(.15,.45,.15),Vector3(x,-.4,.2),Color("#b65f74"))
	else:
		box(root,Vector3(.78,.65,.92),Vector3.ZERO,c)
		box(root,Vector3(.55,.5,.48),Vector3(0,.12,-.63),Color("#4c4b52"))
		for x in [-.24,.24]: box(root,Vector3(.14,.45,.14),Vector3(x,-.42,.2),Color("#4c4b52"))
	creatures.append(root)

func build_ui() -> void:
	var layer:=CanvasLayer.new()
	add_child(layer)
	var root:=Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	hud_root=root
	game_ui=Control.new()
	game_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(game_ui)
	var top_band:=ColorRect.new()
	top_band.color=Color("#668bd1b8"); top_band.position=Vector2(0,0); top_band.size=Vector2(540,108); top_band.mouse_filter=Control.MOUSE_FILTER_IGNORE
	game_ui.add_child(top_band)
	score_label=make_label(game_ui,"0",Vector2(24,22),42)
	timer_label=make_label(game_ui,"",Vector2.ZERO,1); timer_label.visible=false
	var meter_outer:=panel(game_ui,Vector2(226,9),Vector2(88,88),Color("#f8c62d"))
	round_panel(meter_outer,44,Color("#f8c62d"),0)
	var meter_inner:=panel(game_ui,Vector2(236,19),Vector2(68,68),Color("#43516a"))
	round_panel(meter_inner,34,Color("#43516a"),0)
	make_label(game_ui,"[]",Vector2(236,27),30,68,HORIZONTAL_ALIGNMENT_CENTER)
	target_label=make_label(game_ui,KINDS[target_kind],Vector2(210,81),13,120,HORIZONTAL_ALIGNMENT_CENTER)
	combo_label=make_label(game_ui,"",Vector2.ZERO,1); combo_label.visible=false
	frenzy_bar=ProgressBar.new(); frenzy_bar.visible=false; game_ui.add_child(frenzy_bar)
	pause_button=Button.new(); pause_button.text="II"; pause_button.position=Vector2(465,20); pause_button.size=Vector2(56,56)
	pause_button.add_theme_font_size_override("font_size",26); pause_button.add_theme_color_override("font_color",Color.WHITE)
	pause_button.process_mode=Node.PROCESS_MODE_ALWAYS; pause_button.pressed.connect(toggle_pause); game_ui.add_child(pause_button)
	result_panel=panel(root,Vector2(55,280),Vector2(430,300),Color("#35479bf2"))
	make_label(result_panel,"SHIFT COMPLETE",Vector2(0,30),34,430,HORIZONTAL_ALIGNMENT_CENTER)
	result_label=make_label(result_panel,"SCORE 0",Vector2(0,110),34,430,HORIZONTAL_ALIGNMENT_CENTER)
	var again:=menu_button(result_panel,"PLAY AGAIN",Vector2(65,215),Vector2(300,64),Color("#c83fe0"))
	again.pressed.connect(start_game)
	result_panel.visible=false
	game_ui.visible=false
	build_menu_shell(root)
	show_menu("home")
	build_splash(root)

func build_splash(root:Control)->void:
	var splash:=Control.new(); splash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); splash.mouse_filter=Control.MOUSE_FILTER_STOP; root.add_child(splash)
	var bg:=ColorRect.new(); bg.color=Color("#d8fff1"); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); splash.add_child(bg)
	var mascot:=panel(splash,Vector2(165,250),Vector2(210,300),Color("#cfd6d5"))
	round_panel(mascot,35,Color("#cfd6d5"),0)
	make_label(mascot,"o   o",Vector2(0,100),42,210,HORIZONTAL_ALIGNMENT_CENTER)
	make_label(mascot,"u",Vector2(0,145),36,210,HORIZONTAL_ALIGNMENT_CENTER)
	make_label(splash,"UFO ABDUCTION",Vector2(0,610),34,540,HORIZONTAL_ALIGNMENT_CENTER)
	var tw:=create_tween(); tw.tween_interval(1.35); tw.tween_property(splash,"modulate:a",0.0,.45); tw.tween_callback(splash.queue_free)

func build_menu_shell(root:Control)->void:
	menu_root=Control.new(); menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_child(menu_root)
	var bg:=ColorRect.new(); bg.color=Color("#8a55c4"); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); menu_root.add_child(bg)
	make_label(menu_root,"◆ %d"%gems,Vector2(16,22),28)
	var gem_plus:=menu_button(menu_root,"+",Vector2(140,13),Vector2(46,52),Color("#16bc67")); gem_plus.add_theme_font_size_override("font_size",30)
	make_label(menu_root,"◇ %d"%coins,Vector2(360,22),28)
	var coin_plus:=menu_button(menu_root,"+",Vector2(480,13),Vector2(46,52),Color("#16bc67")); coin_plus.add_theme_font_size_override("font_size",30)
	menu_content=Control.new(); menu_content.position=Vector2(14,88); menu_content.size=Vector2(512,758); menu_root.add_child(menu_content)
	var tabs=[["COLL",Color("#43d6ec"),"collections"],["LAB",Color("#d547db"),"research"],["PILOTS",Color("#f49b19"),"pilots"],["PLAY",Color("#29c75b"),"play"]]
	for i in tabs.size():
		var b:=menu_button(menu_root,tabs[i][0],Vector2(8+i*133,864),Vector2(125,82),tabs[i][1])
		b.add_theme_font_size_override("font_size",18)
		var page:String=tabs[i][2]
		if page=="play": b.pressed.connect(start_game)
		else: b.pressed.connect(show_menu.bind(page))

func clear_content()->void:
	for child in menu_content.get_children(): child.queue_free()

func show_menu(page:String)->void:
	game_state="menu"; game_ui.visible=false; result_panel.visible=false; menu_root.visible=true
	clear_content()
	if page=="home": build_home()
	elif page=="collections": build_collections()
	elif page=="research": build_research()
	elif page=="pilots": build_pilots()
	elif page=="duck": build_duck_detail()

func menu_heading(title:String,color:=Color("#35479b"))->Panel:
	var h:=panel(menu_content,Vector2(0,0),Vector2(512,82),color)
	make_label(h,title,Vector2(0,18),38,512,HORIZONTAL_ALIGNMENT_CENTER)
	return h

func build_home()->void:
	menu_heading("UFO ABDUCTION")
	var card:=panel(menu_content,Vector2(0,100),Vector2(512,600),Color("#445ba8"))
	make_label(card,"READY,\nSPACE PILOT?",Vector2(0,60),45,512,HORIZONTAL_ALIGNMENT_CENTER)
	make_label(card,"Collect creatures, chain combos,\nand charge into FRENZY!",Vector2(0,190),21,512,HORIZONTAL_ALIGNMENT_CENTER)
	var play:=menu_button(card,"LAUNCH",Vector2(75,330),Vector2(362,100),Color("#2dcc55")); play.add_theme_font_size_override("font_size",38); play.pressed.connect(start_game)
	make_label(card,"BEST SCORE  %05d"%best,Vector2(0,480),22,512,HORIZONTAL_ALIGNMENT_CENTER)

func build_collections()->void:
	menu_heading("COLLECTIONS")
	var card:=panel(menu_content,Vector2(0,100),Vector2(512,600),Color("#556fae"))
	var data=[["COW","COMMON",Color("#48ccef")],["DUCK","COMMON",Color("#d444d9")],["PIG","COMMON",Color("#f49a18")],["SHEEP","RARE",Color("#2bc85b")]]
	for i in data.size():
		var x:=24+(i%2)*240; var y:=35+(i/2.0)*245
		var b:=menu_button(card,data[i][0]+"\nLvl.%d"%(3+i),Vector2(x,y),Vector2(220,205),data[i][2])
		b.add_theme_font_size_override("font_size",27)
		make_label(b,data[i][1],Vector2(0,148),15,220,HORIZONTAL_ALIGNMENT_CENTER)
		if i==1: b.pressed.connect(show_menu.bind("duck"))

func build_research()->void:
	menu_heading("RESEARCH LAB")
	var card:=panel(menu_content,Vector2(0,100),Vector2(512,600),Color("#7652a5"))
	for i in 3:
		var x:=18+i*164
		var pod:=panel(card,Vector2(x,50),Vector2(150,330),Color("#4157a7"))
		make_label(pod,str(i+1),Vector2(0,12),28,150,HORIZONTAL_ALIGNMENT_CENTER)
		var glass:=panel(pod,Vector2(20,62),Vector2(110,145),Color("#cf4be080"))
		round_panel(glass,4,Color("#cf4be080"),2)
		make_label(glass,"EGG" if i<2 else "EMPTY",Vector2(0,50),22,110,HORIZONTAL_ALIGNMENT_CENTER)
		var action:=menu_button(pod,"COLLECT" if i==1 else ("1:59:54" if i==0 else "START"),Vector2(10,235),Vector2(130,68),Color("#f4a014") if i==1 else Color("#36c95c"))
		action.add_theme_font_size_override("font_size",18)
	make_label(card,"Research eggs to discover new creatures",Vector2(0,455),20,512,HORIZONTAL_ALIGNMENT_CENTER)

func build_pilots()->void:
	menu_heading("SPACE PILOTS")
	var card:=panel(menu_content,Vector2(0,100),Vector2(512,600),Color("#596276"))
	var names=["NOVA","PAULA","ACE","BOT","MIMI","LOCKED"]
	for i in names.size():
		var x:=20+(i%3)*164; var y:=28+(i/3.0)*250
		var c:=menu_button(card,names[i],Vector2(x,y),Vector2(145,215),Color("#3c465c") if i==5 else Color("#5364aa"))
		c.add_theme_font_size_override("font_size",20)
		make_label(c,"■",Vector2(0,48),62,145,HORIZONTAL_ALIGNMENT_CENTER)
		make_label(c,"SELECTED" if i==0 else ("???" if i==5 else "UNLOCKED"),Vector2(0,160),14,145,HORIZONTAL_ALIGNMENT_CENTER)

func build_duck_detail()->void:
	menu_heading("Duck        COMMON")
	var card:=panel(menu_content,Vector2(0,96),Vector2(512,650),Color("#35479b"))
	make_label(card,"DUCK",Vector2(28,35),42,190,HORIZONTAL_ALIGNMENT_CENTER)
	make_label(card,"Lvl.%d ▲"%duck_level,Vector2(245,35),32)
	var progress:=ProgressBar.new(); progress.position=Vector2(195,100); progress.size=Vector2(285,42); progress.max_value=500; progress.value=500; progress.show_percentage=false
	var fill:=StyleBoxFlat.new(); fill.bg_color=Color("#42d65c"); progress.add_theme_stylebox_override("fill",fill)
	var back:=StyleBoxFlat.new(); back.bg_color=Color("#253678"); progress.add_theme_stylebox_override("background",back); card.add_child(progress)
	make_label(card,"514/500",Vector2(195,104),22,285,HORIZONTAL_ALIGNMENT_CENTER)
	make_label(card,"Total Sucked: 1139",Vector2(220,150),20)
	var rows:=panel(card,Vector2(20,205),Vector2(472,255),Color("#2d5ca4"))
	round_panel(rows,0,Color("#2d5ca4"),0)
	var upgrades=["lvl.2    10% slower run away speed","lvl.3    14% detection decrease","lvl.4    9% chance Common Egg drop","lvl.5    Extra 1 coins drop","lvl.6    Unlock Duck Pilot"]
	for i in upgrades.size():
		if i<3:
			var strip:=ColorRect.new(); strip.color=Color("#27c943"); strip.position=Vector2(0,i*49); strip.size=Vector2(472,49); rows.add_child(strip)
		make_label(rows,upgrades[i],Vector2(14,8+i*49),18)
	var up:=menu_button(card,"UPGRADE\n◇ 1000",Vector2(105,500),Vector2(302,105),Color("#c83fe0")); up.add_theme_font_size_override("font_size",28)
	up.pressed.connect(upgrade_duck)

func upgrade_duck()->void:
	if coins>=1000:
		coins-=1000; duck_level+=1; show_menu("duck")

func menu_button(parent:Node,text:String,pos:Vector2,size:Vector2,color:Color)->Button:
	var b:=Button.new(); b.text=text; b.position=pos; b.size=size
	b.add_theme_font_size_override("font_size",24); b.add_theme_color_override("font_color",Color.WHITE); b.add_theme_color_override("font_shadow_color",Color("#452861")); b.add_theme_constant_override("shadow_offset_x",2); b.add_theme_constant_override("shadow_offset_y",3)
	var normal:=StyleBoxFlat.new(); normal.bg_color=color; normal.border_width_left=4; normal.border_width_right=4; normal.border_width_top=4; normal.border_width_bottom=8; normal.border_color=color.darkened(.28)
	var pressed:=normal.duplicate(); pressed.bg_color=color.darkened(.12); pressed.border_width_bottom=4
	b.add_theme_stylebox_override("normal",normal); b.add_theme_stylebox_override("hover",normal); b.add_theme_stylebox_override("pressed",pressed)
	parent.add_child(b); return b

func round_panel(p:Panel,radius:int,color:Color,border:int)->void:
	var sb:=p.get_theme_stylebox("panel") as StyleBoxFlat
	sb.bg_color=color; sb.corner_radius_top_left=radius; sb.corner_radius_top_right=radius; sb.corner_radius_bottom_left=radius; sb.corner_radius_bottom_right=radius
	sb.border_width_left=border; sb.border_width_right=border; sb.border_width_top=border; sb.border_width_bottom=border
func make_label(parent:Node,text:String,pos:Vector2,size:int,width:=0.0,align:=HORIZONTAL_ALIGNMENT_LEFT)->Label:
	var l:=Label.new(); l.text=text; l.position=pos; l.add_theme_font_size_override("font_size",size); l.add_theme_color_override("font_color",Color.WHITE); l.add_theme_color_override("font_shadow_color",Color(0.1,0.1,0.2,.75)); l.add_theme_constant_override("shadow_offset_x",3); l.add_theme_constant_override("shadow_offset_y",3)
	if width>0: l.size=Vector2(width,size+12); l.horizontal_alignment=align
	parent.add_child(l); return l

func panel(parent:Node,pos:Vector2,size:Vector2,color:Color)->Panel:
	var p:=Panel.new(); p.position=pos; p.size=size
	var sb:=StyleBoxFlat.new(); sb.bg_color=color; sb.corner_radius_top_left=18; sb.corner_radius_top_right=18; sb.corner_radius_bottom_left=18; sb.corner_radius_bottom_right=18; sb.border_width_left=4; sb.border_width_right=4; sb.border_width_top=4; sb.border_width_bottom=4; sb.border_color=Color("#6ff0da")
	p.add_theme_stylebox_override("panel",sb); parent.add_child(p); return p

func _input(e:InputEvent)->void:
	if e is InputEventScreenTouch:
		dragging=e.pressed
		if e.pressed and game_state=="over": start_game()
	elif e is InputEventScreenDrag and game_state=="play":
		target_position.x=clamp(target_position.x+e.relative.x*.018,-5.4,5.4)
		target_position.z=clamp(target_position.z+e.relative.y*.018,-5.0,5.0)
	elif e is InputEventMouseButton:
		dragging=e.pressed
		if e.pressed and game_state=="over": start_game()
	elif e is InputEventMouseMotion and dragging and game_state=="play":
		target_position.x=clamp(target_position.x+e.relative.x*.018,-5.4,5.4)
		target_position.z=clamp(target_position.z+e.relative.y*.018,-5.0,5.0)

func toggle_pause()->void:
	if game_state!="play": return
	get_tree().paused=not get_tree().paused
	pause_button.text=">" if get_tree().paused else "II"

func start_game()->void:
	game_state="play"; score=0; combo=0; time_left=60; charge=0; frenzy=0; target_kind=rng.randi_range(0,3)
	menu_root.visible=false; game_ui.visible=true; result_panel.visible=false; pause_button.visible=true; camera.size=19.0; create_tween().tween_property(camera,"size",15.5,.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _process(d:float)->void:
	ship.position=ship.position.lerp(target_position,min(1.0,d*8.0))
	ship.position.y=2.7+sin(Time.get_ticks_msec()/180.0)*.08
	ship.rotation.y+=d*.45
	if game_state=="play":
		var camera_goal:=Vector3(ship.position.x,12.5,11.0+ship.position.z)
		camera.position=camera.position.lerp(camera_goal,min(1.0,d*2.8))
		camera.look_at(Vector3(ship.position.x,0,ship.position.z))
		camera.size=lerp(camera.size,14.2 if frenzy>0 else 15.5,min(1.0,d*2.0))
	beam.visible=dragging and game_state=="play"
	if game_state=="play":
		time_left-=d; frenzy=max(0.0,frenzy-d)
		if charge>=100 and frenzy<=0: frenzy=7; charge=0; beam.material_override=mat(Color(1,.82,.18,.34),Color("#ffd331"),true)
		if frenzy<=0 and beam.material_override.albedo_color.r>.9: beam.material_override=mat(Color(.72,.35,.94,.3),Color("#a252df"),true)
		if dragging: abduct(d)
		if time_left<=0: finish_game()
		update_hud()
	for c in creatures:
		if is_instance_valid(c):
			c.rotation.y+=sin(Time.get_ticks_msec()/500.0+c.position.x)*d*.18

func abduct(d:float)->void:
	var chosen:Node3D
	var closest:=99.0
	for c in creatures:
		if not is_instance_valid(c): continue
		var dist:=Vector2(c.position.x-ship.position.x,c.position.z-ship.position.z).length()
		if dist<1.05 and dist<closest: chosen=c; closest=dist
	if chosen==null:return
	chosen.position.x=lerp(chosen.position.x,ship.position.x,d*4)
	chosen.position.z=lerp(chosen.position.z,ship.position.z,d*4)
	chosen.position.y+=d*(2.2 if frenzy>0 else 1.25)
	chosen.scale=Vector3.ONE*clamp((ship.position.y-chosen.position.y)/2.0,.25,1.0)
	if chosen.position.y>2.25:
		var kind:int=chosen.get_meta("kind")
		var good:=kind==target_kind or frenzy>0
		if good:
			combo+=1; var gain:=100*mini(5,1+floori(combo/4.0))*(2 if frenzy>0 else 1); score+=gain; charge=min(100,charge+12); pop_feedback("+%d"%gain,Color("#ffffff"),chosen.global_position)
			if combo%5==0:target_kind=rng.randi_range(0,3)
		else:
			combo=0; score=max(0,score-75); time_left=max(0,time_left-2); pop_feedback("MISS",Color("#ff4e62"),chosen.global_position)
		creatures.erase(chosen); chosen.queue_free(); spawn_creature()

func update_hud()->void:
	score_label.text=str(score); target_label.text=KINDS[target_kind]
	if frenzy>0:target_label.text="FRENZY"

func pop_feedback(message:String,color:Color,world_pos:Vector3)->void:
	var l:=make_label(hud_root,message,camera.unproject_position(world_pos),32,150,HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_color",color)
	l.position-=Vector2(75,0)
	var tw:=create_tween().set_parallel()
	tw.tween_property(l,"position",l.position-Vector2(0,85),.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l,"modulate:a",0.0,.7)
	tw.chain().tween_callback(l.queue_free)

func finish_game()->void:
	game_state="over"; dragging=false; beam.visible=false; camera.size=18.0; game_ui.visible=false
	if score>best:
		best=score
		var f:=FileAccess.open("user://best3d.txt",FileAccess.WRITE); f.store_string(str(best))
	result_label.text="SCORE %05d
BEST %05d"%[score,best]; result_panel.visible=true
