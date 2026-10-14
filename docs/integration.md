# 接入已有 Flake

保留现有 Nixpkgs、Home Manager、桌面和引导配置，只添加个人仓库 input、module 和启用选项。

```nix
{
  inputs = {
    # 保留现有的 nixpkgs 等 input。
    personalPackages = {
      url = "github:lpipp/nix-packages";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, personalPackages, ... }: {
    nixosConfigurations.my-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        personalPackages.nixosModules.hunter-light
      ];
    };
  };
}
```

`configuration.nix` 中新增：

```nix
hardware.hunter-light.enable = true;
```

上述是结构示例，合并到你的原 Flake，避免覆盖已有 input 或 modules。执行 `nix flake lock` 固定新增 input；已有锁定不需要全部更新。然后 `nixos-rebuild build`，构建通过后 `nixos-rebuild boot`，重启验收。

此 module 不更换内核。现有内核需属于 6.18 系列且原 Huawei WMI 驱动不能是内置；更新系统 Nixpkgs 后，应重新检查实际内核与构建结果。其他硬件匹配限制仍由驱动执行，不会在未知机器上开放 Hunter 节点。
