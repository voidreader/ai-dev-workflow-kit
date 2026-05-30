#!/usr/bin/env bash
set -euo pipefail

# Figma MCP가 발급한 submit URL에 raw bytes POST로 자산 업로드.
# multipart/form-data는 metadata만 등록하고 bytes는 안 올라가는 버그가 있어
# (Anthropic memory: figma-mcp-upload-gotcha) 절대 사용하지 말 것.

usage() {
  echo "Usage: $0 <submit_url> <local_image_path>" >&2
  echo "  content-type은 파일 확장자로 자동 결정 (.png/.jpg/.svg/.webp)" >&2
  exit 64
}

[[ $# -ne 2 ]] && usage

SUBMIT_URL="$1"
IMG_PATH="$2"

[[ ! -f "$IMG_PATH" ]] && { echo "error: file not found: $IMG_PATH" >&2; exit 66; }

case "${IMG_PATH##*.}" in
  png)  CT="image/png" ;;
  jpg|jpeg) CT="image/jpeg" ;;
  svg)  CT="image/svg+xml" ;;
  webp) CT="image/webp" ;;
  *)    echo "error: unsupported extension: $IMG_PATH" >&2; exit 65 ;;
esac

# raw bytes POST. --data-binary로 정확한 바이트 보존.
RESP_FILE=$(mktemp /tmp/figma_upload_XXXXXX.json)
trap 'rm -f "$RESP_FILE"' EXIT

HTTP_CODE=$(curl -sS -o "$RESP_FILE" -w "%{http_code}" \
  -X POST -H "Content-Type: $CT" --data-binary "@$IMG_PATH" "$SUBMIT_URL") \
  || { echo "error: curl failed (network error)" >&2; exit 1; }

if [[ "$HTTP_CODE" != "200" && "$HTTP_CODE" != "201" ]]; then
  echo "error: upload failed http=$HTTP_CODE" >&2
  cat "$RESP_FILE" >&2
  exit 1
fi

cat "$RESP_FILE"
