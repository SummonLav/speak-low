# speak-low

<img src="Resources/Brand/speak-low.svg" width="280" alt="小小惊叹气泡与 speak anything 字标">

Mac 上的离线语音输入。把光标放进输入框，按一下右侧 **Option（⌥）** 开始说话，再按一下，把文字写回光标。按 **Esc** 取消。开始录音时会听到轻快的上行双音，结束时是下行双音。

<img src="docs/images/recording.png" width="148" alt="录音时屏幕底部出现气泡和计时器">

## 安装

需要 Apple Silicon Mac、macOS 14+、Swift 5.10+ 和 Python 3.8+。在仓库根目录运行：

```sh
./scripts/build-app.sh
open dist/speak-low.app
```

首次构建会下载 Whisper 模型。打开 App，允许「麦克风」和「辅助功能」，等模型就绪即可听写。看到「已输入」表示已在原输入框中确认写入。若提示「未确认写入」，可从菜单栏气泡选择「复制上次结果」。

<img src="docs/images/settings.png" width="400" alt="speak-low 设置窗口，可选择识别语言并开启听写权限">

## 可选的 Claude 整理

在设置里填入自己的 Anthropic API Key 和模型 ID，保存后开启「启用文字整理」。Claude 可以合并断词、补标点。仅转写文字会发给 Anthropic，费用由你的 API 账户承担，调用失败时使用本地稿。

<img src="docs/images/claude-model.png" width="400" alt="浅色模式下的 Claude 设置，模型 ID 使用中性灰选中高亮">
