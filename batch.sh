#!/usr/bin/env bash
# batch.sh — 批量出图流水线
#
# 把 input/ 里的【每一个输入单元】各起一个独立 codex 会话，按各自的 prompt 出整套图。
# 一个「输入单元」可以是：
#   · 单个图片：input/连衣裙.png          → 1 张参考图，出一整套。
#   · 一个文件夹（组图）：input/连衣裙/    → 该文件夹内的【多张图】是同一个商品的多角度参考，
#                                          全部塞进【同一个会话】当多张 -i 参考图，综合参考出一整套。
#
#   · 隔离：一单元一进程 = 一个独立 codex 会话，不同商品互不干扰。
#   · 并行：默认最多 3 个进程同时跑（MAX 可调）；失败的单元最后回退为串行重试。
#   · 张数：由 prompt 文本里写明（如"输出6张3:4 + 1张1000×1000"），codex 自己读、自己循环调
#           image_gen，本脚本不传 n。
#
# prompt 匹配规则（每个单元按【名字】找 prompt，统一用 .txt）：
#   名字 = 文件夹名（组图）或 不带扩展名的图片名（单图）。
#   1) 同名优先：prompt/<名字>.txt
#   2) 默认兜底：prompt/默认.txt
#   3) 单文件兜底：prompt/ 里只有一个 .txt 时，直接用它（名字随便）
#   都没命中 → 跳过该单元并告警。
#
# 用法：
#   bash batch.sh            # 默认并发 3
#   MAX=5 bash batch.sh      # 自定义并发
set -u

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

MAX="${MAX:-3}"
RETRY="${RETRY:-3}"   # 每个商品「尺寸不达标」时整套重出的最大次数（绝不裁切，只重生）
EFFORT="high"   # 出图固定 high，写死、不读外部环境变量（你本地设的 xhigh 不影响出图；保证发给别人也一致）。要改档只改这里：high/xhigh/medium
RUN_DIR="output/batch-$(date +%Y%m%d-%H%M%S)"
LOGDIR="$RUN_DIR/.logs"
mkdir -p "$RUN_DIR" "$LOGDIR"

shopt -s nullglob nocaseglob nocasematch

prompts=( prompt/*.txt )
if [ ${#prompts[@]} -eq 0 ]; then
  echo "prompt/ 里没有 prompt 文件（.txt），先写一个再跑。"
  exit 1
fi

# 为某个单元解析出该用哪个 prompt 文件；找不到返回非 0
resolve_prompt() {
  local base="$1"
  [ -f "prompt/$base.txt" ] && { echo "prompt/$base.txt"; return 0; }
  [ -f "prompt/默认.txt" ]  && { echo "prompt/默认.txt";  return 0; }
  if [ ${#prompts[@]} -eq 1 ]; then echo "${prompts[0]}"; return 0; fi
  return 1
}

# 把"换行连接的多条路径"还原成数组 REPLY_IMGS（bash 3.2 兼容，避免 mapfile）
imgs_from_str() {
  REPLY_IMGS=()
  local line
  while IFS= read -r line; do
    [ -n "$line" ] && REPLY_IMGS+=("$line")
  done <<< "$1"
}

# ---- 扫描 input/，归并成"输入单元"（单图 or 组图文件夹）----
# 三个平行数组，按下标对齐：U_NAME[i] 名字 / U_PROMPT[i] prompt路径 / U_IMGS[i] 该单元的图(换行连接)
declare -a U_NAME=() U_PROMPT=() U_IMGS=()

for entry in input/*; do
  if [ -d "$entry" ]; then
    # 组图文件夹：收集夹内所有图片当同一商品的多张参考
    base="$(basename "$entry")"
    gimgs=( "$entry"/*.png "$entry"/*.jpg "$entry"/*.jpeg "$entry"/*.webp )
    if [ ${#gimgs[@]} -eq 0 ]; then
      echo "✗ 组图文件夹 $base/ 里没有图片，跳过"
      continue
    fi
    imgstr="$(printf '%s\n' "${gimgs[@]}")"
  else
    # 单个文件：只认图片扩展名
    case "$entry" in
      *.png|*.jpg|*.jpeg|*.webp) ;;
      *) continue ;;
    esac
    bn="$(basename "$entry")"; base="${bn%.*}"
    imgstr="$entry"
  fi

  if ! pf="$(resolve_prompt "$base")"; then
    echo "✗ $base 找不到匹配 prompt（无同名、无 默认、且 prompt 不止一个），跳过"
    continue
  fi
  U_NAME+=("$base"); U_PROMPT+=("$pf"); U_IMGS+=("$imgstr")
done

n=${#U_NAME[@]}
if [ "$n" -eq 0 ]; then
  echo "input/ 里没有可处理的输入。请放入图片（.png/.jpg/.jpeg/.webp）或【含图片的文件夹（组图）】再跑。"
  exit 1
fi

# 把 outdir 里【已是 1:1 比例】的图等比缩放到精确 1000×1000（不裁切、不变形，只统一分辨率）
# image_gen 给不到精确像素（正方形固定约 1254×1254），故只能出图后由脚本归一化。
normalize_square() {
  local d="$1" f w h is11
  for f in "$d"/*.png; do
    [ -f "$f" ] || continue
    w=$(sips -g pixelWidth  "$f" 2>/dev/null | awk '/pixelWidth/{print $2}')
    h=$(sips -g pixelHeight "$f" 2>/dev/null | awk '/pixelHeight/{print $2}')
    [ -n "$w" ] && [ -n "$h" ] || continue
    # 判 1:1（容差 3%）；已是 1000×1000 就跳过
    is11=$(awk "BEGIN{r=$w/$h; print (r>0.97 && r<1.03)?1:0}")
    if [ "$is11" = "1" ] && { [ "$w" != "1000" ] || [ "$h" != "1000" ]; }; then
      sips -z 1000 1000 "$f" >/dev/null 2>&1   # -z 高 宽：1:1→1:1 等比，缩到精确 1000×1000
    fi
  done
}

# 起一个独立 codex 会话给一个单元出整套图
run_one() {  # $1=输出目录  $2=prompt文件  $3=日志文件  $4...=参考图(1张=单图 / 多张=组图)
  local outdir="$1" pf="$2" log="$3"; shift 3
  local imgs=( "$@" )
  mkdir -p "$outdir"
  local brief; brief="$(cat "$pf")"

  # 组装 -i 参考图：每张图各一个 -i（-i 是可变参数，多张可重复给）
  local iargs=() im
  for im in "${imgs[@]}"; do iargs+=( -i "$im" ); done

  # 参考图说明：单图 vs 组图（组图要强调"是同一个商品的多角度参考，不是不同商品")
  local refdesc
  if [ ${#imgs[@]} -eq 1 ]; then
    refdesc="本次只处理这一张参考图：${imgs[0]}。"
  else
    refdesc="本次参考图是【同一个商品的组图】（同一商品的多张参考，不同角度/细节）共 ${#imgs[@]} 张：$(printf '%s ' "${imgs[@]}")。请把它们当成同一个商品来综合参考、出同一套图；不要当成不同商品、不要每张各出一套。"
  fi

  # 注意：$outdir 后面紧跟中文字符时用 ${...}，否则 bash 会把中文首字节并进变量名
  local instr="${refdesc}严格按下面【创意 brief】出图。
**只准使用上面通过 -i 给你的参考图**：绝不要去读 input/ 里的其它文件、其它商品的图，也绝不要把 output/ 或 example/ 里的任何图当参考或输入——那些不是本商品的素材。
只用内置 image_gen：brief 要几张就调用几次，每张单独一次调用，每次产出一张不同的图（不是近似复制）；不要用 n 凑数、不要把多张拼到一张画布。
**严格按 brief 写明的要求执行**（颜色/版型/露脸/背景/品牌/文案/尺寸/风格等具体要求都在 brief 里），不自行增删、不假设固定值。
每生成一张立刻拷到 ${outdir}/ 命名 01.png 02.png …（两位补零）并打印绝对路径。
每张生成后核对其【比例】是否符合 brief（用 sips 读宽高算比例）；比例明显不对才重新生成那一张（**只许重生，绝不许裁切/缩放**）。1:1 正方形那张只看比例是否≈1:1（容差±5%，如 1254×1254 就算对），接近正方形就打 PASS；**严禁因像素大小/分辨率判它不达标或重生**——你只管比例，目标像素你不用知道，由本脚本最后统一处理。
全部出完并逐张核对【比例】后，在输出最后【单独打印一行】状态：所有图比例都达标就打印 SIZECHECK_PASS；只要还有任意一张比例不对就打印 SIZECHECK_FAIL（务必打印其一）。
全程自主、不要提问。
=== 创意 brief ===
$brief"
  # 注意：-i/--image 是可变参数(<FILE>...)，会把后面的 prompt 也当成图片吃掉。
  # 所以 prompt 不走位置参数，改用 stdin 管道喂给 codex，-i 后只留图片。
  # 思考档锁死 xhigh（不锁模型，模型仍跟随本机 codex 的滚动默认 → 自动跟升）
  #
  # 尺寸硬重试：整套最多 RETRY 次。每次判定只看「本次」输出——
  #   达标 = 进程成功(rc=0) + 有产出 + 本次未自报 SIZECHECK_FAIL。
  #   不达标就【清空本商品目录、整套重出】（只重生、绝不裁切）；用满次数仍不达标 → 返回 1 交回上层。
  # 每个商品用【独立 CODEX_HOME】：把 ~/.codex 下的东西软链进去（保留登录/版本/模型缓存等全部依赖），
  # 唯独 generated_images 用独立实体目录——这样 codex 生成图、以及它内部"find 最近生成图"定位产物，
  # 都只在自己目录里进行，根治并发时跨会话 cp 错图（串款）。软链不复制源，开销极小。
  local ch="$RUN_DIR/.codexhome/$(basename "$outdir")"
  mkdir -p "$ch/generated_images"
  local _it _nm
  for _it in "$HOME"/.codex/*; do
    _nm="$(basename "$_it")"
    [ "$_nm" = "generated_images" ] && continue
    ln -sf "$_it" "$ch/$_nm"
  done

  local attempt rc trylog ok=1
  for (( attempt=1; attempt<=RETRY; attempt++ )); do
    if [ $attempt -gt 1 ]; then
      rm -rf "$outdir"; mkdir -p "$outdir"
    fi
    trylog="${log}.try${attempt}"
    # 隔离本机 codex 个性化设置，确保"换一台机器/换一个人"出图效果一致、只由本项目 prompt 决定：
    #   --ignore-user-config       不读 ~/.codex/config.toml（登录仍保留，auth 走 CODEX_HOME）
    #   -c project_doc_max_bytes=0 禁用 AGENTS.md 注入（全局 ~/.codex/AGENTS.md 与项目级都不带入）
    # 注：~/.codex/hooks.json 不受这两项控制；普通用户一般没配 hooks，若你本机配了请知悉。
    printf '%s' "$instr" | CODEX_HOME="$ch" codex exec -s workspace-write -c approval_policy="never" \
      -c model_reasoning_effort="$EFFORT" \
      -c project_doc_max_bytes=0 --ignore-user-config \
      --skip-git-repo-check -C "$ROOT" "${iargs[@]}" > "$trylog" 2>&1
    rc=$?
    { echo "===== 第 ${attempt}/${RETRY} 次出图（rc=${rc}）====="; cat "$trylog"; } >> "$log"
    if [ $rc -eq 0 ] && produced "$outdir" && ! grep -q "SIZECHECK_FAIL" "$trylog"; then
      normalize_square "$outdir"   # 1:1 那张等比缩到精确 1000×1000（不裁切、不变形）
      [ $attempt -gt 1 ] && echo "（第 ${attempt} 次整套重出后比例达标）" >> "$log"
      rm -f "$trylog"; ok=0; break
    fi
    rm -f "$trylog"
    echo "→ 尺寸未达标或出图失败，准备整套重出（已用 ${attempt}/${RETRY} 次）" >> "$log"
  done
  rm -rf "$ch" 2>/dev/null   # 清理本商品独立 CODEX_HOME（含其 generated_images 中间产物；软链只删链接、不删源）
  return $ok
}

# 成功判定：输出目录里至少有一张 png
# 用数组+nullglob，避免 `ls 目录/*.png` 在无匹配时退化成"列目录"而误判
produced() { local f=( "$1"/*.png ); [ ${#f[@]} -gt 0 ]; }
count_png() { local f=( "$1"/*.png ); echo ${#f[@]}; }

declare -a failed=()   # 存失败单元的下标

echo "== 批量出图：$n 个输入单元，最大并发 $MAX =="
echo "== 输出目录：$RUN_DIR =="

# 第一轮：并发波次（每波最多 MAX 个）
i=0
while [ $i -lt $n ]; do
  pids=(); idxs=()
  for ((j=0; j<MAX && i<n; j++, i++)); do
    base="${U_NAME[$i]}"; pf="${U_PROMPT[$i]}"
    outdir="$RUN_DIR/$base"
    imgs_from_str "${U_IMGS[$i]}"; nimg=${#REPLY_IMGS[@]}
    if [ $nimg -gt 1 ]; then label="组图${nimg}张"; else label="单图"; fi
    echo "→ 启动 $base   ($label, prompt: $(basename "$pf"))"
    run_one "$outdir" "$pf" "$LOGDIR/$base.log" "${REPLY_IMGS[@]}" &
    pids+=($!); idxs+=($i)
  done
  # 等本波全部结束，逐个核对结果
  k=0
  for pid in "${pids[@]}"; do
    idx="${idxs[$k]}"; k=$((k+1))
    base="${U_NAME[$idx]}"; outdir="$RUN_DIR/$base"
    wait "$pid"; rc=$?
    if [ $rc -eq 0 ] && produced "$outdir"; then
      echo "✓ $base  → $(count_png "$outdir") 张"
    else
      echo "✗ $base 并发失败 (rc=$rc)，标记待串行重试"
      failed+=($idx)
    fi
  done
done

# 第二轮：失败的回退为串行，一个个重试
if [ ${#failed[@]} -gt 0 ]; then
  echo "== 回退串行重试 ${#failed[@]} 个 =="
  for idx in "${failed[@]}"; do
    base="${U_NAME[$idx]}"; pf="${U_PROMPT[$idx]}"; outdir="$RUN_DIR/$base"
    echo "→ 串行重做 ${base}（仅清空本商品目录 ${base}/ 后重出）"
    # 只删这一个出图不全的商品目录，绝不动其它商品或整个 output
    [ -n "$base" ] && [ -n "$RUN_DIR" ] && rm -rf "$RUN_DIR/$base"
    imgs_from_str "${U_IMGS[$idx]}"
    # 用 run_one 的返回码判定（0=尺寸达标），不能只看有没有图，否则尺寸一直不达标也会误报成功
    if run_one "$outdir" "$pf" "$LOGDIR/$base.serial.log" "${REPLY_IMGS[@]}" && produced "$outdir"; then
      echo "✓ $base 串行成功 → $(count_png "$outdir") 张"
    else
      echo "✗✗ $base 串行仍失败（尺寸未达标或零产出），看日志 $LOGDIR/$base.serial.log"
    fi
  done
fi

# 产出汇总（每张尺寸是否符合要求，已由各 codex 会话按 brief 自行核对；这里只汇总张数）
echo "== 产出汇总 =="
for d in "$RUN_DIR"/*/; do
  echo "  $(basename "$d"): $(count_png "$d") 张"
done

echo "== 完成。产出目录：$RUN_DIR =="
