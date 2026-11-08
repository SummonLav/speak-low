<h1 align="center">speak low</h1>

<img src="Resources/Brand/speak-low.svg" width="140" height="60" alt="speak anything"><br>
Mac 本地听写工具，轻按右侧 Option 键，把说的话写到光标处。

## Skill · 安装与更新

收到安装或更新请求时，由 agent 在目标 Mac 上执行以下步骤并打开 App。先检查 `/Applications` 和 `~/Applications` 中的 `speak-low.app`。已有安装走原位更新。若 App 正从其他位置运行，使用该副本的实际路径。

### 首次安装

确认是 Apple Silicon Mac，运行 macOS 14+，并备有 Git、Swift 6.0+ 工具链和 Python 3.8+。从 GitHub 的 `main` 构建，脚本会下载并校验 Whisper 模型。若用户已指定固定签名证书，构建前将其指纹设为 `SPEAK_LOW_SIGN_IDENTITY`。由 agent 执行以下命令。

```sh
(
  set -eu
  target=/Applications
  if [ ! -w "$target" ]; then
    target="$HOME/Applications"
    mkdir -p "$target"
  fi
  src=$(mktemp -d)
  trap 'rm -rf "$src"' EXIT
  git clone --depth 1 --branch main https://github.com/SummonLav/speak-low.git "$src"
  revision=$(git -C "$src" rev-parse HEAD)
  SPEAK_LOW_BUILD_REVISION="$revision" "$src/scripts/build-app.sh" "$target"
  open "$target/speak-low.app"
)
```

### 原位更新

1. 在目标 Mac 上运行 `gh api repos/SummonLav/speak-low/commits/main --jq .sha`，记下目标提交。若缺少 GitHub CLI，用现有包管理器安装（Homebrew 命令为 `brew install gh`）。需要登录时运行 `gh auth login --hostname github.com --web`，由账户持有人完成 GitHub 验证后继续。
2. 打开已安装的 App，由 agent 在菜单栏气泡 → **设置…** 中点 **检查更新**。保持 App 运行，更新器会复用模型和现有签名配置，等当前听写结束后替换并重新打开。
3. 看到「已是最新版」或「已更新到最新版」后，用以下命令核对提交。将 `app` 设为实际安装路径。若构建失败，检查 `~/Library/Logs/speak-low/update.log`。

```sh
app=/Applications/speak-low.app
/usr/bin/plutil -extract SpeakLowRevision raw "$app/Contents/Info.plist"
```

**就绪检查**　确认菜单栏显示「本地模型就绪」，设置中的「麦克风」和「辅助功能」均为「已授权」。若缺权限，由 agent 打开对应面板，仅在 macOS 要求本人同意或验证身份时交给用户。默认使用临时签名，更新后可能需要再次授权。

## 使用

把光标放进输入框，按一下右 **Option（⌥）** 开始听写，再按一下结束并写入，**Esc** 取消。若显示「未确认写入」，可从菜单栏选择「复制上次结果」。

默认由本机 Whisper 离线转写。可选的 Claude 整理会合并断词、补标点。在设置中填入 Anthropic API Key、保存并开启「启用文字整理」。默认使用 Sonnet 4.5，仅发送转写文字，按该账户计费。调用失败时使用本地稿。

<img src="docs/images/recording.png" width="148" alt="听写计时气泡">

<img src="docs/images/settings.png" width="320" alt="深色听写设置窗口">
