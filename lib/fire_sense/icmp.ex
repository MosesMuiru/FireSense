defmodule FireSense.ICMP do
  @moduledoc """
  Builds ICMP echo request packets. Pure functions, no I/O.
  """
  import Bitwise

  @doc "Build an ICMP echo request (type 8) with the given identifier, sequence and payload."
  @spec echo_request(0..0xFFFF, 0..0xFFFF, binary()) :: binary()
  def echo_request(id, seq, payload \\ "fire_sense") do
    without_sum = <<8, 0, 0::16, id::16, seq::16, payload::binary>>
    <<8, 0, checksum(without_sum)::16, id::16, seq::16, payload::binary>>
  end

  @doc "Internet checksum (RFC 1071)."
  @spec checksum(binary()) :: 0..0xFFFF
  def checksum(data), do: data |> sum(0) |> fold() |> bnot() |> band(0xFFFF)

  defp sum(<<word::16, rest::binary>>, acc), do: sum(rest, acc + word)
  defp sum(<<byte>>, acc), do: acc + (byte <<< 8)
  defp sum(<<>>, acc), do: acc

  defp fold(n) when n > 0xFFFF, do: fold((n &&& 0xFFFF) + (n >>> 16))
  defp fold(n), do: n
end
