#!/usr/bin/env python3
"""Rank candidate SFX by how much of their energy sits in the fatiguing band.

No numpy on this box, so band energy is measured with ffmpeg filters rather than
an FFT: full-band RMS compared against RMS after a steep band filter.

Two caveats learned the hard way:
  * astats prints at info level, so ffmpeg must NOT be run with -v error or the
    stats never appear and every clip reads as silence.
  * a single lowpass/highpass is only 12 dB/octave, which is far too gentle to
    separate a laser zap from a bass thump. The filters are chained three times
    (~36 dB/octave) so the numbers actually discriminate.

Columns:
  hi_2k   RMS after highpass 2 kHz, relative to full-band RMS. Near 0 means the
          clip is dominated by the bright band that gets fatiguing on repeat.
          Very negative means little top end.
  lo_500  RMS after lowpass 500 Hz, relative to full-band RMS. Near 0 means the
          clip's weight is in the low band.

Calibration (see --selftest): a 150 Hz tone reads lo_500 ~0 / hi_2k ~ -75,
a 4 kHz tone reads the reverse.
"""
import subprocess
import sys
import re

LOW = "lowpass=f=500,lowpass=f=500,lowpass=f=500"
HIGH = "highpass=f=2000,highpass=f=2000,highpass=f=2000"


def _stats(path, filt=None):
    chain = []
    if filt:
        chain.append(filt)
    chain.append("astats=measure_perchannel=none")
    cmd = ["ffmpeg", "-hide_banner", "-i", path,
           "-af", ",".join(chain), "-f", "null", "-"]
    return subprocess.run(cmd, capture_output=True, text=True).stderr


def _val(out, label):
    m = re.search(r"%s:\s*(-?[\d.]+|-?inf)" % re.escape(label), out)
    if not m or "inf" in m.group(1):
        return -120.0
    return float(m.group(1))


def rms(path, filt=None):
    return _val(_stats(path, filt), "RMS level dB")


def peak(path):
    return _val(_stats(path), "Peak level dB")


def duration(path):
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "default=nw=1:nk=1", path],
        capture_output=True, text=True).stdout.strip()
    try:
        return float(out)
    except ValueError:
        return 0.0


def main():
    paths = sys.argv[1:]
    rows = []
    for path in paths:
        full = rms(path)
        rows.append({
            "name": path.split("/")[-1],
            "dur": duration(path),
            "rms": full,
            "peak": peak(path),
            "lo": rms(path, LOW) - full,
            "hi": rms(path, HIGH) - full,
        })
    # Darkest first: least high-band energy at the top.
    rows.sort(key=lambda r: r["hi"])
    print(f"{'clip':<44}{'dur_s':>7}{'rms_dB':>9}{'peak_dB':>9}{'hi_2k':>8}{'lo_500':>8}")
    for r in rows:
        print(f"{r['name']:<44}{r['dur']:>7.2f}{r['rms']:>9.1f}"
              f"{r['peak']:>9.1f}{r['hi']:>8.1f}{r['lo']:>8.1f}")


if __name__ == "__main__":
    main()
