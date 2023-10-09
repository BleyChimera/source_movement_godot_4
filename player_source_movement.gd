extends CharacterBody3D

#NOTE 1: Capture the mouse somewhere
#NOTE 2: If you want to recreate even more source-like movement use a box collision shape

@export_category("Movement")
@export var MAX_G_SPEED := 10.0
@export var MAX_G_ACCEL := 20.0 * MAX_G_SPEED
@export var MAX_AIR_SPEED := 0.5
@export var MAX_AIR_ACCEL := 100.0
@export var JUMP_FORCE := 4.5
@export var GRAVITY_FORCE := 15.0
@export var MAX_SLOPE := deg_to_rad(46.0)

@export_category("Settings")
## The local position of the raycast used to check for the floor.
@export var FLOOR_RAY_POS := Vector3.ZERO
## How far down the floor raycast will reach out for collisions.
@export var FLOOR_RAY_REACH := 0.2

@export_category("Nodes")
@export var cam_pivot : Node3D

var on_floor := false
var floor_check := {}

func _check_floor() -> bool:
	var origin = global_position + FLOOR_RAY_POS
	var target = Vector3.DOWN * FLOOR_RAY_REACH
	
	var query = PhysicsRayQueryParameters3D.create(origin, origin + target)
	
	var check = get_world_3d().direct_space_state.intersect_ray(query)
	
	var collided = check.size() > 0
	if collided: floor_check = check
	return collided

func get_slope_angle(normal): return normal.angle_to(up_direction)

# Physics process, where the source magic happens
func _physics_process(delta):
	# Decompose vector
	var vel_planar := Vector2(velocity.x,velocity.z)
	var vel_vertical := velocity.y
	
	# Detect if is on floor
	# In case of not being on it (angle to ground or just not touching it) set to false
	if on_floor:
		var collided = _check_floor()
		var slope_angle = get_slope_angle(floor_check.normal) 
		on_floor = collided and slope_angle < MAX_SLOPE
	
	# Get input vector of the player
	# and rotate it depending on the camera's rotation
	var wish_dir := Input.get_vector("player_l","player_r","player_f","player_b")
	wish_dir = wish_dir.rotated(-cam_pivot.rotation.y)
	
	
	if on_floor and Input.is_action_pressed("player_jump"): # Jump
		on_floor = false
		vel_vertical = JUMP_FORCE
	
	# Apply drag/friction
	if not on_floor: vel_vertical -= GRAVITY_FORCE * delta
	else: 
		vel_planar -= vel_planar.normalized() * delta * (MAX_G_ACCEL / 2.0)
		# Fully stop if there is no velocity
		if vel_planar.length_squared() < 1.0 and wish_dir.length_squared() < 0.01:
			vel_planar = Vector2.ZERO
	
	# Where the source magic happens.
	# This dot is the cause for all the movement tricks in source games
	# Good reference for this: https://www.youtube.com/watch?v=v3zT3Z5apaM
	var current_speed = vel_planar.dot(wish_dir)
	
	# Select the max speed and acceleration depending if its on floor or not
	var max_speed = MAX_G_SPEED if on_floor else MAX_AIR_SPEED
	var max_accel = MAX_G_ACCEL if on_floor else MAX_AIR_ACCEL
	
	# The magic source function
	var add_speed = clamp(max_speed - current_speed, 0.0, max_accel * delta)
	
	vel_planar += wish_dir * add_speed
	
	# We're done working with our decomposed velocity
	# Set the velocity so we can finally simulate our physics
	velocity = Vector3(vel_planar.x,vel_vertical,vel_planar.y)
	
	# We do our own sliding, so we use move_and_collide
	var collision = move_and_collide(velocity * delta)
	if collision:
		# Slide the remaining movement and move
		move_and_collide(collision.get_remainder().slide(collision.get_normal()))
		
		if not on_floor:
			velocity = velocity.slide(collision.get_normal())
			
			var slope_angle = get_slope_angle(collision.get_normal())
			if slope_angle < MAX_SLOPE:
				on_floor = true
				velocity.y = 0.0
	else:
		if on_floor:
			# Detect that in fact, the player is on the ground
			# and snap to ground accordingly
			if _check_floor():
				move_and_collide(floor_check.position - global_position)

# Custom input function (swap for what you need)
func _input(event):
	# Rotate the camera according to mouse input
	if event is InputEventMouseMotion:
		cam_pivot.rotation.y += -event.relative.x*0.001
		cam_pivot.rotation.x += -event.relative.y*0.001
		cam_pivot.rotation_degrees.x = clamp(cam_pivot.rotation_degrees.x, -89.0 , 89.0)
