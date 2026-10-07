#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
zsh scripts/build.sh
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
ARCH=$(uname -m)
DMG="$PWD/dist/LoLPing-v${VERSION}-macOS-${ARCH}.dmg"
STAGING=$(mktemp -d "$PWD/.build/dmg.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT

ditto dist/LoLPing.app "$STAGING/LoLPing.app"
ln -s /Applications "$STAGING/Applications"
cat > "$STAGING/安装说明.txt" <<'INSTALL'
先从菜单栏退出旧版 LoLPing，再将 LoLPing.app 拖入 Applications，替换旧版。
从「应用程序」打开 LoLPing，开启「启用 Ping」。
若辅助功能授权失效，在系统设置 → 隐私与安全性 → 辅助功能中重新添加并允许新版 LoLPing。
按住 Option（⌥），直接移动鼠标选择，松开 Option 发送，无需按鼠标按钮；Esc 或右键取消。
安装完成后可弹出此磁盘映像。
INSTALL
hdiutil create -volname LoLPing -srcfolder "$STAGING" -format UDZO -ov "$DMG"
print "Packaged: $DMG"
