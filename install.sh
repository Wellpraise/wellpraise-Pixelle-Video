#!/usr/bin/env bash
# Pixelle-Video 跨平台安装脚本 (macOS / Linux)
# 用法: bash install.sh
# Windows 用户请用 install.bat
set -e
cd "$(dirname "$0")"

echo "==> [1/4] 检查 Python 版本 (需要 >= 3.11)"
python3 --version

echo "==> [2/4] 创建虚拟环境 .venv"
if [ ! -d .venv ]; then
  python3 -m venv .venv
fi
source .venv/bin/activate

echo "==> [3/4] 安装依赖 (pip install -r requirements.txt + 项目本身)"
pip install --upgrade pip
pip install -r requirements.txt
pip install -e .

echo "==> [4/4] 安装 Playwright 浏览器 (渲染画面用)"
python -m playwright install chromium

echo ""
echo "==> 安装完成。请确认 ffmpeg 已安装:"
if command -v ffmpeg >/dev/null 2>&1; then
  echo "    ✅ ffmpeg 已找到: $(command -v ffmpeg)"
else
  echo "    ⚠️  未找到 ffmpeg。macOS: brew install ffmpeg ;  Ubuntu: sudo apt install ffmpeg"
fi
echo ""
echo "==> 请确认 config.yaml 已填入你的 Agnes key (参考 Pixelle-Video-便携部署说明.md 第三节)"
echo ""
echo "启动: bash start.sh   然后访问 http://127.0.0.1:8504"
