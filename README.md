# sys-toolkit

利用 Docker 製作的拋棄式跨平台工具集，從簡單的檔案整理、圖像處理到影像轉換。

## 功能概覽

| 功能 | 說明 |
|---|---|
| `count-lines` | 統計目錄下所有檔案的行數，支援副檔名篩選與分組統計 |
| `empty-dirs` | 檢查空資料夾。git 切換分支後有時會殘留空資料夾，可用此工具檢查並清理 |
| `extract` | 快速解壓縮，支援 zip、7z、tar、gz、rar 等常見格式，可批次解壓至各自子目錄 |
| `img-convert` | 將目錄下的圖像檔案批次轉換為指定格式（png、jpg、webp、avif 等） |
| `video-frames` | 從影片中均勻擷取指定數量的幀，可批次處理並指定統一輸出目錄與命名前墜 |
| `yt-dlp` | yt-dlp 包裝，用來下載公開影音資源，不支援需登入的情況 |

## 安裝與使用

### 建置映像檔（一次）

```powershell
docker build -t sys-toolkit .
```

### 啟動方式

```powershell
docker run --rm -v ${PWD}:/data sys-toolkit <command> [options]
```

執行時不帶任何參數可查看所有可用命令：

```powershell
docker run --rm sys-toolkit
```

---

## count-lines — 統計行數

統計目錄下所有檔案的行數，支援排除資料夾、副檔名篩選與分組統計。

```powershell
# 基本用法：統計所有檔案
docker run --rm -v ${PWD}:/data sys-toolkit count-lines

# 僅統計指定副檔名
docker run --rm -v ${PWD}:/data sys-toolkit count-lines --ext py,js,ts

# 排除 node_modules 開頭的資料夾
docker run --rm -v ${PWD}:/data sys-toolkit count-lines --exclude node_modules

# 以副檔名分組統計
docker run --rm -v ${PWD}:/data sys-toolkit count-lines --ext py,js --summary

# 僅顯示超過 100 行的檔案
docker run --rm -v ${PWD}:/data sys-toolkit count-lines --min-lines 100
```

| 參數 | 說明 | 預設 |
|---|---|---|
| `--exclude <prefix>` | 跳過名稱以此前墜開頭的資料夾 | 無 |
| `--ext <ext1,ext2>` | 僅計算指定副檔名（逗號分隔） | 全部 |
| `--min-lines <n>` | 低於此行數的檔案不顯示 | 1 |
| `--summary` | 以副檔名分組統計，而非逐檔列出 | 否 |

---

## empty-dirs — 檢查空資料夾

找出目錄下所有空資料夾，可選擇直接刪除。

```powershell
# 列出所有空資料夾
docker run --rm -v ${PWD}:/data sys-toolkit empty-dirs

# 找到並刪除空資料夾
docker run --rm -v ${PWD}:/data sys-toolkit empty-dirs --delete

# 排除 .git 開頭的資料夾
docker run --rm -v ${PWD}:/data sys-toolkit empty-dirs --exclude .git
```

| 參數 | 說明 | 預設 |
|---|---|---|
| `--delete` | 找到空資料夾後直接刪除 | 否（僅列出） |
| `--exclude <prefix>` | 跳過名稱以此前墜開頭的資料夾 | 無 |

---

## extract — 快速解壓縮

利用 7-Zip 解壓各種壓縮格式，支援單檔與批次模式。

```powershell
# 解壓單一檔案
docker run --rm -v ${PWD}:/data sys-toolkit extract archive.zip

# 批次解壓所有壓縮檔（各自解壓至同名子目錄）
docker run --rm -v ${PWD}:/data sys-toolkit extract all
```

| 參數 | 說明 |
|---|---|
| `<file>` | 解壓指定檔案 |
| `all` | 解壓目錄下所有檔案，每個解壓至同名子目錄 |

---

## img-convert — 圖像轉換

將當前目錄下的圖像檔案（直接子檔案，不遞迴）批次轉為指定格式。

```powershell
# 將所有圖片轉為 webp
docker run --rm -v ${PWD}:/data sys-toolkit img-convert webp

# 轉為 png 並保留原檔
docker run --rm -v ${PWD}:/data sys-toolkit img-convert png --keep

# 轉為 jpg 並指定品質
docker run --rm -v ${PWD}:/data sys-toolkit img-convert jpg --quality 80
```

| 參數 | 說明 | 預設 |
|---|---|---|
| `<target-format>` | 目標格式：png, jpg, webp, avif, bmp, tiff, gif | 必填 |
| `--keep` | 轉換後保留原檔 | 否（刪除原檔） |
| `--quality <n>` | 輸出品質 1-100 | 90 |

> 注意：預設行為會刪除原檔，請確認後再執行。加 `--keep` 可保留原檔。

---

## video-frames — 影像擷取

從影片中均勻擷取指定數量的幀。

```powershell
# 從單一影片擷取 12 幀
docker run --rm -v ${PWD}:/data sys-toolkit video-frames clip.mp4 -n 12

# 批次處理所有影片，預設 8 幀
docker run --rm -v ${PWD}:/data sys-toolkit video-frames all

# 批次處理，16 幀，統一輸出到 frames 目錄
docker run --rm -v ${PWD}:/data sys-toolkit video-frames all -n 16 --out-dir frames --prefix shot

# 輸出 png 格式
docker run --rm -v ${PWD}:/data sys-toolkit video-frames clip.mp4 -n 8 --format png
```

| 參數 | 說明 | 預設 |
|---|---|---|
| `<file\|all>` | 指定影片或批次處理所有影片 | 必填 |
| `-n <count>` | 擷取幀數 | 8 |
| `--prefix <name>` | 輸出檔名前墜 | `frame` |
| `--out-dir <dir>` | 統一輸出目錄（否則每個影片各自子目錄） | 無 |
| `--format <ext>` | 輸出格式 jpg 或 png | jpg |

**輸出目錄結構（預設）：**

```
./
├── clip/
│   ├── frame_001.jpg
│   ├── frame_002.jpg
│   └── ...
└── another/
    ├── frame_001.jpg
    └── ...
```

**支援的影片格式：** mp4, mkv, avi, mov, m4v, flv, wmv, webm, ts

---

## yt-dlp — 下載公開影音資源

yt-dlp 的簡單包裝，僅用於下載公開資源。

```powershell
# 下載影片（最佳畫質，合併為 mp4）
docker run --rm -v ${PWD}:/data sys-toolkit yt-dlp "https://example.com/video"

# 僅下載音訊並轉為 mp3
docker run --rm -v ${PWD}:/data sys-toolkit yt-dlp "https://example.com/video" --audio-only

# 指定輸出檔名
docker run --rm -v ${PWD}:/data sys-toolkit yt-dlp "https://example.com/video" --output "my_video.%(ext)s"
```

| 參數 | 說明 | 預設 |
|---|---|---|
| `<url>` | 目標 URL | 必填 |
| `--audio-only` | 僅下載音訊並轉為 mp3 | 否 |
| `--format <id>` | 指定 yt-dlp format | `bestvideo+bestaudio/best` |
| `--output <template>` | 輸出檔名模版 | `%(title)s.%(ext)s` |

> 注意：此工具不支援需要登入或 cookie 的內容，僅適用於公開資源。
