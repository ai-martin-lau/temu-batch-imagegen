#!/usr/bin/env bash
# 批量出图.command — 双击即跑的启动器（macOS）
# 双击它 → 自动打开"终端" → 进入本文件夹 → 运行 batch.sh。
# 给非技术用户用：把图丢进 input/，双击这个文件就行。
set -u

# 切到本文件所在目录（双击时工作目录通常不是这里）
cd "$(dirname "$0")" || exit 1

# 兜底把 codex 默认安装位置加进 PATH（双击启动可能拿不到登录 shell 的 PATH）
export PATH="$HOME/.codex/bin:$PATH"

echo "===================================="
echo "              批量出图"
echo "===================================="
echo

pause() { echo; read -n 1 -s -r -p "按任意键关闭窗口…"; echo; }

# 1) 检查 codex 是否可用
if ! command -v codex >/dev/null 2>&1; then
  echo "❌ 没找到 codex 命令。"
  echo "   请先安装 codex CLI 并登录（终端执行：codex login）。"
  pause; exit 1
fi

# 2) 检查 input/ 是否有图（直接放的图片，或【含图片的文件夹=组图】里的图片）
have_img="$(find input -maxdepth 2 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) 2>/dev/null | head -1)"
if [ -z "$have_img" ]; then
  echo "📂 input/ 文件夹里还没有图片。"
  echo "   请把商品图（.png / .jpg / .jpeg / .webp）放进 input/ 文件夹，"
  echo "   或把同一商品的多张图放进 input/ 下的一个【文件夹】（组图），再双击本文件。"
  open input 2>/dev/null   # 顺手帮用户打开 input 文件夹
  pause; exit 0
fi

echo "✅ 检测到输入，开始批量出图（每个图片 / 每个组图文件夹各出一套）…"
echo

# 3) 跑批处理
bash batch.sh
rc=$?

echo
if [ "$rc" -eq 0 ]; then
  echo "🎉 全部跑完。成品在 output/ 文件夹里。"
  open output 2>/dev/null   # 跑完帮用户打开 output 文件夹
else
  echo "⚠️ 运行结束但有异常（退出码 $rc），请看上面的输出/日志。"
fi
pause
