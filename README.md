# Apogee

Apogee is a 2D rocket-building and flight game. Import `project.godot` in the standard Godot 4.7.2 editor and press **F5**. The project uses typed GDScript and the Compatibility renderer.

The integrated flow is **Campaign star chart → Mission briefing → Rocket Lab → Preflight → Active flight → Mission report**. M01 is available initially; M02–M04 are visible and locked. Mission beacons are generated from JSON. Select an active beacon to open its briefing, and use **Replay track** to watch the mission projection again. The briefing shows the objective, route, build budget, and reward before you assemble the rocket. The launchpad shows your selected parts, calculated cost, mass, and fuel. Launch emits the integration signal once and then opens the authoritative flight simulation with the exact configured rocket.

Active flight has two interchangeable views. **Normal view** uses a Godot camera with a shared scale for the rocket and the local planetary surface. When the rocket shrinks to a marker, a fixed vehicle camera on the right shows the live stack and offers staging and landing-leg controls. On lunar descent the main camera zooms in to show ground clearance and landing guidance. Click the visible active engine to ignite or cut off, or the separator to stage. **Orbit view** is a clean pannable Earth/Moon schematic with a constant-size triangular rocket marker, the Moon's faint orbit, the flown trail, and a complete ballistic projection. Earth and the moving Moon both pull on the rocket, including during projection, so a close lunar approach curves naturally. Velocity-Verlet integration preserves elliptical-orbit energy well enough for gameplay, so the rocket travels fastest at periapsis and slowest at apoapsis. Drag to pan, use the wheel to zoom, and right-click to recenter. Keyboard controls are W/S throttle, A/D steering, X cutoff, Space stage, L landing legs, Tab view toggle, Esc to pause, and 1/5/3/4 for 1×/5×/25×/50× fast-forward. Ignition and steering cancel fast-forward. The detailed Member 1 checklist is in [Member 1 flight tasks](docs/MEMBER_1_FLIGHT_TASKS.md).

Use **Moon flyby demo** on the main menu for an automatic 25x showcase. It opens directly in an auto-framed orbit view with a safe close approach and the projected lunar-gravity bend already visible; manual pan or zoom releases the automatic framing.

**Start here:** [Milestone 1 beginner guide](docs/MILESTONE_1_GUIDE.md) explains how to build a rocket and where to change missions, prerequisites, budgets, cards, and preflight labels. [Shared interfaces](docs/INTERFACES.md) records field names, units, ownership, and integration APIs for team review.

Open **Workshop** from the star chart to build with the full parts catalog. Choose **Pioneer II** for a two-stage reference rocket, then **Test fire** to see ignition and separation. In the mission flow, **Back to briefing** keeps your draft and **Edit Rocket** reloads the confirmed build. Mission builds retain their own parts rules and budgets. M02 introduces upper stages and the separator, M03 requires the science payload, and M04 requires landing legs.

Campaign completion, one-time rewards, best scores and discoveries are saved locally. The **UI sandbox** button preserves M0's changing mock HUD and sample report, with pause/restart and 5× playback. It can also run directly with **F6** from `scenes/ui/ui_sandbox.tscn`. See the [M0 editing guide](docs/MILESTONE_0_GUIDE.md) for sample data changes.

The shared interface theme lives in `assets/ui/apogee_theme.tres`. Edit its type variations in Godot to update headings, controls, or readouts across scenes. Oxanium and IBM Plex Mono are bundled with their licenses under `assets/ui/fonts/`.

## Campaign flight

On the star chart, select **First Flight → Build rocket → Prepare Launch → Launch**. Ignite and climb past 100 km with the pod intact. The result opens automatically and offers **Retry build** or the next unlocked mission. **End** reports an unfinished attempt as a failure. **Tab** opens Orbit view, where AP and PE show the active orbit and the gold track shows an unpowered projection. An impact marker, projected Moon position, and closest-approach label appear when relevant.

**Lunar Encounter** starts on a verified survey approach. Fit the science payload, then coast through the 15–30 km band and back out. **One Small Step** requires legs and a safe Moon touchdown. Landing near the chart's illustrative site unlocks the fictional Apollo 11 tribute. Revisit discoveries through **Archive**.

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

Use SI units for simulation. Positive X points right and positive Y points down. Heading zero is up, with clockwise positive. The UI converts altitude to kilometers for display. At launch M01 starts at the north surface of scaled Earth, centered on the origin. The flight screen computes coast predictions from copied snapshots on a worker thread. The project reserves the design's keyboard actions in Godot's Input Map. The preview map can be toggled with its button.

## Smoke check

From this project folder, with the Godot executable available as `godot`:

```text
godot --headless --editor --path . --import
godot --headless --path . --script res://tests/smoke_test.gd
```

Also run:

```text
godot --headless --path . --script res://tests/test_mission_catalog.gd
godot --headless --path . --script res://tests/test_campaign_missions.gd
godot --headless --path . --script res://tests/test_builder.gd
godot --headless --path . --script res://tests/test_menu_flow.gd
godot --headless --path . --script res://tests/test_rocket_lab_flow.gd
godot --headless --path . --script res://tests/test_mock_telemetry.gd
godot --headless --path . --script res://tests/test_m0_flow.gd
godot --headless --path . --script res://tests/test_flight_simulator.gd
```

These check valid and malformed mission data, detached mock snapshots and playback, the M0 screen flow, retry resets, direct scene startup, and invalid sample recovery. The original smoke check still covers the builder/flight preview, reference budget, launch telemetry, and reserved map input. The beginner guide includes the full PowerShell command for the Godot executable on this computer.

Implemented locally on `codex/m1-launchpad-ui`, carrying forward M0. Team agreement on shared interfaces, pushing the branch, and opening a PR remain team handoff steps; no remote changes were made.
