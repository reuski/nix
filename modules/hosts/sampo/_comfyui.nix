{ inputs }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  outputDir = "${config.profile.homeDirectory}/pictures/ComfyUI";

  cuda = pkgs.comfyui.python.pkgs.torch.cudaPackages;

  python = pkgs.python3.override {
    packageOverrides = final: prev: {
      torch = final.torch-bin;
      torchvision = final.torchvision-bin;
      torchaudio = final.torchaudio-bin;

      torch-bin = prev.torch-bin.override {
        cudaPackages = cuda;
        triton = final.triton;
      };
      torchvision-bin = prev.torchvision-bin.override { cudaPackages = cuda; };
      torchaudio-bin = prev.torchaudio-bin.override { cudaPackages = cuda; };
      triton = prev.triton.override {
        cudaPackages = cuda;
        cudaSupport = true;
      };
    };
  };

  comfyui = pkgs.comfyui.override { python3 = python; };

  customNodes = {
    "ComfyUI-GGUF" = {
      source = inputs.comfyui-gguf;
      runtimeFiles = [ ];
    };
    rgthree-comfy = {
      source = inputs.rgthree-comfy;
      runtimeFiles = [ "rgthree_config.json" ];
    };
  };

  syncCustomNodes = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      name: node:
      let
        dest = "${config.services.comfyui.dataDir}/custom_nodes/${name}";
        excludes = lib.concatMapStringsSep " " (
          file: "--exclude=${lib.escapeShellArg file}"
        ) node.runtimeFiles;
      in
      ''
        mkdir -p ${lib.escapeShellArg dest}
        rsync --recursive --links --times --delete --chmod=u=rwX,go=rX ${excludes} ${lib.escapeShellArg "${node.source}/"} ${lib.escapeShellArg "${dest}/"}
      ''
    ) customNodes
  );
in
{
  nix.settings = {
    substituters = lib.mkAfter [ "https://cache.nixos-cuda.org" ];
    trusted-public-keys = lib.mkAfter [
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
    ];
  };

  services.comfyui = {
    enable = true;
    package = comfyui;
    extraPackages = ps: [
      ps.gguf
      ps.protobuf
    ];
    extraArgs = [ "--output-directory=${outputDir}" ];
  };

  systemd.tmpfiles.settings."10-comfyui-output" = {
    "${config.profile.homeDirectory}/pictures".d = {
      mode = "0755";
      user = config.profile.username;
      group = config.users.users.${config.profile.username}.group;
    };
    ${outputDir} = {
      d = {
        mode = "0770";
        user = config.profile.username;
        group = "comfyui";
      };
      "a+".argument = "u:${config.profile.username}:rwx,d:u:${config.profile.username}:rwx";
    };
  };

  systemd.services.comfyui.serviceConfig = {
    BindPaths = [ outputDir ];
    UMask = "0007";
  };

  systemd.services.comfyui.wantedBy = lib.mkForce [ ];

  systemd.services.comfyui.path = [ pkgs.rsync ];

  systemd.services.comfyui.preStart = syncCustomNodes;
}
