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
