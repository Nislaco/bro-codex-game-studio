import { mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { describe, test } from "node:test";
import { expect } from "expect";
import { readStudioProject } from "../src/projects.js";
import { renderWorkflowPrompt } from "../src/workflows.js";
import { validateRepo } from "../src/validation.js";

function escapeRegex(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function projectWithMalformedStudio(): { projectRoot: string; studioPath: string } {
  const projectRoot = mkdtempSync(path.join(tmpdir(), "cgs-guarded-parse-"));
  mkdirSync(path.join(projectRoot, ".codex"), { recursive: true });
  const studioPath = path.join(projectRoot, ".codex", "studio.json");
  writeFileSync(studioPath, "{ not valid json ");
  return { projectRoot, studioPath };
}

describe("guarded project-state parses", () => {
  test("readStudioProject reports the offending path on malformed studio.json", () => {
    const { projectRoot, studioPath } = projectWithMalformedStudio();
    expect(() => readStudioProject(projectRoot)).toThrow(new RegExp(`${escapeRegex(studioPath)} could not be read as JSON`));
  });

  test("renderWorkflowPrompt reports the offending path on malformed studio.json", () => {
    const { projectRoot, studioPath } = projectWithMalformedStudio();
    expect(() => renderWorkflowPrompt(projectRoot, "bugfix")).toThrow(new RegExp(`${escapeRegex(studioPath)} could not be read as JSON`));
  });

  test("validateRepo reports package.parse on malformed package.json", async () => {
    const root = mkdtempSync(path.join(tmpdir(), "cgs-guarded-parse-pkg-"));
    const pkgPath = path.join(root, "package.json");
    writeFileSync(pkgPath, "{ not valid json ");
    const checks = await validateRepo(root);
    const packageParse = checks.find((check) => check.id === "package.parse");
    expect(packageParse?.status).toBe("fail");
    expect(packageParse?.message).toContain("package.json could not be read or parsed");
    expect(packageParse?.path).toBe(pkgPath);
  });
});
