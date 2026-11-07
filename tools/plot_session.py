#!/usr/bin/env python3
"""Plot a FireSense session folder copied from the Pi.

Usage:  python3 tools/plot_session.py sessions/20261107_150000
Saves plot.png in the session folder: signal, 2 s variability, link speed and
ping replies, with your event marks as red dashed lines.
"""
import sys
from pathlib import Path
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

folder = Path(sys.argv[1])
df = pd.read_csv(folder / "wifi.csv").apply(pd.to_numeric, errors="coerce")
t0 = df["time"].iloc[0]
df["t"] = df["time"] - t0
df["variability"] = df["signal_dbm"].rolling(20, min_periods=5).std()  # 2 s at 10 Hz
ev = pd.read_csv(folder / "events.csv")
ev["t"] = ev["time"] - t0

fig, ax = plt.subplots(4, 1, figsize=(12, 10), sharex=True)
ax[0].plot(df["t"], df["signal_dbm"], lw=0.8); ax[0].set_ylabel("signal (dBm)")
ax[1].plot(df["t"], df["variability"], lw=1, color="tab:orange"); ax[1].set_ylabel("variability (dB)")
ax[2].plot(df["t"], df["linkspeed_mbps"], lw=0.8, color="tab:green"); ax[2].set_ylabel("link speed (Mbit/s)")
ax[3].plot(df["t"], df["ping_replies"], lw=0.8, color="tab:purple"); ax[3].set_ylabel("ping replies / 100 ms")
ax[3].set_xlabel("seconds")
for _, e in ev.iterrows():
    for a in ax:
        a.axvline(e["t"], color="red", lw=0.8, ls="--")
    ax[0].annotate(str(e["note"]), (e["t"], 1), xycoords=("data", "axes fraction"),
                   color="red", rotation=90, va="top", fontsize=8)
fig.tight_layout()
fig.savefig(folder / "plot.png", dpi=120)
print(f"Saved {folder / 'plot.png'}")
