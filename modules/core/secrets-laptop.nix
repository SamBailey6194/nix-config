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
  age.secrets = {
    github-ssh-personal = {
      file = ../../secrets/github-ssh-personal.age;
      path = "/home/${username}/.ssh/github-personal";
      owner = username;
      group = "users";
      mode = "0600";
    };

    github-ssh-syntek = {
      file = ../../secrets/github-ssh-syntek.age;
      path = "/home/${username}/.ssh/github-syntek";
      owner = username;
      group = "users";
      mode = "0600";
    };

    github-ssh-missionalgen = {
      file = ../../secrets/github-ssh-missionalgen.age;
      path = "/home/${username}/.ssh/github-missionalgen";
      owner = username;
      group = "users";
      mode = "0600";
    };
  };
}
