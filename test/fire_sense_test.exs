defmodule FireSenseTest do
  use ExUnit.Case, async: true

  alias FireSense.{ICMP, Net}

  describe "ICMP.echo_request/3" do
    test "builds a packet whose checksum verifies to zero" do
      packet = ICMP.echo_request(0xF15E, 42)
      assert <<8, 0, _sum::16, 0xF15E::16, 42::16, "fire_sense">> = packet
      assert ICMP.checksum(packet) == 0
    end

    test "checksum verifies for odd-length payloads" do
      assert ICMP.checksum(ICMP.echo_request(1, 2, "abc")) == 0
    end
  end

  describe "Net.parse_gateway/2" do
    @route """
    Iface\tDestination\tGateway \tFlags\tRefCnt\tUse\tMetric\tMask\t\tMTU\tWindow\tIRTT
    eth0\t00000000\t0100A8C0\t0003\t0\t0\t10\t00000000\t0\t0\t0
    wlan0\t00000000\t0101A8C0\t0003\t0\t0\t20\t00000000\t0\t0\t0
    wlan0\t0001A8C0\t00000000\t0001\t0\t0\t20\t00FFFFFF\t0\t0\t0
    """

    test "returns the default gateway for the requested interface" do
      assert Net.parse_gateway(@route, "wlan0") == {192, 168, 1, 1}
      assert Net.parse_gateway(@route, "eth0") == {192, 168, 0, 1}
    end

    test "returns nil when the interface has no default route" do
      assert Net.parse_gateway(@route, "usb0") == nil
    end
  end
end
