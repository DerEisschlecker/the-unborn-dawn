# Purpose: Orbit camera for the 3D base fortress (zoom + right-drag rotate).
# Public API: apply_input(), focus_on(), get_camera().
class_name BaseCameraRig
extends Node3D

var camera: Camera3D
var focus_target := Vector3(0, -2, -4)
var orbit_distance := 28.0
var orbit_yaw := -50.0
var orbit_pitch := -18.0
var min_distance := 14.0
var max_distance := 42.0
var rotating := false


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "MainCamera"
	camera.fov = 52.0
	camera.current = true
	add_child(camera)
	_update_camera()


func get_camera() -> Camera3D:
	return camera


func focus_on(target: Vector3) -> void:
	focus_target = target
	_update_camera()


func apply_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			rotating = event.pressed
			return true
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			orbit_distance = maxf(min_distance, orbit_distance - 1.4)
			_update_camera()
			return true
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			orbit_distance = minf(max_distance, orbit_distance + 1.4)
			_update_camera()
			return true
	if event is InputEventMouseMotion and rotating:
		orbit_yaw -= event.relative.x * 0.28
		orbit_pitch = clampf(orbit_pitch - event.relative.y * 0.22, -58.0, -8.0)
		_update_camera()
		return true
	return false


func _update_camera() -> void:
	if camera == null:
		return
	var yaw_rad := deg_to_rad(orbit_yaw)
	var pitch_rad := deg_to_rad(orbit_pitch)
	var offset := Vector3(
		cos(yaw_rad) * cos(pitch_rad),
		sin(pitch_rad),
		sin(yaw_rad) * cos(pitch_rad)
	) * orbit_distance
	camera.global_position = focus_target + offset
	camera.look_at(focus_target, Vector3.UP)
