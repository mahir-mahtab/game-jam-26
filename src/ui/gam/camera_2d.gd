extends Camera2D

# How quickly the shaking stops [0, 1].
@export var decay := 0.8 

# Maximum offset in pixels.
@export var max_offset := Vector2(100, 75) 

# Maximum rotation in radians (use small values!).
@export var max_roll := 0.1 

# The node to follow (assign your Player here).
@export var target: Node2D 

var trauma := 0.0  # Current shake strength [0, 1]
var trauma_power := 2  # Trauma exponent. Use 2 or 3 for a quadratic feel.
var noise_y = 0

# Configure FastNoiseLite for organic randomness
@onready var noise = FastNoiseLite.new()

func _ready() -> void:
	randomize()
	noise.seed = randi()
	noise.frequency = 0.5 # Higher = faster jitter
	noise.fractal_octaves = 2

func _process(delta: float) -> void:
	# 1. Smoothly follow the target (optional, removes need for separate Camera script)
	if target:
		global_position = target.global_position
	
	# 2. Decay trauma over time
	if trauma > 0:
		trauma = max(trauma - decay * delta, 0)
		_shake()
	else:
		# Reset offset/rotation when not shaking to ensure perfect center
		offset = Vector2.ZERO
		rotation = 0

func _shake() -> void:
	var amount = pow(trauma, trauma_power)
	
	# Increment noise "time" (y-axis) to scroll through noise texture
	noise_y += 1.0
	
	# Get rotation from noise
	rotation = max_roll * amount * noise.get_noise_2d(noise.seed, noise_y)
	
	# Get X and Y offsets from noise (using different seeds/coordinates)
	offset.x = max_offset.x * amount * noise.get_noise_2d(noise.seed * 2, noise_y)
	offset.y = max_offset.y * amount * noise.get_noise_2d(noise.seed * 3, noise_y)

func add_trauma(amount: float) -> void:
	trauma = min(trauma + amount, 1.0)
