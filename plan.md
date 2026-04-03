# sys-toolkit 實作計畫

## 目標

將散落各處的常用工具整合為**單一 Docker 映像檔**，以 `docker run --rm -v ${PWD}:/data sys-toolkit <command>` 作為統一入口，提供拋棄式、跨平台的工具集。

---

## 現有資產盤點

| 目錄 | 工具 | 技術 | 遷移狀態 |
|---|---|---|---|
| `powershell/CountLines.ps1` | 統計行數 | PowerShell | 需改寫為 Shell Script |
| `powershell/FindDuplicates.ps1` | 尋找重複檔名 | PowerShell | draft 未提及，暫不納入 |
| `quick-extract/` | 快速解壓縮 | Alpine + p7zip | 需遷移至統一映像 |
| `video-frames/` | 影像擷取 | Alpine + FFmpeg | 需遷移至統一映像並擴增功能 |

---

## 功能規格

### 1. `count-lines` — 統計行數

移植自 `powershell/CountLines.ps1`。

```
sys-toolkit count-lines [OPTIONS]
```

| 參數 | 說明 | 預設 |
|---|---|---|
| `--exclude <prefix>` | 跳過名稱以此前墜開頭的資料夾 | 無 |
| `--ext <ext1,ext2>` | 僅計算指定副檔名 | 全部 |
| `--min-lines <n>` | 低於此行數的檔案不顯示 | 1 |
| `--summary` | 以副檔名分組統計，而非逐檔列出 | 否 |

實作要點：
- 使用 `find` + `wc -l` 取代 PowerShell 的 `Get-Content`
- 輸出格式與原版一致：靠右對齊行數 + 相對路徑，最後一行顯示總計

### 2. `empty-dirs` — 檢查空資料夾

```
sys-toolkit empty-dirs [OPTIONS]
```

| 參數 | 說明 | 預設 |
|---|---|---|
| `--delete` | 找到空資料夾後直接刪除 | 否（僅列出） |
| `--exclude <prefix>` | 跳過名稱以此前墜開頭的資料夾 | 無 |

實作要點：
- 使用 `find /data -type d -empty` 實現
- 預設僅列印路徑，加 `--delete` 才刪除
- 典型用途：git 切換分支後殘留的空資料夾清理

### 3. `extract` — 快速解壓縮

移植自 `quick-extract/`。

```
sys-toolkit extract <file|all>
```

| 參數 | 說明 |
|---|---|
| `<file>` | 解壓指定檔案 |
| `all` | 解壓當前目錄下所有壓縮檔，每個檔案解壓至同名子目錄 |

實作要點：
- 底層使用 `7z`（安裝 `p7zip-full`）
- 邏輯與現有 `quick-extract` Dockerfile 一致
- 批次模式使用 `-o*` 讓每個壓縮檔解壓至獨立目錄

### 4. `img-convert` — 圖像轉換

新功能。

```
sys-toolkit img-convert <target-format> [OPTIONS]
```

| 參數 | 說明 | 預設 |
|---|---|---|
| `<target-format>` | 目標格式，如 `png`、`jpg`、`webp`、`avif` | 必填 |
| `--keep` | 轉換後保留原檔 | 否（預設刪除原檔） |
| `--quality <n>` | 輸出品質 (1-100) | 90 |

實作要點：
- 底層使用 ImageMagick (`convert` / `magick`)
- 僅處理 `/data` 直接子檔案（不遞迴），避免意外處理到子目錄中的檔案
- 支援格式：png, jpg/jpeg, webp, avif, bmp, tiff, gif
- 轉換後刪除原檔為預設行為，`--keep` 可覆蓋

### 5. `video-frames` — 影像擷取

移植自 `video-frames/` 並擴增功能。

```
sys-toolkit video-frames <file|all> [OPTIONS]
```

| 參數 | 說明 | 預設 |
|---|---|---|
| `<file\|all>` | 指定影片或批次處理 | 必填 |
| `-n <count>` | 擷取幀數 | 8 |
| `--prefix <name>` | 輸出檔名前墜 | `frame` |
| `--out-dir <dir>` | 統一輸出目錄（而非每個影片一個子目錄） | 無（每個影片各自子目錄） |
| `--format <ext>` | 輸出格式 (jpg/png) | jpg |

實作要點：
- 底層使用 FFmpeg + FFprobe
- 均勻取幀演算法不變：`fps=N/duration`
- 新增功能：指定 `--out-dir` 時，所有幀輸出至該目錄，命名為 `{prefix}_{0001}.jpg`
- 支援格式：mp4, mkv, avi, mov, m4v, flv, wmv, webm, ts

### 6. `yt-dlp` — yt-dlp 包裝

新功能。僅用於下載公開資源。

```
sys-toolkit yt-dlp <url> [OPTIONS]
```

| 參數 | 說明 | 預設 |
|---|---|---|
| `<url>` | 目標 URL | 必填 |
| `--audio-only` | 僅下載音訊並轉為 mp3 | 否 |
| `--format <id>` | 指定 yt-dlp format | `bestvideo+bestaudio/best` |
| `--output <template>` | 輸出檔名模版 | `%(title)s.%(ext)s` |

實作要點：
- 安裝 `yt-dlp` 與 `ffmpeg`（合併用）
- **不支援** 需登入、cookie 的情境，不提供 `--cookies` 參數
- 預設下載最佳畫質，合併為 mp4

---

## 技術架構

### 目錄結構

```
sys-toolkit/
├── Dockerfile
├── entrypoint.sh          # 主入口，解析子命令並分發
├── scripts/
│   ├── count-lines.sh
│   ├── empty-dirs.sh
│   ├── extract.sh
│   ├── img-convert.sh
│   ├── video-frames.sh
│   └── yt-dlp.sh
├── README.md
├── plan.md
├── draft.md
├── powershell/            # 保留原始 PowerShell 工具（參考用）
├── quick-extract/         # 保留原始工具（參考用）
└── video-frames/          # 保留原始工具（參考用）
```

### Dockerfile 設計

```dockerfile
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    p7zip-full \
    ffmpeg \
    imagemagick \
    python3 \
    python3-pip \
    && pip3 install --break-system-packages yt-dlp \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
COPY scripts/ /scripts/
RUN chmod +x /entrypoint.sh /scripts/*.sh

WORKDIR /data
ENTRYPOINT ["/entrypoint.sh"]
```

基礎映像選用 **Debian Bookworm Slim**：
- 比 Alpine 更容易安裝 ImageMagick、FFmpeg 等有大量依賴的工具
- apt 套件庫完整，不需額外處理 musl 相容問題
- 雖然映像較大，但作為本機工具集可以接受

### entrypoint.sh 設計

```bash
#!/bin/bash
set -euo pipefail

case "${1:-}" in
  count-lines)   shift; exec /scripts/count-lines.sh "$@" ;;
  empty-dirs)    shift; exec /scripts/empty-dirs.sh "$@" ;;
  extract)       shift; exec /scripts/extract.sh "$@" ;;
  img-convert)   shift; exec /scripts/img-convert.sh "$@" ;;
  video-frames)  shift; exec /scripts/video-frames.sh "$@" ;;
  yt-dlp)        shift; exec /scripts/yt-dlp.sh "$@" ;;
  *)
    echo "sys-toolkit — 拋棄式跨平台工具集"
    echo ""
    echo "使用方式: sys-toolkit <command> [options]"
    echo ""
    echo "可用命令:"
    echo "  count-lines    統計檔案行數"
    echo "  empty-dirs     檢查空資料夾"
    echo "  extract        快速解壓縮"
    echo "  img-convert    圖像格式轉換"
    echo "  video-frames   影像擷取"
    echo "  yt-dlp         下載公開影音資源"
    ;;
esac
```

---

## 實作順序

以依賴關係與複雜度排序，由簡至繁：

| 階段 | 任務 | 說明 |
|---|---|---|
| **1** | 建立專案骨架 | `Dockerfile`、`entrypoint.sh`、`scripts/` 目錄、基本幫助訊息 |
| **2** | `empty-dirs.sh` | 最簡單的功能，用來驗證整體架構是否正確 |
| **3** | `count-lines.sh` | 移植 PowerShell 邏輯，驗證參數解析模式 |
| **4** | `extract.sh` | 從現有 quick-extract 遷移，幾乎是搬運 |
| **5** | `video-frames.sh` | 從現有 video-frames 遷移並擴增參數 |
| **6** | `img-convert.sh` | 新功能，依賴 ImageMagick |
| **7** | `yt-dlp.sh` | 新功能，依賴 yt-dlp + ffmpeg |
| **8** | 撰寫 README.md | 按 draft 規格：功能概覽表格 → 安裝啟動 → 各功能詳細用法 |
| **9** | 建置測試 | `docker build` 並逐一測試每個子命令 |

---

## 使用方式（最終）

```powershell
# 建置（一次）
docker build -t sys-toolkit .

# 統計行數
docker run --rm -v ${PWD}:/data sys-toolkit count-lines --ext py,js --summary

# 檢查空資料夾
docker run --rm -v ${PWD}:/data sys-toolkit empty-dirs

# 解壓所有壓縮檔
docker run --rm -v ${PWD}:/data sys-toolkit extract all

# 將所有圖片轉為 webp
docker run --rm -v ${PWD}:/data sys-toolkit img-convert webp

# 從影片擷取 12 幀
docker run --rm -v ${PWD}:/data sys-toolkit video-frames clip.mp4 -n 12

# 下載影片
docker run --rm -v ${PWD}:/data sys-toolkit yt-dlp "https://example.com/video"
```
