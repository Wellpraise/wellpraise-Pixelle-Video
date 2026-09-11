@echo off
rem Pixelle-Video Windows 安装脚本
rem 用法: 双击运行 或 在 cmd 里执行 install.bat
cd /d %~dp0

echo ==^> [1/4] 检查 Python 版本 (需要 ^>= 3.11^)
python --version
if errorlevel 1 (
  echo [错误] 未找到 python。请安装 Python 3.11+ 并加入 PATH。
  pause
  exit /b 1
)

echo ==^> [2/4] 创建虚拟环境 .venv
if not exist .venv (
  python -m venv .venv
)
call .venv\Scripts\activate.bat

echo ==^> [3/4] 安装依赖
python -m pip install --upgrade pip
pip install -r requirements.txt
pip install -e .

echo ==^> [4/4] 安装 Playwright 浏览器
python -m playwright install chromium

echo.
echo ==^> 安装完成。请确认 ffmpeg 已安装 (建议  winget install Gyan.FFmpeg^)
where ffmpeg >nul 2^>nul
if %errorlevel%==0 (
  echo     [OK] ffmpeg 已找到
) else (
  echo     [警告] 未找到 ffmpeg，请安装
)
echo.
echo 请确认 config.yaml 已填入你的 Agnes key
echo 启动: 运行 start_web.bat 后访问 http://127.0.0.1:8504
pause
