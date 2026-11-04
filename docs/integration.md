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

此 module 不更换内核。允许构建的系列为 6.6、6.12、6.18、7.2 和 7.3，且原 Huawei WMI 驱动不能是内置。7.3.0 驱动已通过真实 Nix 构建及重启后的加载、权限和只读查询验证；可见灯效与休眠恢复尚待验收。更新系统 Nixpkgs 后，应重新检查实际内核与构建结果。其他硬件匹配限制仍由驱动执行，不会在未知机器上开放 Hunter 节点。

新版 Nixpkgs 的模块聚合器需要外部模块的 `.ko.cer`。驱动包通过目标内核的 `modules_install` 和 `kernelModuleMakeFlags` 执行签名、安装及证书生成；不要手工复制 `.ko` 或创建空证书绕过检查。安装阶段保留未压缩的 `.ko` 路径，不改变主机的内核压缩配置。使用 kmodigest 的目标必须通过非空证书和模块 PKCS#7 签名标记检查；不要求 signer 名称非空。

已因缺失证书而关闭 Hunter 选项的系统，需要在仓库修复验证通过后更新 `personalPackages` 的锁定版本并恢复所需启用项。仅修改远端仓库不会改变系统锁文件或自动启用驱动，不需要为此更换 `boot.kernelPackages`。

Hunter module 启用时，会通过仓库内的 overlay 修补已知的模块证书聚合命令：按 `modules.dep` 中实际选中的模块收集证书，避免同名替换内核模块时被按行数截取的逻辑遗漏。该修补不改变内核版本或编译配置；不含旧聚合命令的 Nixpkgs 保持原有行为。合并模块树检查会确认 Hunter 证书实际包含在 `modules.cer` 中，缺失时拒绝通过。

两个工具的启用配置与内核系列无关。若需要主动选择内核，在现有主机配置中设置，例如：

```nix
boot.kernelPackages = pkgs.linuxPackages_6_12;
```

该示例需处于已有 `{ pkgs, ... }:` module 内，且你的 Nixpkgs 应提供相应内核包。不要为安装 Hunter 工具盲目更换内核；现有的 Nvidia 等外部驱动也需在新内核下构建通过。继续使用 `nixos-rebuild build` → `boot` → 重启的部署顺序。
