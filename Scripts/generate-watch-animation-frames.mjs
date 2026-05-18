#!/usr/bin/env node
import crypto from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";

const __filename = fileURLToPath(import.meta.url);
const repoRoot = path.resolve(path.dirname(__filename), "..");
const themeRoot = path.join(repoRoot, "apps/apple/Sources/KiriFriendsBuddyMac/Resources/Themes/clawd");
const sourceRoot = path.join(themeRoot, "svg");
const outputRoot = path.join(
  repoRoot,
  "apps/apple/Sources/KiriFriendsWatchKit/Resources/BuddyAnimationFrames/clawd"
);

const frameSize = 192;
const maxFrames = 24;
const minFrames = 8;
const fallbackDurationMs = 2400;

const chromeCandidates = [
  process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE,
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  "/Applications/Chromium.app/Contents/MacOS/Chromium",
  "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
].filter(Boolean);

function basenameStem(filename) {
  return filename.replace(/\.[^.]+$/, "");
}

async function readJson(filePath) {
  return JSON.parse(await fs.readFile(filePath, "utf8"));
}

async function firstExistingPath(candidates) {
  for (const candidate of candidates) {
    try {
      await fs.access(candidate);
      return candidate;
    } catch {}
  }
  return null;
}

function sourceFilesForTheme(theme) {
  const files = new Set();
  for (const value of Object.values(theme.states || {})) {
    if (Array.isArray(value)) {
      for (const file of value) files.add(file);
    }
  }
  for (const tier of theme.workingTiers || []) files.add(tier.file);
  for (const tier of theme.jugglingTiers || []) files.add(tier.file);
  for (const idleAnimation of theme.idleAnimations || []) files.add(idleAnimation.file);
  return [...files].sort();
}

function sha256(buffer) {
  return crypto.createHash("sha256").update(buffer).digest("hex");
}

function durationOverride(theme, file) {
  for (const idleAnimation of theme.idleAnimations || []) {
    if (idleAnimation.file === file && Number.isFinite(idleAnimation.duration)) {
      return idleAnimation.duration;
    }
  }

  for (const [state, files] of Object.entries(theme.states || {})) {
    if (!Array.isArray(files) || !files.includes(file)) continue;
    const autoReturn = theme.timings?.autoReturn?.[state];
    const minDisplay = theme.timings?.minDisplay?.[state];
    if (Number.isFinite(autoReturn)) return autoReturn;
    if (Number.isFinite(minDisplay)) return minDisplay;
  }

  return null;
}

function frameCountFor(durationMs, isStatic) {
  if (isStatic) return 1;
  return Math.max(minFrames, Math.min(maxFrames, Math.ceil(durationMs / 250)));
}

async function preparePage(page, svgText) {
  await page.setViewportSize({ width: frameSize, height: frameSize });
  await page.setContent(`
    <!doctype html>
    <html>
      <head>
        <meta charset="utf-8" />
        <style>
          html, body {
            width: ${frameSize}px;
            height: ${frameSize}px;
            margin: 0;
            background: transparent;
            overflow: hidden;
          }
          #stage {
            width: ${frameSize}px;
            height: ${frameSize}px;
            display: flex;
            align-items: center;
            justify-content: center;
          }
          #stage svg {
            width: ${frameSize}px;
            height: ${frameSize}px;
            display: block;
            image-rendering: pixelated;
          }
        </style>
      </head>
      <body>
        <div id="stage">${svgText}</div>
      </body>
    </html>
  `);
  await page.waitForTimeout(50);
}

async function probeDurationMs(page) {
  return page.evaluate(() => {
    const animations = document.getAnimations({ subtree: true });
    const durations = animations
      .map((animation) => {
        const timing = animation.effect?.getComputedTiming?.();
        const duration = timing?.duration;
        if (!Number.isFinite(duration) || duration <= 0) return null;
        return duration;
      })
      .filter((duration) => Number.isFinite(duration));
    if (!durations.length) return { durationMs: null, isStatic: true };
    return { durationMs: Math.max(...durations), isStatic: false };
  });
}

async function seekAnimations(page, elapsedMs) {
  await page.evaluate((elapsed) => {
    const svg = document.querySelector("svg");
    if (svg && typeof svg.setCurrentTime === "function") {
      try {
        svg.setCurrentTime(elapsed / 1000);
      } catch {}
    }

    for (const animation of document.getAnimations({ subtree: true })) {
      try {
        const timing = animation.effect?.getComputedTiming?.();
        const duration = timing?.duration;
        animation.pause();
        if (Number.isFinite(duration) && duration > 0) {
          animation.currentTime = elapsed % duration;
        }
      } catch {}
    }
  }, elapsedMs);
  await page.waitForTimeout(20);
}

async function renderAnimation(browser, theme, file) {
  const sourcePath = path.join(sourceRoot, file);
  const sourceBuffer = await fs.readFile(sourcePath);
  const svgText = sourceBuffer.toString("utf8");
  const sourceHash = sha256(sourceBuffer);
  const page = await browser.newPage({ deviceScaleFactor: 1 });
  await preparePage(page, svgText);

  const probe = await probeDurationMs(page);
  const overrideDuration = durationOverride(theme, file);
  const durationMs = Math.round(overrideDuration || probe.durationMs || fallbackDurationMs);
  const frameCount = frameCountFor(durationMs, probe.isStatic && !overrideDuration);
  const outputDirectory = path.join(outputRoot, basenameStem(file));
  await fs.rm(outputDirectory, { recursive: true, force: true });
  await fs.mkdir(outputDirectory, { recursive: true });

  const frames = [];
  const stage = page.locator("#stage");
  for (let index = 0; index < frameCount; index += 1) {
    const elapsed = frameCount === 1 ? 0 : (durationMs * index) / frameCount;
    await seekAnimations(page, elapsed);
    const frameName = `frame-${String(index).padStart(3, "0")}.png`;
    await stage.screenshot({
      path: path.join(outputDirectory, frameName),
      omitBackground: true,
    });
    frames.push(frameName);
  }

  const manifest = {
    schemaVersion: 1,
    theme: "clawd",
    sourceFile: file,
    sourceSha256: sourceHash,
    durationMs,
    frameSize,
    frames,
    posterFrame: frames[0],
    layout: {
      viewBox: theme.viewBox,
      contentBox: theme.layout.contentBox,
      centerX: theme.layout.centerX,
      baselineY: theme.layout.baselineY,
      visibleHeightRatio: theme.layout.visibleHeightRatio,
      baselineBottomRatio: theme.layout.baselineBottomRatio,
    },
  };
  await fs.writeFile(
    path.join(outputDirectory, "manifest.json"),
    `${JSON.stringify(manifest, null, 2)}\n`
  );

  await page.close();
  return { file, frameCount, durationMs };
}

async function main() {
  const theme = await readJson(path.join(themeRoot, "theme.json"));
  const files = sourceFilesForTheme(theme);
  await fs.rm(outputRoot, { recursive: true, force: true });
  await fs.mkdir(outputRoot, { recursive: true });

  const executablePath = await firstExistingPath(chromeCandidates);
  const browser = await chromium.launch(
    executablePath ? { executablePath } : undefined
  );
  try {
    for (const file of files) {
      const result = await renderAnimation(browser, theme, file);
      console.log(`${result.file}: ${result.frameCount} frames, ${result.durationMs}ms`);
    }
  } finally {
    await browser.close();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
