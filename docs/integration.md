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
        personalPackages.nixosModules.hunter-performance
      ];
    };
  };
}
```

`configuration.nix` 中新增：

```nix
hardware.hunter-light.enable = true;
hardware.hunter-performance.enable = true;
```

上述是结构示例，合并到你的原 Flake，避免覆盖已有 input 或 modules。执行 `nix flake lock` 固定新增 input；已有锁定不需要全部更新。然后 `nixos-rebuild build`，构建通过后 `nixos-rebuild boot`，重启验收。

只需要其中一套工具时，保留对应的 module 与启用选项即可。性能 module 安装独立的 `hunter-mode` 与 `hunter-fans`，两者均不接收参数。只启用性能工具不添加灯光权限规则；同时启用时，两套工具共用一个匹配当前内核的 `huawei_wmi` 驱动。两套 module 均不启动后台服务。

已接入旧版个人仓库的用户，在系统配置中追加性能 module 与选项，再执行 `nix flake lock --update-input personalPackages`；构建、部署启动代并重启。灯光 module 的原有接入方式继续有效。

此 module 不更换内核。现有内核需属于 6.6、6.12、6.18 或 7.2 系列，且原 Huawei WMI 驱动不能是内置；更新系统 Nixpkgs 后，应重新检查实际内核与构建结果。其他硬件匹配限制仍由驱动执行，不会在未知机器上开放 Hunter 节点。

两个工具的启用配置与内核系列无关。若需要主动选择内核，在现有主机配置中设置，例如：

```nix
boot.kernelPackages = pkgs.linuxPackages_6_12;
```

该示例需处于已有 `{ pkgs, ... }:` module 内，且你的 Nixpkgs 应提供相应内核包。不要为安装 Hunter 工具盲目更换内核；现有的 Nvidia 等外部驱动也需在新内核下构建通过。继续使用 `nixos-rebuild build` → `boot` → 重启的部署顺序。
