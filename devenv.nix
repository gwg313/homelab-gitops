{
  pkgs,
  lib,
  config,
  inputs,
  ...
}: {
  # https://devenv.sh/basics/
  env.GREET = "devenv";
  env = {
  };

  # https://devenv.sh/packages/
  packages = with pkgs; [
    kubectl
    talosctl
    kubeseal
    kubeconform
    yamllint
    shellcheck
    gitleaks
    yamlfmt
  ];

  # https://devenv.sh/languages/
  # languages.rust.enable = true;

  # https://devenv.sh/processes/
  # processes.cargo-watch.exec = "cargo-watch";

  # https://devenv.sh/services/
  # services.postgres.enable = true;

  # https://devenv.sh/scripts/
  scripts.hello.exec = ''
    echo hello from $GREET
  '';

  enterShell = ''
    hello
    git --version
  '';

  # https://devenv.sh/tasks/
  # tasks = {
  #   "myproj:setup".exec = "mytool build";
  #   "devenv:enterShell".after = [ "myproj:setup" ];
  # };

  # https://devenv.sh/tests/
  enterTest = ''
    echo "Running tests"
    git --version | grep --color=auto "${pkgs.git.version}"
  '';

  # https://devenv.sh/pre-commit-hooks/
  # git-hooks.hooks = {
  #   check-yaml.enable = true;
  #   end-of-file-fixer.enable = true;
  #   trim-trailing-whitespace.enable = true;
  #   yamlfmt = {
  #     enable = true;
  #     entry = "yamlfmt";
  #     args = ["-in-place"];
  #     files = "\\.ya?ml$";
  #     language = "system";
  #   };
  #   yamllint.enable = true;
  #   shellcheck.enable = true;
  #
  #   kubeconform = {
  #     enable = true;
  #     entry = "kubeconform";
  #     args = [
  #       "-strict"
  #       "-summary"
  #       "-ignore-missing-schemas"
  #       "-schema-location"
  #       "https://raw.githubusercontent.com/yannh/kubernetes-json-schema/master/{{.ResourceKind}}-{{.ResourceAPIVersion}}.json"
  #       "-schema-location"
  #       "default"
  #     ];
  #     files = "\\.ya?ml$";
  #   };
  #
  #   gitleaks = {
  #     enable = true;
  #     entry = "gitleaks detect --no-git -v --redact";
  #     language = "system";
  #     pass_filenames = false;
  #   };
  # };
  # pre-commit.hooks.shellcheck.enable = true;

  # See full reference at https://devenv.sh/reference/options/
}
