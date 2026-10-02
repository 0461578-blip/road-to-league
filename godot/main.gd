extends Node3D

# Road to the League — original Roblox-inspired 3D football game.
# The menu/camera are original implementations inspired by common football-game UI patterns.

const FIELD_X := 120.0
const FIELD_Z := 52.0
const BLUE := Color("#2467d8")
const RED := Color("#c92f42")
const GREEN := Color("#176b35")
const WHITE := Color("#f5f7f7")
const SKIN := Color("#7a4b31")
const DARK := Color("#151a20")

var players: Array[Dictionary] = []
var user_player: Node3D
var wr_player: Node3D
var football: MeshInstance3D
var camera: Camera3D
var play_live := false
var game_started := false
var role := "QB"
var play_name := "SLANT"
var ball_in_air := false
var ball_t := 0.0
var ball_start := Vector3.ZERO
var ball_target := Vector3.ZERO
var stamina := 100.0
var down := 1
var distance := 10
var home_score := 0
var away_score := 0
var game_clock := 720.0
var catch_window := 0.0
var playbook := ["SLANT","GO","OUT","CURL"]
var play_index := 0
var play_yard_start := -25.0
var first_down_x := -15.0
var tackle_cooldown := 0.0
var block_targets: Dictionary = {}
var route_phase := 0
var status_label: Label
var hud_label: Label
var anim_time := 0.0
var menu_layer: CanvasLayer
var menu_panel: PanelContainer

func _ready() -> void:
    _build_world()
    _build_teams()
    _build_ui()
    _reset_play()
    _show_main_menu()

func _process(delta: float) -> void:
    if not game_started:
        _update_menu_camera(delta)
        return
    game_clock = maxf(0.0, game_clock - delta)
    tackle_cooldown = maxf(0.0, tackle_cooldown - delta)
    _update_user(delta)
    _update_routes(delta)
    _update_defense(delta)
    _update_pass(delta)
    _animate_players(delta)
    _update_camera(delta)
    _update_ui()

func _material(color: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = 0.38
    m.metallic = 0.04
    return m

func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    var node := MeshInstance3D.new()
    node.mesh = mesh
    node.material_override = _material(color)
    node.position = pos
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    parent.add_child(node)
    return node

func _cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    var node := MeshInstance3D.new()
    node.mesh = mesh
    node.material_override = _material(color)
    node.position = pos
    parent.add_child(node)
    return node

func _build_world() -> void:
    var env := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sky_mat := ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Color("#163b68")
    sky_mat.sky_horizon_color = Color("#a7c9dc")
    sky_mat.ground_bottom_color = Color("#172028")
    sky_mat.ground_horizon_color = Color("#667d88")
    sky.sky_material = sky_mat
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("#dce9ee")
    environment.ambient_light_energy = 0.72
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.glow_enabled = true
    environment.glow_intensity = 0.7
    env.environment = environment
    add_child(env)

    var sun := DirectionalLight3D.new()
    sun.light_energy = 1.55
    sun.rotation_degrees = Vector3(-55, -25, 0)
    sun.shadow_enabled = true
    add_child(sun)

    _box(self, Vector3(FIELD_X, 0.2, FIELD_Z), Vector3(0,-0.1,0), GREEN)

    for x in range(-60, 61, 5):
        _box(self, Vector3(0.07,0.03,FIELD_Z), Vector3(x,0.03,0), WHITE)
    for x in range(-60, 61, 10):
        _box(self, Vector3(0.14,0.035,FIELD_Z), Vector3(x,0.04,0), WHITE)
    for x in range(-55, 56, 5):
        for z in [-5.7, 5.7]:
            _box(self, Vector3(0.65,0.03,0.08), Vector3(x,0.04,z), WHITE)

    _box(self, Vector3(10,0.04,FIELD_Z), Vector3(-55,0.05,0), Color("#244c8d"))
    _box(self, Vector3(10,0.04,FIELD_Z), Vector3(55,0.05,0), Color("#7a2940"))

    for x in [-60.0, 60.0]:
        _cylinder(self, 0.09, 8.0, Vector3(x,4,0), Color("#ffd34d"))
        _box(self, Vector3(0.16,0.16,8), Vector3(x,8,0), Color("#ffd34d"))

    for z in [-31.0, 31.0]:
        for r in range(8):
            _box(self, Vector3(122,1.0,3), Vector3(0,1.0+r*1.45,z + (-r*1.7 if z < 0 else r*1.7)), Color("#30363d"))
        _box(self, Vector3(122,0.25,0.25), Vector3(0,12.2,z), Color("#d5d9dc"))

    for x in [-48.0,-24.0,0.0,24.0,48.0]:
        _cylinder(self, 0.22, 16.0, Vector3(x,8,-30), Color("#4b5259"))
        _box(self, Vector3(1.2,0.8,0.35), Vector3(x,16,-30), Color("#e9edf0"))
        _cylinder(self, 0.22, 16.0, Vector3(x,8,30), Color("#4b5259"))
        _box(self, Vector3(1.2,0.8,0.35), Vector3(x,16,30), Color("#e9edf0"))

    camera = Camera3D.new()
    camera.current = true
    camera.fov = 58.0
    camera.near = 0.1
    camera.far = 500.0
    add_child(camera)
    camera.global_position = Vector3(-34, 16, 26)
    camera.look_at(Vector3(-8, 0.5, 0), Vector3.UP)

func _player(team: Color, position: Vector3, position_name: String) -> Node3D:
    var g := Node3D.new()
    add_child(g)
    g.position = position
    var skin_mat := _material(SKIN)
    var pad_mat := _material(team.darkened(0.18))
    for side in [-1, 1]:
        _box(g, Vector3(0.30,0.78,0.34), Vector3(side*0.24,0.48,0), Color("#151a20"))
        _box(g, Vector3(0.38,0.30,0.40), Vector3(side*0.24,0.12,-0.03), Color("#e8ebee"))
        _box(g, Vector3(0.46,0.12,0.72), Vector3(side*0.24,0.03,-0.08), Color("#090b0d"))
    _box(g, Vector3(1.05,0.42,0.68), Vector3(0,1.02,0), pad_mat)
    _box(g, Vector3(0.96,0.88,0.62), Vector3(0,1.47,0), team)
    var shoulder := SphereMesh.new()
    shoulder.radius = 0.62
    shoulder.height = 0.36
    var sh := MeshInstance3D.new()
    sh.mesh = shoulder
    sh.scale = Vector3(1.0,0.55,0.62)
    sh.position = Vector3(0,1.72,0)
    sh.material_override = pad_mat
    g.add_child(sh)
    for side in [-1,1]:
        var arm := _cylinder(g,0.14,0.72,Vector3(side*0.65,1.43,0),team)
        arm.rotation_degrees = Vector3(0,0,side*10)
        var forearm := _cylinder(g,0.115,0.32,Vector3(side*0.69,1.05,-0.05),skin_mat.albedo_color)
        forearm.rotation_degrees = Vector3(0,0,side*10)
        _cylinder(g,0.13,0.20,Vector3(side*0.70,0.86,-0.06),Color("#111820"))
    var head_mesh := SphereMesh.new()
    head_mesh.radius = 0.36
    head_mesh.height = 0.72
    var head := MeshInstance3D.new()
    head.mesh = head_mesh
    head.material_override = skin_mat
    head.position = Vector3(0,2.32,0)
    g.add_child(head)
    var helmet_mesh := SphereMesh.new()
    helmet_mesh.radius = 0.45
    helmet_mesh.height = 0.62
    var helmet := MeshInstance3D.new()
    helmet.mesh = helmet_mesh
    helmet.material_override = _material(team.darkened(0.08))
    helmet.scale = Vector3(1.10,0.76,1.08)
    helmet.position = Vector3(0,2.54,0)
    g.add_child(helmet)
    _box(g,Vector3(0.70,0.08,0.10),Vector3(0,2.45,-0.39),Color("#0a0c0f"))
    for side in [-1,1]:
        var bar := _cylinder(g,0.035,0.42,Vector3(side*0.24,2.37,-0.41),Color("#0a0c0f"))
        bar.rotation_degrees = Vector3(90,0,0)
    var number := {"QB":"12","WR":"11","WR2":"80","RB":"22","TE":"87","FB":"45","OL":"64","DL":"90","LB":"52","CB":"21","S":"31"}.get(position_name,"0")
    var number_label := Label3D.new()
    number_label.text = number
    number_label.font_size = 58
    number_label.modulate = WHITE
    number_label.outline_size = 10
    number_label.outline_modulate = team.darkened(0.68)
    number_label.position = Vector3(0,1.50,-0.35)
    g.add_child(number_label)
    _box(g,Vector3(0.78,0.08,0.62),Vector3(0,1.25,-0.02),Color("#f4f5f5"))
    g.set_meta("team", team)
    g.set_meta("position_name", position_name)
    g.set_meta("route_progress", 0.0)
    players.append({"node":g, "team":team, "position":position_name})
    return g

func _animate_players(delta: float) -> void:
    anim_time += delta
    if not play_live:
        return
    for p in players:
        var n: Node3D = p.node
        var phase := float(n.get_instance_id() % 17) * 0.37
        var bob := sin(anim_time * 10.0 + phase) * 0.035
        n.position.y = bob
        n.rotation.y = lerp_angle(n.rotation.y, 0.0, 0.08)

func _build_teams() -> void:
    user_player = _player(BLUE, Vector3(-25,0,0), "QB")
    _player(BLUE, Vector3(-27,0,2), "RB")
    wr_player = _player(BLUE, Vector3(-25,0,-9), "WR")
    _player(BLUE, Vector3(-25,0,9), "WR2")
    _player(BLUE, Vector3(-25,0,6), "TE")
    for i in range(-2,3):
        _player(BLUE, Vector3(-27,0,i*2), "OL")
    _player(BLUE, Vector3(-28,0,-3), "FB")

    for z in [-3,-1,1,3]:
        _player(RED, Vector3(-22,0,z*2), "DL")
    for z in [-6,0,6]:
        _player(RED, Vector3(-17,0,z), "LB")
    for z in [-9,9]:
        _player(RED, Vector3(-16,0,z), "CB")
    for z in [-4,4]:
        _player(RED, Vector3(-8,0,z), "S")

    football = MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.19
    sphere.height = 0.38
    football.mesh = sphere
    football.scale = Vector3(1,1,1.7)
    football.material_override = _material(Color("#713e1c"))
    add_child(football)

func _build_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)

    hud_label = Label.new()
    hud_label.position = Vector2(18,18)
    hud_label.add_theme_font_size_override("font_size", 20)
    layer.add_child(hud_label)

    status_label = Label.new()
    status_label.position = Vector2(18,650)
    status_label.add_theme_font_size_override("font_size", 16)
    layer.add_child(status_label)

    var title := Label.new()
    title.text = "ROAD TO THE LEAGUE"
    title.position = Vector2(470,18)
    title.add_theme_font_size_override("font_size", 24)
    layer.add_child(title)

func _show_main_menu() -> void:
    menu_layer = CanvasLayer.new()
    menu_layer.layer = 20
    add_child(menu_layer)

    var dim := ColorRect.new()
    dim.color = Color(0.015,0.02,0.03,0.72)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    menu_layer.add_child(dim)

    menu_panel = PanelContainer.new()
    menu_panel.position = Vector2(72,110)
    menu_panel.size = Vector2(470,500)
    menu_layer.add_child(menu_panel)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 18)
    menu_panel.add_child(box)

    var title := Label.new()
    title.text = "ROAD TO\nTHE LEAGUE"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 46)
    box.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "BUILD YOUR CAREER • EARN YOUR SPOT • MAKE THE LEAGUE"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 15)
    box.add_child(subtitle)

    var start := Button.new()
    start.text = "PLAY GAME"
    start.custom_minimum_size = Vector2(0,68)
    start.add_theme_font_size_override("font_size", 25)
    start.pressed.connect(_start_game)
    box.add_child(start)

    var career := Button.new()
    career.text = "ROAD TO GLORY"
    career.custom_minimum_size = Vector2(0,54)
    career.add_theme_font_size_override("font_size", 19)
    career.pressed.connect(_start_game)
    box.add_child(career)

    var controls := Label.new()
    controls.text = "WASD  MOVE    SHIFT  SPRINT\nSPACE  SNAP    E  THROW    C  CATCH\nQ  SWITCH TO WR    1–4  PLAY CALL"
    controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    controls.add_theme_font_size_override("font_size", 15)
    box.add_child(controls)

func _start_game() -> void:
    game_started = true
    if menu_layer:
        menu_layer.queue_free()
        menu_layer = null
    _reset_play()
    _snap_camera_to_player()

func _update_menu_camera(delta: float) -> void:
    if camera == null:
        return
    var t := Time.get_ticks_msec() / 1000.0
    var center := Vector3(-18,1.5,0)
    var desired := center + Vector3(-25.0 + sin(t*0.18)*3.0, 11.0 + sin(t*0.35)*1.0, 28.0)
    camera.global_position = camera.global_position.lerp(desired, minf(1.0,delta*2.5))
    camera.look_at(center,Vector3.UP)

func _snap_camera_to_player() -> void:
    if camera == null or user_player == null:
        return
    camera.global_position = user_player.global_position + Vector3(-10.0,8.0,15.0)
    camera.look_at(user_player.global_position + Vector3(5.0,1.0,0),Vector3.UP)

func _update_user(delta: float) -> void:
    if not play_live:
        return

    var input := Input.get_vector("move_left","move_right","move_forward","move_back")
    var sprinting := Input.is_action_pressed("sprint") and stamina > 0.0
    var speed := 8.2 if sprinting else 5.3

    if sprinting and input.length() > 0.1:
        stamina = maxf(0.0, stamina - delta*28.0)
    else:
        stamina = minf(100.0, stamina + delta*18.0)

    if input.length() > 0.01:
        user_player.position.x += input.y * speed * delta
        user_player.position.z += input.x * speed * delta
        user_player.position.x = clampf(user_player.position.x,-58,58)
        user_player.position.z = clampf(user_player.position.z,-23,23)

    if Input.is_action_just_pressed("switch_wr") and not ball_in_air:
        role = "WR"
        user_player = wr_player
        _snap_camera_to_player()

    if Input.is_action_just_pressed("throw_ball") and role == "QB":
        _throw_ball()

    if Input.is_action_just_pressed("catch_ball") and role == "WR":
        _attempt_catch()

    for i in range(4):
        if Input.is_action_just_pressed("play_%d" % (i + 1)):
            play_index = i
            play_name = playbook[i]

    if Input.is_action_just_pressed("snap_play") and not play_live:
        play_live = true
        route_phase = 0
        _assign_blocks()

func _update_routes(delta: float) -> void:
    if not play_live or role == "WR":
        return
    var target := Vector3(-17,0,-9)
    if route_phase == 0 and wr_player.position.distance_to(target) < 0.8:
        route_phase = 1
    if route_phase == 1:
        target = Vector3(-10,0,-2)
    if play_name == "GO":
        target = Vector3(12,0,-9)
    elif play_name == "OUT":
        target = Vector3(-10,0,-9) if route_phase == 0 else Vector3(-10,0,-17)
    elif play_name == "CURL":
        target = Vector3(-5,0,-9) if route_phase == 0 else Vector3(-9,0,-9)
    var v := target - wr_player.position
    v.y = 0
    if v.length() > 0.5:
        wr_player.position += v.normalized() * 5.4 * delta

func _assign_blocks() -> void:
    block_targets.clear()
    for p in players:
        if p.team != BLUE or p.position != "OL":
            continue
        var best: Dictionary = {}
        var best_dist := 999.0
        for d in players:
            if d.team != RED or (d.position != "DL" and d.position != "LB"):
                continue
            var dist := p.node.position.distance_to(d.node.position)
            if dist < best_dist:
                best_dist = dist
                best = d
        if not best.is_empty():
            block_targets[p.node.get_instance_id()] = best.node

func _update_defense(delta: float) -> void:
    if not play_live:
        return
    for p in players:
        if p.team != RED:
            continue
        var node: Node3D = p.node
        var target := wr_player if p.position == "CB" or p.position == "S" else user_player
        var blocked := false
        for blocker in players:
            if blocker.team == BLUE and blocker.position == "OL" and block_targets.get(blocker.node.get_instance_id(), null) == node:
                var bv: Vector3 = node.position - blocker.node.position
                bv.y = 0
                if bv.length() < 2.0:
                    blocked = true
                    node.position += bv.normalized() * delta * 1.6 if bv.length() > 0.1 else Vector3.ZERO
                    break
        if blocked:
            continue
        var v := target.position - node.position
        v.y = 0
        var speed := 4.0 if p.position == "DL" else 4.8
        if v.length() > 1.2:
            node.position += v.normalized() * speed * delta
        if role == "WR" and node.position.distance_to(user_player.position) < 1.25 and not ball_in_air and tackle_cooldown <= 0.0:
            _tackle()

func _throw_ball() -> void:
    if ball_in_air:
        return
    ball_in_air = true
    ball_t = 0.0
    ball_start = user_player.position + Vector3(0,2,0)
    ball_target = wr_player.position + Vector3(0,1.3,0)

func _update_pass(delta: float) -> void:
    for p in players:
        if p.team == BLUE:
            var pos: String = p.position
            if pos == "RB":
                p.node.position = Vector3(play_yard_start-2,0,2)
            elif pos == "TE":
                p.node.position = Vector3(play_yard_start,0,6)
            elif pos == "FB":
                p.node.position = Vector3(play_yard_start-3,0,-3)
            elif pos == "OL":
                var idx := players.find(p)
                p.node.position = Vector3(play_yard_start-2,0,(idx%5-2)*2)
        elif p.position == "DL":
            p.node.position.x = play_yard_start+3
        elif p.position == "LB":
            p.node.position.x = play_yard_start+8
        elif p.position == "CB":
            p.node.position.x = play_yard_start+9
        elif p.position == "S":
            p.node.position.x = play_yard_start+17

    if not ball_in_air:
        football.position = user_player.position + Vector3(0,1.5,0)
        return

    ball_t += delta
    var t := clampf(ball_t/1.05,0,1)
    football.position = ball_start.lerp(ball_target,t)
    football.position.y += sin(PI*t)*5.5

    if t >= 1.0:
        ball_in_air = false
        _reset_play()

func _attempt_catch() -> void:
    if not ball_in_air:
        return
    var d := user_player.position.distance_to(football.position)
    if d < 2.7 and ball_t > 0.38 and ball_t < 1.03:
        var timing := 1.0 - minf(1.0,absf(ball_t-0.70)/0.30)
        catch_window = timing
        if timing >= 0.82:
            ball_in_air = false
            var gained := int(round(user_player.position.x - play_yard_start))
            if user_player.position.x >= first_down_x:
                distance = 10
                down = 1
            else:
                distance = max(1, distance - max(1, gained))
                down += 1
                if down > 4:
                    down = 1
                    distance = 10
            if user_player.position.x >= 54:
                home_score += 7
            _reset_play()

func _tackle() -> void:
    if tackle_cooldown > 0.0:
        return
    tackle_cooldown = 0.6
    ball_in_air = false
    down += 1
    if down > 4:
        down = 1
        distance = 10
    _reset_play()

func _reset_play() -> void:
    play_live = false
    route_phase = 0
    role = "QB"
    user_player = _find_position("QB")
    wr_player = _find_position("WR")
    play_yard_start = -25.0
    first_down_x = play_yard_start + float(distance)
    user_player.position = Vector3(play_yard_start,0,0)
    wr_player.position = Vector3(play_yard_start,0,-9)
    _snap_camera_to_player()
    football.position = user_player.position + Vector3(0,1.5,0)

func _find_position(name: String) -> Node3D:
    for p in players:
        if p.position == name:
            return p.node
    return null

func _update_camera(delta: float) -> void:
    if camera == null or user_player == null:
        return
    var desired := user_player.global_position + Vector3(-12.5,6.5,17.5)
    desired.y = maxf(desired.y, 4.5)
    camera.global_position = camera.global_position.lerp(desired, minf(1.0, delta * 7.0))
    camera.look_at(user_player.global_position + Vector3(5.0,1.0,0), Vector3.UP)
    if camera.global_position.y < 4.0:
        camera.global_position.y = 4.0

func _update_ui() -> void:
    var mins := int(game_clock)/60
    var secs := int(game_clock)%60
    hud_label.text = "YOU: %s   PLAY: %s   %d & %d   LOS 25\nHOME %d — %d AWAY   %02d:%02d" % [role,play_name,down,distance,home_score,away_score,mins,secs]
    status_label.text = "WASD MOVE   SHIFT SPRINT   SPACE SNAP   E THROW   C CATCH   Q SWITCH WR   1-4 PLAY CALL   STAMINA %d   |   3D FOOTBALL" % int(stamina)
