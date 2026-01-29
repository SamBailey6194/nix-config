# Laptop-specific secrets configuration
# Use this for laptop-intel and framework hosts

{ config, ... }:

let
  # Determine username based on which user exists
  username =
    if config.users.users ? sam-laptop then "sam-laptop"
    else if config.users.users ? sam-framework then "sam-framework"
    else throw "No recognized laptop user found";
in
{
  # Configure agenix to use the system SSH host key
  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  age.secrets = {
    github-ssh-personal = {
      file = ../../secrets/github-ssh-personal-laptop-intel.age;
      path = "/home/${username}/.ssh/github-laptop-intel-personal";
      owner = username;
      group = "users";
      mode = "0600";
    };

    github-ssh-syntek = {
      file = ../../secrets/github-ssh-syntek-laptop-intel.age;
      path = "/home/${username}/.ssh/github-laptop-intel-syntek";
      owner = username;
      group = "users";
      mode = "0600";
    };

    github-ssh-missionalgen = {
      file = ../../secrets/github-ssh-missionalgen-laptop-intel.age;
      path = "/home/${username}/.ssh/github-laptop-intel-missionalgen";
      owner = username;
      group = "users";
      mode = "0600";
    };
  };
}
