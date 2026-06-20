{ pkgs, ... }:

{
  # Internet / network CLI toolkit.
  #
  # Diagnostics baseline mirrors the syntek deployment repos
  # (syntek-nixos-client-deployment, i-had-dad-deployment): dnsutils, mtr,
  # traceroute, nmap, netcat, socat, tcpdump, iperf3, ethtool, lsof, whois.
  # Adds DNS/HTTP/packet-analysis helpers and load/stress/DoS testing tools for
  # authorised security testing and capacity work.
  #
  # NOTE: nmap/tcpdump/tshark and the packet-crafting tools (hping) need root or
  # a capability to do privileged captures/raw sockets — run them under sudo.

  environment.systemPackages = with pkgs; [
    # --- DNS ---
    dnsutils # dig, nslookup
    doggo # modern, colourful dig
    ldns # drill — DNSSEC-aware lookups
    whois # registration / ownership lookups

    # --- TCP / path diagnostics ---
    nmap # port scanning + service/version detection
    mtr # traceroute + ping (live path/latency)
    traceroute # hop-by-hop path tracing
    gping # ping with a live graph
    tcpdump # packet capture
    netcat-openbsd # nc — port reachability / socket testing
    socat # bidirectional stream relay
    iperf3 # throughput / bandwidth testing
    nethogs # per-process bandwidth
    bandwhich # per-connection bandwidth TUI
    ethtool # NIC link / driver / offload state
    lsof # map sockets/files to owning processes

    # --- HTTP / API ---
    httpie # human-friendly HTTP client
    xh # fast HTTPie-like client (Rust)
    grpcurl # curl for gRPC
    websocat # WebSocket client / relay

    # --- Packet / protocol analysis ---
    wireshark-cli # tshark
    ngrep # grep across live network traffic

    # --- Load / stress / DoS testing (authorised security + capacity testing) ---
    wrk # HTTP benchmarking
    hey # HTTP load generator
    vegeta # constant-rate HTTP load testing
    hping # custom TCP/IP packet crafting (SYN floods, etc.)
    slowhttptest # slow-HTTP (slowloris) DoS testing
  ];
}
