# Desktop-specific secrets configuration
# Use this for devtower host

{ config, ... }:

{
  age.secrets = {
    github-ssh-personal = {
      file = ../../secrets/github-ssh-personal.age;
      path = "/home/sam-desktop/.ssh/github-personal";
      owner = "sam-desktop";
      group = "users";
      mode = "0600";
    };

    github-ssh-syntek = {
      file = ../../secrets/github-ssh-syntek.age;
      path = "/home/sam-desktop/.ssh/github-syntek";
      owner = "sam-desktop";
      group = "users";
      mode = "0600";
    };

    github-ssh-missionalgen = {
      file = ../../secrets/github-ssh-missionalgen.age;
      path = "/home/sam-desktop/.ssh/github-missionalgen";
      owner = "sam-desktop";
      group = "users";
      mode = "0600";
    };
  };
}
