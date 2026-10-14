# 验证说明

## 构建验证

基线 Nixpkgs 发布归档：

```text
https://releases.nixos.org/nixos/26.05/nixos-26.05.11527.2efa67fd26b6/nixexprs.tar.xz
```

Hunter 源码固定为 `lpipp/hunter-light` 提交 `9711bfe9d1033fb0e1ddb4fe95cd0fa245fcf96c`。驱动使用源文件校验与生成流程，在 Nix 构建目录工作，不修改上游仓库或宿主系统。版本与通信协议保持 0.8.0。

性能 CLI 源码固定为 `lpipp/hunter-linux` 提交 `ad1559e89d700aa7c6becc37b79160ac418a1ccc`，包版本为 0.3.0。仅将 shell 和 `cat` 路径替换为 Nix store 绝对路径；不调用上游 Ubuntu 安装器，不构建上游旧驱动。两个 NixOS module 共用灯光源码提供的 0.8.0 驱动，其中已包含性能查询节点。

首版目标内核为 6.18.55。驱动通过 `kernel.stdenv` 与 `kernel.moduleBuildDependencies` 编译；安装到 `updates/hunter`，提供 `override huawei_wmi * updates/hunter` 的 depmod 规则。NixOS 合并模块树时重新生成索引，检查实际 `modinfo` 路径与 `modprobe --show-depends`，不加载宿主机模块。

2026-10-14，使用项目外置缓存的便携 Nix 2.20.6，在 Ubuntu 宿主的 Nix 构建沙箱中完成全部 7 项 `nix flake check`。6.18.55 驱动 W=1 编译通过，版本及 vermagic 匹配，合并模块树确实选中扩展驱动。上游 Ubuntu 完整测试也通过。不需要内核 API 兼容补丁，灯光协议源码保持原样。缺少内核 `vmlinux`，BTF 生成跳过；模块生成与检查成功。

同日加入性能包后，全部 9 项 `nix flake check` 通过。安装后的性能 CLI 测试和性能源码协议/并发测试通过；module 检查覆盖默认关闭、灯光单独启用、性能单独启用和同时启用。三个启用组合的模块树一致，只包含一份 Hunter 扩展驱动，继续选中 `hunter-0.8.0`。驱动构建输入与首版相同，无协议或固件行为变更。性能上游仓库的 `make test` 也通过。

## 多内核构建矩阵

扩展接入目标为下列四个系列。`pkgs/hunter-driver/supported-kernels.nix` 统一定义允许的系列，包与 NixOS module 使用同一份列表；默认内核仍由系统配置决定。

| 系列 | 锁定 Nixpkgs 中的版本 | 构建检查 |
|---|---|---|
| 6.6 | 6.6.158 | `driver-6_6`、`module-selection-6_6` |
| 6.12 | 6.12.112 | `driver-6_12`、`module-selection-6_12` |
| 6.18 | 6.18.55 | `driver-6_18`、`module-selection-6_18` |
| 7.2 | 7.2.9 | `driver-7_2`、`module-selection-7_2` |

Linux 6.6 的平台驱动 `void` 移除回调名为 `remove_new`；WMI 通知回调接收 `u32` 整数，新内核则传递 ACPI 对象。Nix 包在生成驱动后应用 `linux-6.6.patch`：替换移除回调字段，并将旧通知值包装成整数型 ACPI 对象后交给原有热键处理函数。保留事件值与上下文，不修改移除流程、通信协议、硬件匹配或用户权限。新内核不应用该补丁。CLI 版本仍为灯光 0.8.0、性能 0.3.0，驱动标识仍为 `hunter-0.8.0`。

全部检查扩展为 15 项：7 项公共 CLI/协议/权限/module 检查，以及四系列各两项驱动和合并模块树检查。CI 的 `kernels` job 按系列独立运行，确认 W=1 编译、版本、vermagic、唯一扩展驱动与 `modprobe` 的实际模块选择。实际结果以该提交的 GitHub Actions 为准；配置求值通过不等于驱动编译通过，编译通过也不等于实机功能验证。

未列入的系列（含 6.1、5.x 和未测试的新系列）仍被拒绝。即使同系列补丁更新，仍需使用自己的系统 Nixpkgs 重新构建；基线测试不会代替每个补丁版本或发行版内核配置的验证。NixOS 上四个系列的实机启动、灯效与休眠恢复均待验收。

**NixOS 实机待验收，重启和休眠恢复未验证。** 后续提交的自动构建状态以对应的 GitHub Actions 为准。

检查包括：

- CLI 的合法与非法命令、临时节点写入、失败退出码，以及安装后 shell 路径。
- 安装后的性能 CLI：三种模式输出、两路 RPM、节点缺失、额外参数及空 PATH；仅在测试副本中替换 sysfs 路径，不访问宿主硬件。
- 性能上游 C 协议、格式、重试和并发测试。
- 上游五项 C 编解码、模式/速度、重试与并发测试，诊断脚本的离线解析和错误停止测试。
- 实际 Nix 权限脚本仅处理三个节点、拒绝额外参数、缺失节点和节点重建。
- 两个 module 默认关闭、分别启用时 CLI 独立、性能单独启用不放宽灯光权限、同时启用仅一份驱动；三个启用组合的合并模块树相同，跟随主机内核、Overlay 及不支持内核拒绝。
- 构建守卫拒绝内置 Huawei WMI 驱动与缺失的目标内核元数据。
- 驱动版本、vermagic、同名模块选择与依赖关系。
- Ubuntu 独立安装、卸载和失败回滚，继续在 Ubuntu job 验证。

## 实机验收

将 module 接入真实 NixOS 配置后，用 `nixos-rebuild boot` 部署并重启。先记录基线 Fn lock、充电阈值、模式与风扇查询结果；部署后核对，没有强制修改它们的步骤。

重启后先进行只读检查：

```sh
uname -r
modinfo -n huawei_wmi
cat /sys/module/huawei_wmi/version
stat -c '%a %n' /sys/bus/platform/devices/huawei-wmi/hunter_light/{logo,wind,keyboard}
stat -c '%a %n' /sys/bus/platform/devices/huawei-wmi/hunter/{mode,fans}
cat /sys/bus/platform/devices/huawei-wmi/hunter/mode
cat /sys/bus/platform/devices/huawei-wmi/hunter/fans
cat /sys/bus/platform/devices/huawei-wmi/fn_lock_state
cat /sys/bus/platform/devices/huawei-wmi/charge_control_thresholds
```

预期模块路径包含 `updates/hunter/huawei-wmi.ko`，版本为 `hunter-0.8.0`；灯光节点为 `222`，两个性能查询节点为 `444`。若不匹配，先停止灯光验收并查看 `journalctl -k -b`。

以下以普通用户执行，不加 sudo：

```sh
hunter-mode
hunter-fans
hunter-light logo off
hunter-light logo color:FF0000
hunter-light wind off
hunter-light wind color:00FF00
hunter-light keyboard off
hunter-light keyboard effect:0 colors:00AAFF,00FF00,FFFF00,FF2424 speed:0
```

性能工具启用后，先确认查询值与当前硬件状态一致。使用电脑自带性能按键切换模式，再运行 `hunter-mode` 确认值随之更新。仅启用性能 module 时，只进行性能查询及原 Huawei 功能验收；无需执行灯光命令。

确认 Logo 红色、风谷整体绿色和键盘四区不同颜色。再分别执行，命令结束后各观察至少 30 秒，确认持续变色：

```sh
hunter-light logo effect:2 colors:FF0000,00FF00,0000FF speed:1
hunter-light wind effect:2 colors:FF0000,00FF00,0000FF speed:1
hunter-light keyboard effect:2 colors:FF0000,00FF00,0000FF speed:1
```

最后恢复三处默认蓝色并确认：

```sh
hunter-light logo on
hunter-light wind on
hunter-light keyboard on
```

命令成功或模块构建通过不等于可见灯效已经验证。管理员可读取 debugfs 的固定查询进行采样诊断，但采样不能完整读回所有灯点或键盘四区；首次 NixOS 验收仍需用户观察。

确认完成后记录实际内核、Nixpkgs 锁定、驱动版本、权限、查询及可见结果，再更新实机支持声明。休眠恢复和其他硬件另行验证。
