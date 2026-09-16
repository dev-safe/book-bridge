#!/usr/bin/env bun
// Minimal dependency-free static file server for the BookBridge web build.

import { extname, join, normalize, sep } from "node:path";

const ROOT = normalize(join(import.meta.dir, "curr"));
const HOSTNAME = process.env.HOST || "0.0.0.0";
const PORT = Number(process.env.FRONTEND_PORT || 3004);

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".wasm": "application/wasm",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".gif": "image/gif",
  ".svg": "image/svg+xml",
  ".webp": "image/webp",
  ".ico": "image/x-icon",
  ".woff": "font/woff",
  ".woff2": "font/woff2",
  ".ttf": "font/ttf",
  ".otf": "font/otf",
  ".bin": "application/octet-stream",
  ".map": "application/json; charset=utf-8",
  ".txt": "text/plain; charset=utf-8",
};

function contentType(path) {
  return MIME[extname(path).toLowerCase()] || "application/octet-stream";
}

function resolveSafe(pathname) {
  const decoded = decodeURIComponent(pathname);
  const rel = decoded.endsWith("/") ? `${decoded}index.html` : decoded;
  const resolved = normalize(join(ROOT, rel));
  if (resolved !== ROOT && !resolved.startsWith(ROOT + sep)) {
    return null;
  }
  return resolved;
}

const INDEX = join(ROOT, "index.html");

Bun.serve({
  hostname: HOSTNAME,
  port: PORT,
  async fetch(req) {
    if (req.method !== "GET" && req.method !== "HEAD") {
      return new Response("Method Not Allowed", { status: 405 });
    }

    const { pathname } = new URL(req.url);
    const filePath = resolveSafe(pathname);
    if (filePath) {
      const file = Bun.file(filePath);
      if (await file.exists()) {
        return new Response(file, {
          headers: { "content-type": contentType(filePath) },
        });
      }
    }

    const index = Bun.file(INDEX);
    if (await index.exists()) {
      return new Response(index, {
        status: 200,
        headers: { "content-type": "text/html; charset=utf-8" },
      });
    }

    return new Response("Not Found", { status: 404 });
  },
});

console.log(`[app] serving ${ROOT} on http://${HOSTNAME}:${PORT}`);
