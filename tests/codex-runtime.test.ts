import { chmodSync, writeFileSync } from "node:fs";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { describe, test } from "node:test";
import { expect } from "expect";
import { buildBroRunArgs, checkBitRouterAvailability, executeBroCommandWithFallback, resolveBroCommand } from "../src/codex-runtime.js";

describe("bro runtime", () => {
  test("resolves bro command from BRO_BIN", () => {
    expect(resolveBroCommand({ BRO_BIN: "bro-custom" })).toBe("bro-custom");
    expect(resolveBroCommand({})).toBe("bro");
  });

  test("builds bro run codex-acp args without the unsupported reasoning-effort flag and maps write policy to permission flags", () => {
    const args = buildBroRunArgs({ projectRoot: "/repo", model: "bitrouter/auto", reasoningEffort: "high", allowFileEdits: true });
    expect(args).toContain("run");
    expect(args).toContain("codex-acp");
    expect(args).toContain("--model");
    expect(args).toContain("bitrouter/auto");
    expect(args).toContain("--cwd");
    expect(args).toContain("/repo");
    expect(args).toContain("-");
    expect(args).toContain("--format");
    expect(args).toContain("quiet");
    expect(args).not.toContain("--model-reasoning-effort");
    // bro defaults to deny-all; the studio maps its write policy explicitly.
    expect(args).toContain("--approve-all");
    expect(args).not.toContain("--approve-reads");

    const readOnlyArgs = buildBroRunArgs({ projectRoot: "/repo", allowFileEdits: false });
    expect(readOnlyArgs).toContain("--approve-reads");
    expect(readOnlyArgs).not.toContain("--approve-all");
  });

  test("reports availability failures without throwing", async () => {
    const result = await checkBitRouterAvailability({ broBin: "/missing/bro" });
    expect(result.ok).toBe(false);
    expect(result.command).toBe("/missing/bro");
    expect(result.reason).toMatch(/not found|unavailable/i);
  });

  test("reports authenticated stub as available", async () => {
    const cwd = mkdtempSync(path.join(tmpdir(), "ogs-bro-"));
    const stub = path.join(cwd, "bro-stub.mjs");
    writeFileSync(stub, "#!/usr/bin/env node\nconsole.log('running: yes');\n");
    chmodSync(stub, 0o755);
    const result = await checkBitRouterAvailability({ broBin: stub });
    expect(result.ok).toBe(true);
    expect(result.command).toBe(stub);
  });

  test("uses the designated fallback only when the primary model is unavailable", async () => {
    const cwd = mkdtempSync(path.join(tmpdir(), "ogs-bro-fallback-"));
    const stub = path.join(cwd, "bro-stub.mjs");
    const stateFile = path.join(cwd, "call-count.json");
    writeFileSync(stub, `#!/usr/bin/env node\nimport { readFileSync, writeFileSync } from "node:fs";\nconst sf = ${JSON.stringify(stateFile)};\nlet count = 0;\ntry { count = JSON.parse(readFileSync(sf, "utf8")).count; } catch { }\nconst newCount = count + 1;\nwriteFileSync(sf, JSON.stringify({ count: newCount }));\nif (newCount === 1) { console.error('model bitrouter/auto is not available for this account'); process.exit(1); }\nconsole.log('bitrouter/auto');\n`);
    chmodSync(stub, 0o755);
    const primary = { command: stub, args: buildBroRunArgs({ projectRoot: cwd, model: "bitrouter/auto", reasoningEffort: "high" }) };
    const fallback = { command: stub, args: buildBroRunArgs({ projectRoot: cwd, model: "bitrouter/auto", reasoningEffort: "high" }) };

    const result = await executeBroCommandWithFallback({ primary, fallback, primaryModel: "bitrouter/auto", fallbackModel: "bitrouter/auto" }, "prompt", { cwd });

    expect(result.status).toBe(0);
    expect(result.stdout.trim()).toBe("bitrouter/auto");
    expect(result.executedModel).toBe("bitrouter/auto");
    expect(result.fallbackFromModel).toBe("bitrouter/auto");
  });

  test("does not hide ordinary execution failures behind a fallback", async () => {
    const cwd = mkdtempSync(path.join(tmpdir(), "ogs-codex-no-fallback-"));
    const stub = path.join(cwd, "codex-stub.mjs");
    writeFileSync(stub, "#!/usr/bin/env node\nconsole.error('tests failed'); process.exit(2);\n");
    chmodSync(stub, 0o755);
    const primary = { command: stub, args: buildBroRunArgs({ projectRoot: cwd, model: "bitrouter/auto", reasoningEffort: "medium" }) };
    const fallback = { command: stub, args: buildBroRunArgs({ projectRoot: cwd, model: "bitrouter/auto", reasoningEffort: "medium" }) };

    const result = await executeBroCommandWithFallback({ primary, fallback, primaryModel: "bitrouter/auto", fallbackModel: "bitrouter/auto" }, "prompt", { cwd });

    expect(result.status).toBe(2);
    expect(result.executedModel).toBe("bitrouter/auto");
    expect(result.fallbackFromModel).toBeUndefined();
  });
});
