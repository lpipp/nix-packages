# nix-packages

个人 Nix 软件包与 NixOS module。

## hunter

[hunter-linux](https://github.com/lpipp/hunter-linux) 的驱动与 `hunter` 命令。

```nix
# flake.nix
inputs.personalPackages = {
  url = "github:lpipp/nix-packages";
  inputs.nixpkgs.follows = "nixpkgs";
};
# modules
personalPackages.nixosModules.hunter
```

```nix
# configuration.nix
hardware.hunter.enable = true;
```

启用后为当前内核构建替换 `huawei_wmi` 的扩展驱动并安装 `hunter`。

更新源码：`nix flake update hunter-src`。
