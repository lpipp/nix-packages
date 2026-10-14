# lpipp / nix-packages

个人 Nix 软件包与 NixOS module 仓库。提供 [hunter-light](https://github.com/lpipp/hunter-light) **0.8.0** 灯光控制与 [hunter-performance](https://github.com/lpipp/hunter-linux) **0.3.0** 性能模式及风扇只读查询，用于 HONOR Hunter / HUAWEI FRD-WX9。

仓库存放可复现的包定义和版本锁定；Nix 下载固定源码并构建。暂未提供个人二进制缓存，依赖优先使用 NixOS 官方缓存。

## 当前支持与验证

| 项目 | 首版目标 |
|---|---|
| 系统 | x86_64-linux，NixOS 26.05 |
| Nixpkgs | 固定发布归档，对应提交 `2efa67fd26b6` |
| 内核系列 | Linux 6.6、6.12、6.18、7.2；系统默认内核不自动更换 |
| 硬件 | HUAWEI FRD-WX9 / FRD-WX9-PCB / M1060 |
| BIOS | 1.18 |
| hunter-light / 驱动版本 | 0.8.0 / hunter-0.8.0 |
| hunter-performance 版本 | 0.3.0 |

**NixOS 实机待验收。** 原项目已在该硬件的 Ubuntu 环境验证灯光功能；这不能代替 NixOS 重启后的硬件验收。构建和测试状态见 [验证说明](docs/validation.md) 与 GitHub Actions。

## 接入 NixOS

在系统的 `flake.nix` 新增 input，并与系统共享 Nixpkgs：

```nix
inputs.personalPackages = {
  url = "github:lpipp/nix-packages";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

在 `outputs` 参数中接收 `personalPackages`，向主机的现有 `modules` 列表追加：

```nix
personalPackages.nixosModules.hunter-light
```

在主机配置中启用：

```nix
hardware.hunter-light.enable = true;
```

灯光 module 默认关闭。启用后，安装 CLI、构建与系统内核匹配的公共驱动，注册 udev 权限规则并加载 `huawei_wmi`。不会自动更换 `boot.kernelPackages`。当前接入支持 6.6、6.12、6.18、7.2 系列；其他系列与原 Huawei 驱动被编译为内置的配置会拒绝构建。构建通过不能代替实机验收。

性能工具可独立启用：向 `modules` 列表追加 `personalPackages.nixosModules.hunter-performance`，并在主机配置设置：

```nix
hardware.hunter-performance.enable = true;
```

两个 module 可以同时导入和启用，只安装一份公共驱动。仅启用性能 module 时，安装 `hunter-mode`、`hunter-fans`，查询节点为 `0444`；不安装灯光 CLI，也不添加灯光权限规则。性能 module 同样默认关闭。

从你的系统配置目录执行，主机名替换为实际 Flake 输出名称：

```sh
nix flake lock
sudo nixos-rebuild build --flake .#my-host
sudo nixos-rebuild boot --flake .#my-host
```

重启进入新系统代，再按 [实机验收](docs/validation.md#实机验收) 检查。`nixos-rebuild switch` 不会自动替换已加载的同名内核模块；首次部署、驱动升级和撤销都采用 `boot` 后重启，不强制卸载运行中的驱动。

## 日常使用

```sh
hunter-light logo on
hunter-light wind off
hunter-light keyboard color:FFFFFF
hunter-light logo effect:1 colors:00AAFF speed:1
hunter-light wind effect:2 colors:FF0000,00FF00,0000FF speed:1
hunter-light keyboard effect:0 colors:00AAFF,00FF00,FFFF00,FF2424 speed:0
hunter-light --help
hunter-mode
hunter-fans
```

日常控制无需 sudo。三个灯光节点权限为 **0222**，所有能访问它们的本地用户与进程均可控制灯光。权限规则仅作用于这三个固定节点；公共性能查询节点保持 `0444`，原始 WMI 和 debugfs 权限不放宽。

`on` 恢复默认蓝色 `00AAFF`，颜色和模式不保存；命令完成后退出，动态效果由设备执行。完整参数规则见 [上游说明](https://github.com/lpipp/hunter-light#模式颜色组与速度)。module 不设置启动灯效，也不创建常驻灯光服务。

`hunter-mode` 不接收参数，输出 `0`（均衡）、`1`（性能）或 `2`（安静）；模式仍由电脑自带性能按键切换。`hunter-fans` 不接收参数，输出两路风扇 RPM，例如 `1962 1969`。两条命令无需 sudo，不缓存查询结果，也不提供模式设置。

## 包和 Overlay

```sh
nix build github:lpipp/nix-packages#hunter-light
nix build github:lpipp/nix-packages#hunter-driver
nix build github:lpipp/nix-packages#hunter-performance
nix run github:lpipp/nix-packages#hunter-performance
nix run github:lpipp/nix-packages -- --help
```

默认包为灯光 CLI；性能包的 `nix run` 默认执行 `hunter-mode`。单独安装任一 CLI 不会安装驱动或放宽 sysfs 权限，完整系统集成使用对应 NixOS module。

`packages.x86_64-linux.hunter-driver` 针对仓库锁定的默认内核构建；NixOS module 则使用你的 `config.boot.kernelPackages`。不要把为不同内核构建的模块复制到当前系统。

如需选择另一个已支持的内核系列，在主机配置中设置（可选）：

```nix
boot.kernelPackages = pkgs.linuxPackages_6_12;
```

驱动会按该内核重新构建，两个 CLI 不需要变化。同系列的补丁版本也会重新构建，但自动测试只覆盖仓库锁定的具体版本；更新 Nixpkgs 后先构建，再部署启动代并重启。

Overlay 提供 `pkgs.hunter-light` 和 `pkgs.hunter-performance`：

```nix
nixpkgs.overlays = [ personalPackages.overlays.default ];
environment.systemPackages = [ pkgs.hunter-light pkgs.hunter-performance ];
```

module 可独立使用，不要求启用 Overlay。两套 CLI 和源代码仓库保持独立；NixOS 统一使用 0.8.0 公共驱动，保留现有通信锁、查询协议和硬件匹配限制。

## 更新与撤销

维护者更新源码引用和仓库锁文件，测试通过后提交。使用者在系统配置目录仅更新此 input：

```sh
nix flake lock --update-input personalPackages
sudo nixos-rebuild build --flake .#my-host
sudo nixos-rebuild boot --flake .#my-host
```

重启使用新驱动。系统 Nixpkgs 若更新到其他内核系列，应先确认支持情况；不通过自动降级内核解决兼容问题。

撤销时移除对应启用配置（或设为 `false`），重建启动代并重启。若另一套工具仍启用，则保留公共驱动；两者均关闭才移除该驱动。旧系统代仍可通过引导菜单恢复。仅删除 CLI 或在线移除 udev 规则不会卸载已加载驱动，也不会立即撤销现存节点的权限。

## 开发与许可证

```sh
nix flake check --no-update-lock-file --print-build-logs
```

检查 CLI、C 协议和并发、Nix 权限辅助脚本、module 默认状态，并对四个内核系列分别编译驱动、核对 vermagic 和合并模块树中的实际选择。GitHub CI 按内核拆成独立 job，Ubuntu 安装/卸载及回滚测试继续在独立 Ubuntu CI job 运行。

采用 [GPL-2.0](LICENSE)。Hunter 源码固定引用上游提交，不包含预编译 Ubuntu 模块、本机原始日志或个人系统配置。驱动保留上游 Huawei 作者版权声明。来源和修改范围见 [验证说明](docs/validation.md)。
