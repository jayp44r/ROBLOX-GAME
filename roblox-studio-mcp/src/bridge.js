// Localhost HTTP bridge between the MCP server and the Roblox Studio plugin.
//
// Studio plugins cannot accept incoming connections, so the plugin long-polls
// GET /poll for work and posts each answer to POST /result.

import http from "node:http";
import { randomUUID } from "node:crypto";

const POLL_HOLD_MS = 15_000; // keep under Studio's HttpService request timeout
const STALE_AFTER_MS = 35_000; // instance counts as gone after this long without polling
const MAX_BODY_BYTES = 20 * 1024 * 1024;

export class StudioBridge {
  constructor({ port, host = "127.0.0.1", log = console.error }) {
    this.port = port;
    this.host = host;
    this.log = log;
    this.instances = new Map(); // instanceId -> { id, placeName, placeId, gameId, lastSeen, queue, waiter }
    this.pending = new Map(); // commandId -> { resolve, reject, timer }
    this.server = null;
  }

  start() {
    return new Promise((resolve, reject) => {
      this.server = http.createServer((req, res) => this.#handle(req, res));
      this.server.once("error", reject);
      this.server.listen(this.port, this.host, () => {
        this.server.off("error", reject);
        this.log(`[roblox-studio-mcp] bridge listening on http://${this.host}:${this.port}`);
        this.#listenIpv6Loopback();
        resolve();
      });
    });
  }

  // The plugin calls "localhost", which some Windows setups resolve to ::1.
  #listenIpv6Loopback() {
    if (this.host !== "127.0.0.1") return;
    const v6 = http.createServer((req, res) => this.#handle(req, res));
    v6.once("error", () => {}); // no IPv6, or ::1 already taken: IPv4 is enough
    v6.listen(this.port, "::1");
  }

  connectedInstances() {
    const now = Date.now();
    return [...this.instances.values()]
      .filter((i) => i.waiter || now - i.lastSeen < STALE_AFTER_MS)
      .sort((a, b) => b.lastSeen - a.lastSeen)
      .map(({ id, placeName, placeId, gameId, lastSeen }) => ({
        instanceId: id,
        placeName,
        placeId,
        gameId,
        lastSeenMsAgo: now - lastSeen,
      }));
  }

  // Sends a command to one Studio instance and resolves with its result.
  send(type, args = {}, { instanceId, timeoutMs = 60_000 } = {}) {
    const connected = this.connectedInstances();
    if (connected.length === 0) {
      return Promise.reject(
        new Error(
          "No Roblox Studio instance is connected. Open Studio, open a place, and make sure the " +
            "RobloxStudioMCP plugin is enabled (Plugins tab > MCP > Connect). Allow its HTTP " +
            "permission prompt for localhost if Studio shows one."
        )
      );
    }
    const target = instanceId
      ? this.instances.get(instanceId)
      : this.instances.get(connected[0].instanceId);
    if (!target) {
      return Promise.reject(new Error(`Unknown Studio instance "${instanceId}". Call get_connected_instances.`));
    }

    const id = randomUUID();
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        target.queue = target.queue.filter((c) => c.id !== id);
        reject(new Error(`Studio did not answer "${type}" within ${Math.round(timeoutMs / 1000)}s.`));
      }, timeoutMs);
      this.pending.set(id, { resolve, reject, timer });
      target.queue.push({ id, type, args });
      this.#flush(target);
    });
  }

  #flush(instance) {
    if (!instance.waiter || instance.queue.length === 0) return;
    const { res, timer } = instance.waiter;
    instance.waiter = null;
    clearTimeout(timer);
    const command = instance.queue.shift();
    sendJson(res, 200, command);
  }

  async #handle(req, res) {
    try {
      const url = new URL(req.url, `http://${req.headers.host || "localhost"}`);
      if (req.method === "GET" && url.pathname === "/poll") return this.#poll(url, res);
      if (req.method === "POST" && url.pathname === "/result") return await this.#result(req, res);
      if (req.method === "GET" && url.pathname === "/health") {
        return sendJson(res, 200, { ok: true, instances: this.connectedInstances() });
      }
      sendJson(res, 404, { error: "not found" });
    } catch (err) {
      sendJson(res, 400, { error: String(err?.message || err) });
    }
  }

  #poll(url, res) {
    const id = url.searchParams.get("instanceId");
    if (!id) return sendJson(res, 400, { error: "instanceId required" });

    let instance = this.instances.get(id);
    if (!instance) {
      instance = { id, queue: [], waiter: null };
      this.instances.set(id, instance);
      this.log(`[roblox-studio-mcp] Studio connected: ${url.searchParams.get("placeName") || id}`);
    }
    instance.placeName = url.searchParams.get("placeName") || instance.placeName;
    instance.placeId = Number(url.searchParams.get("placeId")) || 0;
    instance.gameId = Number(url.searchParams.get("gameId")) || 0;
    instance.lastSeen = Date.now();

    // A newer poll from the same instance replaces an older hanging one.
    if (instance.waiter) {
      clearTimeout(instance.waiter.timer);
      res204(instance.waiter.res);
    }
    const timer = setTimeout(() => {
      if (instance.waiter?.res === res) {
        instance.waiter = null;
        instance.lastSeen = Date.now();
        res204(res);
      }
    }, POLL_HOLD_MS);
    instance.waiter = { res, timer };
    res.on("close", () => {
      if (instance.waiter?.res === res) {
        clearTimeout(timer);
        instance.waiter = null;
      }
    });
    this.#flush(instance);
  }

  async #result(req, res) {
    const body = JSON.parse(await readBody(req));
    const entry = this.pending.get(body.id);
    if (entry) {
      this.pending.delete(body.id);
      clearTimeout(entry.timer);
      if (body.ok) entry.resolve(body.result);
      else entry.reject(new Error(body.error || "Studio reported an error"));
    }
    sendJson(res, 200, { ok: true });
  }
}

function sendJson(res, status, value) {
  if (res.writableEnded) return;
  const body = JSON.stringify(value);
  res.writeHead(status, { "Content-Type": "application/json", "Content-Length": Buffer.byteLength(body) });
  res.end(body);
}

function res204(res) {
  if (res.writableEnded) return;
  res.writeHead(204);
  res.end();
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];
    req.on("data", (chunk) => {
      size += chunk.length;
      if (size > MAX_BODY_BYTES) {
        reject(new Error("request body too large"));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
    req.on("error", reject);
  });
}
