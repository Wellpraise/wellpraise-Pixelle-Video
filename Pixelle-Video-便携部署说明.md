# Pixelle-Video 便携部署与使用说明

> 一份可以在**任意电脑（macOS / Linux / Windows）**上跑起来的完整说明。
> 已集成 **Agnes AI**（文案 / 图片 / 视频）+ **Edge TTS**（免费口播，无需 key）+ **ffmpeg**（合成）。
> 本文档由 2026-09-11 的成功配置整理而成，所有报错点均已修复。

---

## 一、它是什么

Pixelle-Video 是一个 AI 全自动短视频引擎，能根据一句主题/文案，自动完成：

```
主题文案(旁白) → 逐镜画面(图/视频) → 口播配音 → BGM → 合成完整短视频
```

本次已打通的**端到端主链路**（无需任何额外付费 key）：

| 环节 | 引擎 | 说明 |
|------|------|------|
| 文案/旁白 | Agnes `agnes-3.0-flash` | LLM，OpenAI 兼容协议 |
| 画面(图片) | Agnes `agnes-image-2.5-flash` | 图生画面 |
| 口播配音 | Microsoft **Edge TTS** | 免费、无需 API key、无需联网 key |
| 合成 | **ffmpeg** | 拼接 + BGM + 字幕 |

> ⚠️ "数字人口播"（会动的说话人视频）需要参考图→对口型视频能力，只有 **阿里云 DashScope** 或 **RunningHub** 支持，Agnes 暂不提供该模型。若要用数字人，需在 `config.yaml` 里补配 DashScope key（见第八节）。

---

## 二、从压缩包开始（最快路径）

1. 把整个项目目录拷到目标电脑（或用压缩包），解压。
2. 进入目录，装依赖 + 建虚拟环境：

   ```bash
   cd pixelle-video
   python3 -m venv .venv
   # macOS/Linux:
   source .venv/bin/activate
   # Windows PowerShell:
   .venv\Scripts\Activate.ps1
   pip install -e .
   ```

3. 安装 **ffmpeg**（必需，合成要用）：

   - macOS（Homebrew）:  `brew install ffmpeg`
   - Ubuntu/Debian:  `sudo apt install ffmpeg`
   - Windows: `winget install Gyan.FFmpeg` 或下载 exe 放系统目录
   - 验证：`ffmpeg -version`

4. 安装 Playwright 浏览器（用于 HTML 模板渲染画面，必需）：

   ```bash
   .venv/bin/python -m playwright install chromium
   ```

5. 配置 API（见第三节），然后启动（见第五节）。

---

## 三、配置 `config.yaml`（核心）

根目录有 `config.yaml`。关键三处：

```yaml
# 1) LLM（文案/旁白）—— Agnes
llm:
  api_key: "你的AgnesKey"
  base_url: "https://apihub.agnes-ai.com/v1"
  model: "agnes-3.0-flash"

# 2) 直连 API 供应商
api_providers:
  agnes:
    api_key: "你的AgnesKey"
    base_url: "https://apihub.agnes-ai.com/v1"
    use_proxy: false
    video_mode: ""          # Agnes 视频模式；留空自动尝试，已知正确值可填

# 3) ComfyUI / 各能力默认工作流
comfyui:
  tts:
    default_workflow: selfhost/tts_edge.json   # 口播用 Edge TTS（免费）
  image:
    default_workflow: api/agnes/agnes-image-2.5-flash
  video:
    default_workflow: api/agnes/agnes-video-2.5-flash
```

要点：
- **口播默认走 Edge TTS，不需要任何 API key**，只要网络能访问微软服务。
- 图片/视频默认走 Agnes 直连 API（`api/agnes/...`），不要选 `runninghub/` 或 `selfhost/` 的 flux 工作流（本机没装本地 ComfyUI，会连不上 8188）。
- 用你**已有**的 Agnes key 即可。

---

## 四、必须做的三处代码修复（已内置在本包里）

本包已包含以下修复（都是针对"推理模型 + 沙箱环境"踩过的坑），**若你在干净源码上手动部署，请自行补上**：

### 1. LLM 空/截断自动重试（`pixelle_video/services/llm_service.py`）
Agnes `3.0-flash` 是**推理模型**，会把 token 预算花在内置思考上：
- 有时正文 `content` 为空；
- 有时 JSON 写到一半被截断（`finish_reason=length`）。

两者都会让下游 JSON 解析报 `No valid JSON found`。

修复：`_create_with_retry` 在"空内容 **或** `finish_reason==length`"时，自动把 `max_tokens` 预算翻倍重试（2000→4000→8000，上限 16000，最多 3 次）。对普通模型零额外开销。

### 2. 沙箱文件操作降级（`pixelle_video/services/api_media.py`、`video.py`、`frame_html.py`、`frame_processor.py`）
在受限环境（如某些沙箱）里 `os.replace/rename/unlink` 会被拦成 `Operation not permitted`：
- 图片保存：`os.replace` 失败时降级为 `shutil.copy2` + 容忍删除；
- 临时文件清理：`os.unlink` 包 `try/except`，删不掉只打 warning，不影响出片。

### 3. 持久化启动（`start.sh` + `start_detached.py`）
- 启动前清 `PYTHONPATH`（避免注入的 sitecustomize shim 让 `mkdir(exist_ok=True)` 崩溃）、清所有 `*PROXY`（避免 OpenAI SDK 把 Agnes 请求绕到本地代理报 Connection error）、补全 `PATH`（确保找得到 ffmpeg）。
- 用 `start_new_session=True`（等价 setsid）让服务脱离会话，不被回收。

---

## 五、启动

### 方式 A：一键脚本（推荐）
```bash
cd pixelle-video
bash start.sh
```
自动完成：杀旧进程（按端口精确 kill）→ 清环境 → 补 PATH → 启动 API + Web UI → 健康检查。

访问：
- Web UI:  http://127.0.0.1:8504
- API:      http://127.0.0.1:8000 （文档 /docs）

### 方式 B：手动
```bash
source .venv/bin/activate        # Windows: .venv\Scripts\Activate.ps1
unset PYTHONPATH                 # 清掉注入的 shim（如有）
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy NO_PROXY no_proxy
python api/app.py --host 127.0.0.1 --port 8000 &
python -m streamlit run web/app.py --server.port 8504 --server.address 127.0.0.1 --server.headless true
```

### 端口说明（避免冲突）
- `8000` API，`8504` Web UI。
- 8501/8502/8503 留给 MoneyPrinter 系，勿占用。

---

## 六、使用

1. 打开 http://127.0.0.1:8504
2. **选"短视频生成 / 标准"模式**（不要用"数字人口播"，除非配了 DashScope）。
3. 输入主题或文案 → 选场景数（5 左右）→ 生成。
4. 产物在 `output/<时间戳>_<id>/final.mp4`。

注意：Agnes 推理偏慢，**单次 LLM 调用 85~170 秒**，整条流水线请耐心等待，不要中途取消。

---

## 七、常见问题（FAQ）

| 现象 | 原因 / 解决 |
|------|-------------|
| `FFmpeg not found` | 没装 ffmpeg，或 PATH 没包含其目录。`brew install ffmpeg` 后重启。 |
| `No valid JSON found` | Agnes 推理吃光 token。已由第 4 节修复覆盖；仍失败=网络/额度，重试或换 key。 |
| `openai.APIConnectionError: Connection error` | 代理变量被注入。启动前 `unset` 所有 `*PROXY`（start.sh 已做）。 |
| `PermissionError: EEXIST mkdir 'output'` | 注入的 sitecustomize shim。启动前 `unset PYTHONPATH`（start.sh 已做）。 |
| `Operation not permitted (rename/unlink)` | 沙箱拦截文件操作。已由第 4 节降级覆盖。 |
| 服务启动后几秒挂掉 | 后台进程被会话回收。用 `start.sh`（含 setsid 脱离）。 |
| 改了代码没生效 | 旧进程没被杀。用 `start.sh`（按端口 kill）；核对 `lsof` 监听 PID 是否变化。 |
| `ps` 报 operation not permitted | 受限环境正常现象，改用 `lsof -nP -iTCP:<port> -sTCP:LISTEN` 判断。 |
| Agnes 视频 429 / 无结果 | 免费额度限流 + `video_mode` 未公开；图片链路不受影响。 |

---

## 八、（可选）启用数字人口播 / 阿里云能力

若想让"数字人口播"（会动的说话人视频）跑起来，需要在 `config.yaml` 补一个阿里云 DashScope key：

```yaml
api_providers:
  dashscope:
    api_key: "你的阿里云DashScopeKey"
    base_url: "https://dashscope.aliyuncs.com"
```

key 申请：https://dashscope.aliyun.com （控制台 → API-KEY 管理）。
配好后在 Web UI 的"口播视频合成服务"选 `api` + DashScope 模型即可。
> 若没有阿里云 key，请始终用"短视频生成"模式（Agnes + Edge TTS），全链路已通。

---

## 九、目录速查

```
pixelle-video/
├─ config.yaml           # 你的配置（key 在这）
├─ start.sh              # 一键启动（推荐）
├─ start_detached.py     # 持久化启动器（被 start.sh 调用）
├─ api/app.py            # FastAPI 后端 (8000)
├─ web/app.py            # Streamlit 前端 (8504)
├─ pixelle_video/        # 核心代码（已含 4 处修复）
├─ workflows/            # 各能力 ComfyUI/API 工作流
├─ templates/            # HTML 画面模板
├─ bgm/                  # 背景音乐素材
├─ pyproject.toml        # 依赖声明（pip install -e . 用）
└─ output/               # 生成产物
```

（`.venv`、`libs`、`temp`、`output` 为运行时产物/本机缓存，**无需**拷到别的电脑，`pip install -e .` 会自动重建依赖。）
