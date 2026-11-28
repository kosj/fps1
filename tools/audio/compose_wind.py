"""눈 덮인 고지대의 바람 소리(이음매 없는 반복 20초)를 numpy로 합성한다.

python3 tools/audio/compose_wind.py game/audio/sfx/ambience_wind.ogg

- 바탕: 백색 잡음을 주파수 영역에서 깎아(낮은 쪽이 센 분홍 잡음, 1.5 kHz 위는 줄임) 만든 바람.
- 돌풍: 반복 길이의 약수 주기를 가진 느린 사인파 몇 개를 더한 세기 변화.
- 휘파람: 좁은 대역 잡음 세 줄기(약 420, 640, 910 Hz)가 각자 다른 돌풍을 따라 커졌다 작아진다.
- 주파수 영역에서 거르고 주기가 반복 길이의 약수인 변화만 쓰므로 끝이 처음으로 끊김 없이 이어진다.
- 좌우는 다른 잡음을 써서 넓게 들린다.
"""

import subprocess
import sys

import numpy as np

RATE = 44100
SECONDS = 20
LENGTH = RATE * SECONDS
rng = np.random.default_rng(11)


def shaped_noise(shape) -> np.ndarray:
    """백색 잡음의 스펙트럼에 shape(주파수 배열 -> 배율)를 곱해 되돌린다. 결과는 원형(반복) 신호다."""
    spectrum = np.fft.rfft(rng.standard_normal(LENGTH))
    freqs = np.fft.rfftfreq(LENGTH, 1.0 / RATE)
    signal = np.fft.irfft(spectrum * shape(freqs), LENGTH)
    return signal / (np.abs(signal).max() + 1e-9)


def gusts(count: int, depth: float) -> np.ndarray:
    """0~1 사이로 천천히 오르내리는 세기. 주기는 반복 길이를 정수로 나눈 값만 쓴다."""
    t = np.arange(LENGTH) / LENGTH
    total = np.zeros(LENGTH)
    for _ in range(count):
        cycles = rng.integers(1, 7)
        total += rng.uniform(0.4, 1.0) * np.sin(2.0 * np.pi * (cycles * t + rng.uniform()))
    total = (total - total.min()) / (total.max() - total.min() + 1e-9)
    return 1.0 - depth + depth * total


def band(center: float, width: float):
    return lambda f: np.exp(-0.5 * ((f - center) / width) ** 2)


def base_shape(f: np.ndarray) -> np.ndarray:
    pink = 1.0 / np.sqrt(np.maximum(f, 20.0))
    rolloff = 1.0 / (1.0 + (f / 1500.0) ** 2)
    highpass = (f / 60.0) ** 2 / (1.0 + (f / 60.0) ** 2)
    return pink * rolloff * highpass


def channel() -> np.ndarray:
    body = shaped_noise(base_shape) * gusts(4, 0.8) ** 1.5
    howl = np.zeros(LENGTH)
    for center, width, level in [(420.0, 22.0, 0.30), (640.0, 30.0, 0.24), (910.0, 40.0, 0.16)]:
        howl += level * shaped_noise(band(center, width)) * gusts(3, 0.95) ** 2
    return body + howl


def main() -> None:
    out_path = sys.argv[1]
    stereo = np.stack([channel(), channel()], axis=1)
    rms = np.sqrt(np.mean(stereo**2))
    stereo *= 10.0 ** (-16.0 / 20.0) / rms
    stereo = np.clip(stereo, -0.98, 0.98)
    pcm = (stereo * 32767.0).astype(np.int16).tobytes()
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-f", "s16le", "-ar", str(RATE), "-ac", "2", "-i", "-",
         "-c:a", "libvorbis", "-q:a", "1", out_path],
        input=pcm, check=True,
    )
    print("wrote", out_path)


if __name__ == "__main__":
    main()
