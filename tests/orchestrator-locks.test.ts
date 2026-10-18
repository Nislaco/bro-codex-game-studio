import { existsSync, mkdirSync, mkdtempSync, readdirSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { describe, test } from "node:test";
import { expect } from "expect";
import { acquireTaskLocks, locksDir, releaseTaskLocks } from "../src/orchestrator-locks.js";

function lockFiles(projectRoot: string): string[] {
  const dir = locksDir(projectRoot);
  return existsSync(dir) ? readdirSync(dir).sort() : [];
}

describe("orchestration lock TTL", () => {
  test("a live (unexpired) lock blocks acquisition", () => {
    const projectRoot = mkdtempSync(path.join(tmpdir(), "ogs-locks-live-"));
    const task = { id: "task-a", role: "gameplay-programmer" as const, writeFiles: ["src/player.gd"] };

    const first = acquireTaskLocks(projectRoot, task, "run-1", 60_000);
    expect(() => acquireTaskLocks(projectRoot, task, "run-2", 60_000)).toThrow(/Lock already held/);

    releaseTaskLocks(first);
    expect(lockFiles(projectRoot)).toHaveLength(0);
  });

  test("an expired orphaned lock is reclaimed instead of blocking forever", () => {
    const projectRoot = mkdtempSync(path.join(tmpdir(), "ogs-locks-expired-"));
    const task = { id: "task-a", role: "gameplay-programmer" as const, writeFiles: ["src/player.gd"] };

    // Probe to learn the exact lock path, then seed an already-expired lock.
    const probe = acquireTaskLocks(projectRoot, task, "run-probe", 60_000);
    const lockPath = probe[0].file;
    releaseTaskLocks(probe);

    const now = Date.now();
    const expired = { ...probe[0].lock, expiresAt: new Date(now - 1_000).toISOString() };
    writeFileSync(lockPath, `${JSON.stringify(expired, null, 2)}\n`);

    const reclaimed = acquireTaskLocks(projectRoot, task, "run-2", 60_000);

    expect(reclaimed).toHaveLength(1);
    expect(reclaimed[0].lock.orchestrationRunId).toBe("run-2");
    expect(Date.parse(reclaimed[0].lock.expiresAt)).toBeGreaterThan(now);

    releaseTaskLocks(reclaimed);
    expect(lockFiles(projectRoot)).toHaveLength(0);
  });

  test("a malformed lock file still blocks acquisition", () => {
    const projectRoot = mkdtempSync(path.join(tmpdir(), "ogs-locks-malformed-"));
    mkdirSync(locksDir(projectRoot), { recursive: true });
    const task = { id: "task-a", role: "gameplay-programmer" as const, writeFiles: ["src/player.gd"] };

    // Write garbage into the lock path that acquireTaskLocks would compute.
    const probe = acquireTaskLocks(projectRoot, task, "run-probe", 60_000);
    const lockPath = probe[0].file;
    releaseTaskLocks(probe);
    writeFileSync(lockPath, "not json");

    expect(() => acquireTaskLocks(projectRoot, task, "run-1", 60_000)).toThrow(/Lock already held/);
  });

  test("an unparsable expiry does not treat the lock as expired", () => {
    const projectRoot = mkdtempSync(path.join(tmpdir(), "ogs-locks-badexpiry-"));
    const task = { id: "task-a", role: "gameplay-programmer" as const, writeFiles: ["src/player.gd"] };

    // Probe to learn the lock path, then seed a lock with an unparsable expiry.
    const probe = acquireTaskLocks(projectRoot, task, "run-probe", 60_000);
    const lockPath = probe[0].file;
    releaseTaskLocks(probe);

    const badExpiry = { ...probe[0].lock, expiresAt: "not-a-date" };
    writeFileSync(lockPath, `${JSON.stringify(badExpiry, null, 2)}\n`);

    // Number.isFinite(Date.parse("not-a-date")) is false, so it must NOT be reclaimed.
    expect(() => acquireTaskLocks(projectRoot, task, "run-2", 60_000)).toThrow(/Lock already held/);
  });
});
