# FireSense

Wi-Fi fire detection experiments on a Raspberry Pi 5, built with Nerves.
The Pi joins your router over Wi-Fi, pings it 100 times a second so the radio
always has traffic, and logs the signal 10 times a second to CSV.

## Build and burn

```bash
export MIX_TARGET=rpi5
export WIFI_SSID="YourRouterName" WIFI_PSK="your-password" WIFI_COUNTRY="KE"
mix deps.get
mix firmware
mix burn            # with the Pi 5's microSD card in your computer
```

Later updates over the network: `mix upload nerves.local`.

## Live dashboard

Open http://nerves.local in a browser on the same network: live graphs of signal,
variability, flicker spectrum and link health, buttons to record and mark events,
and a baseline comparison that flags fire-like flicker.

Preview it on a laptop with fake data: `iex -S mix`, then http://localhost:4000.

## Record a session

```bash
ssh nerves.local
```

```elixir
FireSense.start()          # begins recording to /data/sessions/<timestamp>
FireSense.mark("quiet")    # note each event as it happens
FireSense.mark("walk")
FireSense.status()         # latest reading, row count
FireSense.stop()
```

Check the Wi-Fi link first: `VintageNet.info()` should show wlan0 connected.

## Plot

```bash
scp -r nerves.local:/data/sessions .
python3 tools/plot_session.py sessions/<timestamp>
```

## Data

`wifi.csv`: time, signal_dbm, linkspeed_mbps, frequency_mhz, width, ping_replies (per 100 ms)
`events.csv`: time, note
