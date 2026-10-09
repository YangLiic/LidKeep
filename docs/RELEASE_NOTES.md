# LidKeep 1.0.0-rc.1

English · 简体中文

## English

First release candidate of LidKeep, a free native utility for keeping a MacBook awake with the lid closed or screen locked.

- English and Simplified Chinese UI, with immediate switching and a saved language preference.
- Menu bar controls and CLI; separate AC/battery policies in Advanced settings.
- An optional external-display disconnect rule that suspends keep-awake before requesting sleep.
- Restricted administrator helper, original power-setting restoration, and complete helper/background-service uninstall.
- Universal Apple Silicon/Intel app for macOS 14+, supplied as an App ZIP and DMG with SHA-256 checksums.

The `universal-local` packages are ad-hoc signed and **not notarized**. Install/uninstall, keep-awake toggles, idle-timer writes/restoration and bilingual UI have been checked on an M4 running macOS 15.7.7 with AC power and an external display. Physical sleep/lock/disconnect tests and other hardware/system combinations remain unverified. This is a pre-release, not a claim of full hardware acceptance.

Lock the screen yourself with Control–Command–Q. Quitting does not restore power settings. To uninstall, use **Uninstall power helper**, quit, then move the app to Trash. See the READMEs and compatibility/testing documents for details.

## 简体中文

LidKeep 首个候选版：免费的原生 MacBook 保持唤醒工具，支持合盖与锁屏后继续运行。

- 中英文界面，即时切换并保存语言选择。
- 菜单栏与终端入口，在高级设置中分别配置插电／电池策略。
- 可选的外接屏断开规则：请求休眠前暂停保持唤醒。
- 受限管理员助手、原始电源设置恢复，以及完整助手／后台服务卸载。
- 支持 macOS 14+ 的 Apple Silicon／Intel 通用 App，提供 ZIP、DMG 与 SHA-256 校验值。

`universal-local` 包只有临时签名，**未经 Apple 公证**。已在 M4、macOS 15.7.7、插电并连接外接屏的环境下检查安装／卸载、保活开关、空闲时间写入／恢复和双语界面。实际休眠／锁屏／断屏测试及其他硬件与系统组合仍待验证。本版为预发布版本，尚不代表全部硬件验收通过。

请自行按 Control+Command+Q 锁屏。退出不会恢复电源设置。卸载时先点击「卸载电源助手」，再退出并将 App 移到废纸篓。详细行为见两份 README 与兼容性、验收文档。
