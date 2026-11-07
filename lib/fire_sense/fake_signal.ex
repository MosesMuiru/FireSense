defmodule FireSense.FakeSignal do
  @moduledoc """
  Synthetic Wi-Fi signal for previewing the dashboard on a laptop
  (`iex -S mix`). Not used on the Pi.

  Produces about -52 dBm with noise, and for 30 s out of every 90 s adds a
  5 Hz flicker and extra jitter, roughly what a small flame might look like.
  """

  def poll(_ifname) do
    t = System.os_time(:millisecond) / 1000
    fire? = rem(trunc(t), 90) < 30

    flicker =
      if fire?, do: 2.5 * :math.sin(2 * :math.pi() * 5 * t) + :rand.normal() * 1.5, else: 0

    signal = round(-52 + :rand.normal() * 0.6 + flicker)

    {:ok, %{signal_dbm: signal, linkspeed: 72, frequency: 2437, width: "20 MHz"}}
  end
end
