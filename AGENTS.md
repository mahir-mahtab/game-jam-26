# Agent Development Guide for game-jam-26

This document provides essential information for AI coding agents working on this Godot 4.5 game project.

## Project Overview

- **Engine**: Godot 4.5
- **Language**: GDScript
- **Platform**: Mobile rendering method
- **Entry Scene**: `res://src/ui/main_menu.tscn`
- **Main Game Scene**: `res://src/ui/gam/game.tscn`
- **License**: MIT (Copyright 2026 Mahir)

## Build, Run, and Test Commands

### Running the Game
- **Run Project**: Open in Godot Editor and press F5 or use Godot CLI:
  ```bash
  godot --path . --verbose
  ```
- **Run Main Scene**: F6 in editor or CLI with scene path
- **Quick Edit Scene**: F7 to run current scene in editor

### Testing
- **No automated testing is currently configured**
- Testing is done manually by running scenes in the Godot Editor
- To add testing in the future, consider:
  - GUT (Godot Unit Test) framework
  - Test files in `test/` directory with pattern `test_*.gd`

### Linting and Validation
- **No linter currently configured**
- Godot Editor provides built-in syntax checking
- Use `GDScript Toolkit` for linting if needed:
  ```bash
  gdlint src/
  ```

### Export/Build
- Configured via Project > Export in Godot Editor
- No export presets currently configured
- Build artifacts should not be committed (excluded by .gitignore)

## Code Structure

```
src/
├── entities/          # Game entity scenes and scripts
│   ├── player/       # Player character (player.tscn, player.gd)
│   └── prey/         # Prey entities (prey.tscn, prey.gd)
├── events/           # Game events (currently empty)
└── ui/               # User interface
	├── gam/          # Game scenes (game.tscn, hud.tscn)
	└── main_menu.*   # Menu controller

assets/               # Art and resource files
├── Buildings/        # Faction buildings
├── Particle FX/      # Visual effects
├── Terrain/          # Tiles and decorations
├── UI Elements/      # UI assets
└── Units/            # Character sprites
```

## Code Style Guidelines

### File Organization
- **One class per file**: Each `.gd` file should contain one primary class
- **Matching names**: Script names should match their attached scene (e.g., `player.gd` for `player.tscn`)
- **Scene-first approach**: Prefer creating `.tscn` scenes and attaching scripts rather than code-only nodes

### Naming Conventions
- **Files**: `snake_case.gd` and `snake_case.tscn`
- **Classes**: PascalCase (implicit from filename in GDScript)
- **Functions**: `snake_case()` with verb prefixes (e.g., `launch_projectile()`, `update_trajectory()`)
- **Variables**: `snake_case` for local and member variables
- **Constants**: `UPPER_SNAKE_CASE` (e.g., `PROJECTILE_SPEED = 1000.0`)
- **Private/internal**: Prefix with `_` (e.g., `_internal_helper()`)
- **Node references**: Descriptive names matching purpose (e.g., `animated_sprite`, `dots_container`)

### Type Annotations
- **Always use type hints** for function parameters and return values:
  ```gdscript
  func _ready() -> void:
  func launch_projectile() -> void:
  func _physics_process(_delta: float) -> void:
  ```
- **Typed variables** where possible:
  ```gdscript
  var dots: Array[Sprite2D] = []
  var projectile_active := false  # Type inferred from value
  var stuck_offset := Vector2.ZERO
  ```	 
- **@onready declarations** with type hints:
  ```gdscript
  @onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
  @onready var dots_container: Node2D = $TrajectoryDots
  ```

### Code Formatting
- **Indentation**: Use tabs (as per .editorconfig)
- **Encoding**: UTF-8 (as per .editorconfig)
- **Spacing**: One space around operators, after commas
- **Line length**: Keep under 100 characters when practical
- **Blank lines**: One blank line between functions, two between sections

### Comments and Documentation
- **Doc comments**: Use `##` for class/function documentation
  ```gdscript
  ## Main Menu UI controller
  ## Handles navigation between menu options and scene transitions
  ```
- **Inline comments**: Explain non-obvious logic, not what the code does
- **TODOs**: Mark incomplete features with `# TODO:` prefix
- **Section headers**: Use for complex files:
  ```gdscript
  # ===== Initialization =====
  # ===== Physics Processing =====
  ```

### Imports and Dependencies
- **No explicit imports**: GDScript uses autoload and node paths
- **Autoload/Singletons**: Configure in Project Settings > Autoload
- **Scene references**: Use string paths with `preload()` or `load()`:
  ```gdscript
  const GAME_SCENE_PATH = "res://src/ui/gam/game.tscn"
  ```
- **Node references**: Use `@onready` for child nodes, `get_node()` for dynamic access

### Error Handling
- **Null checks**: Always verify node existence before use:
  ```gdscript
  var prey_shape = prey_node.get_node_or_null("CollisionShape2D")
  if prey_shape:
	  prey_shape.set_deferred("disabled", true)
  else:
	  print("Warning: No CollisionShape2D found on prey!")
  ```
- **Resource validation**:
  ```gdscript
  if ResourceLoader.exists(GAME_SCENE_PATH):
	  get_tree().change_scene_to_file(GAME_SCENE_PATH)
  else:
	  print("Game scene not found at: ", GAME_SCENE_PATH)
  ```
- **Deferred operations**: Use `set_deferred()` for physics/collision changes
- **Print statements**: Use for warnings and debugging, not production logging

### Godot-Specific Patterns

#### Scene and Node Structure
- **Signals**: Wire in `.tscn` files when possible; keep method names in sync
- **Groups**: Use `add_to_group()` for categorization (e.g., "prey", "enemies")
- **Node paths**: Reference nodes using `$NodeName` or `get_node("NodeName")`
- **Template nodes**: Keep invisible templates for pooling (see `DotTemplate` pattern)

#### Physics and Movement
- **CharacterBody2D**: Use for player/NPC movement with `move_and_slide()`
- **Collision detection**: Use `move_and_collide()` when you need collision info
- **Input handling**:
  ```gdscript
  var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
  ```
- **Ensure input actions exist** in Project > Project Settings > Input Map

#### Performance
- **Object pooling**: Reuse nodes (see trajectory dots implementation)
- **_process vs _physics_process**: Use `_physics_process` for movement/physics
- **Deferred calls**: Use for scene changes and physics modifications

#### Constants and Magic Numbers
- Define constants at top of file:
  ```gdscript
  const SPEED = 300.0
  const DOT_SPACING = 18.0
  const MAX_LENGTH = 1000.0
  ```

## Key Gameplay Mechanics

### Player Movement and Projectile System
- Player has two states: **normal movement** and **projectile mode**
- **Normal mode**: 8-direction movement using arrow keys/WASD
- **Projectile mode**: Mouse click launches player toward cursor
- **Trajectory system**: Visual dots show launch path using raycasting
- **Sticking logic**: Player sticks to "prey" group entities on collision
- **Collision**: Must have `CollisionShape2D` node named exactly "CollisionShape2D"

### Scene Hierarchy
- `game.tscn` instantiates player and prey instances
- New entities should be separate `.tscn` files instanced in world scene
- HUD references `res://src/ui/hud.gd` (currently missing - create if needed)

## Important Notes for Agents

1. **Never modify `project.godot` directly** - use Godot Editor for project settings
2. **Scene files (`.tscn`)**: Prefer editing in Godot Editor to avoid breaking resource UIDs
3. **Signal connections**: Defined in `.tscn` files; keep script method names synced
4. **Asset references**: Use full `res://` paths; assets in `assets/` directory
5. **Platform considerations**: Hide quit button on web builds (see `main_menu.gd:20-21`)
6. **Commit hygiene**: Never commit `.godot/` folder or `/android/` (in .gitignore)

## Reference: Existing Copilot Instructions

For more context, see `.github/copilot-instructions.md` which includes:
- Detailed scene hierarchy documentation
- Key gameplay pattern explanations
- Signal wiring conventions
- Input configuration notes
- Asset management guidelines
