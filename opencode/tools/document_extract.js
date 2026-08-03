import { tool } from "@opencode-ai/plugin"
import { mkdir, readFile, readdir, realpath, stat, writeFile } from "node:fs/promises"
import crypto from "node:crypto"
import os from "node:os"
import path from "node:path"

const cacheVersion = "2"
const doclingPackage = "docling[asr]==2.114.0"
const markItDownPackage = "markitdown[all]==0.1.7"
const defaultPreviewChars = 4000
const maxPreviewChars = 20000
const defaultTimeoutMs = 10 * 60 * 1000
const minTimeoutMs = 30 * 1000
const maxTimeoutMs = 30 * 60 * 1000
const maxStdoutBytes = 64 * 1024 * 1024
const maxStderrBytes = 4 * 1024 * 1024
const maxMarkdownBytes = 64 * 1024 * 1024

function clampMaxChars(value) {
  if (!Number.isFinite(value)) return defaultPreviewChars
  return Math.max(1000, Math.min(maxPreviewChars, Math.trunc(value)))
}

function clampTimeoutMs(value) {
  if (!Number.isFinite(value)) return defaultTimeoutMs
  return Math.max(minTimeoutMs, Math.min(maxTimeoutMs, Math.trunc(value)))
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

function containsPath(root, filePath) {
  const relative = path.relative(root, filePath)
  return relative === "" || (!relative.startsWith(`..${path.sep}`) && relative !== ".." && !path.isAbsolute(relative))
}

function converterPackage(selectedEngine) {
  return selectedEngine === "markitdown" ? markItDownPackage : doclingPackage
}

function converterDescription(selectedEngine, imageMode) {
  if (selectedEngine === "markitdown") {
    return `uvx --from ${markItDownPackage} markitdown`
  }
  return `uvx --from ${doclingPackage} docling convert --to md --no-ocr --image-export-mode ${imageMode}`
}

function resolveUvxExecutable() {
  const configured = process.env.OPENCODE_UVX_PATH?.trim()
  if (configured) return configured

  const discovered = typeof Bun.which === "function" ? Bun.which("uvx") : null
  if (discovered) return discovered

  throw new Error(
    "document_extract requires uvx, but it is not on PATH. Install Astral uv or set OPENCODE_UVX_PATH to the uvx executable.",
  )
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

async function readStreamLimited(stream, maxBytes, label) {
  const reader = stream.getReader()
  const chunks = []
  let totalBytes = 0

  try {
    while (true) {
      const { done, value } = await reader.read()
      if (done) break

      totalBytes += value.byteLength
      if (totalBytes > maxBytes) {
        throw new Error(`document_extract ${label} exceeded ${maxBytes} bytes.`)
      }
      chunks.push(value)
    }
  } finally {
    reader.releaseLock()
  }

  const merged = new Uint8Array(totalBytes)
  let offset = 0
  for (const chunk of chunks) {
    merged.set(chunk, offset)
    offset += chunk.byteLength
  }
  return new TextDecoder().decode(merged)
}

async function runCommand(command, timeoutMs) {
  const child = Bun.spawn(command, {
    stdout: "pipe",
    stderr: "pipe",
  })
  let timedOut = false
  const timer = setTimeout(() => {
    timedOut = true
    try {
      child.kill()
    } catch {
      // Process already exited.
    }
  }, timeoutMs)

  try {
    const [stdout, stderr, exitCode] = await Promise.all([
      readStreamLimited(child.stdout, maxStdoutBytes, "stdout"),
      readStreamLimited(child.stderr, maxStderrBytes, "stderr"),
      child.exited,
    ])

    if (timedOut) {
      throw new Error(`document_extract converter timed out after ${timeoutMs} ms.`)
    }
    return { stdout, stderr, exitCode }
  } catch (error) {
    try {
      child.kill()
      await child.exited
    } catch {
      // Preserve the original converter error.
    }
    throw error
  } finally {
    clearTimeout(timer)
  }
}

async function readIfExists(filePath) {
  try {
    const info = await stat(filePath)
    if (!info.isFile()) return null
    if (info.size > maxMarkdownBytes) {
      throw new Error(`document_extract Markdown output exceeded ${maxMarkdownBytes} bytes.`)
    }
    return await readFile(filePath, "utf8")
  } catch (error) {
    if (error?.code === "ENOENT") return null
    throw error
  }
}

async function readDoclingMarkdown(outputDir, markdownPath) {
  const expected = await readIfExists(markdownPath)
  if (expected !== null) return expected

  const entries = await readdir(outputDir, { withFileTypes: true })
  const markdownFiles = entries.filter((entry) => entry.isFile() && entry.name.toLowerCase().endsWith(".md"))
  if (markdownFiles.length !== 1) {
    throw new Error(`document_extract expected one Docling Markdown output, found ${markdownFiles.length}.`)
  }

  const discoveredPath = path.join(outputDir, markdownFiles[0].name)
  const markdown = await readIfExists(discoveredPath)
  if (markdown === null) {
    throw new Error(`document_extract could not read Docling output: ${discoveredPath}`)
  }
  await writeFile(markdownPath, markdown, "utf8")
  return markdown
}

async function collectReferencedImages(markdown, outputDir) {
  const candidates = []
  const pattern = /!\[[^\]]*\]\(([^)]+)\)/g
  for (const match of markdown.matchAll(pattern)) {
    let target = match[1].trim().replace(/\s+(?:"[^"]*"|'[^']*')\s*$/, "")
    if (target.startsWith("<") && target.endsWith(">")) target = target.slice(1, -1)
    if (/^(?:data:|https?:|file:)/i.test(target)) continue

    try {
      target = decodeURIComponent(target.split("#", 1)[0])
    } catch {
      // Keep the literal path when percent-decoding fails.
    }

    const imagePath = path.resolve(outputDir, target)
    if (!containsPath(outputDir, imagePath)) continue
    candidates.push(imagePath)
  }

  const unique = [...new Set(candidates)]
  const existing = []
  for (const imagePath of unique) {
    try {
      if ((await stat(imagePath)).isFile()) existing.push(imagePath)
    } catch {
      // Ignore stale or non-file Markdown references.
    }
  }
  return existing
}

function conversionMetadata(markdown, selectedEngine, imageMode, warnings, cacheHit, imagePaths) {
  const imagePlaceholderCount = (markdown.match(/<!--\s*image\s*-->/gi) ?? []).length
  if (imagePlaceholderCount > 0) {
    warnings.push(`Document contains ${imagePlaceholderCount} image placeholder(s). Images were not interpreted.`)
  }

  return {
    markdown: markdown.trim(),
    engineUsed: selectedEngine,
    converter: converterDescription(selectedEngine, imageMode),
    warnings,
    cacheHit,
    ocrUsed: false,
    ocrEngine: "none",
    imageMode: selectedEngine === "docling" ? imageMode : "none",
    imagePlaceholderCount,
    imagePaths,
  }
}

async function convertWithMarkItDown(uvx, filePath, timeoutMs) {
  const command = [uvx, "--from", markItDownPackage, "markitdown", filePath]
  const result = await runCommand(command, timeoutMs)

  if (result.exitCode !== 0) {
    throw new Error(result.stderr.trim() || `document_extract MarkItDown failed with exit code ${result.exitCode}.`)
  }
  return result.stdout
}

async function convertWithDocling(uvx, filePath, outputDir, imageMode, timeoutMs) {
  const documentTimeoutSeconds = Math.max(1, Math.floor((timeoutMs - 5000) / 1000))
  const command = [
    uvx,
    "--from",
    doclingPackage,
    "docling",
    "convert",
    "--to",
    "md",
    "--no-ocr",
    "--html-image-fetch",
    "none",
    "--image-export-mode",
    imageMode,
    "--document-timeout",
    String(documentTimeoutSeconds),
    "--output",
    outputDir,
    "--quiet",
    filePath,
  ]
  const result = await runCommand(command, timeoutMs)

  if (result.exitCode !== 0) {
    throw new Error(result.stderr.trim() || `document_extract Docling failed with exit code ${result.exitCode}.`)
  }
  return result.stderr.trim() ? [result.stderr.trim()] : []
}

export default tool({
  description: "Extract structured content from a permitted local PDF, Office document, spreadsheet, presentation, HTML, CSV, JSON, image, audio, or video file. Uses pinned local Docling by default or MarkItDown when explicitly requested, caches complete Markdown at markdownPath, and returns a bounded preview. Set extractImages=true to export visual content as local imagePaths for separate inspection; this tool does not interpret exported images, and OCR is disabled by default.",
  args: {
    filePath: tool.schema.string().describe("Absolute path to an existing permitted local file. Do not pass a URL or directory."),
    engine: tool.schema.enum(["docling", "markitdown"]).optional().describe("Local extraction engine. Defaults to pinned Docling; choose MarkItDown only when explicitly requested."),
    extractImages: tool.schema.boolean().optional().describe("With Docling, export embedded visual content and return local imagePaths for separate inspection. Does not interpret images or enable OCR. Defaults to false."),
    maxChars: tool.schema.number().optional().describe("Maximum preview characters. Full Markdown remains at markdownPath. Default 4000; range 1000-20000."),
    timeoutMs: tool.schema.number().optional().describe("Converter timeout in milliseconds. Default 600000; range 30000-1800000."),
  },
  async execute(args, context) {
    const requestedFilePath = path.resolve(args.filePath)
    const selectedEngine = engine(args.engine)
    const extractImages = args.extractImages === true
    const imageMode = extractImages ? "referenced" : "placeholder"
    const maxChars = clampMaxChars(args.maxChars)
    const timeoutMs = clampTimeoutMs(args.timeoutMs)

    if (selectedEngine === "markitdown" && extractImages) {
      throw new Error("document_extract extractImages is supported only with engine='docling'.")
    }

    await requestReadPermission(context, requestedFilePath)
    const filePath = await realpath(requestedFilePath)
    if (filePath !== requestedFilePath) {
      await requestReadPermission(context, filePath)
    }
    const info = await stat(filePath)
    if (!info.isFile()) {
      throw new Error(`document_extract expected a file path: ${filePath}`)
    }

    const hash = crypto
      .createHash("sha256")
      .update(`${cacheVersion}\0${converterPackage(selectedEngine)}\0${imageMode}\0${filePath}\0${info.mtimeMs}\0${info.size}`)
      .digest("hex")
      .slice(0, 20)
    const outputDir = path.join(os.tmpdir(), "opencode", "document-extract", hash)
    const markdownPath = path.join(outputDir, safeFileName(path.basename(filePath)))
    await mkdir(outputDir, { recursive: true })

    const cachedMarkdown = await readIfExists(markdownPath)
    let conversion
    if (cachedMarkdown !== null) {
      const imagePaths = extractImages ? await collectReferencedImages(cachedMarkdown, outputDir) : []
      conversion = conversionMetadata(cachedMarkdown, selectedEngine, imageMode, ["Reused cached conversion output."], true, imagePaths)
    } else {
      const uvx = resolveUvxExecutable()
      if (selectedEngine === "markitdown") {
        const markdown = await convertWithMarkItDown(uvx, filePath, timeoutMs)
        await writeFile(markdownPath, markdown, "utf8")
        conversion = conversionMetadata(markdown, selectedEngine, imageMode, [], false, [])
      } else {
        const warnings = await convertWithDocling(uvx, filePath, outputDir, imageMode, timeoutMs)
        const markdown = await readDoclingMarkdown(outputDir, markdownPath)
        const imagePaths = extractImages ? await collectReferencedImages(markdown, outputDir) : []
        conversion = conversionMetadata(markdown, selectedEngine, imageMode, warnings, false, imagePaths)
      }
    }

    return JSON.stringify({
      operation: "document_extract",
      filePath,
      fileName: path.basename(filePath),
      fileSize: info.size,
      markdownPath,
      engine: selectedEngine,
      engineUsed: conversion.engineUsed,
      converter: conversion.converter,
      converterPackage: converterPackage(selectedEngine),
      cacheHit: conversion.cacheHit,
      timeoutMs,
      ocrUsed: conversion.ocrUsed,
      ocrEngine: conversion.ocrEngine,
      imageMode: conversion.imageMode,
      imagePlaceholderCount: conversion.imagePlaceholderCount,
      imagePathCount: conversion.imagePaths.length,
      imagePaths: conversion.imagePaths,
      warnings: conversion.warnings,
      previewMaxChars: maxChars,
      ...limitText(conversion.markdown, maxChars),
    })
  },
})
