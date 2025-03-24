extends CharacterBody2D

@export var speed: float = 200.0
@export var jump_force: float = -400.0
@export var gravity: float = 900.0
@export var dash_speed: float = 700.0
@export var dash_time: float = 0.3
@export var dash_cooldown: float = 0.5
@export var dodge_roll_time: float = 0.3
@export var dodge_roll_speed: float = 600.0
@export var dodge_roll_cooldown: float = 5.0
@export var hitbox_scale_during_dodge: float = 0.5
@export var wall_slide_speed: float = 50.0
@export var wall_slide_duration: float = 3.0
@export var wall_jump_force: Vector2 = Vector2(500, -600)
@export var wall_jump_push: float = 2000.0  # Small outward push when jumping off walls
@export var wall_jump_restriction_time: float = 0.5  # Time after a wall jump when the player can't jump back to the wall

@export var max_hp: int = 100  # Declare max_hp
@export var regen_wait_time: float = 10.0  # Declare regen_wait_time
@export var regen_rate: float = 0.02  # Declare regen_rate
@export var invincibility_time: float = 1.0  # Declare invincibility_time

var current_hp: int
var invincible: bool = false
var invincibility_timer: float = 0.0
var time_since_damage: float = 0.0
var regen_timer: float = 0.0

var dashing: bool = false
var dodge_rolling: bool = false
var wall_sliding: bool = false
var wall_slide_timer: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dodge_roll_timer: float = 0.0
var dodge_roll_cooldown_timer: float = 0.0
var air_jump_allowed: bool = true
var original_hitbox_scale: Vector2 = Vector2.ZERO
var wall_jump_restriction_timer: float = 0.0  # Timer for the wall jump restriction

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready():
	original_hitbox_scale = collision_shape.scale
	current_hp = max_hp

func _process(delta):
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
	if dodge_roll_cooldown_timer > 0:
		dodge_roll_cooldown_timer -= delta
	if invincible:
		invincibility_timer -= delta
		if invincibility_timer <= 0:
			invincible = false

	# Passive healing logic
	time_since_damage += delta
	if time_since_damage >= regen_wait_time:
		regen_timer += delta
		if regen_timer >= 1.0:
			heal(int(max_hp * regen_rate))
			regen_timer = 0.0

	# Handle wall jump restriction timer
	if wall_jump_restriction_timer > 0:
		wall_jump_restriction_timer -= delta

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += gravity * delta

	handle_wall_mechanics(delta)

	if dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			dashing = false
		velocity = dash_direction * dash_speed
	elif dodge_rolling:
		dodge_roll_timer -= delta
		if dodge_roll_timer <= 0:
			dodge_rolling = false
			invincible = false
			reset_hitbox()
		velocity = dash_direction * dodge_roll_speed
	else:
		var direction = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		velocity.x = direction * speed

		if Input.is_action_just_pressed("jump"):
			if is_on_floor():
				velocity.y = jump_force
				air_jump_allowed = true
			elif wall_sliding and wall_jump_restriction_timer <= 0:
				wall_jump()
			elif air_jump_allowed:
				velocity.y = jump_force
				air_jump_allowed = false

		if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0:
			start_dash()

		if Input.is_action_just_pressed("dodge") and not dodge_rolling and dodge_roll_cooldown_timer <= 0 and is_on_floor():
			start_dodge_roll()

	move_and_slide()

func start_dash():
	dashing = true
	dash_timer = dash_time
	dash_cooldown_timer = dash_cooldown
	dash_direction = get_movement_direction()

func get_movement_direction() -> Vector2:
	if Input.get_action_strength("move_right") > 0:
		return Vector2.RIGHT
	elif Input.get_action_strength("move_left") > 0:
		return Vector2.LEFT
	return Vector2.RIGHT

func start_dodge_roll():
	dodge_rolling = true
	dodge_roll_timer = dodge_roll_time
	dodge_roll_cooldown_timer = dodge_roll_cooldown
	dash_direction = get_movement_direction()
	scale_hitbox_during_dodge()
	invincible = true

func scale_hitbox_during_dodge():
	collision_shape.scale = original_hitbox_scale * hitbox_scale_during_dodge

func reset_hitbox():
	collision_shape.scale = original_hitbox_scale

func handle_wall_mechanics(_delta):
	# Trigger wall slide immediately when in the air and touching a wall
	if is_on_wall() and not is_on_floor():
		if Input.get_action_strength("move_left") > 0 or Input.get_action_strength("move_right") > 0:
			# Activate wall slide as soon as we touch the wall
			wall_sliding = true
			velocity.y = wall_slide_speed
		else:
			# Wall slide continues until the player jumps or stops touching the wall
			wall_sliding = true
			velocity.y = wall_slide_speed
	elif wall_sliding:
		# Stop sliding if not touching the wall
		wall_sliding = false

func wall_jump():
	# Only perform wall jump if we're not restricted from wall jumping
	if wall_jump_restriction_timer <= 0:
		var jump_direction = Vector2.RIGHT if get_last_wall_direction() == Vector2.LEFT else Vector2.LEFT
		
		# Apply modified wall jump force with a slight push
		velocity = jump_direction * wall_jump_push + Vector2(0, wall_jump_force.y)
		
		# Start the restriction time after the wall jump
		wall_jump_restriction_timer = wall_jump_restriction_time
		
		# Stop wall sliding after a wall jump
		wall_sliding = false

func get_last_wall_direction() -> Vector2:
	if Input.get_action_strength("move_left") > 0:
		return Vector2.LEFT
	elif Input.get_action_strength("move_right") > 0:
		return Vector2.RIGHT
	return Vector2.ZERO

# HP Functions
func take_damage(amount: int):
	if invincible:
		return

	current_hp -= amount
	if current_hp <= 0:
		die()
	else:
		invincible = true
		invincibility_timer = invincibility_time
		time_since_damage = 0.0
		regen_timer = 0.0
		print("Player took damage! HP:", current_hp)

func heal(amount: int):
	current_hp = min(current_hp + amount, max_hp)
	print("Player healed! HP:", current_hp)

func die():
	print("Player died!")
	# Here, you can reset the player's position, trigger a respawn, or load a game over screen.
	# Example: reset HP
	current_hp = max_hp
