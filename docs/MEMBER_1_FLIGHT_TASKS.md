# Member 1 — Physics and flight task map

This task map keeps the simulation deliberately game-like: masses and distances are internally consistent, but they are scaled for short, readable play sessions. Earth is fixed at the system origin; the Moon follows a prescribed circular path; and the rocket is the only dynamically integrated vehicle.

## A. Physics foundation

- [x] A01 Read the selected `RocketConfig` without mutating the builder's copy.
- [x] A02 Resolve each configured part through `data/parts.json`.
- [x] A03 Calculate permanent dry mass, per-stage dry mass, and wet mass.
- [x] A04 Fill a separate fuel reservoir for every configured stage.
- [x] A05 Spawn surface missions at the active body's north surface.
- [x] A06 Add lunar-approach and lunar-descent spawn profiles.
- [x] A07 Advance motion with bounded 120 Hz substeps.
- [x] A08 Keep Earth stationary at the world origin.
- [x] A09 Move the Moon on a prescribed circular orbit around Earth.
- [x] A10 Apply gravity from Earth and the Moon to the rocket.
- [x] A11 Apply engine thrust along the rocket's heading.
- [x] A12 Consume fuel from only the active stage.
- [x] A13 Reduce vehicle mass as propellant is consumed.
- [x] A14 Rotate from the left/right steering command.
- [x] A15 Support continuous throttle and immediate engine cutoff.
- [x] A16 Detect contact with either celestial body.
- [x] A17 Hold an unpowered vehicle on its launch surface.
- [x] A18 Classify touchdown as safe or crashed from legs, speed, and tilt.
- [x] A19 Separate the lower stage and discard its dry mass and remaining fuel.
- [x] A20 Reject staging when no upper stage exists.

## B. Orbit and read-only flight data

- [x] B01 Publish detached position, velocity, heading, throttle, time, and status.
- [x] B02 Publish active-stage fuel remaining and whole-vehicle fuel fraction.
- [x] B03 Publish radial and tangential speed relative to the active body.
- [x] B04 Calculate bound-orbit apoapsis and periapsis from specific energy.
- [x] B05 Mark trajectories whose periapsis intersects the active body.
- [x] B06 Publish Earth/Moon positions and radii for the schematic map.
- [x] B07 Produce an unpowered coast prediction without altering live state.
- [x] B08 Stop a prediction when it intersects Earth or the Moon.

## C. Normal flight view

- [x] C01 Keep the assembled rocket centered at a fixed, non-zoomable scale.
- [x] C02 Reuse the builder's exact rocket art and stage arrangement.
- [x] C03 Animate only the active engine flame from live throttle.
- [x] C04 Rotate the displayed rocket from live heading.
- [x] C05 Make the active engine artwork clickable for ignition/cutoff.
- [x] C06 Make the separator artwork clickable for staging.
- [x] C07 Retain explicit buttons and keyboard controls as accessible fallbacks.

## D. Orbit view

- [x] D01 Switch between normal and orbit views with one button or Tab.
- [x] D02 Draw a compact, abstract Earth/Moon schematic.
- [x] D03 Draw the already-flown path separately from the prediction.
- [x] D04 Draw the coast prediction as a high-contrast route.
- [x] D05 Keep the rocket as a constant-size triangular cursor at every zoom.
- [x] D06 Clamp mouse-wheel zoom to a useful minimum and maximum.
- [x] D07 Focus the map on the mission's active body.

## E. Integration and verification

- [x] E01 Connect preflight Launch to the real Flight scene.
- [x] E02 Preserve the launch integration signal for other modules and tests.
- [x] E03 Feed one telemetry snapshot to HUD, map, artwork, and mission rules.
- [x] E04 Hand End Flight to the existing mission-report flow.
- [x] E05 Add focused tests for mass, fuel, thrust, rotation, cutoff, staging, Moon motion, lunar spawn, and prediction.
- [x] E06 Run the Godot 4.7.2 headless suite.
- [x] E07 Visually verify launch, fixed framing, thrust, view switching, map framing, and control readability in the live scene.

## F. Flight-feel follow-up

- [x] F01 Keep the active planet visible beneath the fixed-size rocket in normal view.
- [x] F02 Point the normal-view horizon toward the planet throughout ascent, orbit, and descent.
- [x] F03 Add click-and-drag panning to the orbit view.
- [x] F04 Keep the world point under the cursor fixed while orbit-view zoom changes.
- [x] F05 Recenter the orbit camera with right-click.
- [x] F06 Increase steering and throttle response for a snappier fictional flight model.
- [x] F07 Increase engine thrust and specific impulse for faster climbs and longer range.
- [x] F08 Add selectable 1x, 5x, 25x, and 50x simulation rates.
- [x] F09 Implement fast-forward by repeating unchanged simulation ticks at 1x, 5x, 25x, or 50x.
- [x] F10 Project one complete bound orbit or a full two-body-system escape window.
- [x] F11 Keep the projected path ballistic; live thrust changes velocity and refreshes the osculating orbit.
- [x] F12 Draw the Moon's translucent orbit around Earth.
- [x] F13 Apply both Earth's and the moving Moon's gravity throughout prediction so lunar encounters curve naturally.
- [x] F14 Use velocity-Verlet integration so elliptical orbits conserve energy and vary speed correctly.
- [x] F15 Derive the Moon's circular angular speed from Earth's gravitational parameter.
- [x] F16 Keep the map readable: bodies, Moon orbit, flown trail, projection, and rocket only.

Mission success/failure evaluation, rewards, unlocking, and report scoring remain Member 3 responsibilities. This module supplies the authoritative values they consume.
