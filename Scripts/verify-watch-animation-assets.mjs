#!/usr/bin/env node
import crypto from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const repoRoot = path.resolve(path.dirname(__filename), "..");
const animationRoot = path.join(
  repoRoot,
  "apps/apple/Sources/KiriFriendsWatchKit/Resources/BuddyAnimationFrames"
);
const macThemeRoot = path.join(
  repoRoot,
  "apps/apple/Sources/KiriFriendsBuddyMac/Resources/Themes"
);

function sourcePathFor(theme, sourceFile) {
  if (theme === "clawd") {
    return path.join(macThemeRoot, "clawd/svg", sourceFile);
  }
  return path.join(macThemeRoot, theme, "assets", sourceFile);
}

async function exists(filePath) {
  try {
    await fs.access(filePath);
    return true;
  } catch {
    return false;
  }
}

async function listManifestPaths(directory) {
  const entries = await fs.readdir(directory, { withFileTypes: true });
  const paths = [];
  for (const entry of entries) {
    const entryPath = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      paths.push(...await listManifestPaths(entryPath));
    } else if (entry.name === "manifest.json") {
      paths.push(entryPath);
    }
  }
  return paths;
}

async function sha256(filePath) {
  const data = await fs.readFile(filePath);
  return crypto.createHash("sha256").update(data).digest("hex");
}

async function verifyManifest(manifestPath) {
  const manifest = JSON.parse(await fs.readFile(manifestPath, "utf8"));
  const errors = [];
  const context = path.relative(repoRoot, manifestPath);

  for (const field of ["theme", "sourceFile", "sourceSha256", "durationMs", "frames", "posterFrame"]) {
    if (manifest[field] == null) errors.push(`${context}: missing ${field}`);
  }
  if (!Array.isArray(manifest.frames) || manifest.frames.length === 0) {
    errors.push(`${context}: frames must be a non-empty array`);
  }

  const sourcePath = sourcePathFor(manifest.theme, manifest.sourceFile);
  if (!await exists(sourcePath)) {
    errors.push(`${context}: missing canonical source ${path.relative(repoRoot, sourcePath)}`);
  } else {
    const actualSha = await sha256(sourcePath);
    if (actualSha !== manifest.sourceSha256) {
      errors.push(`${context}: sourceSha256 drift for ${manifest.sourceFile}`);
    }
  }

  const manifestDirectory = path.dirname(manifestPath);
  for (const frame of manifest.frames || []) {
    const framePath = path.join(manifestDirectory, frame);
    if (!await exists(framePath)) {
      errors.push(`${context}: missing frame ${frame}`);
    }
  }
  if (manifest.posterFrame && !(manifest.frames || []).includes(manifest.posterFrame)) {
    errors.push(`${context}: posterFrame is not listed in frames`);
  }

  return errors;
}

async function main() {
  if (!await exists(animationRoot)) {
    throw new Error(`missing animation root: ${animationRoot}`);
  }

  const manifests = await listManifestPaths(animationRoot);
  if (manifests.length === 0) {
    throw new Error("no Watch animation manifests found");
  }

  const allErrors = [];
  for (const manifest of manifests) {
    allErrors.push(...await verifyManifest(manifest));
  }

  if (allErrors.length > 0) {
    for (const error of allErrors) console.error(`verify-watch-animation-assets: ${error}`);
    process.exitCode = 1;
    return;
  }

  console.log(`verify-watch-animation-assets: ${manifests.length} manifests match canonical sources.`);
}

main().catch((error) => {
  console.error(`verify-watch-animation-assets: ${error.message}`);
  process.exitCode = 1;
});
