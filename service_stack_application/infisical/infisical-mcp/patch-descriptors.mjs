import { spawn } from "node:child_process";

const child = spawn("npx", ["-y", "@infisical/mcp"], {
  stdio: ["pipe", "pipe", "inherit"],
});

process.stdin.pipe(child.stdin);

const LIST_PROJECTS_DESCRIPTION =
  "List Infisical projects that the machine identity can access. The local self-hosted service expects a concrete project type such as `secret-manager`, `cert-manager`, `kms`, `ssh`, `secret-scanning`, `pam`, or `ai`. Do not assume `all` is supported.";

const LIST_PROJECTS_TYPE_DESCRIPTION =
  "Concrete project type filter. Use one of: `secret-manager`, `cert-manager`, `kms`, `ssh`, `secret-scanning`, `pam`, or `ai`. In this local setup, do not use `all`.";

let buffer = Buffer.alloc(0);

child.stdout.on("data", (chunk) => {
  buffer = Buffer.concat([buffer, chunk]);
  flushFrames();
});

child.on("exit", (code, signal) => {
  if (signal) {
    process.kill(process.pid, signal);
    return;
  }
  process.exit(code ?? 0);
});

process.on("SIGINT", () => child.kill("SIGINT"));
process.on("SIGTERM", () => child.kill("SIGTERM"));

function flushFrames() {
  while (true) {
    const headerEnd = buffer.indexOf("\r\n\r\n");
    if (headerEnd === -1) return;

    const headerText = buffer.subarray(0, headerEnd).toString("utf8");
    const headers = parseHeaders(headerText);
    const contentLength = Number(headers["content-length"]);

    if (!Number.isFinite(contentLength) || contentLength < 0) {
      process.stdout.write(buffer);
      buffer = Buffer.alloc(0);
      return;
    }

    const frameEnd = headerEnd + 4 + contentLength;
    if (buffer.length < frameEnd) return;

    const bodyBuffer = buffer.subarray(headerEnd + 4, frameEnd);
    buffer = buffer.subarray(frameEnd);

    process.stdout.write(serializeFrame(headers, patchBody(bodyBuffer)));
  }
}

function parseHeaders(headerText) {
  const headers = {};
  for (const line of headerText.split("\r\n")) {
    const separator = line.indexOf(":");
    if (separator === -1) continue;
    const key = line.slice(0, separator).trim().toLowerCase();
    const value = line.slice(separator + 1).trim();
    headers[key] = value;
  }
  return headers;
}

function patchBody(bodyBuffer) {
  let message;
  try {
    message = JSON.parse(bodyBuffer.toString("utf8"));
  } catch {
    return bodyBuffer;
  }

  const tools = message?.result?.tools;
  if (!Array.isArray(tools)) return bodyBuffer;

  let changed = false;
  for (const tool of tools) {
    if (tool?.name !== "list_projects") continue;
    tool.description = LIST_PROJECTS_DESCRIPTION;

    const typeProperty = tool?.inputSchema?.properties?.type;
    if (typeProperty && typeof typeProperty === "object") {
      typeProperty.description = LIST_PROJECTS_TYPE_DESCRIPTION;
      typeProperty.enum = [
        "secret-manager",
        "cert-manager",
        "kms",
        "ssh",
        "secret-scanning",
        "pam",
        "ai",
      ];
    }

    changed = true;
  }

  if (!changed) return bodyBuffer;
  return Buffer.from(JSON.stringify(message), "utf8");
}

function serializeFrame(headers, bodyBuffer) {
  const lines = [];
  for (const [key, value] of Object.entries(headers)) {
    if (key === "content-length") continue;
    lines.push(`${formatHeaderName(key)}: ${value}`);
  }
  lines.push(`Content-Length: ${bodyBuffer.length}`);
  return Buffer.concat([
    Buffer.from(`${lines.join("\r\n")}\r\n\r\n`, "utf8"),
    bodyBuffer,
  ]);
}

function formatHeaderName(key) {
  return key
    .split("-")
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join("-");
}
