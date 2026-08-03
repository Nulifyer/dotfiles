---
name: document-read
description: Use when the user asks to read, summarize, inspect, convert, or extract text, tables, or images from a local PDF, Office document, spreadsheet, presentation, HTML, CSV, JSON, saved email attachment, image, audio, or video file. Use document_extract for structured or media extraction and native image reading for standalone or exported images.
---

# Document Read

Use `document_extract` for permitted local files. It extracts content to cached Markdown and returns a capped preview plus the full `markdownPath`. The tool normalizes evidence; the model derives meaning from the Markdown and any separately inspected images.

## Routing

- Default to `engine: "docling"` for local structured extraction.
- Use `engine: "markitdown"` only when the user explicitly requests Microsoft MarkItDown.
- Inspect standalone images directly when the task requires visual meaning; use `document_extract` only when conversion or textual extraction is useful.
- Set `extractImages: true` with Docling when document images need separate inspection. Read only relevant returned `imagePaths`.
- Keep OCR off by default. If text is absent or unusable, report that OCR or visual inspection is needed rather than silently changing extraction mode.

## Tool Contract

- Docling is pinned to `docling[asr]==2.114.0`.
- MarkItDown is pinned to `markitdown[all]==0.1.7`.
- Both run through local `uvx`; no remote conversion API is used.
- `uvx` must be on `PATH`, or `OPENCODE_UVX_PATH` must point to it.
- Default timeout is 600,000 ms; accepted range is 30,000-1,800,000 ms.
- Preview defaults to 4,000 characters and is capped at 20,000. Use `markdownPath` for targeted follow-up reads.
- Cache keys include converter version, image mode, source path, modification time, and size. Check `cacheHit` in the result.
- Docling blocks remote HTML image fetching and uses `--no-ocr`.

## Images And Large Files

- Placeholder mode reports `imagePlaceholderCount`; images were detected but not interpreted.
- Referenced mode returns existing local PNG paths in `imagePaths`.
- Inspect selected images instead of loading every extracted image into context.
- Full converter output is bounded; converter time and output-limit failures are explicit.
- When `ffmpeg` is available, pinned Docling ASR can process supported audio/video files locally.

## Output

Report the conversion engine, whether cache was reused, whether the preview was truncated, the full Markdown path, and any image or converter warnings relevant to the task.
