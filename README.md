# LoLPing · Mac 桌面信号

一个原生 Swift / AppKit 菜单栏软件。在 Mac 上按住 Option（⌥），移动鼠标选择英雄联盟风格的信号，松开 Option 发送。无需按鼠标按钮。

## 安装与更新

当前版本为 **1.3.0**：**按住 Option（⌥）→ 移动鼠标选择 → 松开 Option 发送**，无需按住鼠标按钮，也不再使用三键组合或 Option + 左键拖动。

- 系统要求：macOS 13 或更新版本；当前构建产物为 Apple Silicon（M 系列芯片）版本。
- App 内包含图标和音效，安装后离线运行，无需 Xcode、Swift 或其他开发工具。
- 新版的构建与手势状态机检查已通过；真实全局输入、外接屏和全屏覆盖仍待实测。历史验证与本次检查结果见 [验证记录](VERIFICATION.md)。

### 直接安装 App

1. 按文末命令构建，得到 `dist/LoLPing.app`。`.app` 是软件本体，可以直接安装。
2. 更新前先从旧版的菜单栏菜单中选择「退出 LoLPing」，仅关闭窗口不会退出软件。
3. 将新版 `LoLPing.app` 拖入「应用程序」文件夹；已有旧版时选择替换。
4. 从「应用程序」打开新版，开启「启用 Ping」。首次安装默认关闭。
5. 在 **系统设置 → 隐私与安全性 → 辅助功能** 中允许 LoLPing。如果更新后无法触发，移除旧的授权条目，重新添加「应用程序」中的新版 LoLPing，再退出并重新打开软件。

### 使用 DMG 安装

运行文末的打包命令，得到 `dist/LoLPing-v1.3.0-macOS-arm64.dmg`。`.dmg` 是包含同一个 App 的磁盘映像安装包。

退出旧版后，双击 DMG，将其中的 LoLPing 拖到 **Applications** 入口并替换旧版。安装完成后弹出 DMG，从「应用程序」打开软件，按上面的步骤授权。

当前构建使用本地签名，尚未使用 Developer ID 签名及 Apple 公证。如果系统提示无法验证开发者，确认来源可信后，尝试打开并进入 **系统设置 → 隐私与安全性 → 仍要打开**。详见 [Apple 官方说明](https://support.apple.com/zh-cn/102445)。

### 原作者旧版下载

[原作者 v1.1.0 · Apple Silicon ZIP](https://github.com/AllenTHT/LoLPing-Mac/releases/download/v1.1.0/LoLPing-v1.1.0-macOS-arm64.zip) 使用 **Control + Option + Command** 三键触发，不包含本仓库的新版交互。本文以下使用说明对应 **1.3.0**。GitHub 自动提供的 `Source code (zip)` 和 `Source code (tar.gz)` 是源码，不是 App 安装包。

## 使用

1. 打开 LoLPing，在「信号试用」中点选九种信号。窗口内预览不需要系统权限，也不受全局开关限制。
2. 开启「启用 Ping」。如果提示授权，进入 **系统设置 → 隐私与安全性 → 辅助功能**，允许 **LoLPing**。这一步需要你亲自操作；应用不会替你更改系统权限。
3. 将鼠标放在要标记的位置，按住 **Option（⌥）** 立即呼出轮盘，直接移动鼠标选择，**松开 Option 发送**。无需点击或按住鼠标按钮。
4. 中央是普通蓝色信号；按下 Option 后原地松开，可发送普通信号。Esc / 右键取消。信号出现在最初按下 Option 的位置。取消后需要先松开 Option，再重新按下触发。
5. 关闭总开关会立刻取消轮盘、停止动画与声音。关闭窗口仍可从菜单栏打开或暂停；「退出软件」彻底退出。

首次运行默认关闭。启用状态、音量和大小自动保存。触发方式固定为 Option + 移动鼠标，旧版保存的组合键不再使用。软件不会添加登录启动项，不联网同步信号，也不采集键盘输入内容。

菜单栏和主窗口共用一个状态。启用后按住 Option 会显示轮盘。按下其他普通按键、额外修饰键、左键或滚动鼠标会取消当前手势并放行原操作，不会误发信号。已有鼠标拖动或按键按下时不会触发；取消后必须先松开 Option。

如果辅助功能已开启但无法触发，请关闭并重新运行应用，再检查权限帮助。只有系统确实要求时才额外开启输入监控；不需要屏幕录制或麦克风权限。重新构建会改变本地签名，macOS 可能要求重新添加授权条目。

## 素材与效果

- 官方布局与视觉参照：<https://support.riotgames.com/en-us/league-of-legends/gameplay/smart-ping>
- 图标依据：CommunityDragon 15.24 的 `assets/ux/menu/` 轮盘图集。它是社区维护的游戏素材镜像，不是 Riot 官方服务。按轮盘图标轮廓重建可缩放矢量路径，修整压缩纹理的边缘噪点；不再放大小地图图片。
- 轮盘悬浮时图标从 22 点平滑放大到 30 点，并改变颜色与扇区高亮。中心圆半径为 66 点，实际判定区域同步缩放；金色尖角、青色短弧随指针方向旋转，功能名称显示在中心。
- 音效来源：`alibaztomars/lol-ping-overlay` 的九个音频文件，锁定具体提交；详见 `Resources/asset-sources.json`。与 Riot 原录音完全一致尚未核实，不标称官方原声。
- 游戏素材归 Riot Games 所有。LoLPing 是独立的个人桌面工具，非 Riot 官方产品。
- 动画使用原生 AppKit / Quartz 绘制，包含独立变化的浮起、辉光、扩散光圈、短暂光点和约两秒淡出。蓝色普通 Ping 对照用户提供的实拍视频调整；其余八种落点动画是同风格重建，未经逐帧原版对照。
- 图标、文字和光圈按屏幕像素倍率绘制，支持 Retina。效果预览高度随大小调整，最大 150% 时也能容纳完整图标。

## 构建与检查

需要 macOS 13 或更新版本及 Swift 命令行工具。当前交付针对 Apple Silicon；无需额外第三方运行库或完整 Xcode。

```sh
zsh scripts/build.sh
zsh scripts/test.sh
dist/LoLPing.app/Contents/MacOS/LoLPing --check-assets
dist/LoLPing.app/Contents/MacOS/LoLPing --visual-check "$PWD/Verification/Visuals"
```

构建脚本生成并本地签名 `dist/LoLPing.app`。首次取得素材或恢复缺失素材时可运行 `python3 scripts/fetch_assets.py`，正常构建与软件运行均无需网络。

`--visual-check` 使用与应用相同的绘制和动画插值，输出九种状态的 75% / 100% / 150% Retina 对照图、1x 图、动画阶段图及无声演示视频。它检查九种效果的动态变化和立即停止行为，不创建全局输入监听、不改偏好设置、不捕获桌面。生成视频需要系统编码器，受限沙箱可能无法调用。

轮廓数据随软件离线打包；仅维护素材时才需要 `scripts/trace_wheel_icons.py`（Pillow + NumPy），普通构建与使用不依赖 Python。

全局手势状态机有单元测试，包括 Option 按下呼出、释放单次发送、取消后不发送、重复触发、其他快捷键、现有拖动、八向和屏幕边缘坐标。实际辅助功能授权、外接屏及不同应用的全屏覆盖仍需实机检查；系统受保护画面不保证覆盖。

测试使用独立的 `PingCoreChecks` 程序，因为仅安装 Command Line Tools 的 Mac 不一定带 XCTest；失败时返回非零退出状态。

## 生成 DMG 安装包

需要方便保存或分发的安装包时，运行：

```sh
zsh scripts/package_dmg.sh
```

脚本会先构建并本地签名 App，再生成 `dist/LoLPing-v1.3.0-macOS-arm64.dmg`，包含 App、Applications 入口和安装说明。文件名按构建机器架构生成；安装步骤见上文。DMG 不会额外申请系统权限或写入启动项。
