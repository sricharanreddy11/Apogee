# Apogee

Milestones 0–1 for Member 3 (missions, map, and UI) of the 2D rocket-building game. Import `project.godot` in the standard Godot 4.7.2 editor and press **F5**. The project uses typed GDScript and the Compatibility renderer.

The integrated flow is **Mission-selecting main menu → M01 → Rocket Lab → Prepare Launch → Launchpad/preflight → Edit Rocket or Missions**. M01 is available initially; M02–M04 are visible and locked. Cards are generated from JSON. The launchpad shows your selected parts with the same artwork, mission briefing, calculated cost, mass, and fuel. Launch emits a single integration request while retaining the same preview scene and rocket; real flight is connected later.

**Start here:** [Milestone 1 beginner guide](docs/MILESTONE_1_GUIDE.md) explains how to build a rocket and where to change missions, prerequisites, budgets, cards, and preflight labels. [Shared interfaces](docs/INTERFACES.md) records field names, units, ownership, and integration APIs for team review.

Rocket Lab comes from `main` (`0bf817f`, "added rocket lab v1"). Open **Pods**, **Fuel**, or **Engines**, then drag a part onto the matching mount. Right-click an installed module to detach it, use **Clear rocket** to start over, or **Restore Sparrow I** to reset. Change the rocket name before **Prepare Launch**. **Edit Rocket** reloads your selected parts and name. This version supports one pod, one tank, and one engine in one stage.

Progress is held in memory; mission evaluation, rewards, and save files are later milestones. The **UI sandbox** button preserves M0's changing mock HUD and sample report, with pause/restart and 5× playback. It can also run directly with **F6** from `scenes/ui/ui_sandbox.tscn`. See the [M0 editing guide](docs/MILESTONE_0_GUIDE.md) for sample data changes.

## Team ownership

| Owner | Start here | First implementation |
| --- | --- | --- |
| Member 1 · Physics and integration | `scripts/physics/flight_simulator.gd`, `scripts/physics/flight_screen.gd`, `scenes/flight/` | Initialize mass and fuel, then implement fixed-step motion and wire the reserved flight controls. |
| Member 2 · Builder and visuals | `scripts/builder/builder_controller.gd`, `scenes/builder/`, `data/parts.json`, `assets/rockets/` | Extend Rocket Lab's mounts, parts catalog, and staging rules while retaining validated config handoffs. |
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

Also run:

```text
godot --headless --path . --script res://tests/test_mission_catalog.gd
godot --headless --path . --script res://tests/test_builder.gd
godot --headless --path . --script res://tests/test_menu_flow.gd
godot --headless --path . --script res://tests/test_rocket_lab_flow.gd
godot --headless --path . --script res://tests/test_mock_telemetry.gd
godot --headless --path . --script res://tests/test_m0_flow.gd
```

These check valid and malformed mission data, detached mock snapshots and playback, the M0 screen flow, retry resets, direct scene startup, and invalid sample recovery. The original smoke check still covers the builder/flight preview, reference budget, launch telemetry, and reserved map input. The beginner guide includes the full PowerShell command for the Godot executable on this computer.

Implemented locally on `codex/m1-launchpad-ui`, carrying forward M0. Team agreement on shared interfaces, pushing the branch, and opening a PR remain team handoff steps; no remote changes were made.
