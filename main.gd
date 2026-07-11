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

func box(parent: Node, size: Vector3, pos: Vector3, color: Color, rotation := Vector3.ZERO) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.position = pos
	n.rotation = rotation
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
	score_label=make_label(root,"0",Vector2(22,32),34)
	timer_label=make_label(root,"60",Vector2(450,32),34)
	target_label=make_label(root,"BEAM: COW",Vector2(165,34),24)
	combo_label=make_label(root,"COMBO 0",Vector2(22,78),19)
	frenzy_bar=ProgressBar.new()
	frenzy_bar.position=Vector2(165,75); frenzy_bar.size=Vector2(220,18); frenzy_bar.max_value=100; frenzy_bar.show_percentage=false
	root.add_child(frenzy_bar)
	title_panel=panel(root,Vector2(45,270),Vector2(450,300),Color(0.18,0.12,0.48,.92))
	make_label(title_panel,"UFO",Vector2(0,35),62,450,HORIZONTAL_ALIGNMENT_CENTER)
	make_label(title_panel,"ABDUCTION",Vector2(0,100),45,450,HORIZONTAL_ALIGNMENT_CENTER)
	make_label(title_panel,"Drag to fly • Hold to beam",Vector2(0,175),20,450,HORIZONTAL_ALIGNMENT_CENTER)
	make_label(title_panel,"TAP TO LAUNCH",Vector2(0,230),27,450,HORIZONTAL_ALIGNMENT_CENTER)
	result_panel=panel(root,Vector2(55,280),Vector2(430,300),Color(0.12,0.1,0.35,.94))
	make_label(result_panel,"SHIFT COMPLETE",Vector2(0,30),34,430,HORIZONTAL_ALIGNMENT_CENTER)
	result_label=make_label(result_panel,"SCORE 0",Vector2(0,110),34,430,HORIZONTAL_ALIGNMENT_CENTER)
	make_label(result_panel,"TAP TO PLAY AGAIN",Vector2(0,225),23,430,HORIZONTAL_ALIGNMENT_CENTER)
	result_panel.visible=false

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
		if e.pressed and game_state!="play": start_game()
	elif e is InputEventScreenDrag and game_state=="play":
		target_position.x=clamp(target_position.x+e.relative.x*.018,-5.4,5.4)
		target_position.z=clamp(target_position.z+e.relative.y*.018,-5.0,5.0)
	elif e is InputEventMouseButton:
		dragging=e.pressed
		if e.pressed and game_state!="play": start_game()
	elif e is InputEventMouseMotion and dragging and game_state=="play":
		target_position.x=clamp(target_position.x+e.relative.x*.018,-5.4,5.4)
		target_position.z=clamp(target_position.z+e.relative.y*.018,-5.0,5.0)

func start_game()->void:
	game_state="play"; score=0; combo=0; time_left=60; charge=0; frenzy=0; target_kind=rng.randi_range(0,3)
	title_panel.visible=false; result_panel.visible=false

func _process(d:float)->void:
	ship.position=ship.position.lerp(target_position,min(1.0,d*8.0))
	ship.position.y=2.7+sin(Time.get_ticks_msec()/180.0)*.08
	ship.rotation.y+=d*.45
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
			combo+=1; score+=100*mini(5,1+combo/4)*(2 if frenzy>0 else 1); charge=min(100,charge+12)
			if combo%5==0:target_kind=rng.randi_range(0,3)
		else:
			combo=0; score=max(0,score-75); time_left=max(0,time_left-2)
		creatures.erase(chosen); chosen.queue_free(); spawn_creature()

func update_hud()->void:
	score_label.text="%05d"%score; timer_label.text="%02d"%ceili(time_left); target_label.text="BEAM: "+KINDS[target_kind]; combo_label.text="COMBO %d"%combo; frenzy_bar.value=charge
	if frenzy>0:target_label.text="FRENZY %.1f"%frenzy

func finish_game()->void:
	game_state="over"; dragging=false; beam.visible=false
	if score>best:
		best=score
		var f:=FileAccess.open("user://best3d.txt",FileAccess.WRITE); f.store_string(str(best))
	result_label.text="SCORE %05d
BEST %05d"%[score,best]; result_panel.visible=true