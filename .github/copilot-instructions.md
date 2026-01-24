# Copilot instructions for game-jam-26

## Project overview
- Godot 4.5 project (see [project.godot](project.godot)); the main entry scene is [src/ui/main_menu.tscn](src/ui/main_menu.tscn).
- The main menu controller lives in [src/ui/main_menu.gd](src/ui/main_menu.gd) and uses hard-coded button node paths under `CenterContainer/VBoxContainer`.
- The gameplay scene is [src/ui/gam/game.tscn](src/ui/gam/game.tscn). It instances the player and prey scenes and includes the TileMap and world boundary.
- Entities live under [src/entities](src/entities):
  - Player: [src/entities/player/player.tscn](src/entities/player/player.tscn) + [src/entities/player/player.gd](src/entities/player/player.gd)
  - Prey: [src/entities/prey/prey.tscn](src/entities/prey/prey.tscn) + [src/entities/prey/prey.gd](src/entities/prey/prey.gd)

## Key gameplay patterns
- `player.gd` drives both normal movement and projectile mode in `_physics_process()` and `move_and_collide()`; keep this flow intact if adding new movement states.
- Sticking logic depends on the prey being in the `prey` group and having a `CollisionShape2D` node named exactly `CollisionShape2D` (see `stick_to_prey()` in [src/entities/player/player.gd](src/entities/player/player.gd)).
- Trajectory dots are a pooled set of `Sprite2D` children under `TrajectoryDots` with a `DotTemplate` instance in the player scene. If you rename these nodes, update the `@onready` paths in `player.gd`.

## Scene/node conventions
- Scene files wire signals directly in the `.tscn` (e.g., menu button `pressed` signals in [src/ui/main_menu.tscn](src/ui/main_menu.tscn)). Keep method names in sync with these connections.
- `game.tscn` instantiates `player` and multiple `Prey` nodes. New enemies or pickups should be authored as their own `.tscn` and instanced similarly.

## Inputs and engine setup
- Player movement uses `Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")` (see [src/entities/player/player.gd](src/entities/player/player.gd)); ensure the Input Map defines these actions in project settings.
- The runtime main scene is configured in [project.godot](project.godot) (`run/main_scene`).

## UI/HUD
- HUD scene is [src/ui/gam/hud.tscn](src/ui/gam/hud.tscn); it references a script at `res://src/ui/hud.gd` which is currently missing. If you add HUD logic, create this script and attach it.

## Assets
- Art assets are under [assets](assets) and referenced directly in `.tscn` scenes. Prefer updating scenes in the Godot editor to avoid breaking resource UIDs.
