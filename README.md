# Apogee

Apogee is a 2D rocket-building and flight game. Import `project.godot` in the standard Godot 4.7.2 editor and press **F5**. The project uses typed GDScript and the Compatibility renderer.

The integrated flow is **Campaign star chart → Mission briefing → Rocket Lab → Preflight → Active flight → Mission report**. M01 is available initially; M02–M04 are visible and locked. Mission beacons are generated from JSON. Select an active beacon to open its briefing and watch the mission projection loop automatically. The briefing shows the objective, route, build budget, and reward before you assemble the rocket. The launchpad shows your selected parts, calculated cost, mass, and fuel. Launch emits the integration signal once and then opens the authoritative flight simulation with the exact configured rocket.

The flight deck shows the **forward window** and **orbit display** side by side. When the rocket shrinks to a marker, Vehicle Cam opens across the center seam and shows the live stack with staging and landing-leg controls. The forward camera zooms in on lunar descent to show ground clearance. The orbit display shows the flown trail and a gold ballistic projection based on Earth and lunar gravity. Drag to pan, scroll to zoom, right-click to recenter, or press Tab to fit the projected route. Use the lower-deck rate dial for 1×, 5×, 25×, or 50× speed. Press **?** on the deck for a control reference that holds the simulation while open.

Vehicle Cam gives the rocket engine vibration proportional to throttle and the active engine's catalog thrust, with up to 5.4 px horizontal travel, 6.3 px vertical travel, and 0.6 degrees of roll at full thrust. A separate visual mount moves the rocket and its steering jets while the bezel, controls, world camera, and simulator stay steady. Cutoff, empty fuel, touchdown, crash, pause, the control manual, or closing Vehicle Cam stops the vibration. The lunar landing scenario starts exactly **10 km above the Moon**, retaining the existing 55 m/s descent velocity.

Rocket parts use shaded white insulation, black thermal bands, brushed metal, copper engine plumbing, dark ribbed nozzles, and gold payload foil. All ten part SVGs retain their original sizes and attachment points, so builder mounts, exhaust origins, and the flight stack use the same geometry and part stats.

Use **Moon flyby demo** on the main menu for an automatic 25x showcase. It opens with the orbit display auto-framed with a safe close approach and the projected lunar-gravity bend already visible; manual pan or zoom releases the automatic framing.

**Start here:** [Milestone 1 beginner guide](docs/MILESTONE_1_GUIDE.md) explains how to build a rocket and where to change missions, prerequisites, budgets, cards, and preflight labels. [Shared interfaces](docs/INTERFACES.md) records field names, units, ownership, and integration APIs for team review.

Open **Workshop** from the star chart to build with the full parts catalog. Choose **Pioneer II** for a two-stage reference rocket. Parts animate as they are equipped. In the mission flow, **Back to briefing** keeps your draft and **Edit Rocket** reloads the confirmed build. Mission builds retain their own parts rules and budgets. M02 introduces upper stages and the separator, M03 requires the science payload, and M04 requires landing legs.

New mission and Workshop builds start empty. Open a storage category and drag a part onto a compatible mount. Parts enlarge while held. Hover a stored part for a visual forecast of fuel, mass, thrust, delta-v, and cost; the tooltip names the empty mount or replacement used for the estimate and never changes the assembly. Sparrow I and Pioneer II remain optional presets, and returning to a saved draft preserves its parts.

The builder's live analysis panel uses a fuel tank, a dry/fuel mass split, a thrust gauge, and a Δv bar. Pale ticks and arrow deltas compare with the previous assembly edit; renaming does not reset that comparison. Hover a dragged part over a compatible mount to preview its metrics, cost, and validation before fitting it. Canceling restores the installed build. Gold diamonds mark applicable mission minimums; the Δv minimum is an ideal energy estimate and needs flight margin. Hover or focus the cards for exact values and explanations.

Campaign completion, one-time rewards, best scores and discoveries are saved locally. The **Agency Reserve** instrument shows your credit balance. Use the gear icon to open volume settings. For internal UI testing, open `scenes/ui/ui_sandbox.tscn` and press **F6**.

The campaign command center has three cursor-driven background layers (deep stars, nebula/dust, and close stars) with overscan and smooth motion. A perspective grid tilts the mission tree while labels stay upright. Cyan energy packets flow from Earth along completed prerequisite branches; unopened branches stay dashed. Earth and Moon rotate slowly, with an atmospheric glow and an orbiting satellite around Earth. Completed beacons have a solid cyan core and rotating rings, available beacons breathe, and locked beacons show dim interference. Hover or keyboard-focus a beacon to preview its objective wireframe and unfold the bottom briefing. Clicking opens the full briefing with a short holographic reveal.

The right-hand vehicle display renders the actual equipped `RocketConfig` with sprite yaw, moving lighting, and a holographic turntable. A fresh campaign shows an empty hangar until a rocket is equipped. The briefing and reserve/settings housing use screen-sampled frosted glass with sharp foreground text. These effects use the Compatibility renderer and require no external assets or dependencies. The visuals live in `scripts/ui/campaign_hologram.gd`, `star_chart_layer.gd`, `mission_beacon_visual.gd`, `mission_objective_preview.gd`, and `campaign_rocket_preview.gd`.

Rocket Lab plays installation effects when a part is fitted. Tanks vent from both valves and engines play a short smoke purge with a hiss. Launch Control runs a single pressure check on the active engine. The simulator uses its original rocket sprites and exhaust with the cockpit steering jets and crash effects.

Effects live in `scripts/effects/component_effect.gd`. Engine intensity follows catalog thrust, and tank vapor intensity follows capacity; an optional `fx_strength` field supports future visual upgrades, including pod tiers. No extra pod or fuel types have been added. GPU particle systems use regular emitters and one-shot restart, compatible with the project's Compatibility renderer. The animation review is generated by the local QA harness under `exports/qa/`.

Rocket Lab has a wide observation bay, a raised assembly platform, and a separate live-build instrument panel. The APOGEE LABS tubes flicker above the assembly. A narrow storage cabinet runs down the left side. Select a hatch to slide the shutter sideways and reveal that category.

The builder, mission briefing, and launch control use the same recessed cockpit button style. Cyan marks the main navigation action, amber marks launch, and keyboard focus has a visible outline.

Mission briefings show a neon holographic route board with a grid, glowing traveled segment, start/goal markers, and a pulsing vehicle marker. The authored eight-second route loops automatically, with no replay button or progress bar; all four mission routes remain schematic, not flight predictions. Launch control reuses the builder's visual fuel, mass, thrust, and delta-v cards with actual confirmed stats, applicable mission minimums, and a live budget bar. Edit and Launch stay visible while long names or validation messages scroll. Preflight does not invent a previous-build comparison. The launchpad frames the equipped rocket in a bolted observation window.

The shared interface theme lives in `assets/ui/apogee_theme.tres`. Edit its type variations in Godot to update headings, controls, or readouts across scenes. Oxanium and IBM Plex Mono are bundled with their licenses under `assets/ui/fonts/`.

Mission Control now uses a female ElevenLabs narrator with pronounced radio distortion, minimal background static, and distinct walkie-talkie key clicks across 29 bundled clips, with matching subtitles, priority interruption, stale-warning removal, pause support, and music ducking. Calls use validated launch state, measured altitude/fuel/engine/stage/gear telemetry, or confirmed mission results. The narrator does not invent Max Q, thermal damage, a countdown, or a crash when a flight is ended early. See [voiceover triggers and regeneration](docs/MISSION_VOICEOVER.md) for the evidence behind every line and the existing mismatch between lunar mission prose and simulator contact limits. No API key or online speech request is required by the game.

## Campaign flight

On the star chart, select **First Flight → Build rocket → Prepare Launch → Launch**. Ignite and climb past 100 km with the pod intact. The result opens automatically and offers **Retry build** or the next unlocked mission. **End** reports an unfinished attempt as a failure. The orbit display shows the active orbit at AP and PE and the unpowered projection in gold. An impact marker, projected Moon position, and closest-approach label appear when relevant.

**Lunar Encounter** starts on a verified survey approach. Fit the science payload, then coast through the 15–30 km band and back out. **One Small Step** requires legs and a safe Moon touchdown. Landing near the chart's illustrative site unlocks the fictional Apollo 11 tribute in the debrief.

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
godot --headless --path . --script res://tests/test_builder_metrics.gd
godot --headless --path . --script res://tests/test_component_effects.gd
godot --headless --path . --script res://tests/test_lab_atmosphere.gd
godot --headless --path . --script res://tests/test_projection_visuals.gd
godot --headless --path . --script res://tests/test_campaign_vfx.gd
godot --headless --path . --script res://tests/test_mission_voiceover.gd
godot --headless --path . --script res://tests/test_vehicle_vibration.gd
godot --headless --path . --script res://tests/test_menu_flow.gd
godot --headless --path . --script res://tests/test_rocket_lab_flow.gd
godot --headless --path . --script res://tests/test_mock_telemetry.gd
godot --headless --path . --script res://tests/test_m0_flow.gd
godot --headless --path . --script res://tests/test_flight_simulator.gd
```

These check valid and malformed mission data, detached mock snapshots and playback, the M0 screen flow, retry resets, direct scene startup, and invalid sample recovery. The original smoke check still covers the builder/flight preview, reference budget, launch telemetry, and reserved map input. The beginner guide includes the full PowerShell command for the Godot executable on this computer.

For rendered campaign VFX captures, run `godot --path . --script res://tests/test_campaign_vfx.gd -- --capture`. Images are saved under `exports/qa/campaign-vfx/`. On Windows systems with native OpenGL resize-driver issues, add `--rendering-driver opengl3_angle` to use Godot's ANGLE Compatibility backend. The VFX suite checks route completion branches, projection/hit alignment at multiple resolutions, actual equipped parts and copy isolation, hover/focus previews, and briefing transitions without writing campaign progress.

Implemented locally on `codex/m1-launchpad-ui`, carrying forward M0. Team agreement on shared interfaces, pushing the branch, and opening a PR remain team handoff steps; no remote changes were made.
