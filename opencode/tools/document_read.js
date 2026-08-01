import { tool } from "@opencode-ai/plugin"
import { mkdir, readFile, realpath, stat, writeFile } from "node:fs/promises"
import crypto from "node:crypto"
import os from "node:os"
import path from "node:path"

const defaultPreviewChars = 4000
const maxPreviewChars = 20000

function clampMaxChars(value) {
  if (!Number.isFinite(value)) return defaultPreviewChars
  return Math.max(1000, Math.min(maxPreviewChars, Math.trunc(value)))
}

function limitText(text, maxChars) {
  const value = String(text ?? "")
  const truncated = value.length > maxChars
  return {
    text: truncated ? value.slice(0, maxChars) : value,
    textLength: value.length,
    textTruncated: truncated,
  }
}

function safeFileName(fileName) {
  const parsed = path.parse(fileName)
  const base = parsed.name.replace(/[<>:"/\\|?*\x00-\x1F]/g, "_").trim() || "document"
  return `${base}.md`
}

function engine(value) {
  if (value === "markitdown") return "markitdown"
  return "docling"
}

function isLikelyOcrDownloadFailure(stderr) {
  return /RapidOCR|DownloadFileException|Failed to download|modelscope\.cn/i.test(stderr)
}

function containsPath(root, filePath) {
  const relative = path.relative(root, filePath)
  return relative === "" || (!relative.startsWith(`..${path.sep}`) && relative !== ".." && !path.isAbsolute(relative))
}

async function requestReadPermission(context, filePath) {
  const insideWorkspace = [context.directory, context.worktree]
    .filter(Boolean)
    .some((root) => containsPath(path.resolve(root), filePath))

  if (!insideWorkspace) {
    const parentDir = path.dirname(filePath)
    const pattern = path.join(parentDir, "*").replaceAll("\\", "/")
    await context.ask({
      permission: "external_directory",
      patterns: [pattern],
      always: [pattern],
      metadata: { filepath: filePath, parentDir },
    })
  }

  const pattern = path.relative(context.worktree || context.directory, filePath)
  await context.ask({
    permission: "read",
    patterns: [pattern],
    always: [pattern],
    metadata: { filepath: filePath },
  })
}

async function runCommand(command) {
  const process = Bun.spawn(command, {
    stdout: "pipe",
    stderr: "pipe",
  })

  const [stdout, stderr, exitCode] = await Promise.all([
    new Response(process.stdout).text(),
    new Response(process.stderr).text(),
    process.exited,
  ])

  return { stdout, stderr, exitCode }
}

async function convertWithMarkItDown(filePath) {
  const command = ["uvx", "--from", "markitdown[all]", "markitdown", filePath]
  const result = await runCommand(command)

  if (result.exitCode !== 0) {
    throw new Error(result.stderr.trim() || `document_read MarkItDown failed with exit code ${result.exitCode}.`)
  }

  return {
    markdown: result.stdout.trim(),
    engineUsed: "markitdown",
    converter: "uvx --from markitdown[all] markitdown",
    warnings: result.stderr.trim() ? [result.stderr.trim()] : [],
  }
}

async function convertWithDocling(filePath, outputDir) {
  const doclingPackage = "docling[asr]"
  const command = [
    "uvx",
    "--from",
    doclingPackage,
    "docling",
    "convert",
    "--to",
    "md",
    "--no-ocr",
    "--image-export-mode",
    "placeholder",
    "--output",
    outputDir,
    "--quiet",
  ]
  command.push(filePath)

  const result = await runCommand(command)
  const warnings = []

  if (result.exitCode !== 0) {
    throw new Error(result.stderr.trim() || `document_read Docling failed with exit code ${result.exitCode}.`)
  }

  if (result.stderr.trim()) warnings.push(result.stderr.trim())

  const expectedPath = path.join(outputDir, safeFileName(path.basename(filePath)))
  const markdown = await readFile(expectedPath, "utf8")
  const imagePlaceholderCount = (markdown.match(/<!--\s*image\s*-->/gi) ?? []).length
  if (imagePlaceholderCount > 0) {
    warnings.push(`Document contains ${imagePlaceholderCount} image placeholder(s). OCR and image interpretation were not run.`)
  }

  return {
    markdown: markdown.trim(),
    engineUsed: "docling",
    converter: `uvx --from ${doclingPackage} docling convert --to md --no-ocr --image-export-mode placeholder`,
    warnings,
    ocrUsed: false,
    ocrEngine: "none",
    imageMode: "placeholder",
    imagePlaceholderCount,
  }
}

export default tool({
  description: "Read a local document file by converting it to Markdown. Defaults to local Docling conversion. Use engine='markitdown' for explicit Microsoft MarkItDown conversion. Saves full Markdown to markdownPath and returns a capped preview. No remote conversion is used.",
  args: {
    filePath: tool.schema.string().describe("Absolute local file path to read."),
    engine: tool.schema.enum(["docling", "markitdown"]).optional().describe("Conversion engine. Defaults to docling. MarkItDown is only used when explicitly requested."),
    maxChars: tool.schema.number().optional().describe("Maximum preview characters to return. Full Markdown is always saved to markdownPath. Default 4000. Maximum 20000."),
  },
  async execute(args, context) {
    const requestedFilePath = path.resolve(args.filePath)
    const maxChars = clampMaxChars(args.maxChars)
    const requestedEngine = engine(args.engine)

    await requestReadPermission(context, requestedFilePath)
    const filePath = await realpath(requestedFilePath)
    if (filePath !== requestedFilePath) {
      await requestReadPermission(context, filePath)
    }
    const info = await stat(filePath)

    if (!info.isFile()) {
      throw new Error(`document_read expected a file path: ${filePath}`)
    }

    const hash = crypto
      .createHash("sha256")
      .update(`${requestedEngine}\0${filePath}\0${info.mtimeMs}\0${info.size}`)
      .digest("hex")
      .slice(0, 16)
    const outputDir = path.join(os.tmpdir(), "opencode", "document-read", hash)
    const markdownPath = path.join(outputDir, safeFileName(path.basename(filePath)))
    await mkdir(outputDir, { recursive: true })

    const conversion = requestedEngine === "markitdown"
      ? await convertWithMarkItDown(filePath)
      : await convertWithDocling(filePath, outputDir)

    const markdown = conversion.markdown
    await writeFile(markdownPath, markdown, "utf8")

    const limited = limitText(markdown, maxChars)

    return JSON.stringify({
      operation: "document_read",
      filePath,
      fileName: path.basename(filePath),
      fileSize: info.size,
      markdownPath,
      engine: requestedEngine,
      engineUsed: conversion.engineUsed,
      converter: conversion.converter,
      ocrUsed: conversion.ocrUsed ?? null,
      ocrEngine: conversion.ocrEngine ?? null,
      imageMode: conversion.imageMode ?? null,
      imagePlaceholderCount: conversion.imagePlaceholderCount ?? 0,
      warnings: conversion.warnings,
      previewMaxChars: maxChars,
      ...limited,
    })
  },
})
