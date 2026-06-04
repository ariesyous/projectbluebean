import wave
import struct
import math
import random

SAMPLE_RATE = 44100

def save_wav(filename, samples):
    with wave.open(filename, 'w') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        for s in samples:
            # Clamp and convert to 16-bit integer
            val = int(max(-1.0, min(1.0, s)) * 32767)
            w.writeframesraw(struct.pack('<h', val))

def generate_staff_fire():
    # A descending sine sweep (pew)
    samples = []
    duration = 0.3
    freq_start = 1200.0
    freq_end = 200.0
    for i in range(int(SAMPLE_RATE * duration)):
        t = i / SAMPLE_RATE
        # Exponential frequency decay
        freq = freq_start * ((freq_end/freq_start) ** (t/duration))
        # Envelope
        env = max(0, 1.0 - t/duration)
        val = math.sin(2 * math.pi * freq * t) * env * 0.5
        samples.append(val)
    return samples

def generate_crossbow_fire():
    # A short snappy noise burst mixed with a punchy sine
    samples = []
    duration = 0.2
    for i in range(int(SAMPLE_RATE * duration)):
        t = i / SAMPLE_RATE
        env = max(0, 1.0 - (t/duration)**0.5)
        noise = random.uniform(-1, 1) * 0.4
        sine = math.sin(2 * math.pi * max(50, 400 - 3000*t) * t) * 0.6
        samples.append((noise + sine) * env * 0.8)
    return samples

def generate_axe_throw():
    # A mid-frequency whoosh
    samples = []
    duration = 0.4
    for i in range(int(SAMPLE_RATE * duration)):
        t = i / SAMPLE_RATE
        # Bell curve envelope
        env = math.sin(math.pi * t / duration)
        noise = random.uniform(-1, 1)
        # Low pass filter effect on noise (simplified)
        val = noise * env * 0.4
        samples.append(val)
    return samples

def generate_impact():
    # Short crunch
    samples = []
    duration = 0.15
    for i in range(int(SAMPLE_RATE * duration)):
        t = i / SAMPLE_RATE
        env = max(0, 1.0 - t/duration) ** 2
        noise = random.uniform(-1, 1)
        samples.append(noise * env * 0.6)
    return samples

def generate_reload():
    # Mechanical clack: two short bursts
    samples = []
    duration = 0.3
    for i in range(int(SAMPLE_RATE * duration)):
        t = i / SAMPLE_RATE
        # Two distinct envelope peaks
        env1 = max(0, 1.0 - t/0.05) if t < 0.05 else 0
        env2 = max(0, 1.0 - (t-0.15)/0.05) if 0.15 <= t < 0.2 else 0
        env = env1 + env2
        noise = random.uniform(-1, 1)
        sine = math.sin(2 * math.pi * 800 * t) * 0.5
        samples.append((noise * 0.5 + sine) * env * 0.6)
    return samples

def main():
    base_dir = "C:/Users/sith/Code/projectbluebean/projectbluebean/assets/sounds"
    save_wav(f"{base_dir}/staff_fire.wav", generate_staff_fire())
    save_wav(f"{base_dir}/crossbow_fire.wav", generate_crossbow_fire())
    save_wav(f"{base_dir}/axe_throw.wav", generate_axe_throw())
    save_wav(f"{base_dir}/impact.wav", generate_impact())
    save_wav(f"{base_dir}/reload.wav", generate_reload())
    print("Generated 5 procedural audio files.")

if __name__ == "__main__":
    main()
