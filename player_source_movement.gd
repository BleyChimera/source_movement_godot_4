extends CharacterBody3D

#NOTE 1: Capture the mouse somewhere
#NOTE 2: If you want to recreate even more source-like movement use a box collision shape

@export_category("Movement")
#Constants to make editing game feel easier
@export var MAX_G_SPEED : float = 7.0
@export var MAX_G_ACCELERATION : float = 20.0 * MAX_G_SPEED
@export var MAX_A_SPEED : float = 0.5
@export var MAX_A_ACCELERATION : float = 100.0
@export var JUMP_FORCE : float = 4.5
@export var GRAVITY_FORCE : float = 15.0
@export var MAX_SLOPE : float = deg_to_rad(46.0)

#Store horizontal and aerial velocity differently
var hvelocity : Vector2 = Vector2.ZERO
var vvelocity : float = 0.0

@export_category("Nodes")
#Raycast for the ground and a custom "is_on_floor variable"
@export var FLOOR_CAST : RayCast3D
var on_floor : bool = false

#Get the camera pivot (needed to not rotate the character)
@export var CAMERA_PIVOT : Node3D

#Physics process, where the magic source magic happens
func _physics_process(delta):
	#Detect if is on floor
	#In case of not being on it (angle to ground or just not touching it) set to false
	if on_floor:
		if FLOOR_CAST.is_colliding():
			if Vector3.UP.angle_to(FLOOR_CAST.get_collision_normal()) < MAX_SLOPE:
				on_floor = true
			else:
				on_floor = false
		else:
			on_floor = false
	
	#Get input vector of the player and rotate it depending on the camera's rotation
	var wish_dir : Vector2 = Input.get_vector("player_l","player_r","player_f","player_b")
	wish_dir = wish_dir.rotated(-CAMERA_PIVOT.rotation.y)
	
	#Jump
	if on_floor and Input.is_action_pressed("player_jump"):
		on_floor = false
		vvelocity = JUMP_FORCE
	
	#Basic gravity
	if !on_floor:
		vvelocity -= GRAVITY_FORCE * delta
	#Basic friction
	else:
		hvelocity -= hvelocity.normalized() * delta * (MAX_G_ACCELERATION / 2.0)
		#Fully stop if there is no input
		if hvelocity.length() < 1.0 and wish_dir.length_squared() < 0.01:
			hvelocity = Vector2.ZERO
	
	#Where the source magic happens.
	#This dot is the cause for all the movement tricks in source games
	#Good reference for this: https://www.youtube.com/watch?v=v3zT3Z5apaM
	var current_speed : float = hvelocity.dot(wish_dir)
	#Select the max speed and acceleration depending if its on floor or not
	var MAX_SPEED : float = MAX_G_SPEED if on_floor else MAX_A_SPEED
	var MAX_ACCELERATION : float = MAX_G_ACCELERATION if on_floor else MAX_A_ACCELERATION
	#The magic source function
	var add_speed : float = clamp(MAX_SPEED - current_speed, 0.0, MAX_ACCELERATION * delta)
	
	#Add the speed to the horizontal speed
	hvelocity += wish_dir * add_speed
	
	#Set the velocity to our horizontal and vertical speeds
	velocity.x = hvelocity.x; velocity.z = hvelocity.y
	velocity.y = vvelocity
	
	#Move and collide is better to handle every aspect of how the velocity is modified
	var collision : KinematicCollision3D = move_and_collide(velocity*delta)
	if collision:
		#Slide the remaining movement and move
		move_and_collide(collision.get_remainder().slide(collision.get_normal()))
		#Slide the speed against the collision if 
		if !on_floor:
			velocity = velocity.slide(collision.get_normal())
			#Detect if it has collided with the ground
			if collision.get_normal().angle_to(Vector3.UP) < MAX_SLOPE:
				on_floor = true
				velocity.y = 0.0
	else:
		#Snap to ground
		if on_floor:
			#Detect that in fact, the player is on the ground
			FLOOR_CAST.force_raycast_update()
			if FLOOR_CAST.is_colliding():
				move_and_collide(FLOOR_CAST.get_collision_point()-global_position)
	
	#Set the modified velocity onto the separate variables again
	hvelocity.x = velocity.x; hvelocity.y = velocity.z
	vvelocity = velocity.y

#Custom input function (swap for what you need)
func _input(event):
	#Rotate the camera according to mouse input
	if event is InputEventMouseMotion:
		CAMERA_PIVOT.rotation.y += -event.relative.x * 0.002
		CAMERA_PIVOT.rotation.x += -event.relative.y * 0.002
		CAMERA_PIVOT.rotation_degrees.x = clamp(CAMERA_PIVOT.global_rotation_degrees.x, -89.0 , 89.0)
