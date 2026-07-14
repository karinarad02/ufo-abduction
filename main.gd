extends Node3D

const KINDS := ["COW", "CHICKEN", "PIG", "SHEEP", "CORN", "FRUIT"]
const KIND_COLORS := [Color("#f4f0df"), Color("#ffd83f"), Color("#f38ca2"), Color("#d5d5d0"), Color("#f1c82f"), Color("#ed4f62")]
const ANIMAL_SCALES := [.58, .52, .58, .58]
const ANIMAL_RUN_SPEEDS := [1.18, 1.48, 1.28, 1.32]
const FLEE_DETECTION_RADIUS := 2.25
const BEAM_CAPTURE_RADIUS := 1.32
const SHIP_GAME_SCALE := .82
const ARRIVAL_RING_SCALE := 2.05
const ARRIVAL_RING_DEPTH_SCALE := 1.0
const ARRIVAL_RING_OFFSETS := [1.95,-0.45,-2.10]
const GameplayHUD = preload("res://scripts/ui/gameplay_hud.gd")
const IntroScreen = preload("res://scripts/ui/intro_screen.gd")
const SplashScreen = preload("res://scripts/ui/splash_screen.gd")
var rng := RandomNumberGenerator.new()
var ship: Node3D
var ship_sprite: Sprite3D
var charge_segments: Array[MeshInstance3D] = []
var beam: MeshInstance3D
var camera: Camera3D
var target_position := Vector3(0, 2.7, 0)
var creatures: Array[Node3D] = []
var hazards: Array[Node3D] = []
var particles: Array[Dictionary] = []
var dragging := false
var game_state := "boot"
var score := 0
var best := 0
var combo := 0
var suction_chain_count := 0
var suction_chain_points := 0
var suction_chain_time := 0.0
var target_kind := 0
var time_left := 60.0
var charge := 0.0
var frenzy := 0.0
var result_panel: Control
var result_label: Label
var result_detail_label: Label
var hud_root: Control
var gameplay_hud: Control
var intro_screen: Control
var menu_root: Control
var menu_content: Control
var game_ui: Control
var gems := 55
var coins := 1195
var duck_level := 4
var level := 1
var level_progress := 0
var level_goal := 600
var arrival_rings: Array[MeshInstance3D] = []
var arrival_flash: MeshInstance3D
var intro_time := 0.0
var intro_landed := false
var ring_center := Vector3(0,2.7,0)
var portal_open := false
var boundary_alert: Label3D
var fire_visual: Node3D
var burning := false
var burn_time := 0.0
var continue_panel: Control
var continue_countdown: Label
var continue_time := 5.0
var death_fx: Node3D

func _ready() -> void:
	rng.randomize()
	if FileAccess.file_exists("user://best3d.txt"):
		best = int(FileAccess.get_file_as_string("user://best3d.txt"))
	build_world()
	build_ui()
	populate_level()
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
	environment.ambient_light_energy = 0.30
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = environment
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -35, 0)
	sun.light_color = Color("#ffffff")
	sun.light_energy = 0.76
	sun.shadow_enabled = true
	add_child(sun)

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 13.8
	camera.position = Vector3(0, 14.0, 10.0)
	camera.look_at_from_position(camera.position, Vector3(0, 0, 0))
	add_child(camera)

	# Layered floating island.
	cylinder(self, 7.25, 1.25, Vector3(0,-0.85,0), Color("#8a542f"), 8)
	cylinder(self, 7.05, .72, Vector3(0,-0.22,0), Color("#b77842"), 8)
	cylinder(self, 6.95, .32, Vector3(0,.18,0), Color("#477d29"), 8)
	cylinder(self, 6.82, .16, Vector3(0,.39,0), Color("#609b32"), 8)

	# Pond, well, barn, crop plot and fences.
	# Compact raised stone well from reference 1: about one cow-length wide.
	cylinder(self, .62, .08, Vector3(-3.7,.72,-2.7), Color("#39bce1"), 10)
	for i in 8:
		var a := i*TAU/8.0
		var stone_color:=Color("#9ba6a1") if i%2==0 else Color("#858f8c")
		box(self,Vector3(.34,.46,.34),Vector3(-3.7+cos(a)*.72,.77,-2.7+sin(a)*.72),stone_color,Vector3(0,-a,0))
	# Dark inner lip makes the water opening read at the steeper camera angle.
	for i in 8:
		var a := i*TAU/8.0
		box(self,Vector3(.25,.12,.18),Vector3(-3.7+cos(a)*.56,1.02,-2.7+sin(a)*.56),Color("#c0c8c2"),Vector3(0,-a,0))
	box(self, Vector3(2.2,1.65,1.8), Vector3(3.8,1.2,-2.7), Color("#d34f4c"))
	var roof := box(self, Vector3(2.65,.35,2.25), Vector3(3.8,2.15,-2.7), Color("#79364e"))
	roof.rotation_degrees.z = 7
	box(self, Vector3(.75,1.25,.08), Vector3(3.8,1.0,-1.77), Color("#733848"))
	# Reference-video crop bed: red square, ochre rim, green open center.
	var plot_pos:=Vector3(3.05,.58,3.15)
	box(self,Vector3(2.18,.11,2.18),plot_pos,Color("#b94d2c"))
	box(self,Vector3(2.30,.07,.16),plot_pos+Vector3(0,.09,1.09),Color("#d97a28")); box(self,Vector3(2.30,.07,.16),plot_pos+Vector3(0,.09,-1.09),Color("#d97a28"))
	box(self,Vector3(.16,.07,2.18),plot_pos+Vector3(1.09,.09,0),Color("#d97a28")); box(self,Vector3(.16,.07,2.18),plot_pos+Vector3(-1.09,.09,0),Color("#d97a28"))
	box(self,Vector3(.86,.06,.86),plot_pos+Vector3(0,.10,0),Color("#55ad31"))
	for side in [-1,1]:
		for i in 6:
			box(self,Vector3(.15,.7,.15),Vector3(side*6.1,.9,-3.3+i*1.1),Color("#a36a39"))
			box(self,Vector3(.12,.15,1.05),Vector3(side*6.1,1.0,-3.3+i*1.1),Color("#c58a4b"))
	# Sparse grass blades and tiny yellow flowers soften the otherwise empty turf.
	for i in 34:
		var detail_angle:=rng.randf_range(0,TAU); var detail_radius:=rng.randf_range(1.4,6.1)
		var detail_pos:=Vector3(cos(detail_angle)*detail_radius,.56,sin(detail_angle)*detail_radius)
		if i%3==0:
			box(self,Vector3(.07,.07,.07),detail_pos,Color("#ffe24c")); box(self,Vector3(.07,.07,.07),detail_pos+Vector3(.10,0,.04),Color("#fff4a0")); box(self,Vector3(.07,.07,.07),detail_pos+Vector3(-.06,0,.10),Color("#ffe24c"))
		else:
			box(self,Vector3(.035,.18,.035),detail_pos,Color("#347f2c"),Vector3(0,0,rng.randf_range(-.5,.5)))

	build_ship()

func build_ship() -> void:
	ship = Node3D.new()
	ship.position = target_position
	add_child(ship)
	# Chunky, faceted saucer matching the supplied app icon.
	var lower_hull:=cylinder(ship,1.03,.34,Vector3(0,-.13,0),Color("#276ab8"),10)
	lower_hull.scale.z=.78
	var upper_hull:=cylinder(ship,.92,.30,Vector3(0,.08,0),Color("#328ee8"),10)
	upper_hull.scale.z=.78
	var rim:=cylinder(ship,1.08,.11,Vector3(0,.02,0),Color("#174a87"),10)
	rim.scale.z=.78
	# Warm glowing intake on the underside.
	var intake:=cylinder(ship,.39,.045,Vector3(0,-.34,.18),Color("#ffe990"),16)
	intake.scale.z=.58; intake.material_override=mat(Color("#ffe990"),Color("#ffe778"))
	var intake_rim:=cylinder(ship,.47,.035,Vector3(0,-.36,.18),Color("#f59bc8"),16)
	intake_rim.scale.z=.58; intake_rim.material_override=mat(Color("#f59bc8"),Color("#f36cb8"))
	# Pink square pilot, face and side ears inside the canopy.
	box(ship,Vector3(.72,.55,.38),Vector3(0,.50,.05),Color("#e5a6e9"))
	box(ship,Vector3(.13,.28,.12),Vector3(-.43,.49,.08),Color("#cd8bdc"))
	box(ship,Vector3(.13,.28,.12),Vector3(.43,.49,.08),Color("#cd8bdc"))
	box(ship,Vector3(.07,.17,.035),Vector3(-.22,.54,.265),Color("#487b66"))
	box(ship,Vector3(.07,.17,.035),Vector3(.22,.54,.265),Color("#487b66"))
	box(ship,Vector3(.20,.10,.04),Vector3(0,.36,.27),Color("#f06462"))
	# Pale cyan glass canopy with a strong navy outline.
	var canopy:=MeshInstance3D.new(); var glass:=SphereMesh.new()
	glass.radius=.67; glass.height=1.05; glass.radial_segments=10; glass.rings=6
	canopy.mesh=glass; canopy.position=Vector3(0,.48,0); canopy.scale.z=.62; canopy.material_override=mat(Color(0.72,1.0,1.0,.28),Color.BLACK,true); ship.add_child(canopy)
	box(ship,Vector3(.09,.62,.09),Vector3(-.64,.50,.04),Color("#174a87"),Vector3(0,0,-.18))
	box(ship,Vector3(.09,.62,.09),Vector3(.64,.50,.04),Color("#174a87"),Vector3(0,0,.18))
	box(ship,Vector3(.92,.09,.09),Vector3(0,.94,.04),Color("#174a87"))
	# Yellow and pink glowing side markers.
	var left_light:=box(ship,Vector3(.28,.28,.055),Vector3(-.65,.12,.63),Color("#ffe354"),Vector3(0,0,.78))
	left_light.material_override=mat(Color("#ffe354"),Color("#ffe354"))
	var right_light:=box(ship,Vector3(.28,.28,.055),Vector3(.65,.12,.63),Color("#fa62ec"),Vector3(0,0,.78))
	right_light.material_override=mat(Color("#fa62ec"),Color("#fa62ec"))
	beam = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius=.13; cone.bottom_radius=1.0; cone.height=2.65; cone.radial_segments=20
	beam.mesh=cone
	beam.position=Vector3(0,-1.43,0)
	beam.material_override=mat(Color(0.72,0.35,0.94,.3),Color("#a252df"),true)
	beam.visible=false
	ship.add_child(beam)
	# Keep the gameplay craft fully 3D; the sprite node only carries bank state.
	for child in ship.get_children():
		if child is MeshInstance3D and child!=beam: child.visible=true
	ship_sprite=Sprite3D.new(); ship_sprite.visible=false
	ship.add_child(ship_sprite)
	boundary_alert=Label3D.new(); boundary_alert.text="!"; boundary_alert.font_size=112; boundary_alert.modulate=Color("#ff4829"); boundary_alert.outline_modulate=Color.WHITE; boundary_alert.outline_size=16; boundary_alert.position=Vector3(0,1.62,0); boundary_alert.billboard=BaseMaterial3D.BILLBOARD_ENABLED; boundary_alert.visible=false; ship.add_child(boundary_alert)
	fire_visual=Node3D.new(); fire_visual.visible=false; ship.add_child(fire_visual)
	for q in [Vector3(-.48,.18,.18),Vector3(0,.32,.12),Vector3(.48,.16,.16)]:
		box(fire_visual,Vector3(.22,.58,.18),q,Color("#ff5a22"),Vector3(0,0,q.x*.5))
		box(fire_visual,Vector3(.12,.35,.12),q+Vector3(0,.25,0),Color("#ffe13d"),Vector3(0,0,-q.x*.4))
	# Twelve loading tiles form the circular meter on the ground under the beam.
	for i in 12:
		var a:=i*TAU/12.0
		var segment:=box(ship,Vector3(.20,.045,.34),Vector3(cos(a)*.98,-2.22,sin(a)*.98),Color("#7656a8"))
		segment.rotation.y=-a; segment.material_override=mat(Color("#7656a8"),Color("#523878")); charge_segments.append(segment)
	# Three large perspective hoops spanning the beam, as in the reference frame.
	for i in 3:
		var ring:=MeshInstance3D.new()
		var tone:=i/2.0
		var ring_color:=Color(lerpf(.76,.28,tone),1.0,lerpf(.98,.88,tone))
		ring.mesh=make_soft_arrival_ring(ring_color)
		var ring_shader:=Shader.new(); ring_shader.code="shader_type spatial; render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque; uniform float opacity = 1.0; void fragment(){ ALBEDO = COLOR.rgb; EMISSION = COLOR.rgb * 0.70; ALPHA = COLOR.a * opacity; }"
		var ring_material:=ShaderMaterial.new(); ring_material.shader=ring_shader; ring_material.set_shader_parameter("opacity",lerpf(.88,1.0,tone))
		ring.scale=Vector3(ARRIVAL_RING_SCALE,ARRIVAL_RING_SCALE,ARRIVAL_RING_SCALE*ARRIVAL_RING_DEPTH_SCALE); ring.material_override=ring_material; ring.visible=false
		add_child(ring); arrival_rings.append(ring)
	arrival_flash=MeshInstance3D.new(); var flash_mesh:=SphereMesh.new()
	flash_mesh.radius=.72; flash_mesh.height=1.15; flash_mesh.radial_segments=20; flash_mesh.rings=10
	arrival_flash.mesh=flash_mesh; arrival_flash.material_override=mat(Color(1.0,.91,.42,.42),Color("#ffe96b"),true); arrival_flash.visible=false; add_child(arrival_flash)

func make_soft_arrival_ring(base_color:Color)->ArrayMesh:
	var surface:=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radii:=[.78,.84,.91,.97,1.03,1.10,1.16]
	var alpha_stops:=[0.0,.10,.38,.72,.38,.10,0.0]
	var white_mix:=[.05,.16,.40,.72,.40,.16,.05]
	var colors:Array[Color]=[]
	for i in radii.size():
		var color:=base_color.lerp(Color.WHITE,white_mix[i]); color.a=alpha_stops[i]; colors.append(color)
	for segment in 96:
		var a0:=TAU*segment/96.0; var a1:=TAU*(segment+1)/96.0
		for band in radii.size()-1:
			var p00:=Vector3(cos(a0)*radii[band],0,sin(a0)*radii[band]); var p01:=Vector3(cos(a1)*radii[band],0,sin(a1)*radii[band])
			var p10:=Vector3(cos(a0)*radii[band+1],0,sin(a0)*radii[band+1]); var p11:=Vector3(cos(a1)*radii[band+1],0,sin(a1)*radii[band+1])
			for item in [[p00,colors[band]],[p10,colors[band+1]],[p11,colors[band+1]],[p00,colors[band]],[p11,colors[band+1]],[p01,colors[band]]]:
				surface.set_normal(Vector3.UP); surface.set_color(item[1]); surface.add_vertex(item[0])
	return surface.commit()

func animal_eye(parent:Node3D,pos:Vector3)->void:
	box(parent,Vector3(.115,.16,.055),pos,Color("#171923"))
	box(parent,Vector3(.035,.05,.018),pos+Vector3(-.024,.035,.034),Color("#ffffff"))

func animal_leg(parent:Node3D,pos:Vector3,color:Color,hoof:Color)->void:
	box(parent,Vector3(.17,.42,.17),pos,color)
	box(parent,Vector3(.19,.13,.21),pos+Vector3(0,-.25,.025),hoof)

func make_corn_model(parent:Node3D)->void:
	# Chunky golden cob and four low-poly husk leaves seen around 1:10.
	box(parent,Vector3(.12,.48,.12),Vector3(0,-.10,0),Color("#4b8f31"))
	box(parent,Vector3(.31,.48,.28),Vector3(0,.10,0),Color("#e5aa21"))
	for y in [-.03,.10,.23]:
		box(parent,Vector3(.34,.055,.31),Vector3(0,y,.01),Color("#ffd63a"))
	box(parent,Vector3(.27,.08,.42),Vector3(0,-.10,.17),Color("#55a735"),Vector3(-.62,0,0))
	box(parent,Vector3(.27,.08,.42),Vector3(0,-.10,-.17),Color("#438f30"),Vector3(.62,0,0))
	box(parent,Vector3(.42,.08,.24),Vector3(-.17,-.08,0),Color("#61b33b"),Vector3(0,0,-.62))
	box(parent,Vector3(.42,.08,.24),Vector3(.17,-.08,0),Color("#3f8c2e"),Vector3(0,0,.62))

func spawn_corn_at(pos:Vector3)->void:
	var root:=Node3D.new(); root.position=pos; root.set_meta("kind",4); root.set_meta("planted",true); root.set_meta("capture_state","ground"); add_child(root)
	make_corn_model(root); creatures.append(root)

func corn_positions()->Array[Vector3]:
	var positions:Array[Vector3]=[]
	var center:=Vector3(3.05,.94,3.15)
	for offset in [-.78,-.26,.26,.78]:
		positions.append(center+Vector3(offset,0,-.78))
		positions.append(center+Vector3(offset,0,.78))
	for offset in [-.26,.26]:
		positions.append(center+Vector3(-.78,0,offset))
		positions.append(center+Vector3(.78,0,offset))
	return positions

func populate_level()->void:
	portal_open=false
	for old_hazard in hazards:
		if is_instance_valid(old_hazard): old_hazard.queue_free()
	hazards.clear()
	# Corn uses fixed plot slots; roaming population is capped by usable island area.
	var corn_slots:=mini(corn_positions().size(),8+level*2)
	for i in corn_slots: spawn_corn_at(corn_positions()[i])
	var unlocked_animals:=mini(4,2+floori((level-1)/2.0))
	var allowed:Array[int]=[]
	for kind in unlocked_animals: allowed.append(kind)
	if level>=3: allowed.append(5) # Fruit joins once the player has space-management experience.
	var featured:=allowed[rng.randi_range(0,allowed.size()-1)]
	# Keep the readable groups of roughly eight animals seen in gameplay.
	var roaming_capacity:=mini(12,8+floori((level-1)/2.0)+rng.randi_range(-1,1))
	for i in roaming_capacity:
		var kind:=featured if i<2 or rng.randf()<.36 else allowed[rng.randi_range(0,allowed.size()-1)]
		spawn_creature(kind)
	for i in mini(4,1+floori(level/2.0)): spawn_hazard(i%2)
	if level>=3: spawn_hazard(2)
	var present:Array[int]=[]
	for c in creatures:
		var kind:int=c.get_meta("kind")
		if not present.has(kind): present.append(kind)
	if not present.is_empty(): target_kind=present[rng.randi_range(0,present.size()-1)]

func spawn_hazard(hazard_kind:int)->void:
	var root:=Node3D.new(); var placed:=false
	for attempt in 32:
		var angle:=rng.randf_range(0,TAU); var radius:=rng.randf_range(2.0,5.2)
		root.position=Vector3(cos(angle)*radius,.78,sin(angle)*radius)
		if abs(root.position.x-3.25)>1.5 or abs(root.position.z-3.25)>1.3: placed=true; break
	if not placed: return
	root.set_meta("hazard",hazard_kind); add_child(root)
	if hazard_kind==0:
		box(root,Vector3(.48,.48,.48),Vector3.ZERO,Color("#171820"))
		box(root,Vector3(.10,.34,.10),Vector3(.18,.37,0),Color("#79543c"),Vector3(0,0,-.55))
		box(root,Vector3(.13,.13,.13),Vector3(.30,.52,0),Color("#ffe13d"))
	elif hazard_kind==1:
		box(root,Vector3(.34,.62,.30),Vector3(0,.10,0),Color("#ff5729"))
		box(root,Vector3(.20,.42,.20),Vector3(0,.42,0),Color("#ffe13d"),Vector3(0,0,.35))
		box(root,Vector3(.10,.34,.10),Vector3(0,.72,0),Color("#efe8d5"))
	else:
		# Farmer enemy from later islands: straw hat, overalls and pitchfork.
		box(root,Vector3(.62,.70,.42),Vector3(0,.18,0),Color("#e9a46f")); box(root,Vector3(.82,.13,.58),Vector3(0,.58,0),Color("#e9bd35")); box(root,Vector3(.55,.20,.45),Vector3(0,.70,0),Color("#d99d24"))
		box(root,Vector3(.62,.55,.38),Vector3(0,-.42,0),Color("#3478b8")); box(root,Vector3(.16,.50,.16),Vector3(-.19,-.91,0),Color("#5b402d")); box(root,Vector3(.16,.50,.16),Vector3(.19,-.91,0),Color("#5b402d"))
		box(root,Vector3(.07,.12,.03),Vector3(-.17,.27,.23),Color("#171923")); box(root,Vector3(.07,.12,.03),Vector3(.17,.27,.23),Color("#171923"))
		box(root,Vector3(.08,1.28,.08),Vector3(.54,-.05,0),Color("#70452d"),Vector3(0,0,-.12)); box(root,Vector3(.42,.07,.07),Vector3(.47,.57,0),Color("#9aa0a1"))
		var alert:=Label3D.new(); alert.text="!"; alert.font_size=92; alert.modulate=Color("#ff3d3d"); alert.outline_modulate=Color.WHITE; alert.outline_size=13; alert.position=Vector3(0,1.48,0); alert.billboard=BaseMaterial3D.BILLBOARD_ENABLED; alert.visible=false; root.add_child(alert); root.set_meta("alert",alert); root.set_meta("chasing",false)
	hazards.append(root)

func spawn_creature(kind_override:=-1) -> void:
	var kind:int=kind_override if kind_override>=0 else rng.randi_range(0,KINDS.size()-1)
	var p:=Vector3.ZERO; var found_space:=false
	for attempt in 48:
		p=Vector3(rng.randf_range(-5.2,5.2),.88,rng.randf_range(-4.7,4.7))
		var blocked:bool=Vector2(p.x,p.z).length()>5.55 or (abs(p.x-3.8)<1.8 and abs(p.z+2.7)<1.7)
		# Keep roaming entities out of both crop beds and away from existing objects.
		blocked=blocked or (abs(p.x-3.05)<1.35 and abs(p.z-3.15)<1.35)
		if not blocked:
			for existing in creatures:
				if is_instance_valid(existing) and Vector2(p.x-existing.position.x,p.z-existing.position.z).length()<.82:
					blocked=true; break
		if not blocked: found_space=true; break
	if not found_space: return
	var root:=Node3D.new()
	root.position=p
	root.rotation.y=rng.randf_range(-.22,.22)
	root.set_meta("kind",kind)
	root.set_meta("move_dir",Vector2.from_angle(rng.randf_range(0,TAU)))
	root.set_meta("move_timer",rng.randf_range(.4,2.4))
	root.set_meta("walk_phase",rng.randf_range(0,TAU))
	root.set_meta("air_state","ground")
	root.set_meta("capture_state","ground")
	add_child(root)

	if kind==0:
		# Cute cube cow: oversized face, pink muzzle, ears, horns and irregular patches.
		var cream:=Color("#d8d5c7"); var dark:=Color("#292c31"); var pink:=Color("#d98b7c")
		box(root,Vector3(.86,.66,.84),Vector3(0,0,-.08),cream)
		box(root,Vector3(.76,.72,.62),Vector3(0,.20,.61),cream)
		box(root,Vector3(.28,.18,.10),Vector3(-.49,.34,.68),pink)
		box(root,Vector3(.28,.18,.10),Vector3(.49,.34,.68),pink)
		box(root,Vector3(.13,.18,.12),Vector3(-.29,.62,.68),Color("#d9c47c"),Vector3(0,0,-.25))
		box(root,Vector3(.13,.18,.12),Vector3(.29,.62,.68),Color("#d9c47c"),Vector3(0,0,.25))
		box(root,Vector3(.52,.27,.12),Vector3(0,.02,.94),pink)
		box(root,Vector3(.07,.08,.025),Vector3(-.14,.02,1.01),Color("#7b4c4c")); box(root,Vector3(.07,.08,.025),Vector3(.14,.02,1.01),Color("#7b4c4c"))
		animal_eye(root,Vector3(-.22,.31,.945)); animal_eye(root,Vector3(.22,.31,.945))
		box(root,Vector3(.30,.24,.035),Vector3(-.27,.15,.34),dark)
		box(root,Vector3(.34,.26,.035),Vector3(.24,-.10,-.62),dark)
		box(root,Vector3(.22,.20,.035),Vector3(.33,.18,-.35),dark)
		for q in [Vector3(-.29,-.45,.31),Vector3(.29,-.45,.31),Vector3(-.29,-.45,-.31),Vector3(.29,-.45,-.31)]:
			animal_leg(root,q,cream,dark)
		box(root,Vector3(.09,.55,.09),Vector3(.40,.03,-.62),cream,Vector3(.55,0,0))
		box(root,Vector3(.16,.16,.16),Vector3(.40,-.22,-.79),dark)
	elif kind==1:
		# Bright duckling with a big square head, tiny wings and orange webbed feet.
		var yellow:=Color("#d5c126"); var orange:=Color("#d48620")
		box(root,Vector3(.58,.54,.66),Vector3(0,-.07,-.05),yellow)
		box(root,Vector3(.72,.68,.62),Vector3(0,.32,.48),Color("#ddca2d"))
		box(root,Vector3(.34,.17,.20),Vector3(0,.22,.85),orange)
		animal_eye(root,Vector3(-.22,.43,.80)); animal_eye(root,Vector3(.22,.43,.80))
		box(root,Vector3(.18,.42,.42),Vector3(-.43,.0,.0),Color("#e5c92b"),Vector3(0,0,-.25))
		box(root,Vector3(.18,.42,.42),Vector3(.43,.0,.0),Color("#e5c92b"),Vector3(0,0,.25))
		box(root,Vector3(.22,.14,.34),Vector3(-.20,-.46,.16),orange)
		box(root,Vector3(.22,.14,.34),Vector3(.20,-.46,.16),orange)
		box(root,Vector3(.24,.28,.20),Vector3(0,.0,-.46),yellow,Vector3(.35,0,0))
	elif kind==2:
		# The reference pig is a compact taupe-gray voxel animal, not a pink round pig.
		var pig:=Color("#969791"); var pig_light:=Color("#aaa9a1"); var hoof:=Color("#55595a")
		box(root,Vector3(.88,.62,.96),Vector3(0,-.02,-.08),pig)
		box(root,Vector3(.76,.70,.58),Vector3(0,.18,.56),pig_light)
		box(root,Vector3(.20,.23,.13),Vector3(-.39,.45,.55),pig,Vector3(0,0,-.28)); box(root,Vector3(.20,.23,.13),Vector3(.39,.45,.55),pig,Vector3(0,0,.28))
		box(root,Vector3(.43,.25,.14),Vector3(0,.02,.91),Color("#bab9ae"))
		box(root,Vector3(.055,.075,.025),Vector3(-.12,.02,.99),Color("#4a4d4e")); box(root,Vector3(.055,.075,.025),Vector3(.12,.02,.99),Color("#4a4d4e"))
		animal_eye(root,Vector3(-.21,.31,.90)); animal_eye(root,Vector3(.21,.31,.90))
		for q in [Vector3(-.27,-.41,.25),Vector3(.27,-.41,.25),Vector3(-.27,-.41,-.29),Vector3(.27,-.41,-.29)]: animal_leg(root,q,pig,hoof)
		box(root,Vector3(.09,.09,.31),Vector3(.34,.06,-.59),pig,Vector3(.55,0,0))
	elif kind==3:
		# Simple cuboid sheep from the collection case: gray wool, flat dark face and ears.
		var wool:=Color("#aaa9a2"); var wool_top:=Color("#b9b8b0"); var face:=Color("#626566")
		box(root,Vector3(.90,.68,.98),Vector3(0,0,-.08),wool); box(root,Vector3(.82,.16,.88),Vector3(0,.40,-.08),wool_top)
		box(root,Vector3(.66,.64,.54),Vector3(0,.16,.58),face)
		box(root,Vector3(.24,.17,.12),Vector3(-.40,.29,.58),face); box(root,Vector3(.24,.17,.12),Vector3(.40,.29,.58),face)
		animal_eye(root,Vector3(-.19,.29,.87)); animal_eye(root,Vector3(.19,.29,.87)); box(root,Vector3(.18,.08,.035),Vector3(0,.06,.88),Color("#343738"))
		for q in [Vector3(-.27,-.43,.25),Vector3(.27,-.43,.25),Vector3(-.27,-.43,-.29),Vector3(.27,-.43,-.29)]: animal_leg(root,q,face,Color("#3e4243"))
	elif kind==4:
		make_corn_model(root)
	else:
		# Reference 1 uses a single large cubic crown with sparse orange fruit.
		box(root,Vector3(.30,.72,.30),Vector3(0,-.22,0),Color("#7b4b2c"))
		box(root,Vector3(1.46,1.02,1.38),Vector3(0,.38,0),Color("#16873f"))
		box(root,Vector3(1.22,.18,1.16),Vector3(0,.94,0),Color("#24a54c"))
		for q in [Vector3(-.42,.78,.70),Vector3(.34,.42,.72),Vector3(.69,.62,.18)]:
			box(root,Vector3(.25,.25,.22),q,Color("#f37824"))
			box(root,Vector3(.07,.13,.07),q+Vector3(0,.16,0),Color("#315d2e"))
	if kind<4:
		var alert:=Label3D.new(); alert.text="!"; alert.font_size=80; alert.modulate=Color("#ff3d48"); alert.outline_modulate=Color.WHITE; alert.outline_size=10; alert.position=Vector3(0,1.45,0); alert.billboard=BaseMaterial3D.BILLBOARD_ENABLED; alert.visible=false
		root.add_child(alert); root.set_meta("alert",alert)
	var base_scale:float=ANIMAL_SCALES[kind] if kind<4 else 1.0
	root.set_meta("base_scale",base_scale)
	root.scale=Vector3.ONE*base_scale
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
	gameplay_hud=GameplayHUD.new(); game_ui.add_child(gameplay_hud); gameplay_hud.setup()
	gameplay_hud.pause_requested.connect(toggle_pause)
	intro_screen=IntroScreen.new(); game_ui.add_child(intro_screen); intro_screen.setup()
	intro_screen.pilots_requested.connect(show_menu.bind("pilots"))
	intro_screen.research_requested.connect(show_menu.bind("research"))
	result_panel=panel(root,Vector2(55,220),Vector2(430,460),Color("#35479bf2"))
	make_label(result_panel,"RESULTS",Vector2(0,24),38,430,HORIZONTAL_ALIGNMENT_CENTER)
	result_label=make_label(result_panel,"NEW BEST\n00000",Vector2(0,92),34,430,HORIZONTAL_ALIGNMENT_CENTER)
	result_detail_label=make_label(result_panel,"Total sucked: 0\n◆ 0     ◇ 0",Vector2(0,220),22,430,HORIZONTAL_ALIGNMENT_CENTER)
	var again:=menu_button(result_panel,"CONTINUE",Vector2(65,350),Vector2(300,76),Color("#2dcc55")); again.add_theme_font_size_override("font_size",30)
	again.pressed.connect(close_results)
	result_panel.visible=false
	build_continue_panel(root)
	game_ui.visible=false
	build_menu_shell(root)
	menu_root.visible=false
	if OS.get_cmdline_user_args().has("--capture-gameplay"):
		begin_game_intro(); activate_intro_control()
	else:
		var splash:=SplashScreen.new(); root.add_child(splash); splash.setup(); splash.finished.connect(begin_game_intro)

func build_continue_panel(root:Control)->void:
	continue_panel=Control.new(); continue_panel.position=Vector2.ZERO; continue_panel.size=Vector2(540,960); continue_panel.mouse_filter=Control.MOUSE_FILTER_STOP; root.add_child(continue_panel)
	var shade:=ColorRect.new(); shade.color=Color(0.05,.12,.18,.42); shade.position=Vector2.ZERO; shade.size=Vector2(540,960); continue_panel.add_child(shade)
	var card:=panel(continue_panel,Vector2(55,290),Vector2(430,365),Color("#4268b5f2")); round_panel(card,0,Color("#4268b5f2"),0)
	var title:=make_label(card,"CONTINUE?",Vector2(0,22),38,430,HORIZONTAL_ALIGNMENT_CENTER); title.add_theme_color_override("font_color",Color("#72f2ec")); title.add_theme_constant_override("outline_size",4); title.add_theme_color_override("font_outline_color",Color("#284b8d"))
	# Small square pink pilot shown beneath the title in the reference.
	var pilot:=Control.new(); pilot.position=Vector2(177,88); card.add_child(pilot)
	icon_rect(pilot,Vector2(0,0),Vector2(76,72),Color("#e6a4e8")); icon_rect(pilot,Vector2(-10,16),Vector2(15,30),Color("#c783d5")); icon_rect(pilot,Vector2(71,16),Vector2(15,30),Color("#c783d5")); icon_rect(pilot,Vector2(13,27),Vector2(8,13),Color("#384e55")); icon_rect(pilot,Vector2(55,27),Vector2(8,13),Color("#384e55")); icon_rect(pilot,Vector2(27,48),Vector2(22,9),Color("#ed665f"))
	continue_countdown=make_label(card,"5",Vector2(0,166),58,430,HORIZONTAL_ALIGNMENT_CENTER)
	var restart:=menu_button(card,"×",Vector2(18,274),Vector2(120,70),Color("#e43d2d")); restart.add_theme_font_size_override("font_size",42); restart.pressed.connect(restart_after_death)
	var ad:=menu_button(card,"▶ AD",Vector2(155,274),Vector2(120,70),Color("#29c85d")); ad.add_theme_font_size_override("font_size",22); ad.pressed.connect(continue_after_ad)
	var paid:=menu_button(card,"◆ 5",Vector2(292,274),Vector2(120,70),Color("#cf43df")); paid.add_theme_font_size_override("font_size",24); paid.pressed.connect(continue_with_gems)
	continue_panel.visible=false

func begin_game_intro()->void:
	game_state="intro"; score=0; combo=0; suction_chain_count=0; suction_chain_points=0; suction_chain_time=0; level=1; level_progress=0; level_goal=25; time_left=45; charge=0; frenzy=0
	continue_panel.visible=false; ship.visible=true
	update_charge_segments(); gameplay_hud.set_level_progress(level_progress,level_goal)
	menu_root.visible=false; game_ui.visible=true; result_panel.visible=false
	gameplay_hud.reset_hidden(); intro_screen.reset_hidden(); intro_time=0.0; intro_landed=false
	target_position=Vector3(0,2.7,0); ship.scale=Vector3.ONE*(SHIP_GAME_SCALE*.78); ship.position=Vector3(0,6.8,-1.35); camera.size=13.8
	ring_center=target_position
	for ring in arrival_rings: ring.visible=true
	arrival_flash.visible=true; arrival_flash.position=Vector3(0,1.8,0); arrival_flash.scale=Vector3(.08,.08,.08)
	var tw:=create_tween().set_parallel(true)
	tw.tween_property(arrival_flash,"scale",Vector3(1.15,1.15,1.15),.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ship,"scale",Vector3.ONE*SHIP_GAME_SCALE,.30).set_delay(.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(ship,"position",target_position,.30).set_delay(.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(finish_intro_arrival)

func finish_intro_arrival()->void:
	if game_state!="intro": return
	intro_landed=true; beam.visible=true; arrival_flash.visible=false
	intro_screen.reveal()

func activate_intro_control()->void:
	if game_state!="intro": return
	game_state="play"; dragging=true
	intro_screen.animate_out(); gameplay_hud.animate_in()
	for ring in arrival_rings: ring.visible=false
	arrival_flash.visible=false

func start_level_portal()->void:
	if game_state!="play": return
	game_state="portal"; dragging=false; beam.visible=false; portal_open=false
	for ring in arrival_rings: ring.visible=true
	arrival_flash.visible=true; arrival_flash.position=Vector3(ring_center.x,1.8,ring_center.z); arrival_flash.scale=Vector3(.12,.12,.12)
	var exit_tween:=create_tween()
	exit_tween.tween_property(arrival_flash,"scale",Vector3(1.25,1.25,1.25),.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	exit_tween.parallel().tween_property(ship,"position",Vector3(ring_center.x,7.2,ring_center.z),.58).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	exit_tween.parallel().tween_property(ship,"scale",Vector3(.28,.28,.28),.58)
	exit_tween.tween_callback(complete_level_portal)

func complete_level_portal()->void:
	level+=1; level_progress=0; level_goal=roundi(level_goal*1.25); time_left=45.0; suction_chain_count=0; suction_chain_points=0; suction_chain_time=0; target_kind=rng.randi_range(0,KINDS.size()-1)
	gameplay_hud.set_level_progress(level_progress,level_goal)
	populate_level()
	target_position=Vector3(0,2.7,0); ring_center=target_position; ship.position=Vector3(0,7.2,-1.0); ship.scale=Vector3(.45,.45,.45)
	arrival_flash.position=Vector3(0,1.8,0); arrival_flash.scale=Vector3(1.1,1.1,1.1)
	var enter_tween:=create_tween().set_parallel(true)
	enter_tween.tween_property(ship,"position",target_position,.48).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	enter_tween.tween_property(ship,"scale",Vector3.ONE*SHIP_GAME_SCALE,.48).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	enter_tween.chain().tween_callback(finish_level_portal)

func finish_level_portal()->void:
	game_state="play"; arrival_flash.visible=false
	for ring in arrival_rings: ring.visible=false
	pop_feedback("LEVEL %d"%level,Color("#ffe33d"),ship.global_position)

func open_exit_portal()->void:
	if portal_open or game_state!="play": return
	portal_open=true; dragging=false; beam.visible=false
	ring_center=Vector3(-3.4,2.7,2.6) if ship.position.x>0 else Vector3(3.4,2.7,2.6)
	for ring in arrival_rings: ring.visible=true
	arrival_flash.visible=true; arrival_flash.position=Vector3(ring_center.x,1.8,ring_center.z); arrival_flash.scale=Vector3(.95,.95,.95)
	pop_feedback("PORTAL OPEN",Color("#b8ffff"),ring_center)
func build_menu_shell(root:Control)->void:
	menu_root=Control.new(); menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_child(menu_root)
	var bg:=ColorRect.new(); bg.color=Color("#8a55c4"); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); menu_root.add_child(bg)
	make_label(menu_root,"◆ %d"%gems,Vector2(16,22),28)
	var gem_plus:=menu_button(menu_root,"+",Vector2(140,13),Vector2(46,52),Color("#16bc67")); gem_plus.add_theme_font_size_override("font_size",30)
	make_label(menu_root,"◇ %d"%coins,Vector2(360,22),28)
	var coin_plus:=menu_button(menu_root,"+",Vector2(480,13),Vector2(46,52),Color("#16bc67")); coin_plus.add_theme_font_size_override("font_size",30)
	menu_content=Control.new(); menu_content.position=Vector2(14,88); menu_content.size=Vector2(512,758); menu_root.add_child(menu_content)
	var nav_back:=ColorRect.new(); nav_back.position=Vector2(0,810); nav_back.size=Vector2(540,150); nav_back.color=Color("#406898"); nav_back.mouse_filter=Control.MOUSE_FILTER_IGNORE; menu_root.add_child(nav_back)
	var tabs=[
		["collection",Color("#48a1e3"),Color("#86e8dc"),Color("#106fba"),"collections"],
		["research",Color("#af47d0"),Color("#ebb6fc"),Color("#7d27b1"),"research"],
		["pilots",Color("#eb9e00"),Color("#ffde04"),Color("#d45d00"),"pilots"],
		["play",Color("#27b956"),Color("#77d480"),Color("#158c54"),"play"]
	]
	var tab_x:=[8.0,140.0,274.0,407.0]
	for i in tabs.size():
		var b:=nav_menu_button(menu_root,Vector2(tab_x[i],822),tabs[i][1],tabs[i][2],tabs[i][3])
		add_nav_icon(b,tabs[i][0])
		var page:String=tabs[i][4]
		if page=="play": b.pressed.connect(start_game)
		else: b.pressed.connect(show_menu.bind(page))

func nav_menu_button(parent:Node,pos:Vector2,face_color:Color,rim_color:Color,step_color:Color)->Button:
	# Reference 10: 149x154 px at 640x1136, scaled to the 540x960 project viewport.
	var button:=Button.new(); button.position=pos; button.size=Vector2(126,130); button.focus_mode=Control.FOCUS_NONE
	var clear:=StyleBoxFlat.new(); clear.bg_color=Color(0,0,0,0)
	button.add_theme_stylebox_override("normal",clear); button.add_theme_stylebox_override("hover",clear); button.add_theme_stylebox_override("pressed",clear)
	var step:=ColorRect.new(); step.position=Vector2.ZERO; step.size=Vector2(126,130); step.color=step_color; step.mouse_filter=Control.MOUSE_FILTER_IGNORE; button.add_child(step)
	var face:=Panel.new(); face.position=Vector2.ZERO; face.size=Vector2(126,108); face.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var face_style:=StyleBoxFlat.new(); face_style.bg_color=face_color; face_style.border_color=rim_color
	face_style.border_width_left=6; face_style.border_width_right=6; face_style.border_width_top=6; face_style.border_width_bottom=6
	face.add_theme_stylebox_override("panel",face_style); button.add_child(face)
	# Reference 10 keeps the artwork and its shadow inside the bordered upper face.
	var icon_host:=Control.new(); icon_host.position=Vector2(6,6); icon_host.size=Vector2(114,96); icon_host.clip_contents=true; icon_host.mouse_filter=Control.MOUSE_FILTER_IGNORE
	button.add_child(icon_host); button.set_meta("icon_host",icon_host)
	button.button_down.connect(press_menu_button.bind(button,pos)); button.button_up.connect(release_menu_button.bind(button,pos)); button.mouse_exited.connect(release_menu_button.bind(button,pos))
	parent.add_child(button); return button

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
	reference_heading("COLLECTIONS",Color("#5ee9ff"),Color("#ffe65a"))
	var glass:=panel(menu_content,Vector2(42,126),Vector2(428,470),Color("#718bc280")); round_panel(glass,0,Color("#718bc280"),0)
	var display_floor:=Polygon2D.new(); display_floor.polygon=PackedVector2Array([Vector2(0,470),Vector2(214,410),Vector2(428,470),Vector2(214,532)]); display_floor.color=Color("#77ddd7"); glass.add_child(display_floor)
	var base:=panel(menu_content,Vector2(24,594),Vector2(464,105),Color("#315bd2")); round_panel(base,0,Color("#315bd2"),0)
	var glow:=ColorRect.new(); glow.color=Color("#54eadf"); glow.position=Vector2(0,68); glow.size=Vector2(464,17); base.add_child(glow)
	var animal_data=[[Vector2(70,80),"cow"],[Vector2(282,108),"sheep"],[Vector2(190,210),"pig"],[Vector2(62,300),"bull"],[Vector2(288,310),"lamb"]]
	for item in animal_data: add_collection_animal(glass,item[0],item[1])

func build_research()->void:
	reference_heading("RESEARCH LAB",Color("#ffe65a"),Color("#f34ee6"))
	for i in 2:
		var x:=26+i*244
		var cap:=panel(menu_content,Vector2(x,154),Vector2(216,64),Color("#315bd2")); round_panel(cap,0,Color("#315bd2"),0); make_label(cap,str(i+1),Vector2(0,4),34,216,HORIZONTAL_ALIGNMENT_CENTER)
		var chamber:=panel(menu_content,Vector2(x+14,214),Vector2(188,210),Color("#ca4cda88")); round_panel(chamber,0,Color("#ca4cda88"),0)
		var pad:=ColorRect.new(); pad.color=Color("#ed54c5"); pad.position=Vector2(14,178); pad.size=Vector2(160,25); chamber.add_child(pad)
		add_research_egg(chamber,Vector2(94,100),i==1)
		var foot:=panel(menu_content,Vector2(x,420),Vector2(216,54),Color("#315bd2")); round_panel(foot,0,Color("#315bd2"),0)
		var foot_glow:=ColorRect.new(); foot_glow.color=Color("#ef5ad2"); foot_glow.position=Vector2(0,38); foot_glow.size=Vector2(216,9); foot.add_child(foot_glow)
		var action:=menu_button(menu_content,"COLLECT" if i==1 else "Researching\n1:59:54",Vector2(x,492),Vector2(216,96),Color("#f5a019") if i==1 else Color("#5b5b5b")); action.add_theme_font_size_override("font_size",22)
		if i==0:
			var speed:=menu_button(menu_content,"▶",Vector2(x+6,600),Vector2(92,62),Color("#33c869")); speed.add_theme_font_size_override("font_size",26)
			var gems_button:=menu_button(menu_content,"◆ 8",Vector2(x+108,600),Vector2(98,62),Color("#42bde8")); gems_button.add_theme_font_size_override("font_size",22)

func build_pilots()->void:
	if game_state!="__legacy_pilot_layout__":
		build_reference_pilots()
		return
	menu_heading("SPACE PILOTS")
	var card:=panel(menu_content,Vector2(0,100),Vector2(512,600),Color("#596276"))
	var names=["NOVA","PAULA","ACE","BOT","MIMI","LOCKED"]
	for i in names.size():
		var x:=20+(i%3)*164; var y:=28+(i/3.0)*250
		var c:=menu_button(card,names[i],Vector2(x,y),Vector2(145,215),Color("#3c465c") if i==5 else Color("#5364aa"))
		c.add_theme_font_size_override("font_size",20)
		make_label(c,"■",Vector2(0,48),62,145,HORIZONTAL_ALIGNMENT_CENTER)
		make_label(c,"SELECTED" if i==0 else ("???" if i==5 else "UNLOCKED"),Vector2(0,160),14,145,HORIZONTAL_ALIGNMENT_CENTER)

func build_reference_pilots()->void:
	reference_heading("SPACE PILOTS",Color("#5ee9ff"),Color("#ffe65a"))
	var deck:=panel(menu_content,Vector2(14,118),Vector2(484,578),Color("#5c6371")); round_panel(deck,0,Color("#5c6371"),0)
	for i in 6:
		var x:=30+(i%3)*158; var y:=25+floori(i/3.0)*255
		var pad:=Polygon2D.new(); pad.polygon=PackedVector2Array([Vector2(x+10,y+128),Vector2(x+64,y+102),Vector2(x+118,y+128),Vector2(x+118,y+166),Vector2(x+64,y+190),Vector2(x+10,y+166)]); pad.color=Color("#747b89"); deck.add_child(pad)
		add_pilot_figure(deck,Vector2(x+12,y+20),i)
		var select:=menu_button(deck,"SELECTED" if i==0 else ("???" if i==5 else "USE"),Vector2(x+5,y+196),Vector2(122,45),Color("#ef9b18") if i==0 else Color("#3f6caa")); select.add_theme_font_size_override("font_size",14)

func add_pilot_figure(parent:Node,pos:Vector2,index:int)->void:
	var pilot:=Control.new(); pilot.position=pos; pilot.mouse_filter=Control.MOUSE_FILTER_IGNORE; parent.add_child(pilot)
	var skin:=Color("#e8a27f"); var hair_colors:=[Color("#4c3d35"),Color("#32d531"),Color("#22252b"),Color("#3164e7"),Color("#d8a7d2"),Color("#16191e")]; var suit_colors:=[Color("#efa53a"),Color("#f06b96"),Color("#ee718c"),Color("#e04b4b"),Color("#e6e9e8"),Color("#444950")]
	icon_rect(pilot,Vector2(19,8),Vector2(66,62),skin); icon_rect(pilot,Vector2(14,3),Vector2(76,22),hair_colors[index]); icon_rect(pilot,Vector2(8,12),Vector2(17,45),hair_colors[index]); icon_rect(pilot,Vector2(81,12),Vector2(17,45),hair_colors[index])
	icon_rect(pilot,Vector2(25,31),Vector2(7,13),Color("#14161b")); icon_rect(pilot,Vector2(71,31),Vector2(7,13),Color("#14161b")); icon_rect(pilot,Vector2(43,50),Vector2(20,7),Color("#ec655f"))
	icon_rect(pilot,Vector2(16,70),Vector2(78,55),suit_colors[index]); icon_rect(pilot,Vector2(23,122),Vector2(25,30),suit_colors[index].darkened(.15)); icon_rect(pilot,Vector2(63,122),Vector2(25,30),suit_colors[index].darkened(.15))

func build_duck_detail()->void:
	menu_heading("Duck        COMMON")
	var close:=menu_button(menu_content,"×",Vector2(467,7),Vector2(42,52),Color("#d64d32")); close.add_theme_font_size_override("font_size",31); close.pressed.connect(show_menu.bind("collections"))
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
	var normal:=StyleBoxFlat.new(); normal.bg_color=color; normal.border_width_left=5; normal.border_width_right=5; normal.border_width_top=5; normal.border_width_bottom=16; normal.border_color=color.lightened(.42)
	normal.shadow_color=color.darkened(.38); normal.shadow_size=0; normal.shadow_offset=Vector2(0,7)
	var pressed:=normal.duplicate(); pressed.bg_color=color.darkened(.10); pressed.border_width_bottom=8; pressed.shadow_offset=Vector2(0,3)
	b.add_theme_stylebox_override("normal",normal); b.add_theme_stylebox_override("hover",normal); b.add_theme_stylebox_override("pressed",pressed)
	b.button_down.connect(press_menu_button.bind(b,pos))
	b.button_up.connect(release_menu_button.bind(b,pos))
	b.mouse_exited.connect(release_menu_button.bind(b,pos))
	parent.add_child(b); return b

func press_menu_button(button:Button,rest_position:Vector2)->void:
	if not button.button_pressed and button.toggle_mode: return
	button.position=rest_position+Vector2(0,7)
	button.scale=Vector2(1.0,.97)

func release_menu_button(button:Button,rest_position:Vector2)->void:
	if not is_instance_valid(button): return
	var old_tween:Tween=button.get_meta("release_tween") as Tween if button.has_meta("release_tween") else null
	if old_tween and old_tween.is_valid(): old_tween.kill()
	var tween:=button.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(button,"position",rest_position,.10)
	tween.tween_property(button,"scale",Vector2.ONE,.10)
	button.set_meta("release_tween",tween)

func icon_rect(parent:Node,pos:Vector2,size:Vector2,color:Color)->ColorRect:
	var r:=ColorRect.new(); r.position=pos; r.size=size; r.color=color; r.mouse_filter=Control.MOUSE_FILTER_IGNORE; parent.add_child(r); return r

func icon_poly(parent:Node,points:PackedVector2Array,color:Color)->Polygon2D:
	var p:=Polygon2D.new(); p.polygon=points; p.color=color; parent.add_child(p); return p

func add_nav_icon(button:Button,kind:String)->void:
	var paths={
		"collection":"res://assets/ui/nav-icons/nav-collection-icon.png",
		"research":"res://assets/ui/nav-icons/nav-research-icon.png",
		"pilots":"res://assets/ui/nav-icons/nav-pilots-icon.png",
		"play":"res://assets/ui/nav-icons/nav-play-icon.png"
	}
	var icon:=TextureRect.new()
	# Center against the 126x108 colored face, excluding the 22px lower step.
	icon.texture=load(paths[kind]); icon.position=Vector2(7,0); icon.size=Vector2(100,96)
	icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
	(button.get_meta("icon_host") as Control).add_child(icon)

func reference_heading(title:String,left_color:Color,right_color:Color)->void:
	var bar:=panel(menu_content,Vector2(0,0),Vector2(512,104),Color("#3155bd")); round_panel(bar,0,Color("#3155bd"),0)
	make_label(bar,title,Vector2(0,22),38,512,HORIZONTAL_ALIGNMENT_CENTER)
	icon_poly(bar,PackedVector2Array([Vector2(20,30),Vector2(20,76),Vector2(60,53)]),left_color)
	icon_poly(bar,PackedVector2Array([Vector2(492,30),Vector2(492,76),Vector2(452,53)]),right_color)

func add_collection_animal(parent:Node,pos:Vector2,kind:String)->void:
	var animal:=Control.new(); animal.position=pos; animal.mouse_filter=Control.MOUSE_FILTER_IGNORE; parent.add_child(animal)
	var body_color:=Color("#f0efe1") if kind=="cow" else (Color("#8d8f8d") if kind in ["sheep","pig"] else Color("#4d5051"))
	if kind=="lamb": body_color=Color("#b8bab5")
	icon_rect(animal,Vector2(5,14),Vector2(72,64),body_color); icon_rect(animal,Vector2(0,22),Vector2(14,22),body_color.darkened(.12)); icon_rect(animal,Vector2(68,22),Vector2(14,22),body_color.darkened(.12))
	icon_rect(animal,Vector2(14,72),Vector2(14,16),body_color.darkened(.18)); icon_rect(animal,Vector2(55,72),Vector2(14,16),body_color.darkened(.18))
	if kind=="cow": icon_rect(animal,Vector2(10,10),Vector2(22,20),Color("#303237")); icon_rect(animal,Vector2(25,48),Vector2(36,20),Color("#efa08d"))
	for x in [23,56]: icon_rect(animal,Vector2(x,34),Vector2(7,11),Color("#14161b"))
	for x in [32,51]: icon_rect(animal,Vector2(x,55),Vector2(5,5),Color("#343139"))

func add_research_egg(parent:Node,center:Vector2,egg_ready:bool)->void:
	var color:=Color("#ffd629") if egg_ready else Color("#f4f2df")
	icon_poly(parent,PackedVector2Array([center+Vector2(-34,28),center+Vector2(-40,4),center+Vector2(-25,-35),center+Vector2(0,-49),center+Vector2(25,-35),center+Vector2(40,4),center+Vector2(34,28),center+Vector2(0,39)]),color)
	icon_rect(parent,center+Vector2(-21,-22),Vector2(16,18),Color("#8aca43") if not egg_ready else Color("#ef9d1b")); icon_rect(parent,center+Vector2(12,4),Vector2(18,15),Color("#8aca43") if not egg_ready else Color("#ef9d1b"))
	if egg_ready:
		icon_rect(parent,center+Vector2(-11,-10),Vector2(23,17),Color("#f7b417"))

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
		if not e.pressed and game_state=="play": finalize_suction_chain()
		if e.pressed and game_state=="over": start_game()
	elif e is InputEventScreenDrag:
		if game_state=="intro" and e.relative.length()>1.0 and not intro_shortcut_at(e.position): activate_intro_control()
		if game_state=="play":
			target_position.x=clamp(target_position.x+e.relative.x*.018,-7.4,7.4)
			target_position.z=clamp(target_position.z+e.relative.y*.018,-7.0,7.0)
	elif e is InputEventMouseButton:
		dragging=e.pressed
		if not e.pressed and game_state=="play": finalize_suction_chain()
		if e.pressed and game_state=="over": start_game()
	elif e is InputEventMouseMotion and dragging:
		if game_state=="intro" and e.relative.length()>1.0 and not intro_shortcut_at(e.position): activate_intro_control()
		if game_state=="play":
			target_position.x=clamp(target_position.x+e.relative.x*.018,-7.4,7.4)
			target_position.z=clamp(target_position.z+e.relative.y*.018,-7.0,7.0)

func intro_shortcut_at(screen_position:Vector2)->bool:
	return intro_screen.has_shortcut_at(screen_position)

func toggle_pause()->void:
	if game_state!="play": return
	get_tree().paused=not get_tree().paused

func start_game()->void:
	begin_game_intro()

func _process(d:float)->void:
	if game_state=="continue":
		continue_time=maxf(0.0,continue_time-d); continue_countdown.text=str(maxi(1,ceili(continue_time)))
		if continue_time<=0.0: restart_after_death()
		return
	if game_state=="dying": return
	if game_state=="intro" or game_state=="portal" or portal_open:
		intro_time+=d
		var ring_bob:=sin(intro_time*2.4)*.07
		var ring_pulse:=1.0+sin(intro_time*3.0)*.025
		var ring_alpha:=.66+sin(intro_time*3.0)*.045
		for i in arrival_rings.size():
			var ring:=arrival_rings[i]
			ring.position=Vector3(ring_center.x,ring_center.y+ARRIVAL_RING_OFFSETS[i]+ring_bob,ring_center.z)
			ring.scale=Vector3(ARRIVAL_RING_SCALE*ring_pulse,ARRIVAL_RING_SCALE*ring_pulse,ARRIVAL_RING_SCALE*ARRIVAL_RING_DEPTH_SCALE*ring_pulse)
			ring.rotation=Vector3.ZERO
			var tone:=i/2.0
			var ring_mat:=ring.material_override as ShaderMaterial
			ring_mat.set_shader_parameter("opacity",ring_alpha*lerpf(1.25,1.45,tone))
	if game_state=="play":
		var previous_x:=ship.position.x
		ship.position=ship.position.lerp(target_position,min(1.0,d*8.0))
		ship.position.y=2.7+sin(Time.get_ticks_msec()/180.0)*.08
		var horizontal_speed:=(ship.position.x-previous_x)/maxf(d,.001)
		ship.rotation.z=lerp(ship.rotation.z,clamp(-horizontal_speed*.035,-.13,.13),min(1.0,d*8.0))
	if game_state=="intro" or game_state=="portal": ship.rotation.z=lerp(ship.rotation.z,0.0,min(1.0,d*10.0))
	if game_state=="play":
		var camera_goal:=Vector3(ship.position.x,14.0,10.0+ship.position.z)
		camera.position=camera.position.lerp(camera_goal,min(1.0,d*2.8))
		camera.look_at(Vector3(ship.position.x,0,ship.position.z))
		camera.size=lerp(camera.size,12.8 if frenzy>0 else 13.8,min(1.0,d*2.0))
		update_animals(d); update_hazards(d)
		if portal_open and Vector2(ship.position.x-ring_center.x,ship.position.z-ring_center.z).length()<1.05: start_level_portal()
		var edge_distance:=Vector2(ship.position.x,ship.position.z).length()
		boundary_alert.visible=edge_distance>5.48
		if boundary_alert.visible:
			var warning_pulse:=1.0+sin(Time.get_ticks_msec()/70.0)*.13
			boundary_alert.scale=Vector3.ONE*warning_pulse
		if burning:
			burn_time-=d; fire_visual.visible=true; fire_visual.scale=Vector3.ONE*(1.0+sin(Time.get_ticks_msec()/80.0)*.08)
			if Vector2(ship.position.x+3.7,ship.position.z+2.7).length()<1.35:
				burning=false; fire_visual.visible=false; pop_feedback("EXTINGUISHED",Color("#72e8ff"),ship.global_position)
			elif burn_time<=0.0: destroy_ufo()
	beam.visible=(game_state=="intro" and intro_landed) or (dragging and game_state=="play")
	if game_state=="play":
		time_left-=d; frenzy=max(0.0,frenzy-d)
		if suction_chain_count>0:
			suction_chain_time-=d
			if suction_chain_time<=0.0: finalize_suction_chain()
		if charge>=100 and frenzy<=0: frenzy=7; charge=0; update_charge_segments(); beam.material_override=mat(Color(1,.82,.18,.34),Color("#ffd331"),true)
		if frenzy<=0 and beam.material_override.albedo_color.r>.9: beam.material_override=mat(Color(.72,.35,.94,.3),Color("#a252df"),true)
		abduct(d)
		if dragging: abduct_hazards(d)
		if time_left<=0: finish_game()
		update_hud()

func update_hazards(d:float)->void:
	for hazard in hazards:
		if not is_instance_valid(hazard) or int(hazard.get_meta("hazard"))!=2: continue
		var offset:=Vector2(ship.position.x-hazard.position.x,ship.position.z-hazard.position.z)
		var alert:Label3D=hazard.get_meta("alert")
		if offset.length()<3.25:
			hazard.set_meta("chasing",true); alert.visible=true; alert.scale=Vector3.ONE*(1.0+sin(Time.get_ticks_msec()/85.0)*.11)
		elif offset.length()>4.2:
			hazard.set_meta("chasing",false); alert.visible=false
		if hazard.get_meta("chasing",false):
			var direction:=offset.normalized(); hazard.position.x+=direction.x*d*1.05; hazard.position.z+=direction.y*d*1.05
			hazard.rotation.y=lerp_angle(hazard.rotation.y,atan2(direction.x,direction.y),minf(1.0,d*7.0))
			hazard.position.y=.78+abs(sin(Time.get_ticks_msec()/95.0))*.07
			if offset.length()<.82:
				destroy_ufo(); return

func update_animals(d:float)->void:
	for c in creatures:
		if not is_instance_valid(c) or int(c.get_meta("kind"))>=4: continue
		if c.get_meta("capture_state","ground")!="ground": continue
		var air_state:String=c.get_meta("air_state","ground")
		var base_scale:float=c.get_meta("base_scale",1.0)
		if air_state=="falling":
			var fall_direction:Vector2=c.get_meta("flee_dir",Vector2(c.position.x,c.position.z).normalized())
			c.position.x+=fall_direction.x*d*.75; c.position.z+=fall_direction.y*d*.75
			c.position.y-=d*(3.2+absf(c.position.y)*.5); c.rotation.x+=d*4.5; c.rotation.z+=d*3.2
			c.scale=Vector3.ONE*base_scale*maxf(.45,1.0-(.88-c.position.y)*.12)
			if c.position.y< -2.4:
				var return_angle:=rng.randf_range(0,TAU); var return_radius:=rng.randf_range(2.6,4.8)
				c.position=Vector3(cos(return_angle)*return_radius,5.2,sin(return_angle)*return_radius)
				c.rotation=Vector3(rng.randf_range(-.3,.3),rng.randf_range(0,TAU),rng.randf_range(-.3,.3)); c.scale=Vector3.ONE*base_scale*.58; c.set_meta("air_state","returning")
			continue
		if air_state=="returning":
			c.position.y-=d*4.1; c.rotation.x=lerp(c.rotation.x,0.0,minf(1.0,d*7.0)); c.rotation.z=lerp(c.rotation.z,0.0,minf(1.0,d*7.0)); c.scale=c.scale.lerp(Vector3.ONE*base_scale,minf(1.0,d*5.0))
			if c.position.y<=.88:
				c.position.y=.88; c.rotation.x=0; c.rotation.z=0; c.scale=Vector3.ONE*base_scale; c.set_meta("air_state","ground"); c.set_meta("fleeing",false); c.set_meta("move_timer",rng.randf_range(.5,1.5)); (c.get_meta("alert") as Label3D).visible=false
			continue
		var offset:=Vector2(c.position.x-ship.position.x,c.position.z-ship.position.z)
		if dragging and not c.get_meta("fleeing",false) and offset.length()>=BEAM_CAPTURE_RADIUS and offset.length()<FLEE_DETECTION_RADIUS:
			c.set_meta("fleeing",true); c.set_meta("flee_dir",offset.normalized()); c.set_meta("flee_warmup",.18); (c.get_meta("alert") as Label3D).visible=true
		if c.get_meta("fleeing",false):
			var warmup:float=c.get_meta("flee_warmup",0.0)
			if warmup>0.0:
				c.set_meta("flee_warmup",maxf(0.0,warmup-d))
				continue
			var direction:Vector2=c.get_meta("flee_dir")
			var kind:int=c.get_meta("kind")
			var run_speed:float=ANIMAL_RUN_SPEEDS[kind]
			c.position.x+=direction.x*d*run_speed; c.position.z+=direction.y*d*run_speed
			c.rotation.y=lerp_angle(c.rotation.y,atan2(direction.x,direction.y),min(1.0,d*12.0))
			var phase:float=c.get_meta("walk_phase")+d*18.0; c.set_meta("walk_phase",phase); c.position.y=.88+abs(sin(phase))*.11
			if Vector2(c.position.x,c.position.z).length()>6.15:
				c.set_meta("air_state","falling"); c.set_meta("fleeing",false); (c.get_meta("alert") as Label3D).visible=false
		else:
			if dragging and offset.length()<BEAM_CAPTURE_RADIUS+.12: continue
			var timer:float=c.get_meta("move_timer")-d
			if timer<=0.0:
				var pause:=rng.randf()<.28
				c.set_meta("move_dir",Vector2.ZERO if pause else Vector2.from_angle(rng.randf_range(0,TAU)))
				timer=rng.randf_range(.45,1.15) if pause else rng.randf_range(1.2,3.2)
			c.set_meta("move_timer",timer)
			var direction:Vector2=c.get_meta("move_dir")
			if Vector2(c.position.x,c.position.z).length()>5.65:
				direction=Vector2(-c.position.x,-c.position.z).normalized(); c.set_meta("move_dir",direction)
			if direction.length_squared()>.01:
				c.position.x+=direction.x*d*.52; c.position.z+=direction.y*d*.52
				c.rotation.y=lerp_angle(c.rotation.y,atan2(direction.x,direction.y),min(1.0,d*5.0))
				var phase:float=c.get_meta("walk_phase")+d*7.0; c.set_meta("walk_phase",phase); c.position.y=.88+abs(sin(phase))*.055

func abduct(d:float)->void:
	# Once caught, collectibles spiral into the intake; interrupted suction drops them.
	for chosen in creatures.duplicate():
		if not is_instance_valid(chosen): continue
		if chosen.get_meta("air_state","ground")!="ground": continue
		var state:String=chosen.get_meta("capture_state","ground")
		var dist:=Vector2(chosen.position.x-ship.position.x,chosen.position.z-ship.position.z).length()
		var base_scale:float=chosen.get_meta("base_scale",1.0)
		var ground_height:=.94 if int(chosen.get_meta("kind"))==4 else .88
		if state=="ground":
			if not dragging or dist>=BEAM_CAPTURE_RADIUS: continue
			state="sucking"; chosen.set_meta("capture_state",state); chosen.set_meta("suck_angle",atan2(chosen.position.z-ship.position.z,chosen.position.x-ship.position.x)); chosen.set_meta("suck_radius",maxf(.16,dist)); chosen.set_meta("lift_speed",1.7)
		if state=="sucking" and not dragging:
			state="falling_back"; chosen.set_meta("capture_state",state)
		if state=="falling_back":
			chosen.position.y-=d*3.4; chosen.rotation.x=lerp(chosen.rotation.x,0.0,minf(1.0,d*6.0)); chosen.rotation.z=lerp(chosen.rotation.z,0.0,minf(1.0,d*6.0)); chosen.scale=chosen.scale.lerp(Vector3.ONE*base_scale,minf(1.0,d*7.0))
			if chosen.position.y<=ground_height:
				chosen.position.y=ground_height; chosen.rotation.x=0; chosen.rotation.z=0; chosen.scale=Vector3.ONE*base_scale; chosen.set_meta("capture_state","ground")
			continue
		var angle:float=chosen.get_meta("suck_angle")+d*(11.0 if frenzy>0 else 8.5)
		var radius:float=move_toward(float(chosen.get_meta("suck_radius")),0.0,d*(2.5 if frenzy>0 else 1.75))
		var lift_speed:float=float(chosen.get_meta("lift_speed"))+d*(6.0 if frenzy>0 else 4.2)
		chosen.set_meta("suck_angle",angle); chosen.set_meta("suck_radius",radius); chosen.set_meta("lift_speed",lift_speed)
		chosen.position.x=ship.position.x+cos(angle)*radius; chosen.position.z=ship.position.z+sin(angle)*radius
		chosen.position.y+=d*lift_speed
		chosen.rotation.x+=d*7.0; chosen.rotation.y+=d*9.0; chosen.rotation.z+=d*5.5
		chosen.scale=Vector3.ONE*base_scale*clamp((ship.position.y-chosen.position.y)/1.75,.12,1.0)
		if chosen.position.y<ship.position.y-.25: continue
		var kind:int=chosen.get_meta("kind")
		combo+=1
		var gain:=1 if kind>=4 else 2
		if frenzy>0: gain*=2
		score+=gain; level_progress+=gain; suction_chain_count+=1; suction_chain_points+=gain; suction_chain_time=.58; charge=min(100,charge+8.34); coins+=1
		update_charge_segments(); pop_feedback("+%d"%gain,Color("#ffffff"),chosen.global_position)
		if combo%12==0:
			gems+=1; pop_feedback("◆ +1",Color("#ffec48"),ship.global_position+Vector3(0,.5,0))
		creatures.erase(chosen); chosen.queue_free()
		if combo%5==0: target_kind=rng.randi_range(0,KINDS.size()-1)
		if creatures.is_empty():
			finalize_suction_chain()
			open_exit_portal()
			return

func finalize_suction_chain()->void:
	if suction_chain_count<=0: return
	var rating:="OK"; var bonus:=3; var color:=Color("#46c9f2")
	if suction_chain_count>=5:
		rating="GREAT"; bonus=12; color=Color("#f05bdc")
	elif suction_chain_count>=3:
		rating="GOOD"; bonus=6; color=Color("#ffe34c")
	if frenzy>0: bonus*=2
	score+=bonus; level_progress+=bonus
	pop_feedback("%s\n+%d"%[rating,bonus],color,ship.global_position+Vector3(0,.55,0))
	if suction_chain_count>=3: spawn_confetti()
	suction_chain_count=0; suction_chain_points=0; suction_chain_time=0.0

func abduct_hazards(d:float)->void:
	for hazard in hazards.duplicate():
		if not is_instance_valid(hazard):
			hazards.erase(hazard)
			continue
		var distance:=Vector2(hazard.position.x-ship.position.x,hazard.position.z-ship.position.z).length()
		if distance>=1.18: continue
		hazard.position.x=lerp(hazard.position.x,ship.position.x,minf(1.0,d*5.2))
		hazard.position.z=lerp(hazard.position.z,ship.position.z,minf(1.0,d*5.2))
		hazard.position.y+=d*1.8
		hazard.rotation.y+=d*8.0
		hazard.scale=Vector3.ONE*clamp((ship.position.y-hazard.position.y)/2.0,.18,1.0)
		if hazard.position.y<=2.28: continue
		var hazard_kind:int=hazard.get_meta("hazard")
		hazards.erase(hazard)
		hazard.queue_free()
		if hazard_kind==0 or hazard_kind==2:
			pop_feedback("BOOM!",Color("#ff5a3d"),ship.global_position)
			destroy_ufo()
			return
		if not burning:
			burning=true
			burn_time=4.0
			pop_feedback("FIRE! FIND THE POND",Color("#ffb52f"),ship.global_position)

func spawn_confetti()->void:
	var colors:=[Color("#ff3f74"),Color("#ffe33d"),Color("#34dcda"),Color("#536dff"),Color("#dc49ed")]
	var origin:=camera.unproject_position(ship.global_position)+Vector2(0,-35)
	for i in 18:
		var piece:=ColorRect.new(); piece.color=colors[i%colors.size()]; piece.position=origin+Vector2(rng.randf_range(-45,45),rng.randf_range(-20,20)); piece.size=Vector2(rng.randf_range(5,10),rng.randf_range(8,16)); piece.rotation=rng.randf_range(0,TAU); piece.mouse_filter=Control.MOUSE_FILTER_IGNORE; hud_root.add_child(piece)
		var target:=piece.position+Vector2(rng.randf_range(-90,90),rng.randf_range(80,170))
		var tw:=create_tween().set_parallel(true); tw.tween_property(piece,"position",target,.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN); tw.tween_property(piece,"rotation",piece.rotation+rng.randf_range(3,8),.9); tw.tween_property(piece,"modulate:a",0.0,.9).set_delay(.35); tw.chain().tween_callback(piece.queue_free)

func destroy_ufo()->void:
	if game_state!="play": return
	game_state="dying"
	suction_chain_count=0; suction_chain_points=0; suction_chain_time=0
	burning=false
	burn_time=0.0
	fire_visual.visible=false; boundary_alert.visible=false
	dragging=false
	beam.visible=false
	play_ufo_explosion()

func play_ufo_explosion()->void:
	if is_instance_valid(death_fx): death_fx.queue_free()
	death_fx=Node3D.new(); death_fx.position=ship.position; add_child(death_fx)
	ship.visible=false
	# Flat white starburst rays followed by orange flame and charcoal debris.
	for i in 12:
		var angle:=i*TAU/12.0
		var ray:=box(death_fx,Vector3(.16,.10,1.25),Vector3(cos(angle)*.72,0,sin(angle)*.72),Color.WHITE,Vector3(0,-angle,0)); ray.material_override=mat(Color.WHITE,Color.WHITE)
	for i in 14:
		var angle:=rng.randf_range(0,TAU); var radius:=rng.randf_range(.18,1.0)
		var chunk_color:=Color("#ff8a20") if i<8 else Color("#342b28")
		var chunk:=box(death_fx,Vector3.ONE*rng.randf_range(.12,.30),Vector3(cos(angle)*radius,rng.randf_range(-.35,.45),sin(angle)*radius),chunk_color,Vector3(rng.randf(),rng.randf(),rng.randf()))
		var chunk_target:=chunk.position+Vector3(cos(angle)*rng.randf_range(.6,1.5),rng.randf_range(.2,1.0),sin(angle)*rng.randf_range(.6,1.5))
		create_tween().tween_property(chunk,"position",chunk_target,.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	death_fx.scale=Vector3.ONE*.08
	var blast:=create_tween()
	blast.tween_property(death_fx,"scale",Vector3.ONE*1.35,.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	blast.tween_property(death_fx,"scale",Vector3.ONE*.72,.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	blast.tween_callback(show_continue_menu)

func show_continue_menu()->void:
	if is_instance_valid(death_fx): death_fx.queue_free()
	continue_time=5.0; continue_countdown.text="5"; continue_panel.visible=true; game_ui.visible=true; game_state="continue"

func resume_after_death()->void:
	continue_panel.visible=false; ship.visible=true; game_ui.visible=true; game_state="play"
	target_position=Vector3(0,2.7,0); ship.position=target_position; ship.rotation=Vector3.ZERO; ship.scale=Vector3.ONE*SHIP_GAME_SCALE
	burning=false; burn_time=0.0; fire_visual.visible=false; dragging=false

func continue_after_ad()->void:
	# Rewarded-ad integration can call this same completion handler.
	resume_after_death()

func continue_with_gems()->void:
	if gems<5: return
	gems-=5
	resume_after_death()

func restart_after_death()->void:
	continue_panel.visible=false
	for creature in creatures:
		if is_instance_valid(creature): creature.queue_free()
	creatures.clear()
	for hazard in hazards:
		if is_instance_valid(hazard): hazard.queue_free()
	hazards.clear()
	begin_game_intro()
	populate_level()

func next_level()->void:
	start_level_portal()
func update_hud()->void:
	gameplay_hud.set_score(score)
	gameplay_hud.set_level_progress(level_progress,level_goal)
	if level_progress>=level_goal and not portal_open and game_state=="play": open_exit_portal()

func update_charge_segments()->void:
	var lit_count:=ceili(charge/100.0*charge_segments.size())
	for i in charge_segments.size():
		if i<lit_count:
			charge_segments[i].material_override=mat(Color("#ffe34c"),Color("#ffd52c"))
		else:
			charge_segments[i].material_override=mat(Color("#7656a8"),Color("#523878"))

func pop_feedback(message:String,color:Color,world_pos:Vector3)->void:
	var l:=make_label(hud_root,message,camera.unproject_position(world_pos),32,150,HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_color",color)
	l.position-=Vector2(75,0)
	var tw:=create_tween().set_parallel()
	tw.tween_property(l,"position",l.position-Vector2(0,85),.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l,"modulate:a",0.0,.7)
	tw.chain().tween_callback(l.queue_free)

func finish_game()->void:
	if game_state=="play": finalize_suction_chain()
	game_state="results"; dragging=false; beam.visible=false; camera.size=18.0; game_ui.visible=false; continue_panel.visible=false
	var new_best:=score>best
	if score>best:
		best=score
		var f:=FileAccess.open("user://best3d.txt",FileAccess.WRITE); f.store_string(str(best))
	result_label.text=("NEW BEST" if new_best else "SCORE")+"\n%05d"%score
	result_detail_label.text="Total sucked: %d\n◆ %d     ◇ %d"%[combo,gems,coins]
	result_panel.visible=true

func close_results()->void:
	result_panel.visible=false
	show_menu("collections")
