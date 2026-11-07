defmodule FireSense.Net do
  @moduledoc """
  Finds the default gateway (the router) for a network interface by reading
  the kernel routing table.
  """

  @doc "Default gateway for `ifname`, read from /proc/net/route."
  @spec gateway(String.t(), Path.t()) :: {:ok, :inet.ip4_address()} | {:error, :no_gateway}
  def gateway(ifname, route_file \\ "/proc/net/route") do
    with {:ok, text} <- File.read(route_file),
         gw when is_tuple(gw) <- parse_gateway(text, ifname) do
      {:ok, gw}
    else
      _ -> {:error, :no_gateway}
    end
  end

  @doc false
  def parse_gateway(text, ifname) do
    text
    |> String.split("\n", trim: true)
    |> Enum.drop(1)
    |> Enum.map(&String.split/1)
    |> Enum.find_value(fn
      [^ifname, "00000000", gw_hex | _] -> hex_to_ip(gw_hex)
      _ -> nil
    end)
  end

  # /proc/net/route stores addresses as little-endian hex.
  defp hex_to_ip(hex) do
    <<a, b, c, d>> = <<String.to_integer(hex, 16)::little-32>>
    {a, b, c, d}
  end
end
