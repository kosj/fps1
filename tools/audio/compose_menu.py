"""시작 화면 음악(이음매 없는 반복 32초)을 numpy로 합성한다.

python3 tools/audio/compose_menu.py game/audio/music/menu_loop.ogg

어두운 군대풍 분위기: A 단조, 90 BPM, 12마디.
- 현악 패드: 약간씩 음정을 어긋낸 톱니파 여러 개를 저역 통과 필터로 깎는다(Am - F - C - G, 마디 셋씩).
- 베이스: 8분음 반복 음형, 저역 통과 필터가 음마다 열렸다 닫힌다.
- 북: 음정이 떨어지는 사인파와 잡음 덩어리로 만든 타이코 비슷한 소리.
- 잔향: 지수적으로 줄어드는 잡음 임펄스와 원형 합성곱. 끝의 잔향이 처음으로 이어져 이음매가 없다.
"""

import subprocess
import sys

import numpy as np

RATE = 44100
BPM = 90.0
BARS = 12
BEAT = 60.0 / BPM
LENGTH = int(round(BARS * 4 * BEAT * RATE))
rng = np.random.default_rng(7)


def note(name_midi):
    return 440.0 * 2.0 ** ((name_midi - 69) / 12.0)


def lowpass(signal, cutoff, circular=False):
    """한 극 저역 통과. cutoff는 표본마다 달라도 된다(배열).
    circular이면 신호를 두 번 이어 걸러 뒤쪽 절반을 쓴다. 반복 재생할 때 필터 상태가 끊기지 않는다."""
    cutoff = np.broadcast_to(cutoff, signal.shape)
    if circular:
        doubled = lowpass(np.concatenate([signal, signal]), np.concatenate([cutoff, cutoff]))
        return doubled[len(signal):]
    alpha = 1.0 - np.exp(-2.0 * np.pi * cutoff / RATE)
    out = np.empty_like(signal)
    acc = 0.0
    for i in range(len(signal)):
        acc += alpha[i] * (signal[i] - acc)
        out[i] = acc
    return out


def saw(freq, length, phase=0.0):
    t = np.arange(length) / RATE
    return 2.0 * ((t * freq + phase) % 1.0) - 1.0


def pad_layer():
    chords = [[57, 60, 64], [53, 57, 60], [48, 55, 64], [55, 59, 62]]  # Am F C G
    out = np.zeros(LENGTH)
    span = int(3 * 4 * BEAT * RATE)
    for index, chord in enumerate(chords):
        start = index * span
        voice = np.zeros(span)
        for midi in chord:
            for detune in (-0.12, 0.0, 0.11):
                voice += saw(note(midi) * 2 ** (detune / 12.0), span, rng.random())
        env = np.ones(span)
        fade = int(1.2 * RATE)
        env[:fade] = np.linspace(0.0, 1.0, fade) ** 1.5
        env[-fade:] *= np.linspace(1.0, 0.0, fade) ** 0.7
        out[start:start + span] += voice * env
    sweep = 1500.0 + 600.0 * np.sin(2.0 * np.pi * np.arange(LENGTH) / LENGTH * 3.0)
    return lowpass(out, sweep, circular=True) * 0.085


def bass_layer():
    pattern = [45, 45, 45, 48, 45, 45, 43, 40]  # A A A C A A G E (8분음)
    roots = {0: 0, 1: -4, 2: -9, 3: -2}  # 화음마다 옮긴다
    eighth = int(BEAT / 2.0 * RATE)
    out = np.zeros(LENGTH)
    cutoff = np.full(LENGTH, 120.0)
    for step in range(LENGTH // eighth):
        bar = step // 8
        shift = roots[(bar // 3) % 4]
        midi = pattern[step % 8] + shift
        start = step * eighth
        tone = saw(note(midi), eighth) * 0.7 + np.sin(2 * np.pi * note(midi) * np.arange(eighth) / RATE)
        env = np.exp(-np.arange(eighth) / (0.16 * RATE))
        out[start:start + eighth] += tone * env
        cutoff[start:start + eighth] = 160.0 + 900.0 * np.exp(-np.arange(eighth) / (0.05 * RATE))
    return lowpass(out, cutoff, circular=True) * 0.32


def drum(length, pitch_from, pitch_to, decay):
    t = np.arange(length) / RATE
    freq = pitch_to + (pitch_from - pitch_to) * np.exp(-t / 0.05)
    body = np.sin(2.0 * np.pi * np.cumsum(freq) / RATE) * np.exp(-t / decay)
    noise = lowpass(rng.standard_normal(length), 1800.0) * np.exp(-t / 0.03) * 0.6
    return body + noise


def drum_layer():
    out = np.zeros(LENGTH)
    big = drum(int(1.2 * RATE), 110.0, 46.0, 0.35)
    small = drum(int(0.6 * RATE), 180.0, 90.0, 0.14)
    bar_len = 4 * BEAT
    for bar in range(BARS):
        hits = [(0.0, big, 1.0), (1.5, small, 0.45), (2.0, big, 0.7), (3.5, small, 0.35)]
        if bar % 4 == 3:
            hits += [(3.0, small, 0.5), (3.25, small, 0.55), (3.75, small, 0.6)]
        for beat, sound, gain in hits:
            start = int((bar * bar_len + beat * BEAT) * RATE)
            end = min(start + len(sound), LENGTH)
            out[start:end] += sound[: end - start] * gain
            # 반복할 때 마지막 마디의 북 꼬리가 처음으로 넘어가게 한다.
            spill = start + len(sound) - LENGTH
            if spill > 0:
                out[:spill] += sound[len(sound) - spill:] * gain
    return out * 0.42


def air_layer():
    noise = rng.standard_normal(LENGTH)
    swell = 0.5 + 0.5 * np.sin(2.0 * np.pi * np.arange(LENGTH) / LENGTH * 2.0 - np.pi / 2.0)
    high = noise - lowpass(noise, 3000.0, circular=True)
    return lowpass(high, 7000.0, circular=True) * swell * 0.012


def reverb(signal, seconds=2.2, mix=0.28):
    """원형 합성곱 잔향: 길이 LENGTH의 반복이라 꼬리가 처음으로 감겨 들어간다."""
    length = int(seconds * RATE)
    t = np.arange(length) / RATE
    impulse = rng.standard_normal(length) * np.exp(-t / (seconds / 6.9))
    # 잔향은 어둡게: 고역이 쉬익거리지 않게 두 번 깎는다.
    impulse = lowpass(lowpass(impulse, 3000.0), 3000.0)
    impulse /= np.sqrt(np.sum(impulse ** 2))
    kernel = np.zeros(LENGTH)
    kernel[:length] = impulse
    wet = np.real(np.fft.ifft(np.fft.fft(signal) * np.fft.fft(kernel)))
    return signal * (1.0 - mix) + wet * mix * 3.0


def main():
    out_path = sys.argv[1]
    mix = pad_layer() + bass_layer() + drum_layer() + air_layer()
    left = reverb(mix)
    right = reverb(np.roll(mix, int(0.011 * RATE)))
    stereo = np.stack([left, right], axis=1)
    stereo /= np.max(np.abs(stereo)) / 0.89
    raw = (stereo * 32767).astype(np.int16).tobytes()
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-f", "s16le", "-ar", str(RATE), "-ac", "2", "-i", "-",
         "-c:a", "libvorbis", "-q:a", "3", out_path],
        input=raw, check=True,
    )
    print("menu loop: %.2f s" % (LENGTH / RATE))


if __name__ == "__main__":
    main()
