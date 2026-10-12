# The davinci-resolve-studio FHS wrapper from the host's system packages, or
# null. Its passthru.davinci is the unwrapped tree holding bin/ResolveMCP.
{ lib, osConfig }:
lib.findFirst (p: (p.pname or "") == "davinci-resolve-studio") null
  (osConfig.environment.systemPackages or [ ])
