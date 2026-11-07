defmodule FireSense.Pinger do
  @moduledoc """
  Sends ICMP echo requests to the router over Wi-Fi at a fixed rate so the
  radio always has packets to measure. The socket is bound to the Wi-Fi
  interface, so traffic never leaks onto Ethernet.

  Counts replies so the recorder can log packet loss alongside the signal.
  """
  use GenServer
  require Logger

  alias FireSense.ICMP

  @id 0xF15E

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc "Return and reset the number of echo replies received since the last call."
  def take_replies, do: GenServer.call(__MODULE__, :take_replies)

  @impl true
  def init(opts) do
    state = %{
      ifname: Keyword.fetch!(opts, :ifname),
      interval: Keyword.get(opts, :interval_ms, 10),
      socket: nil,
      target: nil,
      seq: 0,
      replies: 0
    }

    send(self(), :tick)
    {:ok, state}
  end

  @impl true
  def handle_call(:take_replies, _from, state), do: {:reply, state.replies, %{state | replies: 0}}

  @impl true
  def handle_info(:tick, state) do
    Process.send_after(self(), :tick, state.interval)
    {:noreply, state |> ensure_socket() |> drain() |> send_echo()}
  end

  defp ensure_socket(%{socket: nil} = state) do
    with {:ok, gw} <- FireSense.Net.gateway(state.ifname),
         {:ok, sock} <- :socket.open(:inet, :raw, :icmp),
         :ok <- :socket.setopt(sock, {:socket, :bindtodevice}, String.to_charlist(state.ifname)) do
      Logger.info("Pinger: sending to #{:inet.ntoa(gw)} over #{state.ifname}")
      %{state | socket: sock, target: gw}
    else
      _ -> state
    end
  end

  defp ensure_socket(state), do: state

  defp send_echo(%{socket: nil} = state), do: state

  defp send_echo(state) do
    seq = rem(state.seq + 1, 0x10000)
    packet = ICMP.echo_request(@id, seq)

    case :socket.sendto(state.socket, packet, %{family: :inet, addr: state.target, port: 0}) do
      :ok ->
        %{state | seq: seq}

      {:error, reason} ->
        Logger.warning("Pinger: send failed (#{inspect(reason)}), reconnecting")
        :socket.close(state.socket)
        %{state | socket: nil, seq: seq}
    end
  end

  # Raw ICMP sockets receive every ICMP packet; count our echo replies (type 0).
  defp drain(%{socket: nil} = state), do: state

  defp drain(state) do
    case :socket.recv(state.socket, 0, [], 0) do
      {:ok, <<_::4, ihl::4, _::binary-size(ihl * 4 - 1), 0, _code, _sum::16, @id::16, _::binary>>} ->
        drain(%{state | replies: state.replies + 1})

      {:ok, _other} ->
        drain(state)

      {:error, _} ->
        state
    end
  end
end
