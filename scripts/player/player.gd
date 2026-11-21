class_name Player
extends CharacterBody3D
## Third-person character: camera-relative movement, interaction ray,
## grab & throw for physics props.
##
## Input comes from `input` (a PlayerInput). By default it is refreshed from
## the keyboard/mouse every physics frame; tests set `scripted = true` and
## fill it themselves.

const WALK_SPEED := 4.2
const SPRINT_SPEED := 6.5
const ACCEL := 30.0
const GRAVITY := 18.0
const INTERACT_RANGE := 2.8
const HOLD_DISTANCE := 1.5
const HOLD_HEIGHT := 1.1
const THROW_SPEED := 9.0
const MOUSE_SENS := 0.0025
const KEY_TURN := 2.2

class PlayerInput:
	var move := Vector2.ZERO   # x = strafe, y = forward
	var look := Vector2.ZERO   # radians this frame (yaw, pitch)
	var sprint := false
	var interact := false      # pressed this frame
	var grab := false          # pressed this frame
	var throw := false         # pressed this frame

var game: Game
var input := PlayerInput.new()
var scripted := false
var focused: Node = null       ## what the interaction ray points at
var held: RigidBody3D = null   ## crate being carried
var controls_enabled := true

@onready var pivot: Node3D = $Pivot
@onready var pitch: Node3D = $Pivot/Pitch
@onready var arm: SpringArm3D = $Pivot/Pitch/SpringArm3D
@onready var camera: Camera3D = $Pivot/Pitch/SpringArm3D/Camera3D
@onready var model: Node3D = $Model


func _ready() -> void:
	arm.add_excluded_object(get_rid())
	pitch.rotation.x = deg_to_rad(-16.0)


func _unhandled_input(event: InputEvent) -> void:
	if scripted or not controls_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		input.look += Vector2(-event.relative.x, -event.relative.y) * MOUSE_SENS


func _read_live_input(delta: float) -> void:
	input.move = Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	input.sprint = Input.is_action_pressed("sprint")
	input.interact = Input.is_action_just_pressed("interact")
	input.grab = Input.is_action_just_pressed("grab")
	input.throw = Input.is_action_just_pressed("throw") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	input.look.x += Input.get_axis("cam_right", "cam_left") * KEY_TURN * delta
	input.look.y += Input.get_axis("cam_down", "cam_up") * KEY_TURN * delta


func _physics_process(delta: float) -> void:
	if not scripted:
		if controls_enabled:
			_read_live_input(delta)
		else:
			input = PlayerInput.new()
	# camera
	pivot.rotation.y += input.look.x
	pitch.rotation.x = clampf(pitch.rotation.x + input.look.y, deg_to_rad(-55), deg_to_rad(20))
	input.look = Vector2.ZERO
	# movement relative to camera yaw
	var basis_yaw := Basis(Vector3.UP, pivot.rotation.y)
	var wish := basis_yaw * Vector3(input.move.x, 0, -input.move.y)
	wish = wish.limit_length(1.0)
	var speed := SPRINT_SPEED if input.sprint and held == null else WALK_SPEED
	var target := wish * speed
	velocity.x = move_toward(velocity.x, target.x, ACCEL * delta)
	velocity.z = move_toward(velocity.z, target.z, ACCEL * delta)
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	# Hide the body when a wall pushes the camera into it (it would fill the screen).
	model.visible = arm.get_hit_length() > 1.3
	if wish.length() > 0.1:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(wish.x, wish.z), 12.0 * delta)
	# interaction
	focused = _find_focus()
	if input.interact and focused != null and focused.has_method("interact"):
		focused.interact(self)
	if input.grab:
		if held != null:
			release(false)
		elif focused is RigidBody3D:
			_grab(focused)
	if input.throw and held != null:
		release(true)
	_carry(delta)
	input.interact = false
	input.grab = false
	input.throw = false


## Closest usable thing under the crosshair within reach. The ray starts at
## the camera (so aiming feels right in third person) but the reach is
## measured from the player, and walls stop the ray (no using through walls).
func _find_focus() -> Node:
	var space := get_world_3d().direct_space_state
	var from := camera.global_position
	var dir := -camera.global_transform.basis.z
	var to := from + dir * (arm.get_hit_length() + INTERACT_RANGE + 0.5)
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 4 | 8)
	q.exclude = [get_rid()] + ([held.get_rid()] if held != null else [])
	var res := space.intersect_ray(q)
	if not res.is_empty():
		var col: Object = res["collider"]
		if col.has_method("prompt") and (res["position"] as Vector3).distance_to(global_position + Vector3.UP) <= INTERACT_RANGE:
			return col
	return _nearest_in_front()


## Fallback when the crosshair is not exactly on something: the closest
## usable object within reach in front of the character, with a clear line
## from the chest (so this can't reach through walls either).
func _nearest_in_front() -> Node:
	var fwd := Basis(Vector3.UP, pivot.rotation.y) * Vector3.FORWARD
	var chest := global_position + Vector3.UP * 1.0
	var best: Node3D = null
	var best_d := INTERACT_RANGE
	for id in game.entities:
		var n = game.entities[id]
		if not (n is Node3D) or not n.has_method("prompt") or not is_instance_valid(n) or n == held:
			continue
		var to: Vector3 = (n as Node3D).global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d > best_d or d < 0.01 or fwd.dot(to / d) < 0.6:
			continue
		var los := PhysicsRayQueryParameters3D.create(chest, (n as Node3D).global_position + Vector3.UP * 0.5, 1)
		los.exclude = [get_rid(), (n as CollisionObject3D).get_rid()]
		if not get_world_3d().direct_space_state.intersect_ray(los).is_empty():
			continue
		best = n
		best_d = d
	return best


func focus_prompt() -> String:
	if held != null:
		return "F — Drop   ·   Click — Throw"
	if focused != null:
		return focused.prompt(self)
	return ""


func _grab(body: RigidBody3D) -> void:
	held = body
	held.gravity_scale = 0.0
	held.angular_damp = 8.0


func release(throw: bool) -> void:
	if held == null:
		return
	held.gravity_scale = 1.0
	held.angular_damp = 0.0
	if throw:
		held.linear_velocity = (-camera.global_transform.basis.z + Vector3.UP * 0.25).normalized() * THROW_SPEED
	held = null


func _carry(_delta: float) -> void:
	if held == null:
		return
	var fwd := Basis(Vector3.UP, pivot.rotation.y) * Vector3.FORWARD
	var target := global_position + fwd * HOLD_DISTANCE + Vector3.UP * HOLD_HEIGHT
	var to_target := target - held.global_position
	if to_target.length() > 2.5:
		release(false) # snagged on something: let go instead of tunnelling it
		return
	held.linear_velocity = to_target * 14.0


func teleport(pos: Vector3, yaw := 0.0) -> void:
	release(false)
	global_position = pos
	velocity = Vector3.ZERO
	pivot.rotation.y = yaw
