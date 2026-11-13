"""Verify two WAV exports produced by VoxCarve on the emulator."""
from pathlib import Path
import hashlib
import wave

ROOT = Path(__file__).resolve().parents[2]
INPUTS = ROOT / "entry/src/main/resources/rawfile"
OUTPUTS = ROOT / "docs/dev/exports"


def verify(source_name, output_name):
    source = INPUTS / source_name
    output = OUTPUTS / output_name
    with wave.open(str(source), "rb") as wav:
        rate = wav.getframerate()
        channels = wav.getnchannels()
        width = wav.getsampwidth()
        original = wav.readframes(wav.getnframes())
    frame_size = channels * width
    cut_start = rate // 2 * frame_size
    cut_end = rate * frame_size
    assert not any(original[cut_start:cut_end]), "Fixture silence is missing"
    expected = original[:cut_start] + original[cut_end:]
    with wave.open(str(output), "rb") as wav:
        assert (wav.getframerate(), wav.getnchannels(), wav.getsampwidth()) == (rate, channels, width)
        frames = wav.getnframes()
        assert frames == rate * 3 // 2
        actual = wav.readframes(frames)
        assert actual == expected, "Export differs from source PCM outside the cut"
    output_hash = hashlib.sha256(output.read_bytes()).hexdigest()
    source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
    print(f"{output.name}: {rate} Hz, {channels} ch, {frames} frames, {frames / rate:.3f} s, {output.stat().st_size} bytes")
    print(f"  Export SHA256: {output_hash}")
    print(f"  Input SHA256:  {source_hash}")
    print("  PCM matches the concatenation of [0, 0.5) s and [1.0, 2.0) s byte-for-byte.")


if __name__ == "__main__":
    verify("mono-16k.wav", "mono-cut.wav")
    verify("stereo-48k.wav", "stereo-cut.wav")
