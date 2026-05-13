# Codex 变更记录

本文档用于记录 Codex 每次对项目做出的代码、文档、配置变动，避免只依赖聊天记录追踪上下文。

## 记录规则

每次变动尽量记录以下信息：

1. 日期时间
2. 变动文件
3. 变动原因
4. 具体修改内容
5. 验证方式与结果
6. 后续注意事项

## 2026-05-12

### 建立 Flutter Android 构建说明

变动文件：

```text
docs\Flutter安卓构建说明.md
mobile\flutterw.cmd
.gitignore
```

变动原因：

Windows 用户目录包含中文时，Flutter / Gradle / Kotlin 可能把 Pub 缓存路径错误解析，导致 Android 插件编译失败。

主要内容：

- 约定在 `mobile` 目录使用 `.\flutterw.cmd`，让 `PUB_CACHE` 指向 `E:\.pub-cache`
- 文档记录 `Expected to find project root in current working directory.` 的处理方式
- 文档记录 `E:\SECP-frontend` 与 `E:\SCEP-backend` 的区别，避免走错仓库
- 文档记录 Android 模拟器、Android 真机、Windows 桌面端的 `API_BASE` 用法

验证结果：

- `cd E:\SECP-frontend\mobile`
- `.\flutterw.cmd pub get` 成功

### 修复老人端全局 SOS 黑屏

变动文件：

```text
mobile\lib\features\elder\presentation\elder_global_sos_overlay.dart
```

变动原因：

全局 SOS 悬浮层用 `Stack` 包裹主页面，但 `Stack` 未强制子组件铺满屏幕，导致主页面可能被布局成接近 0 尺寸，只剩 SOS 悬浮按钮可见。

主要内容：

- 给全局 `Stack` 增加 `fit: StackFit.expand`
- 给 `ScaffoldMessenger.showSnackBar` 增加保护，避免无可用 `Scaffold` 时抛异常

验证结果：

- App 重新运行后，老人端首页恢复显示

### 为全局 SOS 弹窗增加语音撤回流程

变动文件：

```text
mobile\lib\features\elder\presentation\elder_global_sos_overlay.dart
```

变动原因：

在不改变现有底部弹窗整体结构的前提下，增加“语音撤回”能力，并处理手动按钮、语音命中、立即发送、倒计时超时之间的并发竞争。

主要内容：

- 增加 `_VoiceWithdrawPhase` 状态机：`speaking`、`listening`、`submitting`
- 增加 `mockSpeechStream()`，监听开启 2.5 秒后 yield 包含“撤回”的文本，用于本地快速验证
- 弹窗出现后先执行 TTS 播报“误触请说撤回”
- TTS 完成后才进入语音监听阶段
- 在副标题和红色进度条之间插入麦克风状态 Row
- 监听阶段麦克风显示蓝色并带缩放/透明度呼吸动效
- 增加 `_isSubmitting` 锁，防止手动撤回、语音撤回、立即发送、超时发送重复提交
- 抢锁后会停止倒计时、停止语音监听、停止 TTS，然后调用后端方法并关闭弹窗

当前接口状态：

撤回和立即发送当前已经通过 `ElderHelpService` 间接调用真实接口，不是本地模拟网络请求。

```text
ElderHelpService.revokeHelpRequest(...)
  -> ElderHelpApi.revokeHelpRequest(...)
  -> POST /v1/elder/emergency-alerts/{alertId}/revoke

ElderHelpService.sendNow(...)
  -> ElderHelpApi.sendNow(...)
  -> POST /v1/elder/emergency-alerts/{alertId}/send-now
```

是否真实走后端由 `AppConfig.useMockSos` 决定：

```text
useMockSos = false  走真实 ElderHelpApi
useMockSos = true   走 ElderHelpMockService
```

验证结果：

```powershell
cd E:\SECP-frontend\mobile
.\flutterw.cmd analyze lib\features\elder\presentation\elder_global_sos_overlay.dart
```

结果：

```text
No issues found!
```

后续注意事项：

- 当前仍然保留的是语音识别 mock：`mockSpeechStream()`
- 后续如果要接真实 STT，应替换 `mockSpeechStream()` 的来源，而不是重复改撤回/立即发送 HTTP 接口
- 点击 SOS 时已经先调用 `ElderHelpService.createHelpRequest()` 创建求助单，并把真实 `alertId` 传给 `_GlobalSosCountdownSheet`
- 本地联调时需要确认后端已启动，且 `API_BASE` 指向正确环境

### 关于下一步真实联调的提醒

用户贴出的后续联调目标：

```text
撤回求助：
POST /v1/elder/emergency-alerts/{alertId}/revoke
body: {"cancelMode": "button"} 或 {"cancelMode": "voice"}

立即发送：
POST /v1/elder/emergency-alerts/{alertId}/send-now
body: {}
```

当前核对结论：

- 上述两个 HTTP 接口已经在 `mobile\lib\features\elder\data\elder_help_api.dart` 中实现
- `ApiClient` 已统一处理 `baseUrl`、超时、`Authorization: Bearer <token>` 注入和 Dio 异常转译
- `elder_global_sos_overlay.dart` 目前调用的是服务层 `ElderHelpService`，符合现有分层，不建议直接在 UI 文件里手写 Dio 请求
- 若后端联调失败，应优先检查 `AppConfig.useMockSos`、登录 token、`API_BASE`、后端日志和数据库状态

### 将 SOS 语音撤回从 mock 替换为真实 speech_to_text

变动文件：

```text
mobile\lib\features\elder\presentation\elder_global_sos_overlay.dart
```

变动原因：

之前 `mockSpeechStream()` 会在 2.5 秒后自动 yield 包含“撤回”的文本，只适合本地快速验证。现在需要接入真实麦克风语音识别。

主要内容：

- 删除 `mockSpeechStream()`
- 引入 `speech_to_text`
- 在 `_GlobalSosCountdownSheetState` 中增加 `SpeechToText _speech`
- TTS 播报结束后调用 `_startSpeechListening()`
- 通过 `_speech.initialize()` 初始化语音识别，并记录 `onStatus` / `onError` 日志
- 使用 `localeId: 'zh_CN'`
- 使用 `SpeechListenOptions(partialResults: true)` 接收实时识别结果
- 在 `onResult` 中读取 `recognizedWords`
- 命中 `撤回`、`取消求助`、`不要发送` 后，先停止语音识别，再调用现有 `_submitRevoke(cancelMode: 'voice')`
- 在 `dispose()` 中调用 `_speech.cancel()`，释放麦克风资源
- 如果麦克风权限被拒绝或识别不可用，只记录日志并显示“语音撤回不可用，请使用按钮撤回”，倒计时继续运行

原生权限检查：

Android 已存在：

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
```

并且已声明：

```xml
<action android:name="android.speech.RecognitionService"/>
```

iOS 已存在：

```xml
NSMicrophoneUsageDescription
NSSpeechRecognitionUsageDescription
```

因此本次没有修改 Android / iOS 原生权限文件。

验证结果：

```powershell
cd E:\SECP-frontend\mobile
.\flutterw.cmd analyze lib\features\elder\presentation\elder_global_sos_overlay.dart
```

结果：

```text
No issues found!
```

### 增强 SOS 真机语音识别可诊断性

变动文件：

```text
mobile\lib\features\elder\presentation\elder_global_sos_overlay.dart
```

变动原因：

真机测试时，用户说“撤回”后弹窗仍停留在倒计时界面，无法判断是麦克风没有输入、系统没有识别、识别结果不匹配，还是后端提交正在等待。

主要内容：

- 增加 `_lastRecognizedWords`，在语音提示行显示“识别到：xxx”
- `speech_to_text` 状态变为 `done` / `notListening` 且倒计时未结束时，自动重启监听
- 扩展撤回关键词匹配，包括 `撤了`、`撤销`、`取消`、`误触`、`车回`、`策回` 等常见识别结果
- `onError` 遇到非永久错误时尝试重新监听；永久错误才标记语音不可用
- 使用 `ListenMode.confirmation`，更贴近短指令确认场景

验证结果：

```powershell
cd E:\SECP-frontend\mobile
.\flutterw.cmd analyze lib\features\elder\presentation\elder_global_sos_overlay.dart
```

结果：

```text
No issues found!
```

### 增加 SOS 全链路调试日志与前端命令速查

变动文件：

```text
mobile\lib\features\elder\presentation\elder_global_sos_overlay.dart
docs\前端运行命令速查.md
```

变动原因：

真机测试时需要判断 SOS 流程到底断在创建求助单、TTS、STT、关键词匹配、撤回接口、立即发送接口还是网络层，因此增加统一日志。另整理前端运行命令，方便下次直接复制。

主要内容：

- 增加统一日志方法 `_sosLog()`，日志前缀为 `[SOS]`
- 点击 SOS 时记录 `API_BASE`、`useMockSos`、token 状态
- 创建求助单成功后记录 `alertId`、`status`、`serverTime`、`revokeDeadline`
- 弹窗打开/关闭记录结果
- 倒计时开始、停止、超时触发记录日志
- TTS 开始、完成、失败 fallback 记录日志
- STT 初始化、权限、监听启动、状态变化、错误、自动重启记录日志
- 每次语音识别结果记录 `recognizedWords`
- 关键词匹配记录 `matched=true/false`
- 撤回和立即发送接口记录 start / success / failed
- 新增 `docs\前端运行命令速查.md`，记录后端、模拟器、真机热点、真机 WiFi、Windows 桌面端运行命令

验证结果：

```powershell
cd E:\SECP-frontend\mobile
.\flutterw.cmd analyze lib\features\elder\presentation\elder_global_sos_overlay.dart
```

结果：

```text
No issues found!
```

### 优化 SOS 语音不可用与网络超时提示

变动文件：

```text
mobile\lib\features\elder\presentation\elder_global_sos_overlay.dart
```

变动原因：

真机测试出现“语音撤回不可用”和后端请求 `connection timeout`，需要在 UI 和日志里更明确地区分麦克风权限、系统语音服务不可用、语音初始化失败、后端网络超时等情况。

主要内容：

- 在启动 `speech_to_text` 前通过 `permission_handler` 主动请求麦克风权限
- 增加 `_voiceUnavailableReason`，界面显示具体不可用原因
- 永久语音识别错误会显示错误原因，而不是只显示通用“不可用”
- 撤回/发送接口失败时通过 `_friendlySubmitError()` 转成中文短提示
- 后端超时提示改为“连接后端超时，请检查手机和电脑网络”

验证结果：

```powershell
cd E:\SECP-frontend\mobile
.\flutterw.cmd analyze lib\features\elder\presentation\elder_global_sos_overlay.dart
```

结果：

```text
No issues found!
```

### 增加麦克风权限设置入口与模拟器授权命令

变动文件：

```text
mobile\lib\features\elder\presentation\elder_global_sos_overlay.dart
docs\前端运行命令速查.md
```

变动原因：

模拟器显示“麦克风权限未开启”，需要更快定位和处理运行时权限问题。

主要内容：

- 当语音行显示“麦克风权限未开启”时，点击该行会打开 App 设置页
- 在命令速查中增加 `adb shell pm grant ... RECORD_AUDIO` 授权命令
- 已对当前模拟器执行授权：

```powershell
& 'C:\Users\张博龙\AppData\Local\Android\Sdk\platform-tools\adb.exe' shell pm grant com.laoleme.smartcare.mobile android.permission.RECORD_AUDIO
```

验证结果：

```powershell
cd E:\SECP-frontend\mobile
.\flutterw.cmd analyze lib\features\elder\presentation\elder_global_sos_overlay.dart
```

结果：

```text
No issues found!
```

### 增加 STT mock 开关并修复语音监听重复重启

变动文件：

```text
mobile\lib\core\config\app_config.dart
mobile\lib\features\elder\presentation\elder_global_sos_overlay.dart
docs\前端运行命令速查.md
```

变动原因：

模拟器和部分国产 Android ROM 的系统 SpeechRecognizer 会返回 `error_client` / `error_network`，说明系统语音识别服务不可用或依赖网络服务不可达。日志还显示 `notListening` 与 `done` 会连续触发两次重启，导致重复启动 listen。

主要内容：

- 新增 `AppConfig.useMockStt`，通过 `--dart-define=USE_MOCK_STT=true` 启用
- mock STT 只模拟“识别到撤回”，撤回接口仍走真实后端
- 增加 `_speechStartInFlight`、`_speechRestartPending`、`_speechPermanentlyUnavailable`，避免重复启动系统语音监听
- 语音服务永久不可用后不再反复重启
- 命令速查中增加模拟器 STT mock 运行命令

验证结果：

```powershell
cd E:\SECP-frontend\mobile
.\flutterw.cmd analyze lib\core\config\app_config.dart lib\features\elder\presentation\elder_global_sos_overlay.dart
```

结果：

```text
No issues found!
```

### 将 SOS 语音撤回切换为讯飞流式听写 WebSocket

变动文件：

```text
mobile\lib\core\config\app_config.dart
mobile\lib\features\elder\presentation\elder_global_sos_overlay.dart
mobile\lib\features\elder\presentation\elder_home_page.dart
mobile\pubspec.yaml
mobile\pubspec.lock
docs\前端运行命令速查.md
```

变动原因：

荣耀等国内 Android 真机的系统 SpeechRecognizer 可能返回 `error_client` / `error_network`，导致 `speech_to_text` 不可用。改为通过 `record` 采集 PCM 音频流，再用 `web_socket_channel` 直接接入科大讯飞语音听写 WebAPI。

主要内容：

- 移除 `speech_to_text` 依赖和老人首页旧弹窗中的残留 `SpeechToText` 逻辑
- 保留全局 SOS 弹窗原有结构：TTS 播报 -> 语音监听 -> 倒计时进度条 -> 撤回/立即发送按钮
- 新增 `XFYUN_IAT_APP_ID`、`XFYUN_IAT_API_KEY`、`XFYUN_IAT_API_SECRET` 三个 `--dart-define` 配置项
- 启动讯飞录音前先主动请求麦克风权限，并记录 `microphone permission` 与 `record permission` 两层日志
- 使用 HMAC-SHA256 生成讯飞 WebSocket 鉴权 URL
- 将讯飞 WebSocket 鉴权 URL 的 query 参数改为手动 `Uri.encodeComponent` 编码，避免 `date` 中空格被编码为 `+` 后导致服务端拒绝升级 WebSocket
- 将 `was not upgraded to websocket` 归类为讯飞鉴权/应用权限类错误，方便真机排查
- 新增 `XFYUN_IAT_HOST` 与 `XFYUN_IAT_PATH`，默认端点使用流式听写 v2：`wss://iat-api.xfyun.cn/v2/iat`
- 保留通过 `--dart-define=XFYUN_IAT_HOST=iat.xf-yun.com --dart-define=XFYUN_IAT_PATH=/v1` 临时切到旧鉴权文档示例端点的能力
- 如果讯飞返回缺少 `code` 字段的包，改为记录原始 JSON 并忽略，不再直接显示 `讯飞识别错误：-1`
- 使用 `record` 启动 `AudioEncoder.pcm16bits`、16kHz、单声道录音流
- 按讯飞格式发送 `status=0/1/2` 的音频 JSON 帧
- 解析讯飞返回的 `data.result.ws[].cw[].w`，命中“撤回 / 取消 / 不要发”等关键词后调用 `_submitRevoke(cancelMode: 'voice')`
- 保留 `_isSubmitting` 并发锁，避免语音撤回、按钮撤回、立即发送、倒计时超时重复提交
- `dispose()` 和提交前都会停止录音流并关闭 WebSocket
- 清理老人首页旧弹窗未使用组件和过期 `withOpacity()` 提示，避免干扰后续分析
- 文档新增真实讯飞 STT 与本地 `USE_MOCK_STT=true` 两套运行命令

安全注意：

- 讯飞密钥没有写入仓库源码或文档，运行时通过 `--dart-define` 传入
- 移动端内置第三方密钥仍有被反编译风险，生产环境建议改成后端签发短时鉴权地址或后端代理
- 本次聊天中已暴露测试密钥，正式上线前建议在讯飞控制台轮换密钥

验证结果：

```powershell
cd E:\SECP-frontend\mobile
.\flutterw.cmd analyze lib\core\config\app_config.dart lib\features\elder\presentation\elder_global_sos_overlay.dart lib\features\elder\presentation\elder_home_page.dart
```

结果：

```text
No issues found!
```

后续注意事项：

- 真机测试真实讯飞语音撤回时必须传 `XFYUN_IAT_*` 三个配置
- 如果 UI 显示“语音撤回不可用：讯飞配置缺失”，说明没有传讯飞配置
- 如果没有 `xfyun websocket ready` 日志，优先检查外网、讯飞服务和密钥
- 如果有录音流但没有识别文字，优先检查麦克风权限、录音输入和说话时机

### 增加讯飞语音撤回组员使用说明

变动文件：

```text
docs\讯飞语音撤回组员使用说明.md
```

变动原因：

SOS 语音撤回已在真机跑通，需要给组员一份安全、可复制的联调说明，同时避免把真实讯飞密钥写进 Git。

主要内容：

- 说明 SOS 语音撤回的完整业务流程
- 说明后端启动、电脑 IP 查询、真机运行、模拟器运行命令
- 说明 `APPID`、`APIKey`、`APISecret` 通过 `--dart-define` 传入
- 强调真实密钥不要提交到 Git，应通过私聊或安全渠道发给组员
- 记录成功日志和常见问题排查方式

验证结果：

文档新增，无代码变动。
