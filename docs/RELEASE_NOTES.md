# LidKeep 1.0.0-rc.3

**⬇ 下载 / Download:** [**DMG**](https://github.com/YangLiic/LidKeep/releases/download/v1.0.0-rc.3/LidKeep-1.0.0-rc.3-universal-local.dmg) · [**App ZIP**](https://github.com/YangLiic/LidKeep/releases/download/v1.0.0-rc.3/LidKeep-1.0.0-rc.3-universal-local.zip)

## 简体中文

- 🌙 **熄屏保活**：无外接屏时默认合盖自动熄屏，内置屏幕与键盘灯一同熄灭，任务继续运行；也可选择保持亮屏。
- 🛰️ **远程不中断**：保留显示会话，熄屏后仍可通过远程软件操作 MacBook。
- 🔄 **亮度自动恢复**：开盖恢复原屏幕亮度，退出 App 后合盖策略仍生效。
- 🔒 **锁屏遵循系统设置**：开盖锁屏不再强制立即熄屏，按系统设置的时间执行。
- 修复后台启动崩溃，完善亮度恢复和后台服务卸载。

已在 M4、macOS 15.7.7 上确认合盖熄灯和远程控制正常。其他机型与系统组合的验证情况见[兼容性说明](https://github.com/YangLiic/LidKeep/blob/main/docs/COMPATIBILITY.md)。需要 macOS 14+，提供 Apple Silicon / Intel 通用版本。

**安装：** 打开 DMG，将 LidKeep 拖入「应用程序」。当前版本未经过 Apple 公证：首次双击被拦截后，点击「完成」，进入「系统设置 → 隐私与安全性 → 安全性」，点击「仍要打开」，完成认证并确认「打开」。该按钮仅在首次打开被拦截后出现。

## English

- 🌙 **Lights off, work on:** With no external display, automatic screen off darkens the built-in display and keyboard backlight on lid closure while tasks continue. Keep-screen-on is also available.
- 🛰️ **Stay connected:** Retain the display session so your remote desktop software can keep controlling your MacBook with the backlight off.
- 🔄 **Brightness restored:** Opening the lid restores screen brightness; the closed-lid policy continues after quitting the app.
- 🔒 **System lock timing:** Locking with the lid open follows the display-sleep timing in System Settings.
- Fix background startup crashes and improve brightness recovery and background-service removal.

Closed-lid lights-off behavior and remote control are confirmed on an M4 running macOS 15.7.7. See [compatibility](https://github.com/YangLiic/LidKeep/blob/main/docs/COMPATIBILITY.md) for other environments. Requires macOS 14+; one universal Apple Silicon / Intel app.

**Install:** Open the DMG and drag LidKeep into Applications. This release is ad-hoc signed and not Apple-notarized. If the first launch is blocked, click **Done**, open **System Settings → Privacy & Security → Security**, choose **Open Anyway**, authenticate, and confirm **Open**. The button appears only after macOS blocks an attempted launch.
