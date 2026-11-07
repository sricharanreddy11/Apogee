# Apogee

Phase 1 starter for the 2D rocket-building game. Import `project.godot` in the standard Godot 4.6 or newer editor and press **F5**. The project uses typed GDScript and the Compatibility renderer.

The preview follows **Main menu → M01 First Flight → Builder → Flight → Report → Retry or Main menu**. The builder opens with Sparrow I, the reference craft. Choose **Build a rocket** on the title screen to go straight to the assembly bay. Open Pods, Fuel, or Engines to reveal that category's parts on the arc. Drag a part near its mount to preview the attachment in green. The wrong mount turns red while you hover. Right-click an installed module to detach it. Use **Restore Sparrow I** to reset the stack. The flight scene shows the launch position and a map preview. Its report shows an attempt in progress. Implement flight, advanced construction, and mission evaluation in the entry points below.

## Team ownership

| Owner | Start here | First implementation |
| --- | --- | --- |
| Member 1 · Physics and integration | `scripts/physics/flight_simulator.gd`, `scripts/physics/flight_screen.gd`, `scenes/flight/` | Initialize mass and fuel, then implement fixed-step motion and wire the reserved flight controls. |
| Member 2 · Builder and visuals | `scripts/builder/builder_controller.gd`, `scenes/builder/`, `data/parts.json`, `assets/rockets/` | Extend the one-stage builder with stack rules, engineering estimates, and part sprites. |
| Member 3 · Missions, map and UI | `scripts/missions/mission_manager.gd`, `scripts/ui/`, `scenes/missions/`, `scenes/ui/`, `data/missions/` | Evaluate M01 from telemetry, add a live report transition, and develop the HUD and map. |

Member 1 is the proposed integrator for `scripts/core/`, `project.godot`, and shared scene changes. Confirm the contract with all three teammates before changing it. Suggested branches are `feature/physics`, `feature/builder`, and `feature/missions-ui`. Keep the root folder together when putting the project on GitHub.

## Module handoffs

| Contract | Ownership and use |
| --- | --- |
| `RocketConfig` and `StageConfig` | Builder exports a design with stable part IDs. The first stage to fire is at index 0. The simulator owns a deep copy. Compute costs and masses from the catalog. |
| `FlightState` | The simulator alone changes the live state. The flight scene owns one simulator per attempt. |
| `FlightTelemetry` | `get_telemetry()` creates a detached snapshot. The HUD, map, and mission checker treat it as read-only. HUD and map can also accept a fabricated snapshot while being developed. |
| `MissionDefinition` | The mission loader reads JSON into a typed definition. Builder validation consumes its budget and part restrictions. Flight initialization consumes its scenario. |
| `MissionResult` | The mission manager owns the result while evaluating telemetry. The report reads the outcome and measured stats. |

Use SI units for simulation. Positive X points right and positive Y points down. Heading zero is up, with clockwise positive. The UI converts altitude to kilometers for display. At launch M01 starts at the north surface of scaled Earth, centered on the origin. A future trajectory predictor can consume `get_state_snapshot()` and send results to `OrbitMap.set_prediction()`. The project reserves the design's keyboard actions in Godot's Input Map. The preview map can be toggled with its button.

## Smoke check

From this project folder, with the Godot executable available as `godot`:

```text
godot --headless --editor --path . --import
godot --headless --path . --script res://tests/smoke_test.gd
```

The check drives the preview from the main menu to the report, retries the builder, and checks the reference budget, valid and invalid drops, the small-tank swap at launch, launch telemetry, and the reserved map input.
