defmodule FireSense.Recorder do
  @moduledoc """
  Samples the Wi-Fi signal continuously and keeps the last five minutes in
  memory for the live dashboard. While a session is active, every sample and
  event note is also written to CSV.

  Each tick asks the configured poller (wpa_supplicant on the Pi) for the
  current signal (RSSI, link speed, frequency, channel width) and the pinger
  for how many echo replies arrived since the previous tick.

  Session files live in `<data_dir>/<session>/wifi.csv` and `events.csv`.
  """
  use GenServer
  require Logger

  @wifi_header "time,signal_dbm,linkspeed_mbps,frequency_mhz,width,ping_replies\n"
  @events_header "time,note\n"
  @max_events 500

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def start_session(name \\ nil), do: GenServer.call(__MODULE__, {:start, name})
  def stop_session, do: GenServer.call(__MODULE__, :stop)
  def mark(note), do: GenServer.call(__MODULE__, {:mark, note})
  def status, do: GenServer.call(__MODULE__, :status)

  @doc "Samples and events newer than `t` (Unix seconds)."
  def since(t), do: GenServer.call(__MODULE__, {:since, t})

  @impl true
  def init(opts) do
    interval = Keyword.get(opts, :interval_ms, 50)

    state = %{
      ifname: Keyword.fetch!(opts, :ifname),
      data_dir: Keyword.fetch!(opts, :data_dir),
      interval: interval,
      poller: Keyword.fetch!(opts, :poller),
      buffer: :queue.new(),
      buffer_len: 0,
      buffer_max: div(300_000, interval),
      events: [],
      session: nil,
      wifi: nil,
      events_file: nil,
      rows: 0,
      last: nil
    }

    send(self(), :tick)
    {:ok, state}
  end

  @impl true
  def handle_call({:start, _name}, _from, %{session: s} = state) when s != nil,
    do: {:reply, {:error, {:already_recording, s}}, state}

  def handle_call({:start, name}, _from, state) do
    session = name || Calendar.strftime(DateTime.utc_now(), "%Y%m%d_%H%M%S")
    dir = Path.join(state.data_dir, session)
    File.mkdir_p!(dir)
    wifi = File.open!(Path.join(dir, "wifi.csv"), [:write, :utf8])
    events = File.open!(Path.join(dir, "events.csv"), [:write, :utf8])
    IO.write(wifi, @wifi_header)
    IO.write(events, @events_header)
    Logger.info("Recording session #{session} in #{dir}")

    {:reply, {:ok, dir}, %{state | session: session, wifi: wifi, events_file: events, rows: 0}}
  end

  def handle_call(:stop, _from, %{session: nil} = state),
    do: {:reply, {:error, :not_recording}, state}

  def handle_call(:stop, _from, state) do
    File.close(state.wifi)
    File.close(state.events_file)
    result = {:ok, %{session: state.session, rows: state.rows}}
    {:reply, result, %{state | session: nil, wifi: nil, events_file: nil}}
  end

  def handle_call({:mark, note}, _from, state) do
    note = csv_safe(note)
    t = now()
    if state.events_file, do: IO.write(state.events_file, "#{fmt(t)},#{note}\n")
    events = Enum.take([%{t: t, note: note} | state.events], @max_events)
    {:reply, :ok, %{state | events: events}}
  end

  def handle_call(:status, _from, state) do
    {:reply, %{session: state.session, rows: state.rows, last: state.last}, state}
  end

  def handle_call({:since, t}, _from, state) do
    samples =
      state.buffer
      |> :queue.to_list()
      |> Enum.filter(fn [st | _] -> st > t end)

    events = state.events |> Enum.filter(&(&1.t > t)) |> Enum.reverse()
    {:reply, %{samples: samples, events: events}, state}
  end

  @impl true
  def handle_info(:tick, state) do
    Process.send_after(self(), :tick, state.interval)
    {mod, fun} = state.poller

    {signal, speed, freq, width} =
      case apply(mod, fun, [state.ifname]) do
        {:ok, info} -> {info.signal_dbm, info.linkspeed, info.frequency, info.width}
        {:error, _} -> {nil, nil, nil, nil}
      end

    t = now()
    replies = take_replies()
    state = push(state, [t, signal, speed, replies])

    state =
      if state.wifi do
        line = Enum.map_join([fmt(t), signal, speed, freq, width, replies], ",", &to_string/1)
        IO.write(state.wifi, line <> "\n")
        %{state | rows: state.rows + 1, last: line}
      else
        %{state | last: {signal, speed, replies}}
      end

    {:noreply, state}
  end

  defp push(%{buffer_len: n, buffer_max: max} = state, sample) when n >= max do
    {_, q} = :queue.out(state.buffer)
    %{state | buffer: :queue.in(sample, q)}
  end

  defp push(state, sample),
    do: %{state | buffer: :queue.in(sample, state.buffer), buffer_len: state.buffer_len + 1}

  defp take_replies do
    if Process.whereis(FireSense.Pinger), do: FireSense.Pinger.take_replies(), else: 0
  end

  defp now, do: System.os_time(:millisecond) / 1000
  defp fmt(t), do: :erlang.float_to_binary(t, decimals: 3)
  defp csv_safe(note), do: note |> to_string() |> String.replace([",", "\n", "\r"], " ")
end
