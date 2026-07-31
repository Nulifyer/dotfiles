---
name: document-read
description: Use when the user asks to read, convert, summarize, inspect, or extract text from local files, PDFs, Office documents, spreadsheets, presentations, HTML, CSV, JSON, or Outlook attachments saved to filePath.
---

# Document Read

Use `document_read` to convert local files to Markdown. It defaults to local Docling text extraction without OCR, saves full Markdown to `markdownPath`, and returns a capped preview. Use `engine: "markitdown"` only when the user explicitly wants Microsoft MarkItDown.

## Use When

- Reading PDF attachments saved by Outlook mail tools.
- Extracting text from PDFs, DOCX, PPTX, XLSX, HTML, CSV, JSON, Markdown, text, images, audio, video, and other Docling-supported local files.
- Summarizing a local document from `filePath`.

## Rules

- The default converter runs locally through `uvx --from "docling[asr]" docling convert --no-ocr --image-export-mode placeholder`.
- Never use `docling convert-remote`.
- Do not run OCR by default. Extract existing text layers and preserve image placeholders so the model can decide whether to inspect images separately.
- When `ffmpeg` is on PATH, Docling can process supported audio/video inputs locally with its ASR pipeline.
- MarkItDown is available only by explicit `engine: "markitdown"` and runs locally through `uvx --from markitdown[all] markitdown`.
- Do not use cloud conversion flags such as Document Intelligence or Content Understanding unless the user explicitly asks.
- Use `maxChars` to control preview size. Default is 4,000 characters; maximum is 20,000.
- For large documents, use `read` and `grep` on returned `markdownPath` instead of asking `document_read` for huge output.
- If preview is truncated, say so and use `markdownPath` for targeted follow-up reads.
- If `imagePlaceholderCount` is greater than zero, mention that images were detected but not interpreted.
