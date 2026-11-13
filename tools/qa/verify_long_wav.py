"""Recreate the 30-minute WAV and verify the exported one-second interval."""
from pathlib import Path
import hashlib
import struct
import sys
import wave

ROOT = Path(__file__).resolve().parents[2]
RATE = 44100


def generate(directory):
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / "VoxCarve-QA-30min.wav"
    second = struct.pack("<441h", *(1500 if i % 21 < 10 else -1500 for i in range(441))) * 100
    silence = bytes(len(second))
    with wave.open(str(path), "wb") as output:
        output.setparams((1, 2, RATE, 0, "NONE", ""))
        for index in range(1800):
            output.writeframesraw(silence if index == 900 else second)
    return path


def digest(path):
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def verify(source, exported):
    with wave.open(str(exported), "rb") as actual, wave.open(str(source), "rb") as original:
        assert (actual.getframerate(), actual.getnchannels(), actual.getsampwidth(), actual.getnframes()) == (RATE, 1, 2, RATE)
        original.setpos(900 * RATE)
        assert actual.readframes(RATE) == original.readframes(RATE) == bytes(RATE * 2)
    print(f"{source.name}: {source.stat().st_size} bytes, SHA-256 {digest(source)}")
    print(f"{exported.name}: {exported.stat().st_size} bytes, SHA-256 {digest(exported)}")
    print("44100 output frames match source PCM [900, 901) seconds exactly.")


if __name__ == "__main__":
    directory = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / ".artifacts/stage06"
    verify(generate(directory), ROOT / "docs/dev/exports/stage06-long-cut.wav")
