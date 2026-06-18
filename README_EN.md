<p align="center">
  <a href="README.md">简体中文</a> · <a href="README_EN.md">English</a> · <a href="README_JA.md">日本語</a> · <a href="README_KO.md">한국어</a> · <a href="README_ES.md">Español</a>
</p>

# TEMU Product-Image Batch Generator

Drop a batch of product inputs into `input/` — each product can be **a single image** or **a folder (multiple reference shots of the same product)** — and this tool generates N e-commerce main images / image sets for each one, following its matching creative prompt, using **codex's built-in `image_gen`** (runs on your codex subscription, **no API key needed**). Results land in `output/`.

Good for: turning a batch of real product photos into TEMU / cross-border / online-store main images + image sets, each in the style you specify.

---

## 1. Prerequisites (one time)

You only need the **codex CLI, logged in** (a codex subscription is enough):

```bash
codex --version      # should print a version
codex login          # log in if you haven't
```

No Python, no `OPENAI_API_KEY`, nothing else to install.

---

## 2. Install into codex

Drop the whole `temu-batch-imagegen/` folder into codex's skills directory:

```bash
cp -R temu-batch-imagegen ~/.codex/skills/
```

> You can also skip the skills directory and just `cd` into this folder to use it (see "Option B").

---

## 3. How to use

> Core convention: **every unit in `input/` (single images + image folders) is processed. You are never asked "which one / which prompt / how many"** — all three are predetermined (process everything, match prompts by name, count comes from the prompt text).

### Easiest: double-click `批量出图.command` (for non-technical users)
Drop images into `input/`, then **double-click `批量出图.command`** — it opens a terminal, runs the batch, and pops open the `output/` folder when done.
- If `input/` is empty it shows a friendly message and opens the input folder; if codex isn't installed / logged in it errors clearly.
- On first double-click, if macOS blocks it, **right-click → Open** once to confirm.
- Same requirement: **codex installed + logged in**.

### Option A: one command (recommended, terminal users)
1. Put your **inputs** into `input/`. Two forms can be mixed:
   - **A single image** (`dress.png`) = one product, one reference shot;
   - **A folder** (`jeans/`, holding several photos of the same product) = one product's **image set**; all photos inside are fed into the same session as multi-angle references.
2. Prepare prompts (`prompt/*.txt`, plain natural-language requirements): the generic one is named `默认.txt` ("default"); to customize a specific product, create a `.txt` **named after the image or folder**.
3. Run, inside this folder:

```bash
bash batch.sh            # up to 3 parallel processes by default
MAX=5 bash batch.sh      # raise concurrency to go faster (mind your codex rate limits)
```

- **One image, one process**: each image gets its own independent codex session; default 3 in parallel, and **failures automatically fall back to serial retry**.
- **Automatic prompt matching**: each unit looks up `prompt/<name>.txt` by its **name** (image / folder name); if there's no same-name file it uses `prompt/默认.txt`; if `prompt/` has only one `.txt`, every unit uses it.
- **The number of images is written in the prompt** (e.g. "output 6 × 3:4 + 1 × 1000×1000"); to change the count, edit the prompt text — the command stays the same.
- Results land in `output/batch-<timestamp>/<image-name>/01.png 02.png …`, logs in that folder's `.logs/`; the script runs a size self-check at the end.

### Option B: let codex run it (autonomous, no questions)
With images in `input/` and prompts in place, start codex in this folder and tell it:
> Use the temu-batch-imagegen skill to generate my images

codex will **process every unit in `input/`** (single images + folders, no questions), generating and writing to `output/batch-<timestamp>/<unit-name>/` by the same rules.

> A single product runs the same `bash batch.sh` — the script just processes that one, no special command needed.

---

## 4. Layout

```
temu-batch-imagegen/
├── README.md           # 简体中文 (default)
├── README_EN.md        # this file
├── SKILL.md            # codex execution flow (codex reads this)
├── 批量出图.command     # double-click launcher (macOS, for non-technical users)
├── batch.sh            # batch generator: one session per image, 3 parallel + serial fallback
├── input/              # put [single images] or [image folders] here (.png/.jpg/.webp, mixable)
│   ├── dress.png       #   single image = one product
│   └── jeans/          #   folder = one product's image set (multi-angle references)
├── prompt/             # creative prompt templates (.txt; matched by name, generic one = 默认.txt)
│   └── 默认.txt
├── output/             # results: batch-<timestamp>/<unit-name>/01.png 02.png …
└── example/            # runnable sample (same layout as a real project: input + prompt + output)
    ├── input/product.png
    └── prompt/默认.txt
```

---

## 5. Tips for writing prompts

- **Write in plain language**, like a brief — spell out "product / style / requirements" (see `prompt/默认.txt`, which is a real brief).
- Want foreign-language copy on the image (e.g. Japanese selling points)? Just say so in the prompt, e.g. "natural, refined Japanese copy".
- **State every requirement explicitly**: whatever you want — size, color fidelity, style, faces or no faces, background, how to handle brand logos — set it per your product and platform. The tool only follows the prompt and **assumes no constraints for you**.
- For a set of N images that are **each different**, say so in the prompt: "generate each independently, vary each one (pose/scene/etc.)" to avoid "same image, different text".

## 6. Notes

- **Foreign text on images may have typos**: image models occasionally misspell foreign-language text. Check each result; for any you don't like, ask codex to **regenerate just that one**. For text that must be 100% accurate, generate clean images first and overlay the copy precisely later with another tool.
- Intermediate files stay in codex's default directory `~/.codex/generated_images/`; final results are in this project's `output/`.

---

*Generation runs on codex's built-in `image_gen` (your subscription), so there's no API key to manage. This is the macOS version.*
