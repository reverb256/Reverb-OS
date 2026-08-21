{
  pkgs,
  lib,
  ...
}: {
  programs.git = {
    enable = true;

    settings = {
      user.name = "reverb256";
      user.email = "j_kroeker@reverb256.ca";
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      pull.rebase = true;
      rerere.enabled = true;
      core.pager = "delta";
      merge.conflictstyle = "diff3";

      # GitHub HTTPS credential helper.
      #
      # Declared here because it was previously imperative drift in
      # ~/.gitconfig pinned to an ABSOLUTE store path
      # (!/nix/store/…-gh-2.93.0/bin/.gh-wrapped). That path was
      # garbage-collected while the live gh moved to 2.97.0, so every HTTPS
      # fetch to github.com failed with "could not read Username". It broke
      # `nix flake update` silently: the fetch failed, Nix fell back to an
      # expired cached ref, and still exited 0.
      #
      # FIRST ATTEMPT used a PATH-relative `!gh auth git-credential`. That
      # still breaks: `gh` is only on PATH inside a login shell that has
      # sourced the nix/HM profile. Stripped-PATH callers (the nix-daemon
      # subprocess that runs `nix flake update`, `sudo`, embedded terminals,
      # cron) cannot find `gh`, the helper returns nothing, and git prompts
      # for a username. Verified: `env -i PATH=/usr/bin:/bin gh` → 127.
      #
      # DURABLE FIX: pin the helper to the user's active HM profile symlink
      # (/home/j_kro/.nix-profile/bin/gh). The profile path is a GC root, so
      # it survives both store GC and gh version bumps, AND it is an absolute
      # path so it resolves even when PATH is stripped. Verified: the same
      # stripped-PATH test returns a token. The leading `!` marks it as a
      # shell command.
      #
      # This matters beyond convenience: every flake input in this repo uses
      # git+https:// (git+ssh hits GitHub 401 / curl-42 aborts on Lix), so a
      # working HTTPS credential path is load-bearing for eval itself.
      credential."https://github.com".helper = "!/home/j_kro/.nix-profile/bin/gh auth git-credential";
      credential."https://gist.github.com".helper = "!/home/j_kro/.nix-profile/bin/gh auth git-credential";
    };

    lfs.enable = true;
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      side-by-side = true;
      line-numbers = true;
    };
  };

  programs.gh = {
    enable = true;
    # The HM gh module's gitCredentialHelper (default on) emits the helper as
    # a LIST for github.com + gist.github.com; our credential.*.helper above is
    # a deliberate string (pinned profile path). Both defining the same option
    # with different types breaks eval — so disable the module's auto helper
    # and keep the pinned-profile one as the single source of truth.
    gitCredentialHelper.enable = false;
    settings = {
      git_protocol = "ssh";
      prompt = "enabled";
    };
  };
}
