# Milestone 1: menus, builder handoff, and launchpad

Open `project.godot` in Godot 4.7.2 and press **F5**. The main menu now contains
the campaign star chart. Click the **M01 / First Flight** beacon to see the
animated flight projection, objective, route, build budget, and reward. Choose **Build rocket** to open
RocketLab, then **Prepare Launch** to review the assembled rocket at the launchpad.

**Edit Rocket** brings the same design back to the builder. **Missions** returns
to the main menu. **Launch** emits the agreed launch request once, in the same
preview scene. Actual rocket flight is connected in M4; this milestone has no
physics, win detection, rewards, or save-file writes.

The hangar starts with Sparrow I. Add up to two stages and three tanks per stage. Click a category to reveal the parts arc. Drag parts onto the glowing mount or right-click a mounted part to detach it. The **Kit** category includes the stage separator, science payload, and landing legs when the mission allows them. **Workshop** on the star chart gives access to the entire catalog and both reference designs.

## Build and change your rocket

1. Open **Pods**, **Fuel**, or **Engines** to reveal that category's part cards.
2. Drag a part from the category arc onto its matching
   mount. Wrong-category drops are rejected. Replacing a part updates the picture,
   cost, mass, and fuel immediately.
3. Right-click an installed module on the rocket to detach it. A missing required
   module blocks **Prepare Launch** and shows the reason in the readiness area.
4. Edit the rocket name in its text field. **Clear** removes the assembly;
   **Sparrow I** restores the reference pod, large tank, and launch engine.
5. Choose **Prepare Launch** when the build is valid. **Back to briefing** keeps the draft.
   **Edit Rocket** from preflight restores your selected parts and name.

Sparrow I costs **1,600 CR** and has **3,600 kg wet mass**. Using the small tank
instead costs **1,250 CR** and gives **2,200 kg wet mass**. Wet mass includes fuel;
it is the number used while the fully fueled rocket is on the launchpad.

## Understand the files

A `.tscn` file describes what is on a screen. A `.gd` script describes how that
screen behaves. A `.json` file holds editable content and numbers.

| What you want to edit | File |
| --- | --- |
| Mission title, objective, budget, reward | `data/missions/m01.json` (or m02–m04) |
| Mission order, prerequisite, starting location, destination | `data/missions/index.json` |
| Beacon labels, status colors, locked appearance | `scenes/menus/mission_card.tscn`, `scripts/ui/mission_card.gd` |
| Star chart, campaign route, and mission marker anchors | `scenes/ui/main_menu.tscn`, `scripts/ui/main_menu.gd` |
| Mission projection sprites, flight paths, and animations | `scenes/missions/mission_projection.tscn` |
| Mission briefing layout and text | `scenes/missions/mission_select.tscn`, `scripts/ui/mission_select.gd` |
| Selected parts, reference assembly, validation | `scripts/builder/builder_controller.gd` |
| Part categories and clickable/draggable cards | `scripts/builder/part_carousel.gd`, `scripts/builder/part_card.gd` |
| Builder mounts, drop targets, and detach action | `scripts/builder/rocket_preview.gd` |
| Rocket artwork and preflight rendering | `assets/rockets/*.svg`, `scripts/ui/rocket_preview.gd` |
| Preflight wording, displayed stats, Launch/Edit buttons | `scenes/flight/preflight_panel.tscn`, `scripts/ui/preflight_panel.gd` |
| Launch request and preview session state | `scripts/ui/launchpad_preview.gd` |
| Remembered mission, rocket, and navigation | `scripts/core/game_manager.gd` |

In Godot, open a scene, select a node in the **Scene** panel, and edit its properties
in the **Inspector**. Use containers and separation settings for spacing. Preserve
node names referenced with `%`, such as `%LaunchButton`, or update the script too.

## Example: change a mission budget

In `data/missions/m01.json`, change `"budget_credits": 2000` to
`"budget_credits": 2500`. Stop and rerun the game. The menu, builder, and preflight
panel all read the same mission definition, so they show the new budget.

The displayed objective is `objective_text`. The future objective target is in
`win_conditions`; changing the description alone does not change the target.
Distances are meters: `100000` means 100 km. JSON text uses double quotes; numbers
and `true`/`false` do not. Keep field names, commas, and value types intact.

## Example: try a smaller tank

Choose **Fuel**, then click **Small tank** or drag its card to the middle mount.
The rocket becomes shorter and the totals change to 1,250 CR and 2,200 kg wet mass.
Choose **Prepare Launch**, then **Edit Rocket**: the smaller tank stays selected.
Use **Sparrow I** whenever you want the original reference assembly back.

To change the default for future assemblies, open
`scripts/builder/builder_controller.gd` and edit `_reset_assembly()`, for example its
`"tank": "TANK_L"` entry to `"tank": "TANK_S"`. `_reset_assembly()` reads those
defaults; `build_config()` exports your current choices. Stop and select M01 again
to start fresh. The **Sparrow I** action also uses the edited defaults.

To tune a part's price, dry mass, or fuel capacity, edit that part's entry in
`data/parts.json` and rerun. Keep stable IDs such as `TANK_S` intact: these connect
the catalog, mission restrictions, chosen configuration, and artwork. Tests assert
the supplied reference numbers, so deliberate balancing changes may require
updating their corresponding expectations.

## Example: change the unlock path

In `data/missions/index.json`, each mission has `unlock_requirement`. `null` means
it is initially available. `"M01"` means completing M01 unlocks it. A prerequisite
must already appear earlier in the ordered list. Keep IDs unique, and keep the
filename aligned: M02 lives in `m02.json`.

Initially, only M01 is available. M01 unlocks M02; M02 unlocks both M03 and M04.
Agency credits are a campaign total, not the amount available for a rocket build.
Rocket affordability uses the selected mission's budget.

Completion is only an in-memory display state in M1. To inspect completed cards
while developing, temporarily initialize these values in `game_manager.gd`:

```gdscript
var completed_missions: Array[String] = ["M01"]
var best_scores: Dictionary = {"M01": 84}
```

Rerun to see M01 completed/replayable and M02 available. Restore the empty values
after testing. This is a developer fixture; the real mission manager will supply
completion events in M3, and saving arrives in M7.

M03/M04 data reserves lunar approach/descent checkpoints for later milestones.
Member 1 must supply their verified starting states, and Member 2 must supply the
science payload/landing parts. M1 does not simulate or enforce those future lunar
objectives; only their definitions and locked cards are prepared here.

## How the handoff works

1. A reusable mission card asks `GameManager.select_mission(id)` to open a mission.
2. GameManager checks that it exists, is released, and is unlocked, then shows
   the briefing. **Build rocket** opens the builder with that definition.
3. The builder calculates cost from the parts catalog and validates the design.
   **Prepare Launch** emits `configuration_confirmed(config)` only for a valid build.
4. GameManager validates again at the handoff, stores an independent copy, and opens
   the preflight preview.
5. The preview draws that config. **Edit Rocket** reloads the stored design into the
   builder. **Launch** revalidates, marks the session as requested, and emits a copy. **Test fire** in the hangar previews exhaust and stage separation without running the flight simulation.

The real RocketLab editor uses the same adapter contract:
`setup(mission)`, `load_config(config)`, `build_config()`, `validate(config, mission)`,
and `configuration_confirmed(config)`. GameManager handles screen changes.
`%MissionBriefing` reminds the player of the objective while building;
`%BuildStatus` displays validation errors and advice. Unsupported loaded designs
are retained and rejected; loading a multi-stage or multi-tank design must not
silently discard parts to make it fit the current three-mount editor.

Member 1's flight integration preserves
`GameManager.flight_launch_requested(config, mission_id)` for observers and then
opens the authoritative Flight scene with a separate copied configuration. There
is no simulator inside the preflight preview.

## Run checks after editing

From PowerShell in `E:\Apogee`:

```powershell
$godotExe = 'C:\Users\prava\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
& $godotExe --headless --editor --path . --import
& $godotExe --headless --path . --script res://tests/test_mission_catalog.gd
& $godotExe --headless --path . --script res://tests/test_builder.gd
& $godotExe --headless --path . --script res://tests/test_menu_flow.gd
& $godotExe --headless --path . --script res://tests/test_rocket_lab_flow.gd
& $godotExe --headless --path . --script res://tests/test_mock_telemetry.gd
& $godotExe --headless --path . --script res://tests/test_m0_flow.gd
& $godotExe --headless --path . --script res://tests/smoke_test.gd
```

The M1 flow checks cover the acceptance cases: locked cards, direct API guards,
missing engines, wrong part types, over-budget builds, preflight data, Edit Rocket,
retained config, a single launch request, and completed/unlocked card states.
The RocketLab check also covers real part selection and assembly preservation
through Prepare Launch → Edit Rocket.

The old M0 demo remains available through the main menu's **UI sandbox** button or
by opening `scenes/ui/ui_sandbox.tscn` and pressing **F6**. You can also run the
launchpad preview directly with F6 to inspect its reference craft.

If a normal run closes immediately with a local Windows `WASAPI` audio error, use
`& $godotExe --path . --audio-driver Dummy` for a silent preview. No project audio
settings are changed by that command.

Changes are local on `codex/m1-launchpad-ui`. The team still needs to review the
shared interfaces and merge the work; no branch push or PR has been performed.
