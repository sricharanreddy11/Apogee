"""Development-only ElevenLabs generation and offline radio processing.

Set ELEVENLABS_API_KEY in the invoking process; never pass it as a CLI argument.
By default reuse matching clips. --check verifies cache hashes without network.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import urllib.error
import urllib.request


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "data" / "mission_voiceover.json"
DESTINATION = ROOT / "assets" / "audio" / "voiceover"


def fingerprint(value):
    encoded = json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def process_radio(source, target, profile):
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        raise RuntimeError("Install ffmpeg to process the radio voice. The game itself does not need ffmpeg.")
    filters = ",".join([
        f"highpass=f={profile['highpass_hz']}",
        f"lowpass=f={profile['lowpass_hz']}",
        f"equalizer=f={profile['presence_hz']}:t=q:w=1:g={profile['presence_gain_db']}",
        f"acompressor=threshold={profile['compression_threshold']}:ratio={profile['compression_ratio']}:attack=3:release=70:makeup={profile['compression_makeup']}",
        f"volume={profile['saturation_drive']}",
        f"asoftclip=type=tanh:threshold={profile['saturation_threshold']}:oversample=4",
        f"acrusher=bits={profile['crusher_bits']}:mix={profile['crusher_mix']}:samples=2",
        f"highpass=f={profile['highpass_hz']}",
        f"lowpass=f={profile['lowpass_hz']}",
        f"tremolo=f={profile['flutter_hz']}:d={profile['flutter_depth']}",
        f"volume={profile['output_gain']}",
    ])
    # Each offline transmission includes its opening and closing key clicks.
    # The voice controls static duration; the two short clicks add 170 ms.
    rate = profile["sample_rate_hz"]
    click_gain = profile["click_amplitude"]
    opening_seconds = profile["opening_click_ms"] / 1000.0
    closing_seconds = profile["closing_click_ms"] / 1000.0
    graph = (
        f"[0:a]{filters}[voice];"
        f"anoisesrc=color=white:amplitude={profile['static_amplitude']}:sample_rate={profile['sample_rate_hz']}:seed=2718,"
        "highpass=f=650,lowpass=f=3600[static];"
        "[voice][static]amix=inputs=2:duration=first:dropout_transition=0:normalize=0,"
        f"aresample={rate},aformat=sample_fmts=fltp:channel_layouts=mono,afade=t=in:d=0.008[body];"
        # Two brief transients give the key a mechanical snap and latch rather
        # than a sustained electronic tone or a burst of hiss.
        f"aevalsrc='{click_gain}*((0.65*sin(2*PI*2100*t)+0.25*sin(2*PI*4200*t))*exp(-t/0.0018)"
        "+0.08*(2*random(0)-1)*exp(-t/0.004)"
        f"+0.55*gte(t,0.018)*(0.7*sin(2*PI*1250*(t-0.018))+0.3*sin(2*PI*3100*(t-0.018)))*exp(-max(t-0.018,0)/0.0028))':s={rate}:d={opening_seconds},"
        "highpass=f=300,lowpass=f=6800,afade=t=in:d=0.0003[open];"
        f"aevalsrc='{click_gain}*((0.7*sin(2*PI*1700*t)+0.25*sin(2*PI*3600*t))*exp(-t/0.0022)"
        "+0.08*(2*random(0)-1)*exp(-t/0.005)"
        f"+0.6*gte(t,0.024)*(0.65*sin(2*PI*950*(t-0.024))+0.35*sin(2*PI*2800*(t-0.024)))*exp(-max(t-0.024,0)/0.0025))':s={rate}:d={closing_seconds},"
        "highpass=f=300,lowpass=f=6800,afade=t=in:d=0.0003[close];"
        "[open][body][close]concat=n=3:v=0:a=1,alimiter=limit=0.89:level=0:latency=1[out]"
    )
    subprocess.run([
        ffmpeg, "-y", "-v", "error", "-i", str(source), "-filter_complex", graph, "-map", "[out]",
        "-ar", str(profile["sample_rate_hz"]), "-ac", "1", "-c:a", "pcm_s16le", str(target),
    ], check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Check files and fingerprints without generating")
    parser.add_argument("--clip", action="append", help="Generate/check only a named clip (repeatable)")
    parser.add_argument("--process-only", action="store_true", help="Apply radio processing to matching cached sources without API access")
    args = parser.parse_args()
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    settings = {name: manifest[name] for name in ("voice_id", "model_id", "output_format", "voice_settings")}
    radio_profile = manifest["radio_processing"]
    metadata_path = DESTINATION / "generation.json"
    metadata = json.loads(metadata_path.read_text(encoding="utf-8")) if metadata_path.exists() else {}
    fingerprints = metadata.get("clips", {})
    selected = args.clip or list(manifest["clips"])
    failures = 0
    for clip_id in selected:
        if clip_id not in manifest["clips"]:
            print(f"Unknown clip: {clip_id}", file=sys.stderr)
            return 1
        text = manifest["clips"][clip_id]["text"]
        source_hash = fingerprint({**settings, "text": text})
        radio_hash = fingerprint({"version": 4, "source_sha256": source_hash, "radio_processing": radio_profile})
        target = DESTINATION / f"{clip_id}.mp3"
        radio_target = DESTINATION / f"{clip_id}.radio.wav"
        cached = fingerprints.get(clip_id, {})
        source_matches = target.exists() and target.stat().st_size > 1000 and cached.get("sha256") == source_hash and cached.get("bytes") == target.stat().st_size
        radio_matches = radio_target.exists() and radio_target.stat().st_size > 1000 and cached.get("radio_input_sha256") == radio_hash and cached.get("radio_bytes") == radio_target.stat().st_size
        if source_matches and radio_matches:
            print(f"Cached: {clip_id}")
            continue
        if args.check:
            failures += 1
            print(f"Missing or outdated: {clip_id}", file=sys.stderr)
            continue
        if source_matches:
            try:
                process_radio(target, radio_target, radio_profile)
            except (RuntimeError, subprocess.CalledProcessError) as error:
                print(f"Radio processing failed for {clip_id}: {error}", file=sys.stderr)
                return 1
            fingerprints[clip_id] = {**cached, "radio_input_sha256": radio_hash, "radio_bytes": radio_target.stat().st_size}
            metadata_path.write_text(json.dumps({"provider": "ElevenLabs", **settings, "radio_processing": radio_profile, "clips": fingerprints}, indent=2) + "\n", encoding="utf-8")
            print(f"Processed radio: {clip_id}")
            continue
        if args.process_only:
            print(f"Matching source required for {clip_id}; run generation first.", file=sys.stderr)
            return 1
        key = os.environ.get("ELEVENLABS_API_KEY")
        if not key:
            print("Set ELEVENLABS_API_KEY in the process environment before generating.", file=sys.stderr)
            return 1
        payload = {"text": text, "model_id": settings["model_id"], "voice_settings": settings["voice_settings"]}
        request = urllib.request.Request(
            f"https://api.elevenlabs.io/v1/text-to-speech/{settings['voice_id']}?output_format={settings['output_format']}",
            data=json.dumps(payload).encode("utf-8"),
            headers={"xi-api-key": key, "Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=45) as response:
                if not response.headers.get_content_type().startswith("audio/"):
                    print(f"No audio returned for {clip_id}.", file=sys.stderr)
                    return 1
                audio = response.read()
        except urllib.error.HTTPError as error:
            # Do not print request headers, credential values, or response bodies.
            print(f"ElevenLabs rejected {clip_id}: HTTP {error.code}.", file=sys.stderr)
            return 1
        except (urllib.error.URLError, TimeoutError):
            print(f"Could not reach ElevenLabs for {clip_id}.", file=sys.stderr)
            return 1
        if len(audio) < 1000:
            print(f"Audio is unexpectedly short for {clip_id}.", file=sys.stderr)
            return 1
        DESTINATION.mkdir(parents=True, exist_ok=True)
        target.write_bytes(audio)
        fingerprints[clip_id] = {"sha256": source_hash, "bytes": len(audio)}
        # Save the source fingerprint first so a processing failure never causes
        # another paid TTS request when the command is retried.
        metadata_path.write_text(json.dumps({"provider": "ElevenLabs", **settings, "radio_processing": radio_profile, "clips": fingerprints}, indent=2) + "\n", encoding="utf-8")
        try:
            process_radio(target, radio_target, radio_profile)
        except (RuntimeError, subprocess.CalledProcessError) as error:
            print(f"Radio processing failed for {clip_id}: {error}", file=sys.stderr)
            return 1
        fingerprints[clip_id].update({"radio_input_sha256": radio_hash, "radio_bytes": radio_target.stat().st_size})
        metadata_path.write_text(json.dumps({"provider": "ElevenLabs", **settings, "radio_processing": radio_profile, "clips": fingerprints}, indent=2) + "\n", encoding="utf-8")
        print(f"Generated: {clip_id}")
    print(f"Voiceover cache: {len(selected)} clips, {failures} missing/outdated.")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
