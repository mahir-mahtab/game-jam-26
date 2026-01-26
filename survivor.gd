extends CharacterBody2D

# --- CONFIGURATION ---
@export var wander_speed: float = 60.0
@export var run_speed: float = 160.0 # Runs faster than walking
@export var sight_range: float = 400.0 # How far away it spots you

# --- STATE ---
enum { PATROL, FLEE }
var current_state = PATROL
var wander_dir = Vector2.RIGHT

# Shared Variables (For Player Mechanics)
var being_pulled := false
var is_zombified := false

# --- REFERENCES ---
@onready var sprite = $AnimatedSprite2D
@onready var patrol_timer = $PatrolTimer

var player_ref: Node2D = null

func _ready() -> void:
	# 1. Be Edible
	add_to_group("prey")
	
	# 2. Top-Down Physics (No Gravity)
	motion_mode = MOTION_MODE_FLOATING
	
	# 3. Find Player
	player_ref = get_tree().get_first_node_in_group("player")
	
	# 4. Setup Timer
	patrol_timer.timeout.connect(_on_patrol_timer)
	
	# 5. Start Moving
	_pick_random_wander()

func _physics_process(_delta: float) -> void:
	# 1. STOP if captured or pulled (Zombie Logic)
	if is_zombified or being_pulled:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# 2. AI LOGIC
	match current_state:
		PATROL:
			_process_patrol()
			_check_vision() # Look for player
		FLEE:
			_process_flee()

	move_and_slide()

# --- BEHAVIORS ---

func _process_patrol() -> void:
	velocity = wander_dir * wander_speed
	
	# Turn around at walls
	if is_on_wall():
		# Bounce logic to find a new open direction
		wander_dir = velocity.bounce(get_wall_normal()).normalized()
		wander_dir = wander_dir.rotated(randf_range(-0.5, 0.5))
	
	_update_facing()

func _process_flee() -> void:
	if not player_ref:
		current_state = PATROL
		return
		
	var to_player = player_ref.global_position - global_position
	var dist = to_player.length()
	
	# RUN AWAY! (Velocity is opposite to player)
	velocity = -to_player.normalized() * run_speed
	
	# Give up if far enough away (1.5x sight range)
	if dist > sight_range * 1.5:
		current_state = PATROL
		_pick_random_wander()
	
	_update_facing()

func _check_vision() -> void:
	if not player_ref: return
	
	var dist = global_position.distance_to(player_ref.global_position)
	if dist < sight_range:
		# Check Line of Sight (Don't run if behind a wall)
		var space = get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.create(global_position, player_ref.global_position)
		query.exclude = [get_rid()] # Ignore self
		var result = space.intersect_ray(query)
		
		if result and result.collider == player_ref:
			current_state = FLEE

# --- HELPERS ---

func _update_facing() -> void:
	if velocity.x != 0:
		sprite.flip_h = (velocity.x < 0)

func _pick_random_wander() -> void:
	# Pick a random direction (0 to 360 degrees)
	wander_dir = Vector2.RIGHT.rotated(randf() * TAU)
	patrol_timer.start(randf_range(1.0, 3.0))

func _on_patrol_timer() -> void:
	if current_state == PATROL:
		_pick_random_wander()

# --- PLAYER INTERACTION INTERFACE ---
func set_pulled_state(pulled: bool) -> void: being_pulled = pulled
func set_zombified(state: bool) -> void: 
	is_zombified = state
	if is_zombified: modulate = Color(0.5, 1.0, 0.5)
