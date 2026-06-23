<p align="center">
  <a href="README.md">English</a> · <a href="README_ZH.md">简体中文</a> · <a href="README_JA.md">日本語</a> · <a href="README_KO.md">한국어</a> · <a href="README_ES.md">Español</a>
</p>

# TEMU 商品图批量出图助手

把 `input/` 里的【一批商品输入】（每个商品可以是**一张图片**，也可以是**一个文件夹=同一商品的多张参考组图**），按各自匹配的【中文创意 prompt】，用 **codex 内置 image_gen**（走你的 codex 订阅，**免 API key**）各批量生成 N 张电商主图 / 套图，自动落到 `output/`。

适合：把一批实拍图，按风格各扩成 TEMU / 跨境电商 / 网店的主图 + 套图。

---

## 一、准备（一次性）

只需要 **codex CLI 并已登录**（你有 codex 订阅即可）：

```bash
codex --version      # 能打印版本即可
codex login          # 若未登录，按提示登录
```

无需 Python、无需 OPENAI_API_KEY、无需装任何额外东西。

---

## 二、把它接入 codex

把整个 `temu-batch-imagegen/` 文件夹放进 codex 的 skills 目录：

```bash
cp -R temu-batch-imagegen ~/.codex/skills/
```

> 也可以不放进 skills 目录，直接 `cd` 进本文件夹用（见"方式 B"）。

---

## 三、怎么用

> 核心约定：**input/ 里所有单元（单图 + 组图文件夹）都会被处理，不会问你"用哪个 / 哪个 prompt / 几张"**——这三件都已确定（全处理、按名字匹配 prompt、张数看 prompt 文本）。

### 最省事：双击 `批量出图.command`（给非技术用户）
把图丢进 `input/`，**双击 `批量出图.command`** 即可——会自动打开终端、跑完后弹出 `output/` 文件夹。
- input/ 为空会友好提示并打开 input 文件夹；没装/没登录 codex 会明确报错。
- 首次双击若被 macOS 拦，**右键 → 打开**确认一次即可。
- 前提同样是 **codex 已安装 + 登录**。

### 方式 A：一条命令批量（推荐，终端用户）
1. 把要出图的**输入**放进 `input/`，两种形态可混放：
   - **单张图片**（`连衣裙.png`）= 一个商品，1 张参考图；
   - **一个文件夹**（`牛仔裤/`，里面放同一商品的多张照片）= 一个商品的**组图**，夹内多张会一起作为多角度参考喂给同一会话。
2. 准备 prompt（`prompt/*.txt`，纯中文写需求）：通用的命名为 `默认.txt`；要给某个商品单独定制，就建一个和**图片名或文件夹名同名**的 `.txt`。
3. 在本文件夹里跑：

```bash
bash batch.sh            # 默认最多 3 个进程并发
MAX=5 bash batch.sh      # 想更快就调大并发（注意 codex 订阅可能限流）
```

- **一图一进程**：每张图各起一个独立 codex 会话，互不干扰；默认 3 个并行，**失败的自动回退串行重试**。
- **prompt 自动匹配**：每个单元按【名字】（图片名 / 文件夹名）找 `prompt/<名字>.txt`；没同名用 `prompt/默认.txt`；`prompt/` 里只有一个 `.txt` 时所有单元都用它。
- **出几张写在 prompt 里**（如"输出 6 张 3:4 + 1 张 1000×1000"），改张数只改 prompt 文本，命令不用动。
- 成品落 `output/batch-<时间戳>/<原图名>/01.png 02.png …`，日志在该目录 `.logs/`；脚本结束自动跑一遍尺寸自检。

### 方式 B：让 codex 跑（自动，不问问题）
把原图丢进 `input/`、prompt 放好后，在本文件夹启动 codex，对它说：
> 用 temu-batch-imagegen 这个 skill 帮我出图

codex 会**自动处理 `input/` 里的全部单元**（单图 + 组图文件夹，不问任何问题），按同样规则边生成边落到 `output/batch-时间戳/<单元名>/`。

> 只有 1 个商品也一样跑 `bash batch.sh`——脚本会自动只处理这一个，无需单独命令。

---

## 四、目录

```
temu-batch-imagegen/
├── README.md           # 本文件（中文，默认）
├── README_EN.md        # English
├── SKILL.md            # codex 执行流程（codex 读这个）
├── 批量出图.command     # 双击即跑的启动器（macOS，非技术用户用）
├── batch.sh            # 批量出图：input/ 每张图各起独立会话，并发3+失败回退串行
├── input/              # 放【单图】或【组图文件夹】（.png/.jpg/.webp，可混放）
│   ├── 连衣裙.png       #   单图 = 一个商品
│   └── 牛仔裤/          #   文件夹 = 一个商品的组图（多张多角度参考）
├── prompt/             # 中文创意 prompt 模板（.txt；按名匹配，通用的命名为 默认.txt）
│   └── 默认.txt
├── output/             # 出图：batch-时间戳/<单元名>/01.png 02.png …
└── example/            # 可运行范例（和真实项目同样布局：input + prompt）
    ├── input/product.png
    └── prompt/默认.txt
```

---

## 五、写 prompt 的几点经验

- **纯中文写**即可，像写需求一样把"商品 / 风格 / 要求"列清楚（参考 `prompt/默认.txt`，就是一份真实需求）。
- 想要图上带外语文案（如日文卖点），在 prompt 里用中文说明即可，例如"日文文案自然高级"。
- **把所有要求写明确**：你要什么就写什么——尺寸、颜色还原、风格、要不要露脸、背景、品牌 logo 怎么处理……都按你的商品和平台来定，工具只照 prompt 执行、**不替你假设任何约束**。
- 想要一套 N 张且**每张不同**，就在 prompt 里写明"每张独立生成、各张要有变化（姿势/场景等）"，避免出成"同一张换文字"。

## 六、注意

- **图上外语文案可能出错字**：图像模型渲染外语偶尔会写错字，出图后逐张核对；不满意的单张让 codex **只重生这一张**即可。对"必须 100% 准确"的文字，建议先出纯图、文案后期用工具精确叠加。
- 中间产物会留在 codex 默认目录 `~/.codex/generated_images/`，最终成品在本项目 `output/`。

---

*出图走 codex 内置 image_gen（你的订阅），无需管理 API key。本仓库为 macOS 版。*
