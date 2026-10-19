{ ... }:

{
  # DEVTOWER-INTEL printing, every graphical stage (see mkDevtowerIntel in flake.nix).

  # HP DeskJet 2720e on the home LAN, driverless. Its IPP Get-Printer-Attributes
  # (checked 19/10/2026, firmware TCP1FN2550DR) reports ipp-features-supported
  # airprint-2.1 + ipp-everywhere, PWG raster/URF/PCLm/JPEG at 300dpi, A4
  # default, one-sided only, colour + auto-monochrome. No HP driver (hplip):
  # CUPS builds the queue from those attributes ("everywhere").
  #
  # Address: the IP, which needs a DHCP reservation on the router to stay put.
  # The router's DNS name (HPDA6F7D.lan) would follow a changing lease, but it
  # stops resolving whenever Mullvad is connected (DNS then goes to Mullvad),
  # and HPDA6F7D.local needs Avahi, which this host leaves off. With Mullvad
  # connected, its "Local network sharing" setting must be on to reach the LAN.
  #
  # The printer advertises ipps:// on 631 with a self-signed certificate
  # (CN=HPDA6F7D, valid to 16/02/2032); CUPS trusts it on first use, so a
  # factory reset (new certificate) needs the pinned copy removed from
  # /etc/cups/ssl.
  #
  # ensurePrinters runs `lpadmin -m everywhere` in cups.service's postStart,
  # which asks the printer for its attributes: if the printer is off when CUPS
  # starts (socket-activated, so on first use), that start fails and the next
  # print request retries it.
  services.printing = {
    enable = true;
    # Local queue only: no sharing, no listening beyond localhost (the defaults,
    # pinned so a later module cannot quietly publish the printer).
    defaultShared = false;
    browsing = false;
  };

  hardware.printers = {
    ensurePrinters = [
      {
        name = "HP_DeskJet_2720e";
        description = "HP DeskJet 2720e";
        location = "Home";
        deviceUri = "ipps://192.168.1.146:631/ipp/print";
        model = "everywhere";
        ppdOptions.PageSize = "A4";
      }
    ];
    ensureDefaultPrinter = "HP_DeskJet_2720e";
  };
}
