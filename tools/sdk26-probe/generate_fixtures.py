"""Generate two deterministic local PCM fixtures with a tone and a silence interval."""
from pathlib import Path
import struct
import wave


def generate(path, rate, channels):
    frames = bytearray()
    for i in range(rate * 2):
        for channel in range(channels):
            period = rate // (220 * (channel + 1))
            phase = i % period
            sample = (phase * 16000 // period) - 8000
            if rate // 2 <= i < rate:
                sample = 0
            frames.extend(struct.pack("<h", sample))
    with wave.open(str(path), "wb") as target:
        target.setparams((channels, 2, rate, 0, "NONE", "not compressed"))
        target.writeframes(frames)


if __name__ == "__main__":
    destination = Path(__file__).resolve().parents[2] / "entry" / "src" / "main" / "resources" / "rawfile"
    destination.mkdir(parents=True, exist_ok=True)
    generate(destination / "mono-16k.wav", 16000, 1)
    generate(destination / "stereo-48k.wav", 48000, 2)
