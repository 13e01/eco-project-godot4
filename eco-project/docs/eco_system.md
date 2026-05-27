# Eco Cleanup System

## System Design

The eco layer makes past actions rewrite future traversal. A level designer places an `EcoObject` in the past and one or more `EcoFutureEffect` nodes in the future, then gives them the same `eco_id`.

When the player cleans the past object, `EcoManager` marks `eco_object_states[eco_id] = true`, awards eco points, recalculates restoration percent, emits UI/audio signals, and tells future effects to refresh. The future can remove trash collision, swap a dirty object for a clean platform, reveal plants, open routes, or disable hazards.

## Architecture

- `res://systems/eco/eco_manager.gd`: autoload state hub, save-ready dictionary, score, restoration percent, signals.
- `res://systems/eco/eco_object.gd`: reusable past cleanup Area2D.
- `res://systems/eco/eco_future_effect.gd`: reusable future consequence node.
- `res://scenes/eco_objects/eco_object.tscn`: simple designer prefab for trash/pollution pickups.
- `res://scenes/eco_objects/eco_future_effect.tscn`: simple designer prefab for future swaps/collision changes.
- `res://scenes/eco_objects/eco_cleanup_pair_example.tscn`: minimal example with a past object linked to a future consequence by `eco_id`.

Existing patterns reused:

- `time_objects` group and `change_time_state(is_future)` for era visibility.
- `level_base.gd` remains the world-switch coordinator.
- `ui.gd` receives manager signals instead of polling.
- `AudioManager.play_event()` remains the hook for feedback sounds.

## Save Shape

`EcoManager.get_save_data()` returns:

```gdscript
{
	"level_id": "res://scenes/maps/level_1/level1.tscn",
	"eco_points": 40,
	"eco_object_states": {
		"trash_01": true,
		"barrel_02": false
	}
}
```

## Level Design Examples

- Clean a trash pile in the past, then the future landfill mound disappears and exposes a shortcut.
- Remove toxic barrels in the past, then future gas collision disables and a safe tunnel opens.
- Recycle a broken machine in the past, then the future version becomes a moving power platform.
- Clear an oil puddle in the past, then plants grow in the future and create stepping stones.
- Optional cleanup chains can gate secrets by requiring several `EcoObject` IDs to restore a corridor.

## Playable Scene Setup

Both `TutorialLevel.tscn` and `level1.tscn` now include five manual cleanup objects near the player start. Press `F` while the prompt is visible.

Tutorial IDs:

- `tutorial_trash_shortcut`: future shortcut block disappears.
- `tutorial_toxic_barrel`: future toxic floor collision disappears.
- `tutorial_oil_platform`: future plant platform appears.
- `tutorial_scrap_gate`: future scrap gate disappears.
- `tutorial_landfill_clutter`: future landfill clutter disappears.

Level 1 IDs:

- `level1_trash_shortcut`: future shortcut block disappears.
- `level1_toxic_barrel`: future toxic floor collision disappears.
- `level1_oil_platform`: future plant platform appears.
- `level1_scrap_gate`: future scrap gate disappears.
- `level1_machine_waste`: future machine clutter disappears.

## Refactor Notes

- Add a dedicated interaction action later if manual cleanup becomes common.
- Promote hardcoded player collision logic into interaction components.
- Move level state ownership into a save service when persistence is added.
- Consider a future `EcoRegion` node that reacts to several IDs for multi-step puzzle chains.
