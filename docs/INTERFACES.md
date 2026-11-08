# Apogee shared interfaces · M0–M1

This records the interfaces implemented in this branch. **Team agreement is still
pending**: Members 1 and 2 and the integrator must review these contracts before
merging shared changes. Existing class names and fields have been retained.

## Ownership and boundaries

| Area | Proposed owner | Rule |
| --- | --- | --- |
| Rocket design, builder calculations | Member 2 | Produce a validated `RocketConfig`. |
| Live `FlightState`, simulator, and coast predictor | Member 1 | Only the simulator changes live physics. |
| Missions, HUD, sandbox, reports | Member 3 | Consume snapshots; never modify live physics. |
| Core contracts, `GameManager`, project settings, Flight scene | Integrator | Coordinate shared changes with all members. |

The normal route is Main Menu → Builder → Launchpad Preview → Active Flight. Launch emits an
integration handoff and then opens the one authoritative simulation. M0's separate sandbox remains a
UI test tool, with no mission completion, scoring, rewards, or save writes.

## Units and coordinate conventions

- Position: meters; velocity: meters per second; mass/fuel: kilograms.
- Time: elapsed **simulation** seconds. UI playback speed changes the clock rate.
- Shared world frame: Earth-centered, with Earth at `(0, 0)`; +X right, +Y down.
- Heading: radians; `0` is up and positive rotates clockwise.
- Scaled Earth radius: `600000` m, read from `data/planets.json`.
- Earth's north surface launch is `(0, -600000)` m.
- Body-relative altitude is distance from the body's center minus its radius.
- Fuel fraction and throttle: `0.0` through `1.0`; the HUD converts to percent.
- Stage indexes start at **0**, first to fire. Displayed stage numbers start at 1.
- UI displays altitude in kilometers (`meters / 1000`); keep stored values in SI.

The Earth is stationary and the Moon follows the scaled circular orbit declared in
`data/planets.json`; rocket telemetry is transformed into the selected body's frame.
Mars motion remains later work. M0's mock only illustrates a stationary central body and vertical display
values; its scripted speed is not the derivative of its scripted altitude.

## Typed data contracts

All classes below are `RefCounted` objects in `scripts/core/`.

| Contract | Fields and meaning |
| --- | --- |
| `RocketConfig` | `rocket_name`, `command_pod_id`: String; `stages`: Array[StageConfig]; `attachment_ids`, `cosmetic_order`: Array[String]. Part IDs refer to the catalog. `copy()` makes an independent design, retaining null stage entries so validation can explain malformed designs. |
| `StageConfig` | `engine_id`: String; `tank_ids`: Array[String]. `copy()` duplicates the stage. |
| `FlightState` | `position_m`, `velocity_mps`: Vector2; `heading_rad`, `throttle`, `elapsed_time_s`, `mass_kg`: float; `active_stage`: int; `stage_fuel_kg`: Array[float]; `status`: Status enum; `pod_intact`, `legs_deployed`: bool. Simulator-owned mutable state. |
| `FlightTelemetry` | Detached snapshot described below. Consumers treat it as read-only. It also carries Earth/Moon map positions and active-body frame data. |
| `MissionDefinition` | `id`, `title`, `objective_text`, `objective_type`: String; `budget_credits`, `reward_credits`: int; `scenario`, `win_conditions`, `payload`: Dictionary; `allowed_part_ids`, `required_part_ids`, `discovery_ids`: Array[String]. Navigation metadata: `unlock_requirement`, `starting_location`, `destination`: String; `released`: bool. |
| `MissionResult` | `mission_id`, `reason`: String; `outcome`: Outcome enum; `flight_time_s`, `max_altitude_m`, `peak_speed_mps`, `fuel_used_kg`, `fuel_remaining_kg`: float; `launch_cost_credits`, `stages_used`, `score`, `awarded_credits`: int; `discovery_ids`: Array[String]. |
| `TrajectoryPrediction` | Detached ballistic projection: `body_id`: String; `elapsed_time_s`: float snapshot time; `positions_m`: PackedVector2Array; `sample_times_s`: PackedFloat64Array; `valid`: bool. |

`RocketConfig` does **not** cache cost or mass. `BuilderController.calculate(config)`
returns `cost_credits`, `dry_mass_kg`, `fuel_kg`, `wet_mass_kg`, and `launch_twr`,
derived from the parts catalog and scenario gravity. TWR is dimensionless and low
TWR and low ideal delta-v are advisory. Ideal delta-v sums the burns in stage order and discards first-stage dry mass and the separator before the upper burn.

`FlightState.Status` values are `READY`, `FLYING`, `LANDED`, `CRASHED`.
`MissionResult.Outcome` values are `IN_PROGRESS`, `SUCCESS`, `FAILURE`.

### FlightTelemetry fields

| Fields | Type / unit |
| --- | --- |
| `position_m`, `velocity_mps` | Vector2; world meters / world m/s |
| `heading_rad`, `throttle` | float; radians / fraction |
| `elapsed_time_s`, `active_stage` | float seconds / int zero-based index |
| `mass_kg`, `fuel_remaining_kg`, `fuel_fraction` | float kg / kg / fraction |
| `body_id` | String, e.g. `earth` |
| `altitude_m`, `speed_mps` | float meters above body surface / speed magnitude |
| `radial_speed_mps`, `tangential_speed_mps` | float body-relative m/s; radial outward positive |
| `has_bound_orbit` | bool validity flag for orbital values |
| `apoapsis_altitude_m`, `periapsis_altitude_m` | float meters; ignore when `has_bound_orbit == false` |
| `predicted_impact`, `pod_intact`, `legs_deployed` | bool |
| `status` | `FlightState.Status` |

Each provider returns a fresh snapshot; changing a received object cannot change
the provider's next snapshot. M0 leaves orbital values invalid and does not populate
mass or fuel kilograms; their zero defaults mean unavailable in the mock. The real
simulator populates those fields plus active-body and Earth/Moon map coordinates.

Prediction samples use the same world frame as telemetry and **absolute** elapsed
simulation timestamps. When `valid` is true, both arrays must have equal lengths
and timestamps must increase. `OrbitMap.set_prediction(TrajectoryPrediction)` draws
the route without mutating it.

## Mission catalog and progression

`MissionCatalog.get_mission_list()` returns `Array[MissionDefinition]` in the order
of `data/missions/index.json`. The index supplies prerequisites, start/destination
labels, and release state; each mission's remaining content comes from
`data/missions/<lowercase ID>.json`. `load_mission(id)` returns one indexed definition
or `null`. An invalid index or definition returns no partial list; `last_error`
explains the failure. IDs cannot contain path separators. Parsing helpers are
`parse_mission_index_json(text)` and `parse_mission_json(text, expected_id)`.

Legacy M01 JSON remains valid: an omitted `objective_type` means `reach_altitude`.
Missing `payload` means an empty dictionary. The index's null prerequisite becomes
an empty `unlock_requirement` string in the typed definition. Supported schemas:

| `objective_type` | Required `win_conditions` keys |
| --- | --- |
| `reach_altitude` | `min_altitude_m`, `require_intact_pod` |
| `stable_orbit` | `min_periapsis_m`, `max_apoapsis_m`, `hold_duration_s` |
| `lunar_flyby` | `min_altitude_m`, `max_altitude_m`, `require_intact_pod` |
| `safe_landing` | `max_vertical_speed_mps`, `max_horizontal_speed_mps`, `max_orientation_deg`, `require_landing_legs`, `require_intact_pod` |

Schema validation does not implement these objectives. `MissionManager.load_mission`
delegates to the catalog; `evaluate(telemetry)` and scoring in `finalize_result()`
remain later work. Future payload/landing parts and lunar simulation also remain
team integration work. The hangar can assemble two stages, a science payload, and landing legs.
M03 declares a required science payload and a lunar-approach checkpoint; M04 uses
a lunar-descent checkpoint. Their enforcement, verified start states, and missing
science/landing parts are future M6 work with Members 1 and 2.

## Navigation, builder, and preflight APIs

`GameManager` is the autoload and sole navigation owner. It keeps
`selected_mission_id`, `current_rocket_config`, and `last_result` between scenes.
`agency_credits: int`, `completed_missions: Array[String]`, and `best_scores: Dictionary`
are **in-memory** progress, not saved campaign data. Unlocking uses a released
mission's prerequisite completion, never Agency Credits. A completed mission is
itself replayable even if a developer test state omits its prerequisite.

| API | Behavior |
| --- | --- |
| `show_main_menu()` | Open the menu containing mission cards. `show_mission_select()` is a compatibility alias. |
| `is_mission_unlocked(id) -> bool` | Check release state and prerequisite completion. |
| `select_mission(id) -> bool` | Validate/unlock-check, store the mission, clear prior attempt/config, and open the mission briefing. Failed selection leaves the current mission unchanged. |
| `get_selected_mission() -> MissionDefinition` | Return the selected definition; consumers treat it as read-only. |
| `show_builder()` | Pass the mission and any preserved draft or confirmed config to the builder. |
| `prepare_launch(config) -> bool` | Revalidate, preserve a design copy, then open preflight. Invalid configs stay blocked. |
| `show_preflight() -> bool` | Open the separate launchpad preview for a prepared, unlocked mission. |
| `edit_rocket(config, mission_id) -> bool` | Preserve a copy and reopen its builder; also supports direct F6 preview runs. |
| `open_sandbox_for_mission(id = "M01") -> bool` | Select an unlocked mission and enter M0's mock sandbox. `show_ui_sandbox()` opens it for the current selection. |
| `show_report(result, retry_in_sandbox = false)` | Display a result and route retry; load the result's mission if needed after F6. |
| `start_flight(config)` | Open the authoritative active-flight scene with a copied configuration. Preflight invokes this after emitting the launch integration signal. |

`navigation_error(message: String)` and `last_navigation_error` expose readable
failures. `flight_launch_requested(config: RocketConfig, mission_id: String)`
provides a copied validated design to observers before `GameManager` opens active flight.

Builder API: `setup(mission)`, `load_config(config)`, `build_config() -> RocketConfig`,
`calculate(config) -> Dictionary`, and `validate(config, mission) -> Dictionary`.
Validation returns `valid`, `errors`, and `warnings`. The builder copies loaded and
exported designs. **Prepare Launch** revalidates and emits only
`configuration_confirmed(config: RocketConfig)`; it does not navigate itself.
`GameManager` handles that signal. This adapter now wraps the actual RocketLab UI
from `main`: category clicks reveal part cards, card clicks or drag/drop install a
module, and right-click detaches it. Three mounts represent one command pod, one
tank, and one engine. Clear/Restore actions and an editable name update the same
exported config. `%MissionBriefing` shows objective/start/budget/reward and
`%BuildStatus` shows validation errors/advice.

The builder validates one or two propulsion stages with one engine and one to three tanks per stage. Stage index zero is the lower stage and fires first. Tank IDs are ordered from bottom to top. Exactly one DECOUPLER in attachment_ids is required with two stages and drops with stage zero. Optional PROBE and LEGS stay with the upper assembly. The validator enforces mission part rules and budget. RocketRig uses assets/rockets/manifest.json and consumes active_stage, throttle and legs_deployed as presentation inputs.

`PreflightPanel.setup(mission, config, stats, validation)` receives copied display
data and exposes `launch_requested` and `edit_requested`. The launchpad controller
revalidates before launching. Its `session_phase` changes from `PREFLIGHT` to
`LAUNCH_REQUESTED` exactly once. It emits `launch_requested(config)` for
`GameManager` to relay, and GameManager then changes to Member 1's Flight scene.
The launchpad itself creates no simulator and advances no flight clock.

`MissionCard.setup(mission, unlocked, completed, best_score = 0, unlock_text = "")`
renders available, locked, or completed/replay states. `mission_selected(id)` is
guarded for locked cards even if a test emits the button signal manually. The menu
uses data-backed prerequisite names and hides unreleased entries.

## Retained mock telemetry pipeline

`MockTelemetry` is a scene-local Node with `telemetry_updated(FlightTelemetry)`.
`initialize(scenario)` loads the selected body's radius and demo frames; `restart()`
clears time; `step(delta_seconds)` advances deterministic playback;
`get_telemetry()` returns a detached snapshot. Exported `sample_path`,
`playback_speed`, and `paused` control the sandbox. It holds its last frame at the
end. The UI uses `FlightHud.update_from_telemetry(telemetry)`, the same method used
by the real flight screen. A future adapter can forward the real simulator's
`get_telemetry()` output without rewriting HUD display code.

The sandbox's report uses `IN_PROGRESS`; crossing the mock altitude target does not
complete M01. Main-menu mission cards now call `GameManager.select_mission()`;
the separate M0 MissionSelect scene is retained only as a legacy artifact.

## Before merging

Review field names, status meanings, zero-based stages, coordinate frame, and shared
file ownership with teammates. A local implementation and passing tests do not
constitute team sign-off. The local feature branch is `codex/m1-launchpad-ui`.
Pushing it and opening a PR remain separate, pending Git actions.
