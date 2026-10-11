import { describe, test } from "node:test";
import { expect } from "expect";
import {
  isCodexModelName,
  modelPolicyForTier,
  modelTierForModel,
  parsePromptSurfaceFrontmatter,
  resolveModelRoute,
  validateAgentDescriptionQuality,
  validateModelPolicy,
  validateSkillDescriptionQuality,
  validateWorkflowArgumentHintQuality
} from "../src/prompt-surface-metadata.js";

describe("prompt surface metadata", () => {
  test("maps stable model tiers to primary and safe fallback defaults", () => {
    expect(modelPolicyForTier("sol")).toEqual({
      tier: "sol",
      primary: { model: "bitrouter/auto", effort: "high" },
      fallback: { model: "bitrouter/auto", effort: "high" }
    });
    expect(modelPolicyForTier("terra")).toEqual({
      tier: "terra",
      primary: { model: "bitrouter/auto", effort: "medium" },
      fallback: { model: "bitrouter/auto", effort: "medium" }
    });
    expect(modelPolicyForTier("luna")).toEqual({
      tier: "luna",
      primary: { model: "bitrouter/auto", effort: "low" },
      fallback: { model: "bitrouter/auto", effort: "low" }
    });
  });

  test("infers surface tiers while preserving per-surface reasoning effort", () => {
    // Tier is derived from effort level for polymorphic models (bitrouter/auto)
    // low effort → luna, medium effort → terra, high effort → sol
    expect(resolveModelRoute({ surfaceModel: "bitrouter/auto", surfaceEffort: "low" })).toMatchObject({ tier: "luna", source: "surface", primary: { model: "bitrouter/auto", effort: "low" }, fallback: { model: "bitrouter/auto", effort: "low" } });
    expect(resolveModelRoute({ surfaceModel: "bitrouter/auto", surfaceEffort: "medium" })).toMatchObject({ tier: "terra", source: "surface", primary: { model: "bitrouter/auto", effort: "medium" } });
    expect(resolveModelRoute({ surfaceModel: "bitrouter/auto", surfaceEffort: "high" })).toMatchObject({ tier: "sol", source: "surface", primary: { model: "bitrouter/auto", effort: "high" } });
    // Explicit tier override takes precedence
    expect(resolveModelRoute({ surfaceModel: "bitrouter/auto", surfaceEffort: "medium", requestedTier: "sol" })).toMatchObject({ tier: "sol", source: "explicit-tier", primary: { model: "bitrouter/auto", effort: "medium" } });
    // modelTierForModel returns sol for bitrouter/auto (first match); tier is resolved from effort in resolveModelRoute
    expect(modelTierForModel("bitrouter/auto")).toBe("sol");
  });

  test("rejects unregistered models and invalid reasoning effort values without coupling the two", () => {
    for (const valid of ["bitrouter/auto", "bitrouter/auto", "bitrouter/auto", "bitrouter/auto", "bitrouter/auto", "bitrouter/auto"]) expect(isCodexModelName(valid)).toBe(true);
    for (const invalid of ["sonnet", "haiku", "opus", "claude-3.5-sonnet", "complex", "moderate", "simple", "gpt5.5"]) {
      expect(isCodexModelName(invalid)).toBe(false);
      expect(validateModelPolicy({ model: invalid, model_reasoning_effort: "high" }).valid).toBe(false);
    }
    expect(validateModelPolicy({ model: "bitrouter/auto", model_reasoning_effort: "medium" }).valid).toBe(true);
    expect(validateModelPolicy({ model: "bitrouter/auto", model_reasoning_effort: "high" }).valid).toBe(true);
    expect(validateModelPolicy({ model: "bitrouter/auto" }).issues).toContain("missing reasoning effort");
    expect(validateModelPolicy({ model: "bitrouter/auto", model_reasoning_effort: "extreme" }).issues).toContain("invalid reasoning effort: extreme");
  });

  test("parses markdown frontmatter", () => {
    const parsed = parsePromptSurfaceFrontmatter(`---\nname: cgs-prototype\nmodel: bitrouter/auto\nmodel_reasoning_effort: high\nrelated-agents: [producer, qa-playtester]\n---\n\n# Body`);
    expect(parsed.frontmatter.model_tier).toBeUndefined();
    expect(parsed.frontmatter.model).toBe("bitrouter/auto");
    expect(parsed.frontmatter.model_reasoning_effort).toBe("high");
    expect(parsed.body).toContain("# Body");
  });

  test("flags generic agent descriptions and accepts selection-oriented ownership metadata", () => {
    const generic = validateAgentDescriptionQuality("Game development Game Designer agent for game-designer tasks in this template repository.", "game-designer");
    expect(generic.valid).toBe(false);
    expect(generic.diagnostics.map((diagnostic) => diagnostic.id)).toContain("prompt.discovery.agent.generic_description");

    const specific = validateAgentDescriptionQuality(
      "Owns implementable gameplay mechanics, tuning values, edge cases, and player-facing acceptance criteria for bounded feature design; hand off production scope or QA evidence decisions.",
      "game-designer"
    );
    expect(specific.valid).toBe(true);
  });

  test("flags non-actionable skill descriptions and accepts trigger/outcome metadata", () => {
    const generic = validateSkillDescriptionQuality("Use for Codex Game Studio prototype work.", "cgs-prototype");
    expect(generic.valid).toBe(false);
    expect(generic.diagnostics.map((diagnostic) => diagnostic.id)).toContain("prompt.discovery.skill.vague_description");

    const specific = validateSkillDescriptionQuality(
      "Use for prototype experiments: define a falsifiable gameplay hypothesis, throwaway boundary, success signal, cleanup plan, and verification evidence.",
      "cgs-prototype"
    );
    expect(specific.valid).toBe(true);
  });

  test("flags generic workflow argument hints and accepts workflow-specific input guidance", () => {
    const generic = validateWorkflowArgumentHintQuality("Describe the vertical-slice goal, target milestone/files, constraints, and required evidence.", "vertical-slice");
    expect(generic.valid).toBe(false);
    expect(generic.diagnostics.map((diagnostic) => diagnostic.id)).toContain("prompt.discovery.workflow.generic_argument_hint");

    const specific = validateWorkflowArgumentHintQuality(
      "Provide the playable slice goal, milestone target, involved scenes/assets/code paths, scope constraints, acceptance gates, and required build or playtest evidence.",
      "vertical-slice"
    );
    expect(specific.valid).toBe(true);
  });
});
