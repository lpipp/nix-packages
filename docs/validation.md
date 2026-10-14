# 验证说明

## 构建验证

基线 Nixpkgs 发布归档：

```text
https://releases.nixos.org/nixos/26.05/nixos-26.05.11527.2efa67fd26b6/nixexprs.tar.xz
```

Hunter 源码固定为 `lpipp/hunter-light` 提交 `9711bfe9d1033fb0e1ddb4fe95cd0fa245fcf96c`。驱动使用源文件校验与生成流程，在 Nix 构建目录工作，不修改上游仓库或宿主系统。版本与通信协议保持 0.8.0。

首版目标内核为 6.18.55。驱动通过 `kernel.stdenv` 与 `kernel.moduleBuildDependencies` 编译；安装到 `updates/hunter`，提供 `override huawei_wmi * updates/hunter` 的 depmod 规则。NixOS 合并模块树时重新生成索引，检查实际 `modinfo` 路径与 `modprobe --show-depends`，不加载宿主机模块。

2026-10-14，使用项目外置缓存的便携 Nix 2.20.6，在 Ubuntu 宿主的 Nix 构建沙箱中完成全部 7 项 `nix flake check`。6.18.55 驱动 W=1 编译通过，版本及 vermagic 匹配，合并模块树确实选中扩展驱动。上游 Ubuntu 完整测试也通过。不需要内核 API 兼容补丁，灯光协议源码保持原样。缺少内核 `vmlinux`，BTF 生成跳过；模块生成与检查成功。

**NixOS 实机待验收，重启和休眠恢复未验证。** 后续提交的自动构建状态以对应的 GitHub Actions 为准。

检查包括：

- CLI 的合法与非法命令、临时节点写入、失败退出码，以及安装后 shell 路径。
- 上游五项 C 编解码、模式/速度、重试与并发测试，诊断脚本的离线解析和错误停止测试。
- 实际 Nix 权限脚本仅处理三个节点、拒绝额外参数、缺失节点和节点重建。
- module 默认关闭、启用后接入 CLI 和驱动、跟随主机内核、Overlay 及不支持内核拒绝。
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
hunter-light logo off
hunter-light logo color:FF0000
hunter-light wind off
hunter-light wind color:00FF00
hunter-light keyboard off
hunter-light keyboard effect:0 colors:00AAFF,00FF00,FFFF00,FF2424 speed:0
```

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
