# Mission Control voiceover

The game includes 29 prerecorded ElevenLabs clips, generated with Alicia - Polished Global Anchor and `eleven_multilingual_v2`. The female narration uses a pronounced radio transmission effect: a narrow 450 to 2,800 Hz band, 4 dB presence boost, 5:1 compression, driven soft saturation, blended 7-bit distortion, slight amplitude flutter, and minimal band-limited static. Every transmission has a distinct mechanical push-to-talk snap and latch at its opening and closing: two brief transients, with a 75 ms opening slot and a 95 ms closing slot. The background static is 22.5 dB lower than the earlier noisy version. Static plays only for the duration of a voice clip, and a limiter keeps final samples below clipping. The processed mono WAVs play locally through the `MissionVoiceManager` autoload. The game never calls an external speech API. No API key is stored in the source, clip metadata, or exported game.

`data/mission_voiceover.json` is the approved script and priority/expiration manifest. The exact same text supplies the subtitles. `scripts/missions/mission_voice_rules.gd` evaluates detached telemetry; `scripts/audio/mission_voice_manager.gd` owns playback, interruption, queue expiration, and per-attempt deduplication. Music ducks by 8 dB during speech. Pausing or opening the flight manual also pauses narration and queue timers.

## Evidence for each call

| Clip | Required evidence |
| --- | --- |
| Mission Control online; configuration validated | Launchpad opened after `BuilderController.validate()` accepted the actual configuration. This validates the game build, not real guidance or avionics systems. |
| Launch committed | The validated launch enters active flight; this does not claim engine ignition. |
| M01–M04 opening | The loaded mission ID; openings give instructions without claiming an objective has already happened. |
| Ignition | Measured `fuel_burned_kg` increases; queued speech additionally requires positive throttle and fuel. It never claims full thrust. |
| Liftoff | Attempt began in `READY` on the surface, then becomes `FLYING`, with altitude above 1 m and positive radial speed. Airborne lunar scenarios do not get this call. |
| Stage separation | `active_stage` actually advances to a fitted stage. Current builds have at most two stages; the call plays once per attempt. |
| Engine cutoff | Earlier measured fuel burn, then positive throttle becomes zero on the same stage with fuel still aboard. No timed MECO or coast assertion. |
| Landing legs deployed | Fitted legs change from retracted to deployed in telemetry. Altitude alone never triggers this claim. |
| Fuel below 25%; below 10% | `fuel_fraction` crosses strictly below that threshold with fuel remaining. Exactly 25% or 10% is not described as below. A step skipping both bands gets only the critical warning. |
| Propellant exhausted | Total `fuel_remaining_kg` reaches zero from a positive value. An empty active stage with upper-stage fuel is not total depletion. |
| Fifty kilometers crossed | Earth altitude crosses 50,000 m while ascending. The call expires at 100,000 m, on descent, or near another body. |
| Below 1,000 / 100 / 30 / 10 m | M04 descends past the actual lunar altitude threshold. Crossing several bands in one warp step keeps only the lowest live call. No timed 5–3–1 or contact-light countdown. |
| Descent speed warning | M04 is descending below 1,000 m and measured radial speed exceeds the effective contact limit. |
| Landing gear warning | M04 descends below 100 m with fitted legs still retracted. Deploying them removes queued/current warnings. |
| Mission-specific victory | `MissionManager` returns `MissionResult.Outcome.SUCCESS`; the voice layer never independently decides orbit hold, flyby success, or touchdown success. |
| Impact / vehicle lost | Simulator status is `CRASHED`, or the report contains the authoritative crash reason. |
| Objective not achieved | A confirmed failed result, including a manual early end or missed survey corridor. These failures do not imply vehicle loss. |

The collision model currently requires at most **8 m/s vertical, 5 m/s sideways, 20 degrees tilt, deployed legs**, and an intact pod for a safe contact. M04's JSON currently lists 20/15 m/s while some prose lists 8/5. Narration uses the stricter actual collision limit for its descent warning and waits for the authoritative result for success. This voiceover change does not alter mission or physics rules.

No Max Q, heating, engine temperature, structural damage, automated guidance, trajectory correctness, increasing lunar influence, or generic “all systems nominal” messages are included. Those assertions are not backed by the present simulator. No artificial launch delay or countdown was added.

## Regeneration and validation

The initial audio was generated through [ElevenLabs' documented text-to-speech endpoint](https://elevenlabs.io/docs/api-reference/text-to-speech/convert). The original female-voice MP3s are retained for inexpensive effect adjustments; the game loads the processed `.radio.wav` files. Together the source and processed clips total approximately 5.1 MB.

Run `python scripts/audio/generate_voiceover.py --check` to check every cached clip against the approved script/settings fingerprint without making a network request. To regenerate a changed or missing clip, set `ELEVENLABS_API_KEY` in the invoking process environment and run `python scripts/audio/generate_voiceover.py --clip CLIP_ID`. Running without `--clip` processes all entries and reuses matching audio. To change only the radio effect, edit `radio_processing` in the manifest and run `python scripts/audio/generate_voiceover.py --process-only`; this makes no API calls. Radio processing requires ffmpeg during development, while the game has no ffmpeg dependency. Separate source and radio fingerprints prevent an EQ adjustment from spending TTS credits. The script never accepts or prints an API key argument. A key only needs text-to-speech access; voice-list permissions are not needed for the configured default narrator.

After adding audio, import with Godot and run:

```text
godot --headless --editor --path . --import
godot --headless --path . --script res://tests/test_mission_voiceover.gd
godot --headless --path . --script res://tests/test_menu_flow.gd
godot --headless --path . --script res://tests/test_campaign_missions.gd
```

For subtitle-layout screenshots, run the voiceover test without `--headless` and add `-- --capture`. On Windows, `--rendering-driver opengl3_angle` avoids the native OpenGL resize issue observed during previous UI QA. Captures go to `exports/qa/voiceover/`.
