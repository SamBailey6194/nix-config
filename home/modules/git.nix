{ config, pkgs, lib, ... }:

{
  # Git configuration with multi-account support
  # Manages personal, syntek, missional-gen and premier GitHub accounts

  programs.git = {
    enable = true;

    # Git LFS: installs git-lfs and writes the [filter "lfs"] config, so repos
    # that track files with LFS check out real content rather than pointer files.
    lfs.enable = true;

    # Git settings (unified config)
    settings = {
      # No default [user] block here — identity is handled entirely by
      # conditional includes (includeIf) below. This prevents the default
      # from overriding the includes, since Home Manager renders [user]
      # alphabetically after [includeIf] in the generated config.
      # Repos outside ~/Repos/{personal,syntek,missional-gen,premier}/ will require
      # explicit git config before committing, preventing accidental identity leaks.

      # Core settings
      core = {
        editor = "zeditor --wait";
        autocrlf = "input";
        # -F quits if output fits one screen, -R keeps colours,
        # -X leaves the output on screen after quitting
        pager = "less -FRX";
      };

      # Init settings
      init = {
        defaultBranch = "main";
      };

      # Commit settings
      commit = {
        template = "~/.gitmessage";
      };

      # Push settings
      push = {
        autoSetupRemote = true;
        default = "current";
      };

      # Pull settings
      pull = {
        rebase = true;
      };

      # Fetch settings
      fetch = {
        prune = true;
      };

      # Diff settings
      diff = {
        colorMoved = "default";
      };

      # Merge settings
      merge = {
        conflictstyle = "diff3";
      };

      # Conditional includes for multi-account support
      # Personal repos
      includeIf."gitdir:~/Repos/personal/" = {
        path = "~/.gitconfig-personal";
      };
      includeIf."gitdir:/mnt/archive/OldRepos/personal/" = {
        path = "~/.gitconfig-personal";
      };
      # Any repo under personal/ on the data drive (devtower-intel,
      # data-pair.nix), by its mount and through the ~/Data bind mount (see
      # the business rules below). The volume layout is lowercase: NTFS
      # ignores case, gitdir matching does not. Working repos live in
      # ~/Repos; these only cover a repo kept with the media.
      includeIf."gitdir:/mnt/data/personal/" = {
        path = "~/.gitconfig-personal";
      };
      includeIf."gitdir:~/Data/personal/" = {
        path = "~/.gitconfig-personal";
      };

      # Syntek repos
      includeIf."gitdir:~/Repos/syntek/" = {
        path = "~/.gitconfig-syntek";
      };
      includeIf."gitdir:/mnt/archive/OldRepos/syntek/" = {
        path = "~/.gitconfig-syntek";
      };
      # Any repo under business/ on the data drive (lowercase, as above).
      includeIf."gitdir:/mnt/data/business/" = {
        path = "~/.gitconfig-syntek";
      };
      # The same folder through the ~/Data bind mount (devtower-intel,
      # data-pair.nix). Git matches the .git path as found and with symlinks
      # resolved (git-config(1), "gitdir"); a bind mount is not a symlink, so
      # a repo opened through ~/Data never looks like /mnt/data to git.
      includeIf."gitdir:~/Data/business/" = {
        path = "~/.gitconfig-syntek";
      };

      # Missional Gen repos
      includeIf."gitdir:~/Repos/missional-gen/" = {
        path = "~/.gitconfig-missional-gen";
      };
      includeIf."gitdir:/mnt/archive/OldRepos/missional-gen/" = {
        path = "~/.gitconfig-missional-gen";
      };

      # Premier repos
      includeIf."gitdir:~/Repos/premier/" = {
        path = "~/.gitconfig-premier";
      };

      # Aliases
      alias = {
        st = "status";
        co = "checkout";
        br = "branch";
        ci = "commit";
        lg = "log --oneline --graph --decorate -20";
        last = "log -1 HEAD";
        unstage = "reset HEAD --";
        amend = "commit --amend --no-edit";
        undo = "reset --soft HEAD~1";
      };
    };
  };

  # Account-specific configurations
  # These files will be symlinked by Home Manager

  home.file.".gitconfig-personal".text = ''
    [user]
        name = SamBailey6194
        email = samabailey6194@gmail.com

    [url "git@github-personal:"]
        insteadOf = git@github.com:
  '';

  home.file.".gitconfig-syntek".text = ''
    [user]
        name = Syntek-Studio
        email = sam.bailey@syntekstudio.com

    [url "git@github-syntek:"]
        insteadOf = git@github.com:
  '';

  home.file.".gitconfig-missional-gen".text = ''
    [user]
        name = sam-missional-gen
        email = sam@missionalgen.co.uk

    [url "git@github-missionalgen:"]
        insteadOf = git@github.com:
  '';

  home.file.".gitconfig-premier".text = ''
    [user]
        name = Sam-Premier
        email = sam.bailey@premier.org.uk

    [url "git@github-premier:"]
        insteadOf = git@github.com:
  '';

  # Git commit message template
  home.file.".gitmessage".text = ''

    # Title: Summary, imperative, start upper case, don't end with a period
    # No more than 50 chars. #### 50 chars is here:  #

    # Body: Explain *what* and *why* (not *how*).
    # Wrap at 72 chars. ################################## 72 chars is here: #

    # Files changed:
    #

    # Still to do:
    #

    # Types: feat, fix, docs, style, refactor, test, chore
    # Example: feat: add user authentication

    # Breaking changes: Start body with "BREAKING CHANGE:"

    # At the end: Include Co-authored-by for all contributors.
    # Co-authored-by: name <user@example.com>
  '';

  # Git hooks (if you have pre-commit hooks)
  # Note: These will be managed in Phase 2 via secrets if they contain sensitive data
  # For now, we'll just ensure the directory exists
  home.file.".config/git/hooks/.keep".text = "";
}
