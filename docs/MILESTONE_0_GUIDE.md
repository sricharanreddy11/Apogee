# Milestone 0: run it, understand it, change it

**M1 update:** Mission selection now appears directly on the main menu. Use its
**UI sandbox** button to run this M0 demo. The earlier New Campaign/selection steps
below describe the original M0 layout. See [the M1 guide](MILESTONE_1_GUIDE.md) for
the current main menu → builder → preflight flow.

M0 gives you a safe place to build your UI while your teammates work. The flight
numbers are scripted examples. The real rocket simulator, mission win detection,
scoring, and campaign saves are later milestones.

## Run the demo

1. Open Godot Project Manager, choose **Import**, and select `E:\Apogee\project.godot`.
2. Use the standard Godot 4.7.2 editor installed on this computer.
3. Press **F5** to run the whole project.
4. Choose **New Campaign**, then **Select M01 · Open UI sandbox**.
5. Watch altitude and speed rise while fuel falls. Use **Pause** or **Restart sample**.
6. Choose **Open sample report**, then **Retry sandbox** or **Main menu**.

The default 60-second sample takes 12 real seconds at 5× speed, then holds its final
values. **Mock flight report** shows the highest sample altitude and speed seen;
it does not declare mission success. **Back to mission** returns to the briefing.

You can also open `scenes/ui/ui_sandbox.tscn` in Godot and press **F6** to run only
that scene. F5 always starts the project's main scene; F6 starts the selected scene.
The separate builder preview still leads to the existing static Flight placeholder.

## What each kind of file does

Think of a screen as a small stage set:

| File | Meaning | Example |
| --- | --- | --- |
| `.tscn` | The screen's nodes, arrangement, text, and appearance | `scenes/ui/ui_sandbox.tscn` |
| `.gd` | What happens when time passes or a button is pressed | `scripts/ui/ui_sandbox.gd` |
| `.json` | Editable content and sample numbers | `data/missions/m01.json` |

Godot's **Scene** panel shows the nodes. Select a node to edit its properties in
the **Inspector**. A script attached to a node controls its behavior.
`res://` means this project's root folder. You do not need to change that prefix.

## How the pieces talk

`GameManager` is a small coordinator that survives when the screen changes. It
remembers your selected mission, build, and latest result. Each screen asks it to
open the next screen through a connected signal.

`MissionCatalog` reads M01's JSON and checks it before the UI uses it.
`MockTelemetry` produces a new `FlightTelemetry` object containing the current
display values. The sandbox passes that object to `FlightHud`.

The HUD does not need to know where the numbers came from. Later your teammate's
real simulator can supply the same object. That is why the shared contract matters.
See [INTERFACES.md](INTERFACES.md) for the exact fields and units.

## Changes you can make yourself

| What you want to change | Where to start |
| --- | --- |
| Mission title, briefing, budget, reward | `data/missions/m01.json` |
| Fake flight's altitude, speed, fuel, timing | `data/mocks/first_flight.json` |
| How quickly the demo plays | MockTelemetry node's `playback_speed` in the sandbox Inspector |
| HUD wording and number formatting | `scripts/ui/flight_hud.gd` |
| Button wording, spacing, colors | Select the node in the matching `.tscn` scene |
| Navigation and preserved selection | `scripts/core/game_manager.gd` |
| Report presentation | `scripts/ui/mission_report.gd` and its scene |

### Example: edit the mission budget

Open `data/missions/m01.json`. Change `"budget_credits": 2000` to
`"budget_credits": 2500`, save, stop the game, and run again. The mission selection
screen reads the new number. The builder's budget check reads the same mission.

Change `title` or `objective_text` to edit what players read. The actual target is
`win_conditions.min_altitude_m`: `100000` means 100 km. If you change that target,
update the description too. The M0 mock still does not evaluate success.

Keep JSON property names exactly as written. Text uses double quotes; numbers and
`true`/`false` do not. Keep commas between entries and do not add a comma after the
last entry. Budgets must be positive whole numbers and rewards nonnegative whole
numbers. A readable loader error helps identify a broken file.

### Example: change the fake flight

Open `data/mocks/first_flight.json`. The sample frames describe time, altitude,
speed, and fuel. The provider blends between them, like moving a slider between
two values. To make the middle of the flight look higher, increase a frame's
altitude. Start frame times at `0`, keep them increasing, and keep fuel between `0` and `1`.
For example, `{"time_s": 30, "altitude_m": 35000, "speed_mps": 900,
"fuel_fraction": 0.55}` means 35 km, 900 m/s, and 55% fuel at 30 seconds.

Stored distances are meters: `5000` is 5 km. Speed is meters per second. A fuel
fraction of `0.55` means 55%. These numbers test presentation; editing them does
not tune actual rocket physics. Matching position vectors are generated for maps.

In the sandbox scene, select **MockTelemetry**. Adjust **Playback Speed** in the
Inspector; `1` plays at normal speed, `5` advances five simulation seconds per real
second. Save the scene so the value persists. A replay starts from a fresh clock.

### Example: change HUD text or colors

Open `scripts/ui/flight_hud.gd` and find `update_from_telemetry()`. The formatting
code converts meters to kilometers and fuel fractions to percentages. `%.1f` shows
one decimal place; `%.0f` shows no decimals. Keep the value order aligned with the
format string's placeholders. Save, then run the sandbox to see the result.

For a button, open its scene, select the Button node, and edit **Text** in the
Inspector. For a label color, use **Theme Overrides → Colors → Font Color**.
Use containers and their separation settings for spacing. Preserve node names
used by scripts, such as `%Primary`, `%Secondary`, and `%HUD`; renaming a referenced
node can break the connection even when the screen still looks correct.

## Check changes and recover from mistakes

Make one small change, save, and run again. Godot's **Debugger** and **Output**
panels show script and data errors. If a value does not change, stop the old run
and start a new one so data is reloaded. Avoid editing `.godot/`; it is generated.
Use Git's diff view to inspect your edits before committing. Restore only the
specific edit you want to undo so you do not discard a teammate's work.

For the automated checks, run these in PowerShell from `E:\Apogee`:

```powershell
$godotExe = 'C:\Users\prava\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
& $godotExe --headless --editor --path . --import
& $godotExe --headless --path . --script res://tests/test_mission_catalog.gd
& $godotExe --headless --path . --script res://tests/test_mock_telemetry.gd
& $godotExe --headless --path . --script res://tests/test_m0_flow.gd
& $godotExe --headless --path . --script res://tests/smoke_test.gd
```

The import builds Godot's local class cache. The remaining checks validate mission
data, mock snapshots, and the screen flow. These checks do not verify real flight.

If the game immediately closes with a Windows `WASAPI` audio-driver error, use
this silent preview command with the same `$godotExe` variable:

```powershell
& $godotExe --path . --audio-driver Dummy
```

This bypasses the local audio device for that run. It does not change the project's
audio settings. The M0 sandbox has no sound content yet.
Some checks assert the supplied sample values; changing those defaults deliberately
may require updating the corresponding expected values in the tests.

## Your handoff to teammates

Share `docs/INTERFACES.md` and review the contracts with Members 1 and 2 and your
integrator. Ask them to confirm the coordinate frame, field names, statuses, and
which shared files they own. M0's code can be implemented locally; team agreement
and a reviewed merge still need the actual team's participation.

The next step is M1's full menu and mission selection, then M2's HUD/map and M3's
objective checker. Your reusable mock flight stays useful for all of those.
