# Apogee

> **Build it. Fly it. Find out why it didn’t make orbit.**

A 2D rocket-building and flight game made for **UB Hacking 2026 · Into the Hackosmos**. Assemble a spacecraft, take the controls, and see whether your engineering holds up all the way to the Moon.

**A game by Vaikan · Charan · Varun**

[Download](#download-and-play) · [First launch](#your-first-launch) · [The story](#about-the-project) · [Gemini Coach](#gemini-coach) · [Development](#development)

## Download and play

1. Open [GitHub Releases](https://github.com/sricharanreddy11/Apogee/releases) and expand **Assets** on the latest published release.
2. Download the build labeled for your system. The **Source code** ZIP is for running the project in Godot.
3. Extract the entire archive, then launch the game from the extracted folder.

| Platform | How to launch the matching build |
| --- | --- |
| Windows | Open `Apogee.exe`. Keep any accompanying `.pck` and other files beside it. |
| macOS | Open `Apogee.app` from the extracted archive. |
| Linux | Open the extracted Apogee executable. If it lacks execute permission, run `chmod +x Apogee.x86_64` using the filename from the archive, then `./Apogee.x86_64`. |

The Releases page lists which platform builds are available. If your platform build is missing, you can run from source on Windows, macOS, or Linux. The campaign and Mission Control radio work without an API key.

### Run from source

1. Clone this repository or select **Code → Download ZIP** on GitHub and extract it.
2. Install [Godot 4.7.2 Standard](https://godotengine.org/download/archive/4.7.2-stable/).
3. In Godot’s Project Manager, choose **Import** and select `project.godot`. Open the project, let the assets import, and press **F5**.

## Your first launch

Try the **Guided tutorial**, or go straight to **First Flight → Build rocket**. Pick **Sparrow I** for a ready-to-fly build, then select **Prepare Launch → Launch**. In the cockpit, ignite the engine, throttle up, and aim for **100 km** with the command pod intact.

| Cockpit control | Input |
| --- | --- |
| Throttle | **W / S** or the throttle slider |
| Steer | **A / D** or the arrow keys |
| Cut throttle | **X** |
| Separate stage | **Space** |
| Toggle landing legs | **L** |
| Control reference | **?** |

| Mission | Objective |
| --- | --- |
| **M01 · First Flight** | Reach 100 km above Earth with your command pod intact. |
| **M02 · Orbital Challenge** | Hold a stable Earth orbit inside the target band for two seconds. |
| **M03 · Lunar Encounter** | Carry a science payload through a lunar flyby corridor and back out. |
| **M04 · One Small Step** | Deploy your landing legs and touch down safely on the Moon. |

## About the project

### Inspiration

This year’s theme was deep space, so we gave players a rocket and the freedom to make questionable engineering decisions. Our favorite example: a bigger fuel tank gives you more fuel. It also gives your engine a bigger fuel tank to lift. Rocket science is full of these little betrayals.

### What it does

Apogee takes you from your first 100 km climb to Earth orbit and lunar missions. In Rocket Lab, you can see how each part changes your mass, thrust, fuel, and budget before bolting it on. Then you take the controls yourself: throttle up, steer, stage, and watch the orbit display to see where all those excellent decisions are taking you.

During flight, Mission Control uses **ElevenLabs**-generated radio calls triggered by the simulator. It’s a very professional voice for whatever is happening in your cockpit. After First Flight or Orbital Challenge, the **Gemini** coach uses your actual flight data to explain what happened, show you the evidence, and suggest one thing to try next time.

### How we built it

We built Apogee in Godot with GDScript. The rocket you assemble in the hangar is the rocket the simulator flies, questionable fuel tank and all. The cockpit instruments, mission objectives, radio calls, and debrief all read from the same simulation. We gave the star chart, Rocket Lab, and cockpit a shared visual style, because if you’re going to miss orbit, you might as well do it from a good-looking flight deck.

### What challenged us and what we learned

The hardest part was making orbital mechanics readable while the player is busy flying. You can climb 100 km, feel pretty good about yourself, and still come straight back down. The orbit display made the missing ingredient visible: sideways speed.

We also learned how quickly feedback can sound more confident than the data. If you end an attempt early with fuel left, the coach can tell you that. It can’t tell you what you were thinking when you hit End. The debrief works best when it gives you one specific experiment for your next launch, which is a much better reason to hit Retry than sheer spite. Though spite works too.

## Gemini Coach

After **First Flight** or **Orbital Challenge**, open **Gemini coach → Analyze flight** on the mission report. The coach separates the diagnosis, flight-recorder evidence, and one change to test. On a retry, it compares the two attempts.

For a local Godot project, copy `.env.example` to `.env` beside `project.godot` and add a key from [Google AI Studio](https://aistudio.google.com/apikey).

```dotenv
GEMINI_API_KEY=your_key_here
```

Git ignores `.env`. Packaged desktop builds read `GEMINI_API_KEY` from the environment that launches the game. If both are set during development, the process environment takes priority.

## Built with

**Godot Engine · GDScript · Google Gemini API · ElevenLabs · Python · FFmpeg · Godot shaders · SVG**

## Development

- [Beginner and integration guide](docs/MILESTONE_1_GUIDE.md)
- [Shared interfaces](docs/INTERFACES.md)
- [ElevenLabs radio triggers and regeneration](docs/MISSION_VOICEOVER.md)

<details>
<summary>Module handoffs, smoke tests, and visual QA</summary>

### Module handoffs

| Contract | Ownership and use |
| --- | --- |
| `RocketConfig` and `StageConfig` | Builder exports a design with stable part IDs. The first stage to fire is at index 0. The simulator owns a deep copy. Compute costs and masses from the catalog. |
| `FlightState` | The simulator alone changes the live state. The flight scene owns one simulator per attempt. |
| `FlightTelemetry` | `get_telemetry()` creates a detached snapshot. The HUD, map, and mission checker treat it as read-only. HUD and map can also accept a fabricated snapshot while being developed. |
| `MissionDefinition` | The mission loader reads JSON into a typed definition. Builder validation consumes its budget and part restrictions. Flight initialization consumes its scenario. |
| `MissionResult` | The mission manager owns the result while evaluating telemetry. The report reads the outcome and measured stats. |

Use SI units for simulation. Positive X points right and positive Y points down. Heading zero is up, with clockwise positive. The UI converts altitude to kilometers for display. At launch M01 starts at the north surface of scaled Earth, centered on the origin. The flight screen computes coast predictions from copied snapshots on a worker thread. The project reserves the design's keyboard actions in Godot's Input Map. The preview map can be toggled with its button.

### Smoke check

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
godot --headless --path . --script res://tests/test_campaign_controls.gd
godot --headless --path . --script res://tests/test_menu_flow.gd
godot --headless --path . --script res://tests/test_rocket_lab_flow.gd
godot --headless --path . --script res://tests/test_mock_telemetry.gd
godot --headless --path . --script res://tests/test_m0_flow.gd
godot --headless --path . --script res://tests/test_flight_simulator.gd
```

These check valid and malformed mission data, detached mock snapshots and playback, the M0 screen flow, retry resets, direct scene startup, and invalid sample recovery. The original smoke check still covers the builder/flight preview, reference budget, launch telemetry, and reserved map input. The beginner guide includes the full PowerShell command for the Godot executable on this computer.

For rendered campaign VFX captures, run `godot --path . --script res://tests/test_campaign_vfx.gd -- --capture`. Images are saved under `exports/qa/campaign-vfx/`. On Windows systems with native OpenGL resize-driver issues, add `--rendering-driver opengl3_angle` to use Godot's ANGLE Compatibility backend. The VFX suite checks route completion branches, projection/hit alignment at multiple resolutions, actual equipped parts and copy isolation, hover/focus previews, and briefing transitions without writing campaign progress.

</details>
