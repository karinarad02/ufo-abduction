extends Node3D

const KINDS := ["COW", "CHICKEN", "PIG", "SHEEP", "CORN", "FRUIT"]
const KIND_COLORS := [Color("#f4f0df"), Color("#ffd83f"), Color("#f38ca2"), Color("#d5d5d0"), Color("#f1c82f"), Color("#ed4f62")]
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
var level := 1
var lives := 3
var level_progress := 0
var level_goal := 600
var tutorial_panel: Control
var intro_overlay: Control
var intro_rings: Array[Label] = []
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
	environment.ambient_light_energy = 0.52
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = environment
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -35, 0)
	sun.light_color = Color("#ffffff")
	sun.light_energy = 0.62
	sun.shadow_enabled = true
	add_child(sun)

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 14.8
	camera.position = Vector3(0, 14.0, 10.0)
	camera.look_at_from_position(camera.position, Vector3(0, 0, 0))
	add_child(camera)

	# Layered floating island.
	cylinder(self, 7.25, 1.25, Vector3(0,-0.85,0), Color("#8a542f"), 8)
	cylinder(self, 7.05, .72, Vector3(0,-0.22,0), Color("#b77842"), 8)
	cylinder(self, 6.95, .32, Vector3(0,.18,0), Color("#438d28"), 8)
	cylinder(self, 6.82, .16, Vector3(0,.39,0), Color("#5cad35"), 8)

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
	# Bordered red-soil corn plots, each stalk collected independently.
	for plot_pos in [Vector3(3.25,.58,3.25),Vector3(.35,.58,4.15)]:
		box(self,Vector3(2.30,.12,1.95),plot_pos,Color("#c95d32"))
		box(self,Vector3(2.42,.055,.12),plot_pos+Vector3(0,.09,.96),Color("#f0a037")); box(self,Vector3(2.42,.055,.12),plot_pos+Vector3(0,.09,-.96),Color("#f0a037"))
		box(self,Vector3(.12,.055,1.95),plot_pos+Vector3(1.15,.09,0),Color("#f0a037")); box(self,Vector3(.12,.055,1.95),plot_pos+Vector3(-1.15,.09,0),Color("#f0a037"))
	for side in [-1,1]:
		for i in 6:
			box(self,Vector3(.15,.7,.15),Vector3(side*6.1,.9,-3.3+i*1.1),Color("#a36a39"))
			box(self,Vector3(.12,.15,1.05),Vector3(side*6.1,1.0,-3.3+i*1.1),Color("#c58a4b"))

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
	boundary_alert=Label3D.new(); boundary_alert.text="!"; boundary_alert.font_size=96; boundary_alert.modulate=Color("#ff3d48"); boundary_alert.outline_modulate=Color.WHITE; boundary_alert.outline_size=12; boundary_alert.position=Vector3(0,1.55,0); boundary_alert.billboard=BaseMaterial3D.BILLBOARD_ENABLED; boundary_alert.visible=false; ship.add_child(boundary_alert)
	fire_visual=Node3D.new(); fire_visual.visible=false; ship.add_child(fire_visual)
	for q in [Vector3(-.48,.18,.18),Vector3(0,.32,.12),Vector3(.48,.16,.16)]:
		box(fire_visual,Vector3(.22,.58,.18),q,Color("#ff5a22"),Vector3(0,0,q.x*.5))
		box(fire_visual,Vector3(.12,.35,.12),q+Vector3(0,.25,0),Color("#ffe13d"),Vector3(0,0,-q.x*.4))
	# Twelve loading tiles form the circular meter on the ground under the beam.
	for i in 12:
		var a:=i*TAU/12.0
		var segment:=box(ship,Vector3(.20,.045,.34),Vector3(cos(a)*.98,-2.22,sin(a)*.98),Color("#7656a8"))
		segment.rotation.y=-a; segment.material_override=mat(Color("#7656a8"),Color("#523878")); charge_segments.append(segment)
	# Four softly glowing hoops with the stepped silhouette from the reference.
	var ring_sizes:=[1.02,1.30,1.58,1.42]
	for i in 4:
		var ring:=MeshInstance3D.new(); var torus:=TorusMesh.new()
		torus.inner_radius=.91; torus.outer_radius=1.0; torus.rings=32; torus.ring_segments=12
		ring.mesh=torus; ring.scale=Vector3.ONE*ring_sizes[i]; ring.material_override=mat(Color(0.68,1.0,1.0,.76),Color("#8effff"),true); ring.visible=false
		add_child(ring); arrival_rings.append(ring)
	arrival_flash=MeshInstance3D.new(); var flash_mesh:=SphereMesh.new()
	flash_mesh.radius=.72; flash_mesh.height=1.15; flash_mesh.radial_segments=20; flash_mesh.rings=10
	arrival_flash.mesh=flash_mesh; arrival_flash.material_override=mat(Color(1.0,.91,.42,.42),Color("#ffe96b"),true); arrival_flash.visible=false; add_child(arrival_flash)

func animal_eye(parent:Node3D,pos:Vector3)->void:
	box(parent,Vector3(.115,.16,.055),pos,Color("#171923"))
	box(parent,Vector3(.035,.05,.018),pos+Vector3(-.024,.035,.034),Color("#ffffff"))

func animal_leg(parent:Node3D,pos:Vector3,color:Color,hoof:Color)->void:
	box(parent,Vector3(.17,.42,.17),pos,color)
	box(parent,Vector3(.19,.13,.21),pos+Vector3(0,-.25,.025),hoof)

func make_corn_model(parent:Node3D)->void:
	# Small golden cuboid cob with layered green husks, matching the crop plots.
	box(parent,Vector3(.10,.62,.10),Vector3(0,-.10,0),Color("#439443"))
	box(parent,Vector3(.24,.46,.20),Vector3(0,.08,.02),Color("#f3ca2d"))
	for y in [-.08,.05,.18]: box(parent,Vector3(.27,.055,.22),Vector3(0,y,.03),Color("#ffe45a"))
	box(parent,Vector3(.34,.10,.14),Vector3(-.16,-.08,0),Color("#54a848"),Vector3(0,0,-.62))
	box(parent,Vector3(.34,.10,.14),Vector3(.16,.02,0),Color("#54a848"),Vector3(0,0,.62))

func spawn_corn_at(pos:Vector3)->void:
	var root:=Node3D.new(); root.position=pos; root.set_meta("kind",4); root.set_meta("planted",true); add_child(root)
	make_corn_model(root); creatures.append(root)

func corn_positions()->Array[Vector3]:
	var positions:Array[Vector3]=[]
	for plot_pos in [Vector3(3.25,.94,3.25),Vector3(.35,.94,4.15)]:
		for x in 3:
			for z in 2: positions.append(Vector3(plot_pos.x-.68+x*.68,.94,plot_pos.z-.40+z*.80))
	return positions

func populate_level()->void:
	portal_open=false
	for old_hazard in hazards:
		if is_instance_valid(old_hazard): old_hazard.queue_free()
	hazards.clear()
	# Corn uses fixed plot slots; roaming population is capped by usable island area.
	var corn_slots:=mini(corn_positions().size(),6+level*2)
	for i in corn_slots: spawn_corn_at(corn_positions()[i])
	var unlocked_animals:=mini(4,2+floori((level-1)/2.0))
	var allowed:Array[int]=[]
	for kind in unlocked_animals: allowed.append(kind)
	if level>=3: allowed.append(5) # Fruit joins once the player has space-management experience.
	var featured:=allowed[rng.randi_range(0,allowed.size()-1)]
	var roaming_capacity:=mini(16,7+level*2+rng.randi_range(-1,1))
	for i in roaming_capacity:
		var kind:=featured if i<2 or rng.randf()<.36 else allowed[rng.randi_range(0,allowed.size()-1)]
		spawn_creature(kind)
	for i in mini(4,1+floori(level/2.0)): spawn_hazard(i%2)
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
	else:
		box(root,Vector3(.34,.62,.30),Vector3(0,.10,0),Color("#ff5729"))
		box(root,Vector3(.20,.42,.20),Vector3(0,.42,0),Color("#ffe13d"),Vector3(0,0,.35))
	hazards.append(root)

func spawn_creature(kind_override:=-1) -> void:
	var kind:int=kind_override if kind_override>=0 else rng.randi_range(0,KINDS.size()-1)
	var p:=Vector3.ZERO; var found_space:=false
	for attempt in 48:
		p=Vector3(rng.randf_range(-5.2,5.2),.88,rng.randf_range(-4.7,4.7))
		var blocked:bool=Vector2(p.x,p.z).length()>5.55 or (abs(p.x-3.8)<1.8 and abs(p.z+2.7)<1.7)
		# Keep roaming entities out of both crop beds and away from existing objects.
		blocked=blocked or (abs(p.x-3.25)<1.45 and abs(p.z-3.25)<1.25) or (abs(p.x-.35)<1.45 and abs(p.z-4.15)<1.25)
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
	add_child(root)

	if kind==0:
		# Cute cube cow: oversized face, pink muzzle, ears, horns and irregular patches.
		var cream:=Color("#f4f0df"); var dark:=Color("#33343b"); var pink:=Color("#eda18f")
		box(root,Vector3(.88,.66,1.12),Vector3(0,0,-.05),cream)
		box(root,Vector3(.76,.72,.62),Vector3(0,.20,.68),cream)
		box(root,Vector3(.28,.18,.10),Vector3(-.49,.34,.68),pink)
		box(root,Vector3(.28,.18,.10),Vector3(.49,.34,.68),pink)
		box(root,Vector3(.13,.18,.12),Vector3(-.29,.62,.68),Color("#d9c47c"),Vector3(0,0,-.25))
		box(root,Vector3(.13,.18,.12),Vector3(.29,.62,.68),Color("#d9c47c"),Vector3(0,0,.25))
		box(root,Vector3(.52,.27,.12),Vector3(0,.02,1.01),pink)
		box(root,Vector3(.07,.08,.025),Vector3(-.14,.02,1.08),Color("#7b4c4c"))
		box(root,Vector3(.07,.08,.025),Vector3(.14,.02,1.08),Color("#7b4c4c"))
		animal_eye(root,Vector3(-.22,.31,1.015)); animal_eye(root,Vector3(.22,.31,1.015))
		box(root,Vector3(.30,.24,.035),Vector3(-.27,.15,.34),dark)
		box(root,Vector3(.34,.26,.035),Vector3(.24,-.10,-.62),dark)
		box(root,Vector3(.22,.20,.035),Vector3(.33,.18,-.35),dark)
		for q in [Vector3(-.29,-.45,.31),Vector3(.29,-.45,.31),Vector3(-.29,-.45,-.31),Vector3(.29,-.45,-.31)]:
			animal_leg(root,q,cream,dark)
		box(root,Vector3(.09,.55,.09),Vector3(.40,.03,-.62),cream,Vector3(.55,0,0))
		box(root,Vector3(.16,.16,.16),Vector3(.40,-.22,-.79),dark)
	elif kind==1:
		# Bright duckling with a big square head, tiny wings and orange webbed feet.
		var yellow:=Color("#f2dc32"); var orange:=Color("#e99b27")
		box(root,Vector3(.70,.62,.72),Vector3(0,-.02,-.02),yellow)
		box(root,Vector3(.72,.68,.62),Vector3(0,.32,.48),Color("#f5e23b"))
		box(root,Vector3(.34,.17,.20),Vector3(0,.22,.85),orange)
		animal_eye(root,Vector3(-.22,.43,.80)); animal_eye(root,Vector3(.22,.43,.80))
		box(root,Vector3(.18,.42,.42),Vector3(-.43,.0,.0),Color("#e5c92b"),Vector3(0,0,-.25))
		box(root,Vector3(.18,.42,.42),Vector3(.43,.0,.0),Color("#e5c92b"),Vector3(0,0,.25))
		box(root,Vector3(.22,.14,.34),Vector3(-.20,-.46,.16),orange)
		box(root,Vector3(.22,.14,.34),Vector3(.20,-.46,.16),orange)
		box(root,Vector3(.24,.28,.20),Vector3(0,.0,-.46),yellow,Vector3(.35,0,0))
	elif kind==2:
		# Round pink pig with floppy ears, cheek marks and a dimensional snout.
		var pig:=Color("#ee999c"); var pig_light:=Color("#f6b0ae"); var hoof:=Color("#9e5966")
		box(root,Vector3(.94,.68,1.12),Vector3(0,0,-.04),pig)
		box(root,Vector3(.82,.74,.65),Vector3(0,.20,.66),pig_light)
		box(root,Vector3(.24,.28,.16),Vector3(-.38,.56,.64),pig,Vector3(0,0,-.35))
		box(root,Vector3(.24,.28,.16),Vector3(.38,.56,.64),pig,Vector3(0,0,.35))
		box(root,Vector3(.52,.30,.16),Vector3(0,.04,1.02),Color("#f5aaa7"))
		box(root,Vector3(.075,.10,.025),Vector3(-.14,.04,1.11),Color("#8c4f59"))
		box(root,Vector3(.075,.10,.025),Vector3(.14,.04,1.11),Color("#8c4f59"))
		animal_eye(root,Vector3(-.23,.34,1.01)); animal_eye(root,Vector3(.23,.34,1.01))
		box(root,Vector3(.11,.06,.025),Vector3(-.31,.12,1.03),Color("#ef777f"))
		box(root,Vector3(.11,.06,.025),Vector3(.31,.12,1.03),Color("#ef777f"))
		for q in [Vector3(-.30,-.45,.30),Vector3(.30,-.45,.30),Vector3(-.30,-.45,-.30),Vector3(.30,-.45,-.30)]:
			animal_leg(root,q,pig,hoof)
		var tail:=box(root,Vector3(.10,.10,.40),Vector3(.35,.05,-.66),pig)
		tail.rotation.x=.6
	elif kind==3:
		# Soft gray sheep built from chunky wool blocks around a small charcoal face.
		var wool:=Color("#d4d4ce"); var wool_shadow:=Color("#b8bbb7"); var face:=Color("#62666b")
		box(root,Vector3(.94,.72,1.08),Vector3(0,0,-.05),wool)
		for q in [Vector3(-.38,.25,-.34),Vector3(.38,.25,-.34),Vector3(-.38,.25,.20),Vector3(.38,.25,.20),Vector3(0,.38,-.05)]:
			box(root,Vector3(.42,.42,.45),q,wool_shadow if q.x>0 else wool)
		box(root,Vector3(.64,.64,.54),Vector3(0,.15,.69),face)
		box(root,Vector3(.24,.18,.12),Vector3(-.39,.30,.69),face,Vector3(0,0,-.28))
		box(root,Vector3(.24,.18,.12),Vector3(.39,.30,.69),face,Vector3(0,0,.28))
		animal_eye(root,Vector3(-.19,.29,.975)); animal_eye(root,Vector3(.19,.29,.975))
		box(root,Vector3(.20,.10,.04),Vector3(0,.05,.99),Color("#393c42"))
		for q in [Vector3(-.29,-.46,.28),Vector3(.29,-.46,.28),Vector3(-.29,-.46,-.28),Vector3(.29,-.46,-.28)]:
			animal_leg(root,q,face,Color("#3e4247"))
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
	var base_scale:=1.14 if kind==0 else 1.0
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
	tutorial_panel=Control.new(); tutorial_panel.position=Vector2.ZERO; tutorial_panel.size=Vector2(540,960); tutorial_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE; game_ui.add_child(tutorial_panel)
	make_label(tutorial_panel,"SLIDE TO SUCK",Vector2(0,750),25,540,HORIZONTAL_ALIGNMENT_CENTER)
	make_label(tutorial_panel,"←     ▰     →",Vector2(0,795),34,540,HORIZONTAL_ALIGNMENT_CENTER)
	tutorial_panel.visible=false
	intro_overlay=Control.new(); intro_overlay.position=Vector2.ZERO; intro_overlay.size=Vector2(540,960); intro_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE; game_ui.add_child(intro_overlay)
	var logo_shadow:=make_label(intro_overlay,"SUCK IT UP",Vector2(0,67),54,540,HORIZONTAL_ALIGNMENT_CENTER)
	logo_shadow.add_theme_color_override("font_color",Color("#172438")); logo_shadow.add_theme_constant_override("outline_size",10); logo_shadow.add_theme_color_override("font_outline_color",Color("#172438"))
	var logo:=make_label(intro_overlay,"SUCK IT UP",Vector2(0,58),54,540,HORIZONTAL_ALIGNMENT_CENTER)
	logo.add_theme_color_override("font_color",Color("#42d7e8")); logo.add_theme_constant_override("outline_size",5); logo.add_theme_color_override("font_outline_color",Color("#101923"))
	for i in 0:
		var ring:=make_label(intro_overlay,"○",Vector2(0,330+i*62),130+i*26,540,HORIZONTAL_ALIGNMENT_CENTER)
		ring.add_theme_color_override("font_color",Color(0.65,1.0,1.0,.72-i*.13)); intro_rings.append(ring)
	intro_overlay.visible=false
	result_panel=panel(root,Vector2(55,280),Vector2(430,300),Color("#35479bf2"))
	make_label(result_panel,"SHIFT COMPLETE",Vector2(0,30),34,430,HORIZONTAL_ALIGNMENT_CENTER)
	result_label=make_label(result_panel,"SCORE 0",Vector2(0,110),34,430,HORIZONTAL_ALIGNMENT_CENTER)
	var again:=menu_button(result_panel,"PLAY AGAIN",Vector2(65,215),Vector2(300,64),Color("#c83fe0"))
	again.pressed.connect(start_game)
	result_panel.visible=false
	game_ui.visible=false
	build_menu_shell(root)
	menu_root.visible=false
	build_splash(root)

func build_splash(root:Control)->void:
	var splash:=Control.new(); splash.position=Vector2.ZERO; splash.size=Vector2(540,960); splash.mouse_filter=Control.MOUSE_FILTER_STOP; root.add_child(splash)
	var bg:=ColorRect.new(); bg.color=Color("#f6f6f6"); bg.position=Vector2.ZERO; bg.size=Vector2(540,960); splash.add_child(bg)
	var app_logo:=Control.new(); app_logo.position=Vector2.ZERO; app_logo.size=Vector2(540,960); splash.add_child(app_logo)
	var ufo_logo:=TextureRect.new(); ufo_logo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; ufo_logo.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; ufo_logo.texture=load("res://assets/branding/ufo-logo-generated.png"); ufo_logo.position=Vector2(50,245); ufo_logo.size=Vector2(440,402); app_logo.add_child(ufo_logo)
	var company_logo:=Control.new(); company_logo.position=Vector2.ZERO; company_logo.size=Vector2(540,960); company_logo.visible=false; splash.add_child(company_logo)
	var kiseki_logo:=TextureRect.new(); kiseki_logo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; kiseki_logo.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; kiseki_logo.texture=load("res://assets/branding/kiseki-logo-generated.png"); kiseki_logo.position=Vector2(42,330); kiseki_logo.size=Vector2(456,289); company_logo.add_child(kiseki_logo)
	var tw:=create_tween()
	tw.tween_interval(1.8)
	tw.tween_callback(func(): app_logo.visible=false; company_logo.visible=true)
	tw.tween_interval(1.8)
	tw.tween_property(splash,"modulate:a",0.0,.45)
	tw.tween_callback(func(): splash.queue_free(); begin_game_intro())

func begin_game_intro()->void:
	game_state="intro"; score=0; combo=0; level=1; lives=3; level_progress=0; level_goal=50; time_left=45; charge=0; frenzy=0
	update_charge_segments()
	menu_root.visible=false; game_ui.visible=true; result_panel.visible=false; pause_button.visible=false
	intro_overlay.visible=false; tutorial_panel.visible=false; intro_time=0.0; intro_landed=false
	target_position=Vector3(0,2.7,0); ship.scale=Vector3(.78,.78,.78); ship.position=Vector3(0,6.8,-1.35); camera.size=14.8
	ring_center=target_position
	for ring in arrival_rings: ring.visible=true
	arrival_flash.visible=true; arrival_flash.position=Vector3(0,1.8,0); arrival_flash.scale=Vector3(.08,.08,.08)
	var tw:=create_tween().set_parallel(true)
	tw.tween_property(arrival_flash,"scale",Vector3(1.15,1.15,1.15),.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ship,"scale",Vector3.ONE,.30).set_delay(.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(ship,"position",target_position,.30).set_delay(.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(finish_intro_arrival)

func finish_intro_arrival()->void:
	if game_state!="intro": return
	intro_landed=true; intro_overlay.visible=true; tutorial_panel.visible=true; beam.visible=true; arrival_flash.visible=false
	intro_overlay.position=Vector2(540,0); intro_overlay.modulate.a=1.0; tutorial_panel.modulate.a=0.0
	var reveal:=create_tween().set_parallel(true)
	reveal.tween_property(intro_overlay,"position",Vector2.ZERO,.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reveal.tween_property(tutorial_panel,"modulate:a",1.0,.28).set_delay(.08)

func activate_intro_control()->void:
	if game_state!="intro": return
	game_state="play"; intro_overlay.visible=false; tutorial_panel.visible=false; pause_button.visible=true; dragging=true
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
	level+=1; level_progress=0; level_goal=roundi(level_goal*1.25); time_left=45.0; target_kind=rng.randi_range(0,KINDS.size()-1)
	populate_level()
	target_position=Vector3(0,2.7,0); ring_center=target_position; ship.position=Vector3(0,7.2,-1.0); ship.scale=Vector3(.45,.45,.45)
	arrival_flash.position=Vector3(0,1.8,0); arrival_flash.scale=Vector3(1.1,1.1,1.1)
	var enter_tween:=create_tween().set_parallel(true)
	enter_tween.tween_property(ship,"position",target_position,.48).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	enter_tween.tween_property(ship,"scale",Vector3.ONE,.48).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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
		if e.pressed and game_state=="intro": activate_intro_control()
		if e.pressed and game_state=="over": start_game()
	elif e is InputEventScreenDrag and game_state=="play":
		target_position.x=clamp(target_position.x+e.relative.x*.018,-7.4,7.4)
		target_position.z=clamp(target_position.z+e.relative.y*.018,-7.0,7.0)
	elif e is InputEventMouseButton:
		dragging=e.pressed
		if e.pressed and game_state=="intro": activate_intro_control()
		if e.pressed and game_state=="over": start_game()
	elif e is InputEventMouseMotion and dragging and game_state=="play":
		target_position.x=clamp(target_position.x+e.relative.x*.018,-7.4,7.4)
		target_position.z=clamp(target_position.z+e.relative.y*.018,-7.0,7.0)

func toggle_pause()->void:
	if game_state!="play": return
	get_tree().paused=not get_tree().paused
	pause_button.text=">" if get_tree().paused else "II"

func start_game()->void:
	begin_game_intro()

func _process(d:float)->void:
	if game_state=="intro" or game_state=="portal" or portal_open:
		intro_time+=d
		for i in arrival_rings.size():
			var ring:=arrival_rings[i]
			var ring_offsets:=[.70,.05,-.65,-1.32]
			var ring_sizes:=[1.02,1.30,1.58,1.42]
			ring.position=Vector3(ring_center.x,ring_center.y+ring_offsets[i]+sin(intro_time*2.4-i*.7)*.07,ring_center.z)
			var pulse:=1.0+sin(intro_time*3.0-i*.55)*.035
			ring.scale=Vector3.ONE*ring_sizes[i]*pulse
			ring.rotation.y+=d*(.32 if i%2==0 else -.28)
			var ring_mat:=ring.material_override as StandardMaterial3D
			ring_mat.albedo_color=Color(0.68,1.0,1.0,.76)
	if game_state!="intro" and game_state!="portal":
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
		camera.size=lerp(camera.size,13.7 if frenzy>0 else 14.8,min(1.0,d*2.0))
		update_animals(d)
		if portal_open and Vector2(ship.position.x-ring_center.x,ship.position.z-ring_center.z).length()<1.05: start_level_portal()
		boundary_alert.visible=Vector2(ship.position.x,ship.position.z).length()>5.8
		if burning:
			burn_time-=d; fire_visual.visible=true; fire_visual.scale=Vector3.ONE*(1.0+sin(Time.get_ticks_msec()/80.0)*.08)
			if Vector2(ship.position.x+3.7,ship.position.z+2.7).length()<1.35:
				burning=false; fire_visual.visible=false; pop_feedback("EXTINGUISHED",Color("#72e8ff"),ship.global_position)
			elif burn_time<=0.0: destroy_ufo()
	beam.visible=(game_state=="intro" and intro_landed) or (dragging and game_state=="play")
	if game_state=="play":
		time_left-=d; frenzy=max(0.0,frenzy-d)
		if charge>=100 and frenzy<=0: frenzy=7; charge=0; update_charge_segments(); beam.material_override=mat(Color(1,.82,.18,.34),Color("#ffd331"),true)
		if frenzy<=0 and beam.material_override.albedo_color.r>.9: beam.material_override=mat(Color(.72,.35,.94,.3),Color("#a252df"),true)
		if dragging: abduct(d); abduct_hazards(d)
		if time_left<=0: finish_game()
		update_hud()
func update_animals(d:float)->void:
	for c in creatures:
		if not is_instance_valid(c) or int(c.get_meta("kind"))>=4: continue
		var offset:=Vector2(c.position.x-ship.position.x,c.position.z-ship.position.z)
		if dragging and not c.get_meta("fleeing",false) and offset.length()>=1.18 and offset.length()<3.0:
			c.set_meta("fleeing",true); c.set_meta("flee_dir",offset.normalized()); (c.get_meta("alert") as Label3D).visible=true
		if c.get_meta("fleeing",false):
			var direction:Vector2=c.get_meta("flee_dir")
			c.position.x+=direction.x*d*3.4; c.position.z+=direction.y*d*3.4
			c.rotation.y=lerp_angle(c.rotation.y,atan2(direction.x,direction.y),min(1.0,d*12.0))
			var phase:float=c.get_meta("walk_phase")+d*18.0; c.set_meta("walk_phase",phase); c.position.y=.88+abs(sin(phase))*.11
			if Vector2(c.position.x,c.position.z).length()>6.8:
				var angle:=rng.randf_range(0,TAU); var radius:=rng.randf_range(3.8,5.5)
				var base_scale:float=c.get_meta("base_scale",1.0)
				c.position=Vector3(cos(angle)*radius,.88,sin(angle)*radius); c.scale=Vector3.ONE*base_scale; c.set_meta("fleeing",false); (c.get_meta("alert") as Label3D).visible=false; c.set_meta("move_timer",rng.randf_range(.5,1.8))
		else:
			if dragging and offset.length()<1.35: continue
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
	# Every collectible inside the beam is lifted at once, as in the reference.
	for chosen in creatures.duplicate():
		if not is_instance_valid(chosen): continue
		var dist:=Vector2(chosen.position.x-ship.position.x,chosen.position.z-ship.position.z).length()
		if dist>=1.18: continue
		chosen.position.x=lerp(chosen.position.x,ship.position.x,d*5.2)
		chosen.position.z=lerp(chosen.position.z,ship.position.z,d*5.2)
		chosen.position.y+=d*(2.8 if frenzy>0 else 1.65)
		chosen.rotation.y+=d*7.0
		var base_scale:float=chosen.get_meta("base_scale",1.0)
		chosen.scale=Vector3.ONE*base_scale*clamp((ship.position.y-chosen.position.y)/2.0,.18,1.0)
		if chosen.position.y<=2.28: continue
		var kind:int=chosen.get_meta("kind")
		combo+=1
		var gain:=(1 if kind>=4 else 2)+(1 if combo%5==0 else 0)
		if frenzy>0: gain*=2
		score+=gain; level_progress+=gain; charge=min(100,charge+8.34); coins+=1
		update_charge_segments(); pop_feedback("+%d"%gain,Color("#ffffff"),chosen.global_position)
		creatures.erase(chosen); chosen.queue_free()
		if combo%5==0: target_kind=rng.randi_range(0,KINDS.size()-1)
		if creatures.is_empty():
			open_exit_portal()
			return

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
		if hazard_kind==0:
			pop_feedback("BOOM!",Color("#ff5a3d"),ship.global_position)
			destroy_ufo()
			return
		if not burning:
			burning=true
			burn_time=4.0
			pop_feedback("FIRE! FIND THE POND",Color("#ffb52f"),ship.global_position)

func destroy_ufo()->void:
	if game_state!="play": return
	lives-=1
	combo=0
	burning=false
	burn_time=0.0
	fire_visual.visible=false
	dragging=false
	beam.visible=false
	if lives<=0:
		pop_feedback("UFO DESTROYED",Color("#ff4d62"),ship.global_position)
		finish_game()
		return
	target_position=Vector3(0,2.7,0)
	ship.position=target_position
	ship.rotation=Vector3.ZERO
	pop_feedback("LIFE LOST",Color("#ff6b76"),ship.global_position)

func next_level()->void:
	start_level_portal()
func update_hud()->void:
	score_label.text=str(score); target_label.text=KINDS[target_kind]; combo_label.visible=true; combo_label.position=Vector2(20,78); combo_label.text="LEVEL %d   LIVES %d"%[level,lives]; combo_label.add_theme_font_size_override("font_size",16)
	if frenzy>0:target_label.text="FRENZY"

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
	game_state="menu"; dragging=false; beam.visible=false; camera.size=18.0; game_ui.visible=false
	if score>best:
		best=score
		var f:=FileAccess.open("user://best3d.txt",FileAccess.WRITE); f.store_string(str(best))
	show_menu("home")
