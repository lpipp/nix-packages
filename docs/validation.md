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

全部检查扩展为 16 项：8 项公共 CLI/协议/权限/module 检查，以及四系列各两项驱动和合并模块树检查。CI 的 `kernels` job 按系列独立运行，确认 W=1 编译、版本、vermagic、唯一扩展驱动与 `modprobe` 的实际模块选择。实际结果以该提交的 GitHub Actions 为准；配置求值通过不等于驱动编译通过，编译通过也不等于实机功能验证。

未列入的系列（含 6.1、5.x 和未测试的新系列）仍被拒绝。即使同系列补丁更新，仍需使用自己的系统 Nixpkgs 重新构建；基线测试不会代替每个补丁版本或发行版内核配置的验证。NixOS 上四个系列的实机启动、灯效与休眠恢复均待验收。

**该矩阵四个系列的 NixOS 实机启动、灯效与休眠恢复仍待验收。** 后续提交的自动构建状态以对应的 GitHub Actions 为准。

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

## unstable 模块证书与 Linux 7.3

2026-11-04 的修补针对使用 Nixpkgs `1c89083e451e891152365b799595cf7790a43325` 的系统，保留主机的 Linux 7.3 内核选择。旧包手动复制 `.ko`，绕过了新版 Nixpkgs 在 `modules_install` 中执行的 kmodigest 签名及 `.ko.cer` 生成，因而无法满足模块聚合器的要求。

安装阶段改用目标内核的 `modules_install`，传递 `kernelModuleMakeFlags`、包内安装路径及 `updates/hunter` 目录。通过安装命令的 `CONFIG_MODULE_COMPRESS_ALL=` 保留现有未压缩路径，模块仍按目标内核配置编译。使用 kmodigest 时，安装检查要求 `.ko.cer` 非空且模块的 `sig_id` 为 `PKCS#7`；模块树检查同时验证聚合证书、模块版本、vermagic 和实际模块选择。kmodigest 签名不要求可读的 signer 名称非空。

7.3 加入允许构建列表，原有硬件匹配条件、固件协议和 6.6 兼容补丁保持不变。原固定发布归档不提供 7.3，默认矩阵只包含该归档可用的系列；新增 `unstable-kernels` CI job 固定到上述 Nixpkgs，分别构建 6.18 和 7.3 的驱动及模块树。明确指定的 7.3 检查若缺失会使 CI 失败，不会静默跳过。

可独立运行新增检查，不修改主机配置或仓库锁文件：

```sh
nix build --no-link --print-build-logs --no-write-lock-file \
  --override-input nixpkgs github:NixOS/nixpkgs/1c89083e451e891152365b799595cf7790a43325 \
  .#checks.x86_64-linux.module-certificates \
  .#checks.x86_64-linux.driver-7_3 \
  .#checks.x86_64-linux.module-selection-7_3
```

本地已使用缓存源码和 `nix-instantiate --store dummy://` 完成原发布归档的 15 项及上述 unstable 的 17 项检查 derivation 求值。另在临时目录中执行修补包实际求值得到的 buildPhase、installPhase 和 installCheckPhase，使用缓存的 Linux 6.18.55 开发文件完成 W=1 编译、Kbuild 安装以及版本/vermagic 校验，确认输出仍为未压缩 `.ko`。这属于离线阶段验证，不是完整 Nix 沙箱构建，也没有更换或加载宿主内核。

随后用户在本机终端完成了 Linux 7.3.0 的真实 Nix 构建。驱动通过 W=1 编译、安装、strip、签名及安装检查，版本为 `hunter-0.8.0`、vermagic 为 `7.3.0`，生成了 260 字节的 `.ko.cer`；原模块选择检查通过，选中 `updates/hunter/huawei-wmi.ko`。已核对本机输出文件和检查产物，不再将 7.3 编译列为未验证。

进一步核对发现原测试存在遗漏：聚合后的 `modules.cer` 与原内核证书集合完全相同，未包含 Hunter 证书。受影响的 Nixpkgs 先跳过 `modules.order` 行数，再从 `modules.dep` 收集外部模块证书。替换同名模块后两个文件均为 7461 行，而 Hunter 位于 `modules.dep` 最后一行，因此其证书被跳过。证书集合非空并不能证明包含新驱动的证书。

仓库在 Hunter module 启用时对这段聚合命令应用 overlay，改为逐个检查实际选中的模块路径；保留原内核证书集合并追加对应的非空单模块证书，缺失外部模块证书时报错。新增 `module-certificates` 检查覆盖同名替换、模块顺序、三种压缩格式、原生模块以及缺失/空证书，共 9 个用例。模块选择检查新增 Hunter 证书内容必须出现在聚合集合中的断言。

该 helper 的 9 个本地回归用例已通过；对本次真实 7.3 模块树副本运行 helper 后，证书集合由 1939860 字节增长至 1940120 字节，包含 Hunter 证书且保留原内容。Nix 求值确认最终模块树使用修补后的命令。原稳定归档及 unstable 的检查现在分别为 16 项及 18 项。

同日用户再次执行上述三个检查目标，补修后的真实 Nix 构建成功，9 个证书回归用例均通过，模块选择检查包含的证书内容断言通过。已独立读取最终模块树核对：集合为 1940120 字节，包含 260 字节的 Hunter 证书，选中扩展模块。至此，当前 Nixpkgs 下 Linux 7.3.0 的驱动编译、签名、模块证书聚合和实际模块选择均已验证；构建检查本身不代表驱动已在运行中加载。该修补已在 [PR #1](https://github.com/lpipp/nix-packages/pull/1) 提交评审，合并前默认分支不包含。

## Linux 7.3.0 重启后验证

2026-11-04，用户完成完整系统重建并重启后，直接读取运行系统确认：

- `/run/current-system` 与 `/run/booted-system` 指向同一系统代，内核仍为 `7.3.0`。
- 模块路径为启动系统模块树中的 `updates/hunter/huawei-wmi.ko`，`/sys/module/huawei_wmi/version` 为 `hunter-0.8.0`，vermagic 匹配 `7.3.0`。
- 启动系统的 `modules.cer` 包含 Hunter 单模块证书。
- 三个灯光节点权限均为 `0222`，两个性能查询节点均为 `0444`，三个 CLI 均已安装。
- 未使用 sudo 执行 `hunter-mode` 返回 `0`，执行 `hunter-fans` 的一次采样为 `1974 1949` RPM。
- Fn lock 与充电阈值节点可读，分别返回 `1` 和 `0 100`；本轮检查未写入这些节点。

确认范围为启动加载、接口权限及实际只读查询。尚未执行灯光写入或观察可见灯效，也未验证性能按键切换后的读数变化及休眠恢复，不能据此宣称全部硬件功能已验收。

同日按修补后的聚合逻辑复核运行系统：以启动系统模块树中内核原始的 `modules.cer`（1939860 字节）为基础，连同树内 6 个外部模块证书（5 个 NVIDIA 模块各 260 字节与 Hunter 的 260 字节）交给 `merge-module-certificates.sh`，输出 1941420 字节，与系统实际的 `modules.cer` 逐字节一致，Hunter 证书位于偏移 1940640。说明修补后的聚合结果与当前部署产物相同，不是只在合成用例中成立。系统仍通过本地路径输入接入该修补；修补见 [PR #1](https://github.com/lpipp/nix-packages/pull/1)，合并前默认分支不包含。

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
