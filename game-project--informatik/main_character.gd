extends CharacterBody2D

# Movement
const SPEED = 450.0
const JUMP_VELOCITY = -500.0

# Double jump
var jump_count = 0
var max_jumps = 2
var double_jumping = false

# Dash
@export var dash_speed = 700.0
@export var dash_time = 0.3
@export var dash_cooldown = 0.5
var dash_direction = Vector2.ZERO
var dash_timer = 0.0
var dash_cooldown_timer = 0.0
var dashing = false

# Dodge roll
@export var roll_time = 0.4
@export var roll_cooldown = 1.0
var rolling = false
var roll_timer = 0.0
var roll_cooldown_timer = 0.0
var original_collision_scale: Vector2
@onready var collision_shape = $CollisionShape2D

# Wall slide & wall jump
@export var wall_slide_speed = 100.0
@export var wall_jump_velocity = Vector2(400, -450)
@export var wall_jump_cooldown = 0.3
var wall_jump_timer = 0.0
var touching_wall = false

# Regeneration
@export var regen_wait_time = 10.0
@export var regen_rate = 0.02
@export var max_hp = 100
var current_hp = 100
var regen_timer = 0.0

# Invincibility
@export var invincibility_time = 1.0
var invincible = false
var invincibility_timer = 0.0

# Damage
var time_since_damage = 0.0

@onready var sprite_2d = $Sprite2D

func _ready():
	current_hp = max_hp
	original_collision_scale = collision_shape.scale

func _physics_process(delta):
	touching_wall = is_on_wall() and not is_on_floor()

	if rolling:
		roll_timer -= delta
		if roll_timer <= 0:
			rolling = false
			invincible = false
			collision_shape.scale = original_collision_scale
	else:
		if Input.is_action_just_pressed("DodgeRoll") and roll_cooldown_timer <= 0:
			start_roll()

	if dashing:
		dash_timer -= delta
		velocity = dash_direction * dash_speed
		if dash_timer <= 0:
			dashing = false
	else:
		if Input.is_action_just_pressed("Dash") and dash_cooldown_timer <= 0:
			start_dash()

		var direction := Input.get_axis("left", "right")
		if direction:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0.0, 30.0)

		if not is_on_floor():
			if touching_wall and velocity.y > 0 and wall_jump_timer <= 0 and not rolling:
				velocity.y = wall_slide_speed
			else:
				velocity.y += ProjectSettings.get_setting("physics/2d/default_gravity") * delta

		if Input.is_action_just_pressed("Jump"):
			if is_on_floor():
				velocity.y = JUMP_VELOCITY
				jump_count = 1
				double_jumping = false
			elif touching_wall and wall_jump_timer <= 0:
				var wall_dir = get_wall_direction()
				velocity = Vector2(-wall_dir * wall_jump_velocity.x, wall_jump_velocity.y)
				wall_jump_timer = wall_jump_cooldown
				jump_count = 1
				double_jumping = false
				sprite_2d.flip_h = wall_dir < 0
			elif jump_count < max_jumps:
				velocity.y = JUMP_VELOCITY
				jump_count += 1
				double_jumping = true

		if is_on_floor():
			jump_count = 0
			double_jumping = false

	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta

	if roll_cooldown_timer > 0:
		roll_cooldown_timer -= delta

	if wall_jump_timer > 0:
		wall_jump_timer -= delta

	# Animation handling
	if not dashing and not rolling:
		if is_on_floor():
			if abs(velocity.x) > 1:
				play_animation("run")
			else:
				play_animation("default")
		elif touching_wall and velocity.y > 0 and wall_jump_timer <= 0:
			play_animation("wallslide")
			var wall_normal = get_wall_normal()
			sprite_2d.flip_h = wall_normal.x < 0
		elif double_jumping:
			play_animation("double jump")
		else:
			play_animation("jump")
		

	# Flip sprite (don't flip during roll)
	if not rolling:
		sprite_2d.flip_h = velocity.x < 0
	elif rolling:
		play_animation("slide")

	move_and_slide()

	time_since_damage += delta
	if time_since_damage >= regen_wait_time:
		regen_timer += delta
		if regen_timer >= 1.0:
			heal(int(max_hp * regen_rate))
			regen_timer = 0.0

	if invincible and not rolling:
		invincibility_timer -= delta
		if invincibility_timer <= 0:
			invincible = false

# Safe animation playing
func play_animation(anim_name: String):
	if sprite_2d.sprite_frames.has_animation(anim_name):
		sprite_2d.play(anim_name)
	else:
		sprite_2d.play("default")

# Sprite flipping
func get_movement_direction() -> Vector2:
	if Input.get_action_strength("right") > 0:
		return Vector2.RIGHT
	elif Input.get_action_strength("left") > 0:
		return Vector2.LEFT
	return Vector2.RIGHT

# Wall jumps
func get_wall_direction() -> int:
	return -1 if Input.is_action_pressed("right") else 1

# Dashing
func start_dash():
	dashing = true
	dash_timer = dash_time
	dash_cooldown_timer = dash_cooldown
	dash_direction = get_movement_direction()

# Dodge roll
func start_roll():
	rolling = true
	roll_timer = roll_time
	roll_cooldown_timer = roll_cooldown
	invincible = true
	collision_shape.scale = original_collision_scale * Vector2(1.0, 0.5)
	velocity.x = get_movement_direction().x * dash_speed

# Healing
func heal(amount: int):
	current_hp = min(current_hp + amount, max_hp)
	print("Player healed! HP:", current_hp)

# Dying
func die():
	print("Player died!")
	current_hp = max_hp

# Getting damaged
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
