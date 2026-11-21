class_name Drone
extends CharacterBody3D
## Security drone. Navigation uses NavigationAgent3D on the grid navmesh;
## closed doors disable their nav region, so routes update automatically.
##
##   OFFLINE ◀── dock loses power ── (any state)
##   OFFLINE ── power back ──▶ PATROL
##   PATROL ── sees player far ──▶ SUSPICIOUS (goes to last seen spot)
##   PATROL/SUSPICIOUS ── sees player within 4 m ──▶ ALERTED
##   SUSPICIOUS ── searched 2.5 s, nothing ──▶ PATROL
##   ALERTED ── 3 s without sight ──▶ SUSPICIOUS (last known position)
##   ALERTED + within catch range ──▶ player caught (respawn at checkpoint)
##
## Vision: 80° cone, 9 m in light, 4.5 m when the player stands in the dark.

enum State { OFFLINE, PATROL, SUSPICIOUS, ALERTED }
const STATE_NAMES: Array[String] = ["OFFLINE", "PATROL", "SUSPICIOUS", "ALERTED"]

const PATROL_SPEED := 2.4
const CHASE_SPEED := 4.6
const VIEW_RANGE_LIT := 9.0
const VIEW_RANGE_DARK := 4.5
const HALF_FOV := deg_to_rad(40.0)
const ALERT_RANGE := 4.0
const CATCH_RANGE := 1.3
const SEARCH_TIME := 2.5
const LOSE_TIME := 3.0
const EYE_HEIGHT := 1.4

var game: Game
var route: Array[Vector3] = []
var dock_id := ""
var state: int = State.OFFLINE
var route_index := 0
var last_seen := Vector3.ZERO
var timer := 0.0
var facing := Vector3.FORWARD
var sees_player := false

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var body_mesh: Node3D = $Body
@onready var eye: MeshInstance3D = $Body/Eye
@onready var beam: SpotLight3D = $Body/Beam


func _ready() -> void:
	beam.rotation = Vector3(deg_to_rad(-12.0), PI, 0.0) # SpotLight3D shines along -Z; the model faces +Z


func is_dock_powered() -> bool:
	var dock := game.entity(dock_id) as Interactable
	return dock != null and dock.is_powered()


func _physics_process(delta: float) -> void:
	if game == null or game.player == null:
		return
	if not is_dock_powered():
		if state != State.OFFLINE:
			_set_state(State.OFFLINE, "dock lost power")
		velocity = Vector3.ZERO
		_update_visuals(delta)
		return
	if state == State.OFFLINE:
		_set_state(State.PATROL, "power restored")
		_go_to(route[route_index])
	var player := game.player
	sees_player = can_see(player.global_position + Vector3.UP * 1.0)
	var dist := global_position.distance_to(player.global_position)
	match state:
		State.PATROL:
			if sees_player:
				last_seen = player.global_position
				if dist <= ALERT_RANGE:
					_set_state(State.ALERTED, "spotted player up close")
				else:
					_set_state(State.SUSPICIOUS, "glimpsed player")
					_go_to(last_seen)
			elif agent.is_navigation_finished():
				route_index = (route_index + 1) % route.size()
				_go_to(route[route_index])
		State.SUSPICIOUS:
			if sees_player:
				last_seen = player.global_position
				_set_state(State.ALERTED, "confirmed player")
			elif agent.is_navigation_finished():
				timer += delta
				facing = facing.rotated(Vector3.UP, 1.6 * delta)
				if timer >= SEARCH_TIME:
					_set_state(State.PATROL, "nothing found")
					_go_to(route[_nearest_waypoint()])
		State.ALERTED:
			if sees_player:
				last_seen = player.global_position
				timer = 0.0
			else:
				timer += delta
				if timer >= LOSE_TIME:
					_set_state(State.SUSPICIOUS, "lost the player")
					_go_to(last_seen)
			if state == State.ALERTED:
				_go_to(last_seen)
				if dist <= CATCH_RANGE and sees_player:
					game.player_caught()
					return
	_move(delta)
	_update_visuals(delta)


func _move(delta: float) -> void:
	if agent.is_navigation_finished():
		velocity = velocity.move_toward(Vector3.ZERO, 10.0 * delta)
	else:
		var next := agent.get_next_path_position()
		var dir := next - global_position
		dir.y = 0.0
		var speed := CHASE_SPEED if state == State.ALERTED else PATROL_SPEED
		if dir.length() > 0.05:
			dir = dir.normalized()
			velocity = dir * speed
			facing = facing.slerp(dir, clampf(8.0 * delta, 0.0, 1.0)).normalized()
	move_and_slide()


func _go_to(p: Vector3) -> void:
	agent.target_position = p


func _nearest_waypoint() -> int:
	var best := 0
	for i in route.size():
		if route[i].distance_to(global_position) < route[best].distance_to(global_position):
			best = i
	return best


## Cone + range (depends on light at the target) + line of sight.
func can_see(target: Vector3) -> bool:
	var eye_pos := global_position + Vector3.UP * EYE_HEIGHT
	var to := target - eye_pos
	var flat := Vector3(to.x, 0, to.z)
	var range_limit := VIEW_RANGE_LIT if game.is_lit(target) else VIEW_RANGE_DARK
	if flat.length() > range_limit:
		return false
	if flat.length() > 0.5 and facing.angle_to(flat.normalized()) > HALF_FOV:
		return false
	var q := PhysicsRayQueryParameters3D.create(eye_pos, target, 1 | 8) # walls, doors, crates
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _set_state(s: int, reason: String) -> void:
	game.log_event("drone: %s -> %s (%s)" % [STATE_NAMES[state], STATE_NAMES[s], reason])
	state = s
	timer = 0.0


func state_name() -> String:
	return STATE_NAMES[state]


func reset_to(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	route_index = 0
	if state != State.OFFLINE:
		state = State.PATROL
		_go_to(route[0])


func _update_visuals(delta: float) -> void:
	body_mesh.rotation.y = lerp_angle(body_mesh.rotation.y, atan2(facing.x, facing.z), 10.0 * delta)
	var hover := 0.0 if state == State.OFFLINE else 1.4 + sin(Time.get_ticks_msec() * 0.004) * 0.06
	body_mesh.position.y = move_toward(body_mesh.position.y, hover, 3.0 * delta)
	var col: Color = [Color("333333"), Color("4de1ff"), Color("ffc94d"), Color("ff4d4d")][state]
	eye.material_override = Mats.glow(col, 4.0) if state != State.OFFLINE else Mats.solid(col)
	beam.visible = state != State.OFFLINE
	beam.light_color = col
