defmodule FireSense.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        # Children for all targets
        # Starts a worker by calling: FireSense.Worker.start_link(arg)
        # {FireSense.Worker, arg},
      ] ++ target_children()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: FireSense.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # List all child processes to be supervised
  if Mix.target() == :host do
    defp target_children() do
      if Mix.env() == :test do
        []
      else
        [
          {FireSense.Recorder,
           ifname: "fake0",
           data_dir: Application.get_env(:fire_sense, :data_dir, "tmp/sessions"),
           interval_ms: 50,
           poller: {FireSense.FakeSignal, :poll}},
          {Bandit, plug: FireSense.Web, port: Application.get_env(:fire_sense, :web_port, 4000)}
        ]
      end
    end
  else
    defp target_children() do
      ifname = Application.get_env(:fire_sense, :ifname, "wlan0")

      [
        {FireSense.Pinger, ifname: ifname, interval_ms: 10},
        {FireSense.Recorder,
         ifname: ifname,
         data_dir: Application.get_env(:fire_sense, :data_dir, "/data/sessions"),
         interval_ms: 50,
         poller: {VintageNetWiFi.WPASupplicant, :signal_poll}},
        {Bandit, plug: FireSense.Web, port: 80}
      ]
    end
  end
end
