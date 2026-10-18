import { existsSync, mkdirSync, readFileSync, realpathSync, writeFileSync } from "node:fs";
import path from "node:path";
import { explainApprovalMismatch, normalizeApprovalScope, readApprovalStore, type ApprovalMismatchDiagnostic } from "./approvals.js";
import { renderProjectRolePrompt } from "./agents.js";
import { buildBroRunArgs, ensureBitRouterDaemon, executeBroCommandWithFallback, resolveBroCommand, type BitRouterExecutionResult } from "./codex-runtime.js";
import { bitrouterRuntime } from "./bitrouter-runtime.js";
import type { CodexRuntime, RuntimeExecutionResult } from "./runtime.interface.js";
import { renderCodexPrompt } from "./codex-prompts.js";
import { createCodexStudioSession, type VerificationCommand } from "./codex-session.js";
import type { ProjectConfig } from "./config.js";
import { selectContextEntries, type ContextManifestEntry, type ContextRequestEntry, type ContextSelectionResult } from "./context-manifest.js";
import { loadEngineConfigs } from "./engines.js";
import { engineReferenceContextRequests } from "./engine-reference.js";
import { stripGeneratedMetadata } from "./generated-surfaces.js";
import { renderContextContract } from "./prompt-context.js";
import {
  modelPolicyForTier,
  modelTierForModel,
  isReasoningEffort,
  parseTomlStringField,
  resolveModelRoute,
  type CodexModelName,
  type ModelSelectionSource,
  type ModelTier,
  type ReasoningEffort,
  type ResolvedModelRoute
} from "./prompt-surface-metadata.js";
import { configFromStudio, readStudioProject, type StudioProjectState } from "./projects.js";
import { isRoleAvailableForEngine, isStudioRoleId, unknownStudioRoleMessage, type StudioRoleId } from "./roles.js";
import { customPhaseForRun, customTemplateIdsForRole, findCustomRole, renderCustomRolePrompt } from "./customization.js";
import { packageAssetPath, resolveProjectRoot } from "./paths.js";
import { evaluateStudioRunEligibility, type CodexStudioPhase, type StudioRunEligibility } from "./studio-policy.js";
import { renderSelectedTemplates, selectTemplates } from "./templates.js";
import { runVerificationCommand, type VerificationResult } from "./verification.js";

export type RunOptions = {
  project?: string;
  task: string;
  printPrompt?: boolean;
  dryRun?: boolean;
  broBin?: string;
  broConfig?: string;
  includeArtifact?: string[];
  approvedFiles?: string[];
  approvalScope?: string[];
  allowBroadContext?: boolean;
  verifyCommand?: VerificationCommand;
  review?: boolean;
  fix?: boolean;
  maxFixPasses?: number;
  approvedByUser?: boolean;
  constrainedSandbox?: boolean;
  noWrite?: boolean;
  modelTier?: ModelTier;
  surfaceModel?: CodexModelName;
  surfaceEffort?: ReasoningEffort;
  runtimeOptions?: Record<string, any>;
};

export type PreparedRun = {
  prompt: string;
  promptPath: string;
  metadataPath: string;
  projectRoot: string;
  role: string;
  task: string;
  contextFiles: string[];
  verification?: VerificationCommand;
  broCommand: { command: string; args: string[]; display: string };
  fallbackBroCommand: { command: string; args: string[]; display: string };
  reviewBroCommand?: { command: string; args: string[]; display: string };
  reviewFallbackBroCommand?: { command: string; args: string[]; display: string };
  fixBroCommand?: { command: string; args: string[]; display: string };
  fixFallbackBroCommand?: { command: string; args: string[]; display: string };
  output: string;
  reviewPrompt?: string;
  fixPrompt?: string;
  maxFixPasses: number;
  eligibility: StudioRunEligibility;
  selectedModelTier: ModelTier;
  selectedModel: CodexModelName;
  modelReasoningEffort: ReasoningEffort;
  fallbackModel: CodexModelName;
  fallbackReasoningEffort: ReasoningEffort;
  modelSelectionSource: ModelSelectionSource;
  // Runtime for execution
  runtime: CodexRuntime;
  runtimeOptions: Record<string, any>;
};

export type ReviewResult = {
  blockers: string[];
  warnings: string[];
  summary: string;
  needsFix: boolean;
};

export type ReviewPassResult = {
  execution: RuntimeExecutionResult;
  raw: string;
  parsed?: ReviewResult;
  malformed?: string;
};

export type FixPassResult = {
  pass: number;
  execution: RuntimeExecutionResult;
  verification?: VerificationResult;
  review?: ReviewPassResult;
};

export type RunLifecycleResult = {
  implementation: RuntimeExecutionResult;
  verification?: VerificationResult;
  review?: ReviewPassResult;
  fixPasses: FixPassResult[];
  finalStatus: "done" | "blocked";
  output: string;
};

function requireTask(task: string): string {
  if (!task || !task.trim()) throw new Error("task is required and must be non-empty");
  return task.trim();
}

function modelFromCommand(command: { args: string[] }): CodexModelName {
  const index = command.args.indexOf("--model");
  const model = index >= 0 ? command.args[index + 1] : undefined;
  const tier = modelPolicyForTier("terra");
  const supported = [
    modelPolicyForTier("sol").primary.model,
    modelPolicyForTier("sol").fallback.model,
    tier.primary.model,
    tier.fallback.model,
    modelPolicyForTier("luna").primary.model,
    modelPolicyForTier("luna").fallback.model
  ];
  if (!model || !supported.includes(model as CodexModelName)) throw new Error("Codex command does not contain a supported model");
  return model as CodexModelName;
}

function roleSurfaceTarget(projectRoot: string, role: StudioRoleId): { model: CodexModelName; effort: ReasoningEffort } {
  const file = path.join(projectRoot, ".codex", "agents", `${role}.toml`);
  if (!existsSync(file)) return modelPolicyForTier("terra").primary;
  const body = readFileSync(file, "utf8");
  const model = parseTomlStringField(body, "model");
  const effort = parseTomlStringField(body, "model_reasoning_effort");
  if (!modelTierForModel(model)) throw new Error(`${role} has an invalid or unregistered model`);
  if (!isReasoningEffort(effort)) throw new Error(`${role} has an invalid or missing model reasoning effort`);
  return { model: model as CodexModelName, effort };
}

function reviewRouteFor(route: ResolvedModelRoute): ResolvedModelRoute {
  const review = modelPolicyForTier(route.tier === "sol" ? "sol" : "terra");
  const effort = route.primary.effort === "low" || route.primary.effort === "minimal" ? "medium" : route.primary.effort;
  return { ...review, primary: { ...review.primary, effort }, fallback: { ...review.fallback, effort }, source: "surface" };
}

function fixRouteFor(route: ResolvedModelRoute): ResolvedModelRoute {
  if (route.tier !== "luna") return route;
  const fix = modelPolicyForTier("terra");
  const effort = route.primary.effort === "low" || route.primary.effort === "minimal" ? "medium" : route.primary.effort;
  return { ...fix, primary: { ...fix.primary, effort }, fallback: { ...fix.fallback, effort }, source: "verification-escalation" };
}

export function broRunInvocation(
  projectRoot: string,
  broBin = resolveBroCommand(),
  model?: CodexModelName,
  reasoningEffort?: ReasoningEffort,
  broConfig?: string
): { command: string; args: string[]; display: string } {
  const args = buildBroRunArgs({ projectRoot, model, reasoningEffort, broConfig });
  return { command: broBin, args, display: [broBin, ...args.map((arg) => JSON.stringify(arg))].join(" ") };
}

export async function executeBroPromptForRun(run: PreparedRun, prompt: string, command = run.broCommand): Promise<BitRouterExecutionResult> {
  const isReview = command === run.reviewBroCommand;
  const isFix = command === run.fixBroCommand;
  const fallback = isReview ? run.reviewFallbackBroCommand : isFix ? run.fixFallbackBroCommand : run.fallbackBroCommand;
  if (!fallback) throw new Error("Codex fallback command is missing");
  const primaryModel = isReview || isFix ? modelFromCommand(command) : run.selectedModel;
  const fallbackModel = isReview || isFix ? modelFromCommand(fallback) : run.fallbackModel;
  return await executeBroCommandWithFallback(
    { primary: command, fallback, primaryModel, fallbackModel },
    prompt,
    { cwd: run.projectRoot }
  );
}

export async function executeBroRun(run: PreparedRun): Promise<BitRouterExecutionResult> {
  return await executeBroPromptForRun(run, run.prompt);
}

function safeArtifact(projectRoot: string, artifact: string): { full: string; display: string } {
  if (/[\u0000-\u001f\u007f]/.test(artifact)) throw new Error("--include-artifact cannot contain control characters");
  if (path.isAbsolute(artifact)) throw new Error("--include-artifact must be relative");
  const full = path.resolve(projectRoot, artifact);
  if (!full.startsWith(`${projectRoot}${path.sep}`)) throw new Error("--include-artifact cannot escape the project root");
  const realRoot = realpathSync(projectRoot);
  const realFull = realpathSync(full);
  if (realFull !== realRoot && !realFull.startsWith(`${realRoot}${path.sep}`)) throw new Error("--include-artifact cannot escape the project root");
  return { full: realFull, display: path.relative(realRoot, realFull).split(path.sep).join("/") };
}

function renderRuntimeContextBlock(role: StudioRoleId, studio: StudioProjectState, task: string, route: ResolvedModelRoute): string {
  const projectRolePrompt = stripGeneratedMetadata(renderProjectRolePrompt(role, configFromStudio(studio), loadEngineConfigs(packageAssetPath("engine_configs"))));
  const templateBodies = renderSelectedTemplates(selectTemplates(role, task));
  const modelBlock = [
    "## Runtime Model Policy",
    "",
    `- Selected tier: ${route.tier}`,
    `- Selected model: ${route.primary.model}`,
    `- Reasoning effort: ${route.primary.effort}`,
    `- Designated fallback: ${route.fallback.model} (${route.fallback.effort})`,
    `- Selection source: ${route.source}`,
    `- Source surface: .codex/agents/${role}.toml`,
    "- Output contract: summary, changed files or proposed files, verification evidence, blockers, risks, and handoff owner when needed.",
    "- Stop condition: do not continue when required project state, write approval, or verification evidence is missing.",
    ""
  ].join("\n");
  return ["", `# Runtime Role Context: ${role}`, "", modelBlock, projectRolePrompt.trim(), templateBodies, ""].join("\n");
}

function broadContextRequests(): ContextRequestEntry[] {
  return [
    { sourcePath: "design/gdd.md", reason: "design reference" },
    { sourcePath: "production/timeline.md", reason: "production reference" },
    { sourcePath: "docs/market-overview.md", reason: "market reference" }
  ];
}

function contextFiles(entries: ContextManifestEntry[]): string[] {
  return entries.filter((entry) => entry.status === "selected").map((entry) => entry.sourcePath);
}

function formatApprovalDiagnostic(diagnostic: ApprovalMismatchDiagnostic, args: { projectStage: string; studioMode: string; approvalScopes: string[] }): string {
  const lines = [
    "Approval diagnostic:",
    `project stage: ${args.projectStage}`,
    `studio mode: ${args.studioMode}`,
    `approval scopes: ${args.approvalScopes.length ? args.approvalScopes.join(", ") : "none"}`,
    `current objective hash: ${diagnostic.objectiveSha256}`,
    diagnostic.matched ? "matching approval found" : "no matching approval"
  ];
  if (diagnostic.records.length === 0) {
    lines.push("records: none");
    return lines.join("\n");
  }
  lines.push("records:");
  for (const record of diagnostic.records) {
    lines.push(`${record.id}: ${record.authorizing ? "authorizing" : `non-authorizing (${record.reasons.join(", ")})`}`);
  }
  return lines.join("\n");
}

function phaseForRun(role: StudioRoleId): CodexStudioPhase {
  if (role === "producer") return "plan";
  if (role === "qa-playtester") return "review";
  return "implement";
}

function formatEligibility(eligibility: StudioRunEligibility): string {
  const lines = [
    `Eligibility: ${eligibility.allowed ? "allowed" : "blocked"}`,
    `Write policy: ${eligibility.writePolicy}`,
    `Sandbox: ${eligibility.codexSandbox}`,
    `File edits: ${eligibility.allowFileEdits ? "allowed" : "not allowed"}`,
    `Reason: ${eligibility.reason}`,
    `Provenance: ${String(eligibility.metadata.provenance)}`,
    `Approved by user: ${eligibility.metadata.approvedByUser === true}`,
    `Matching approval: ${eligibility.metadata.hasMatchingApproval === true}`,
    `Constrained sandbox: ${eligibility.metadata.constrainedSandbox === true}`
  ];
  if (eligibility.requiredApproval) {
    lines.push(
      "Required approval:",
      `- project stage: ${eligibility.requiredApproval.projectStage}`,
      `- studio mode: ${eligibility.requiredApproval.studioMode}`,
      `- phase: ${eligibility.requiredApproval.phase}`,
      `- approval policy: ${eligibility.requiredApproval.approvalPolicy}`
    );
  }
  return lines.join("\n");
}

function executionFailed(result: RuntimeExecutionResult): boolean {
  return Boolean(result.error) || (result.status ?? 1) !== 0;
}

function verificationFailed(result: VerificationResult): boolean {
  return result.timedOut || result.exitCode !== 0;
}

export function parseReviewJson(raw: string): ReviewResult {
  const trimmed = raw.trim();
  const start = trimmed.indexOf("{");
  const end = trimmed.lastIndexOf("}");
  if (start === -1 || end === -1 || end < start) throw new Error("review output did not contain a JSON object");
  const parsed = JSON.parse(trimmed.slice(start, end + 1)) as Partial<ReviewResult>;
  if (!Array.isArray(parsed.blockers) || !parsed.blockers.every((item) => typeof item === "string")) throw new Error("review JSON blockers must be string[]");
  if (!Array.isArray(parsed.warnings) || !parsed.warnings.every((item) => typeof item === "string")) throw new Error("review JSON warnings must be string[]");
  if (typeof parsed.summary !== "string") throw new Error("review JSON summary must be a string");
  if (typeof parsed.needsFix !== "boolean") throw new Error("review JSON needsFix must be boolean");
  return { blockers: parsed.blockers, warnings: parsed.warnings, summary: parsed.summary, needsFix: parsed.needsFix };
}

async function runReviewPass(run: PreparedRun, previousSummary = ""): Promise<ReviewPassResult | undefined> {
  if (!run.reviewPrompt) return undefined;
  const prompt = `${run.reviewPrompt}\n\n# Implementation and verification output\n\n${previousSummary}\n`;
  const execution = await executeBroPromptForRun(run, prompt, run.reviewBroCommand ?? run.broCommand);
  const raw = execution.stdout.trim() || execution.stderr.trim();
  if (executionFailed(execution)) return { execution, raw, malformed: execution.error?.message ?? `review exited with status ${execution.status}` };
  try {
    return { execution, raw, parsed: parseReviewJson(raw) };
  } catch (error) {
    return { execution, raw, malformed: (error as Error).message };
  }
}

function reviewFailed(review: ReviewPassResult | undefined): boolean {
  if (!review) return false;
  if (review.malformed) return true;
  return Boolean(review.parsed?.needsFix || review.parsed?.blockers.length);
}

function formatCodex(label: string, result: RuntimeExecutionResult): string[] {
  const route = result.executedModel ? ` model=${result.executedModel}${result.fallbackFromModel ? ` fallback-from=${result.fallbackFromModel}` : ""}` : "";
  const lines = [`${label}: exit=${result.status ?? "null"}${result.signal ? ` signal=${result.signal}` : ""}${result.error ? ` error=${result.error.message}` : ""}${route}`];
  if (result.stdout.trim()) lines.push(`${label} stdout:\n${result.stdout.trim()}`);
  if (result.stderr.trim()) lines.push(`${label} stderr:\n${result.stderr.trim()}`);
  return lines;
}

function formatVerification(result: VerificationResult): string[] {
  const lines = [`verification: ${result.command} ${result.args.join(" ")} exit=${result.exitCode ?? "null"}${result.signal ? ` signal=${result.signal}` : ""}${result.timedOut ? " timedOut=true" : ""}`];
  if (result.stdout.trim()) lines.push(`verification stdout:\n${result.stdout.trim()}`);
  if (result.stderr.trim()) lines.push(`verification stderr:\n${result.stderr.trim()}`);
  return lines;
}

function formatReview(review: ReviewPassResult | undefined): string[] {
  if (!review) return [];
  const lines = formatCodex("review", review.execution);
  if (review.malformed) lines.push(`review blocked: malformed review JSON (${review.malformed})`);
  if (review.parsed) {
    lines.push(`review summary: ${review.parsed.summary}`);
    lines.push(`review needsFix: ${review.parsed.needsFix}`);
    if (review.parsed.blockers.length) lines.push(`review blockers:\n${review.parsed.blockers.map((b) => `- ${b}`).join("\n")}`);
    if (review.parsed.warnings.length) lines.push(`review warnings:\n${review.parsed.warnings.map((w) => `- ${w}`).join("\n")}`);
  }
  return lines;
}

async function runVerificationIfConfigured(run: PreparedRun): Promise<VerificationResult | undefined> {
  if (!run.verification) return undefined;
  return await runVerificationCommand(run.verification, { cwd: run.projectRoot });
}

function blockedAfter(implementation: RuntimeExecutionResult, verification?: VerificationResult, review?: ReviewPassResult): boolean {
  return executionFailed(implementation) || Boolean(verification && verificationFailed(verification)) || reviewFailed(review);
}

export async function executeRunLifecycle(run: PreparedRun): Promise<RunLifecycleResult> {
  const output: string[] = [];

  // Ensure BitRouter daemon is available before execution (skip for test stubs)
  const broCmd = run.broCommand.command;
  if (!broCmd.includes("-stub") && !broCmd.includes("/tmp/")) {
    try {
      const { health } = await ensureBitRouterDaemon({ broBin: broCmd, autoStart: true });
      if (!health.daemonRunning && health.issues.length > 0) {
        output.push(`BitRouter daemon warnings: ${health.issues.join(", ")}`);
      }
    } catch {
      // Health check failed — proceed anyway, actual execution will report the error
    }
  }

  const implementation = await executeBroPromptForRun(run, run.prompt);
  output.push(...formatCodex("implementation", implementation));

  let verification: VerificationResult | undefined;
  let review: ReviewPassResult | undefined;
  if (!executionFailed(implementation)) {
    verification = await runVerificationIfConfigured(run);
    if (verification) output.push(...formatVerification(verification));
    if (!verification || !verificationFailed(verification)) {
      review = await runReviewPass(run, output.join("\n\n"));
      output.push(...formatReview(review));
    }
  }

  const fixPasses: FixPassResult[] = [];
  let blocked = blockedAfter(implementation, verification, review);
  while (blocked && run.fixPrompt && fixPasses.length < run.maxFixPasses) {
    const pass = fixPasses.length + 1;
    const fixExecution = await executeBroPromptForRun(run, `${run.fixPrompt}\n\n# Previous run summary\n\n${output.join("\n\n")}\n`, run.fixBroCommand ?? run.broCommand);
    output.push(...formatCodex(`fix pass ${pass}`, fixExecution));
    let fixVerification: VerificationResult | undefined;
    let fixReview: ReviewPassResult | undefined;
    if (!executionFailed(fixExecution)) {
      fixVerification = await runVerificationIfConfigured(run);
      if (fixVerification) output.push(...formatVerification(fixVerification));
      if (!fixVerification || !verificationFailed(fixVerification)) {
        fixReview = await runReviewPass(run, output.join("\n\n"));
        output.push(...formatReview(fixReview));
      }
    }
    fixPasses.push({ pass, execution: fixExecution, verification: fixVerification, review: fixReview });
    blocked = executionFailed(fixExecution) || Boolean(fixVerification && verificationFailed(fixVerification)) || reviewFailed(fixReview);
  }

  if (blocked && run.fixPrompt && fixPasses.length >= run.maxFixPasses) output.push(`blocked: reached max fix passes (${run.maxFixPasses})`);
  const finalStatus: "done" | "blocked" = blocked ? "blocked" : "done";
  output.push(`final status: ${finalStatus}`);
  return { implementation, verification, review, fixPasses, finalStatus, output: output.join("\n\n") };
}

let runSequence = 0;

type RunSharedContext = {
  artifactDisplays: string[];
  contextSelection: ContextSelectionResult;
  contextFilesForRun: string[];
  artifactBodies: string[];
  maxFixPasses: number;
};

function resolveRunSharedContext(args: {
  projectRoot: string;
  options: RunOptions;
  roleContextEntries: ContextRequestEntry[];
  trailingContextEntries?: ContextRequestEntry[];
}): RunSharedContext {
  const artifactRefs = (args.options.includeArtifact ?? []).map((artifact) => {
    const { full, display } = safeArtifact(args.projectRoot, artifact);
    return { full, display };
  });
  const artifactDisplays = artifactRefs.map((artifact) => artifact.display);
  const contextRequests: ContextRequestEntry[] = [
    { sourcePath: "AGENTS.md", reason: "project instructions", required: true },
    { sourcePath: ".codex/studio.json", reason: "project state", required: true },
    ...args.roleContextEntries,
    ...artifactDisplays.map((display) => ({ sourcePath: display, reason: "included artifact", required: true })),
    ...(args.trailingContextEntries ?? []),
    ...(args.options.allowBroadContext ? broadContextRequests() : [])
  ];
  const contextSelection = selectContextEntries(args.projectRoot, contextRequests);
  const contextFilesForRun = contextFiles(contextSelection.entries);
  const selectedContextFiles = new Set(contextFilesForRun);
  const artifactBodies = artifactRefs
    .filter((artifact) => selectedContextFiles.has(artifact.display))
    .map((artifact) => `\n\n# Included Artifact: ${artifact.display}\n\n${readFileSync(artifact.full, "utf8")}`);
  const maxFixPasses = args.options.maxFixPasses ?? 1;
  if (!Number.isFinite(maxFixPasses) || maxFixPasses < 0) throw new Error("--max-fix-passes must be a finite non-negative number");
  return { artifactDisplays, contextSelection, contextFilesForRun, artifactBodies, maxFixPasses };
}

function evaluateRunGate(args: {
  projectRoot: string;
  role: string;
  task: string;
  studio: StudioProjectState;
  options: RunOptions;
  phase: CodexStudioPhase;
  artifactDisplays: string[];
}): { approvalScopes: string[]; approvalDiagnosticResult: ApprovalMismatchDiagnostic; eligibility: StudioRunEligibility } {
  const approvalScopes = normalizeApprovalScope(args.options.approvalScope ?? [], { projectRoot: args.projectRoot });
  const approvalDiagnosticResult = explainApprovalMismatch(readApprovalStore(args.projectRoot), {
    role: args.role,
    objective: args.task,
    approvedGlobs: approvalScopes,
    approvedFiles: args.options.approvedFiles ?? (args.artifactDisplays.length ? args.artifactDisplays : undefined),
    projectStage: args.studio.mode,
    studioMode: args.studio.studioMode
  });
  const eligibility = evaluateStudioRunEligibility({
    projectStage: args.studio.mode,
    studioMode: args.studio.studioMode,
    phase: args.phase,
    hasMatchingApproval: approvalDiagnosticResult.matched,
    approvedByUser: args.options.approvedByUser,
    constrainedSandbox: args.options.constrainedSandbox
  });
  if (!eligibility.allowed && !args.options.printPrompt && !args.options.dryRun) throw new Error(eligibility.reason);
  return { approvalScopes, approvalDiagnosticResult, eligibility };
}

function buildReviewPrompt(args: {
  projectRoot: string;
  studio: StudioProjectState;
  task: string;
  contextSelection: ContextSelectionResult;
  reviewRoute: ResolvedModelRoute;
  enabled: boolean;
}): string | undefined {
  const reviewObjective = `Review the implementation for: ${args.task}. Inspect the diff and verification output. Return only JSON with blockers, warnings, summary, and needsFix.`;
  const reviewSelection = selectContextEntries(args.projectRoot, [
    { sourcePath: "AGENTS.md", reason: "project instructions", required: true },
    { sourcePath: ".codex/studio.json", reason: "project state", required: true },
    { sourcePath: ".codex/agents/qa-playtester.toml", reason: "review custom agent", required: true },
    ...args.contextSelection.selected.map((entry) => ({ sourcePath: entry.sourcePath, reason: `implementation context: ${entry.reason}`, required: entry.required }))
  ]);
  const reviewSession = createCodexStudioSession({
    projectRoot: args.projectRoot,
    role: "qa-playtester",
    objective: reviewObjective,
    phase: "review",
    engine: args.studio.engine,
    contextFiles: contextFiles(reviewSelection.entries),
    expectedOutputs: ["Review JSON", "Blockers", "Warnings"],
    allowFileEdits: false,
    sandbox: "read-only",
    writePolicy: "read-only",
    reviewMode: "diff"
  });
  if (!args.enabled) return undefined;
  return `${renderCodexPrompt({
    ...reviewSession,
    contextContract: renderContextContract({
      session: reviewSession,
      projectStage: args.studio.mode,
      studioMode: args.studio.studioMode,
      entries: reviewSelection.entries,
      readOnlyReview: true
    })
  })}${renderRuntimeContextBlock("qa-playtester", args.studio, reviewObjective, args.reviewRoute)}`;
}

function finalizePreparedRun(args: {
  cwd: string;
  projectRoot: string;
  roleId: string;
  roleReturn: string;
  task: string;
  studio: StudioProjectState;
  options: RunOptions;
  modelRoute: ResolvedModelRoute;
  reviewRoute: ResolvedModelRoute;
  fixRoute: ResolvedModelRoute;
  contextFilesForRun: string[];
  prompt: string;
  reviewPrompt: string | undefined;
  fixPrompt: string | undefined;
  maxFixPasses: number;
  eligibility: StudioRunEligibility;
  approvalScopes: string[];
  approvalDiagnosticResult: ApprovalMismatchDiagnostic;
  runtime?: CodexRuntime;
  customRole?: boolean;
  extraDryRunSummary?: string;
}): PreparedRun {
  const { cwd, projectRoot, options, studio } = args;
  const runId = `${new Date().toISOString().replace(/[-:.TZ]/g, "").slice(0, 17)}-${process.pid}-${++runSequence}`;
  const runDir = path.join(projectRoot, ".codex", "runs", `${runId}-${args.roleId}`);
  const promptPath = path.join(runDir, "prompt.md");
  const metadataPath = path.join(runDir, "metadata.json");
  const selectedModelTier = args.modelRoute.tier;
  const selectedModel = args.modelRoute.primary.model;
  const modelReasoningEffort = args.modelRoute.primary.effort;
  const fallbackModel = args.modelRoute.fallback.model;
  const fallbackReasoningEffort = args.modelRoute.fallback.effort;
  const modelSelectionSource = args.modelRoute.source;
  if (!options.printPrompt && !options.dryRun && !options.noWrite) {
    mkdirSync(runDir, { recursive: true });
    writeFileSync(promptPath, args.prompt);
    writeFileSync(
      metadataPath,
      `${JSON.stringify(
        {
          timestamp: new Date().toISOString(),
          product: "codex-game-studio",
          project: path.relative(cwd, projectRoot) || ".",
          role: args.roleId,
          task: args.task,
          ...(args.customRole ? { customRole: true } : {}),
          prompt_chars: args.prompt.length,
          prompt_cache_path: path.relative(cwd, promptPath),
          selectedModelTier,
          selectedModel,
          modelReasoningEffort,
          fallbackModel,
          fallbackReasoningEffort,
          modelSelectionSource,
          review: Boolean(args.reviewPrompt),
          fix: Boolean(args.fixPrompt),
          max_fix_passes: args.maxFixPasses,
          writePolicy: args.eligibility.writePolicy,
          allowFileEdits: args.eligibility.allowFileEdits,
          codexSandbox: args.eligibility.codexSandbox,
          eligibility: args.eligibility
        },
        null,
        2
      )}\n`
    );
  }
  const rt = args.runtime ?? bitrouterRuntime;
  const broBin = options.broBin ?? resolveBroCommand();
  const broConfig = options.broConfig;
  const broCommand = broRunInvocation(projectRoot, broBin, selectedModel, modelReasoningEffort, broConfig);
  const fallbackBroCommand = broRunInvocation(projectRoot, broBin, fallbackModel, fallbackReasoningEffort, broConfig);
  const reviewBroCommand = args.reviewPrompt ? broRunInvocation(projectRoot, broBin, args.reviewRoute.primary.model, args.reviewRoute.primary.effort, broConfig) : undefined;
  const reviewFallbackBroCommand = args.reviewPrompt ? broRunInvocation(projectRoot, broBin, args.reviewRoute.fallback.model, args.reviewRoute.fallback.effort, broConfig) : undefined;
  const fixBroCommand = args.fixPrompt ? broRunInvocation(projectRoot, broBin, args.fixRoute.primary.model, args.fixRoute.primary.effort, broConfig) : undefined;
  const fixFallbackBroCommand = args.fixPrompt ? broRunInvocation(projectRoot, broBin, args.fixRoute.fallback.model, args.fixRoute.fallback.effort, broConfig) : undefined;
  const dryRunExtra = [
    args.reviewPrompt ? `\n\nReview Codex command: ${reviewBroCommand?.display}\nReview fallback: ${reviewFallbackBroCommand?.display}\n\nReview prompt:\n${args.reviewPrompt}\n\nExpected review JSON schema: {"blockers":[],"warnings":[],"summary":"","needsFix":false}` : "",
    args.fixPrompt ? `\n\nFix Codex command: ${fixBroCommand?.display}\nFix fallback: ${fixFallbackBroCommand?.display}\nFix prompt (max passes: ${args.maxFixPasses}):\n${args.fixPrompt}` : ""
  ].join("");
  const approvalDiagnostic =
    options.dryRun && studio.studioMode !== "fast-prototype"
      ? formatApprovalDiagnostic(args.approvalDiagnosticResult, { projectStage: studio.mode, studioMode: studio.studioMode, approvalScopes: args.approvalScopes })
      : "";
  const eligibilitySummary = formatEligibility(args.eligibility);
  const extraSummary = args.extraDryRunSummary ? `\n${args.extraDryRunSummary}` : "";
  const modelSummary = `Selected tier: ${selectedModelTier}\nSelected model: ${selectedModel} (${modelReasoningEffort})\nFallback model: ${fallbackModel} (${fallbackReasoningEffort})\nSelection source: ${modelSelectionSource}`;
  const output = options.printPrompt
    ? args.prompt
    : options.dryRun
      ? `Prompt cache (not written): ${promptPath}\nMetadata (not written): ${metadataPath}\n${modelSummary}\n${eligibilitySummary}${extraSummary}\nContext files:\n${args.contextFilesForRun.map((f) => `- ${f}`).join("\n")}\nCodex command: ${broCommand.display}\nFallback command: ${fallbackBroCommand.display}${approvalDiagnostic ? `\n\n${approvalDiagnostic}` : ""}${dryRunExtra}`
      : `Prompt cache written: ${promptPath}\n${modelSummary}\n${eligibilitySummary}\nExecuting Codex: ${broCommand.display}`;
  return { prompt: args.prompt, promptPath, metadataPath, projectRoot, role: args.roleReturn, task: args.task, contextFiles: args.contextFilesForRun, verification: options.verifyCommand, broCommand, fallbackBroCommand, reviewBroCommand, reviewFallbackBroCommand, fixBroCommand, fixFallbackBroCommand, output, reviewPrompt: args.reviewPrompt, fixPrompt: args.fixPrompt, maxFixPasses: args.maxFixPasses, eligibility: args.eligibility, selectedModelTier, selectedModel, modelReasoningEffort, fallbackModel, fallbackReasoningEffort, modelSelectionSource, runtime: rt, runtimeOptions: runtimeOptionsFor(rt, projectRoot, options) };
}

function prepareCustomRun(role: ReturnType<typeof findCustomRole> extends infer T ? NonNullable<T> : never, options: RunOptions, cwd: string, roleInput: string, task: string, projectRoot: string): PreparedRun {
  const studio = readStudioProject(projectRoot);
  const customPolicy = modelPolicyForTier(role.modelTier);
  const modelRoute = resolveModelRoute({ surfaceModel: customPolicy.primary.model, surfaceEffort: options.surfaceEffort ?? customPolicy.primary.effort, requestedTier: options.modelTier });
  const reviewRoute = reviewRouteFor(modelRoute);
  const fixRoute = fixRouteFor(modelRoute);
  const shared = resolveRunSharedContext({
    projectRoot,
    options,
    roleContextEntries: [
      { sourcePath: role.promptFile, reason: "selected custom role prompt", required: true },
      ...role.contextFiles.map((sourcePath) => ({ sourcePath, reason: "custom role context", required: false }))
    ]
  });
  const phase = customPhaseForRun(role);
  const gate = evaluateRunGate({ projectRoot, role: role.id, task, studio, options, phase, artifactDisplays: shared.artifactDisplays });
  const templateIds = customTemplateIdsForRole(projectRoot, role.id, task);
  const prompt = [
    "# Codex Game Studio Custom Role Session",
    "",
    `Role: ${role.displayName}`,
    `Role ID: ${role.id}`,
    `Context Strategy: ${role.contextStrategy}`,
    `Phase: ${phase}`,
    `Project Root: ${projectRoot}`,
    `Objective: ${task}`,
    `Engine: ${studio.engine}`,
    `Sandbox: ${gate.eligibility.codexSandbox}`,
    `Write Policy: ${gate.eligibility.writePolicy}`,
    `File Edits: ${gate.eligibility.allowFileEdits ? "allowed" : "not allowed"}`,
    `Model Tier: ${modelRoute.tier}`,
    `Model: ${modelRoute.primary.model} (${modelRoute.primary.effort})`,
    `Fallback: ${modelRoute.fallback.model} (${modelRoute.fallback.effort})`,
    "",
    "## Context Files",
    shared.contextFilesForRun.length ? shared.contextFilesForRun.map((file) => `- ${file}`).join("\n") : "- None selected",
    "",
    renderCustomRolePrompt(projectRoot, role),
    renderSelectedTemplates(templateIds, "## Selected Templates", { projectRoot }),
    shared.artifactBodies.join("")
  ].join("\n");
  const reviewPrompt = buildReviewPrompt({ projectRoot, studio, task, contextSelection: shared.contextSelection, reviewRoute, enabled: Boolean(options.review) });
  const fixContract = renderContextContract({
    session: { phase: "fix", writePolicy: gate.eligibility.writePolicy, sandbox: gate.eligibility.codexSandbox, allowFileEdits: gate.eligibility.allowFileEdits },
    projectStage: studio.mode,
    studioMode: studio.studioMode,
    entries: shared.contextSelection.entries,
    blockers: ["Review and verification blockers will be supplied at execution time."]
  });
  const fixPrompt =
    options.fix && shared.maxFixPasses > 0
      ? [
          "# Codex Game Studio Custom Role Session",
          "",
          `Role: ${role.displayName}`,
          `Role ID: ${role.id}`,
          `Context Strategy: ${role.contextStrategy}`,
          "Phase: fix",
          `Project Root: ${projectRoot}`,
          `Objective: Fix verification failures or review blockers for: ${task}`,
          `Engine: ${studio.engine}`,
          `Sandbox: ${gate.eligibility.codexSandbox}`,
          `Write Policy: ${gate.eligibility.writePolicy}`,
          `File Edits: ${gate.eligibility.allowFileEdits ? "allowed" : "not allowed"}`,
          `Model Tier: ${fixRoute.tier}`,
          `Model: ${fixRoute.primary.model} (${fixRoute.primary.effort})`,
          `Fallback: ${fixRoute.fallback.model} (${fixRoute.fallback.effort})`,
          `Selection Source: ${fixRoute.source}`,
          "",
          fixContract,
          "",
          "## Context Files",
          shared.contextFilesForRun.length ? shared.contextFilesForRun.map((file) => `- ${file}`).join("\n") : "- None selected",
          "",
          "## Verification",
          options.verifyCommand ? `${options.verifyCommand.command} ${options.verifyCommand.args.join(" ")}`.trim() : "No verification command provided.",
          "",
          renderCustomRolePrompt(projectRoot, role),
          renderSelectedTemplates(templateIds, "## Selected Templates", { projectRoot }),
          shared.artifactBodies.join("")
        ].join("\n")
      : undefined;
  return finalizePreparedRun({
    cwd,
    projectRoot,
    roleId: role.id,
    roleReturn: roleInput,
    task,
    studio,
    options,
    modelRoute,
    reviewRoute,
    fixRoute,
    contextFilesForRun: shared.contextFilesForRun,
    prompt,
    reviewPrompt,
    fixPrompt,
    maxFixPasses: shared.maxFixPasses,
    eligibility: gate.eligibility,
    approvalScopes: gate.approvalScopes,
    approvalDiagnosticResult: gate.approvalDiagnosticResult,
    customRole: true
  });
}

export function prepareRun(roleInput: string, options: RunOptions, cwd = process.cwd(), runtime?: CodexRuntime): PreparedRun {
  const task = requireTask(options.task);
  const projectRoot = resolveProjectRoot(options.project, cwd);
  const customRole = isStudioRoleId(roleInput) ? undefined : findCustomRole(projectRoot, roleInput);
  if (customRole) return prepareCustomRun(customRole, options, cwd, roleInput, task, projectRoot);
  if (!isStudioRoleId(roleInput)) throw new Error(unknownStudioRoleMessage(roleInput));
  const role = roleInput as StudioRoleId;
  const studio = readStudioProject(projectRoot);
  const roleTarget = roleSurfaceTarget(projectRoot, role);
  const modelRoute = resolveModelRoute({ surfaceModel: options.surfaceModel ?? roleTarget.model, surfaceEffort: options.surfaceEffort ?? roleTarget.effort, requestedTier: options.modelTier });
  const reviewRoute = reviewRouteFor(modelRoute);
  const fixRoute = fixRouteFor(modelRoute);
  if (!isRoleAvailableForEngine(role, studio.engine)) {
    throw new Error(`${role} is not available for ${studio.engine} projects; use one of ${studio.roles.join(", ")} for this project.`);
  }
  const shared = resolveRunSharedContext({
    projectRoot,
    options,
    roleContextEntries: [{ sourcePath: `.codex/agents/${role}.toml`, reason: "selected custom agent", required: true }],
    trailingContextEntries: engineReferenceContextRequests(studio.engine, role, task)
  });
  const phase = phaseForRun(role);
  const gate = evaluateRunGate({ projectRoot, role, task, studio, options, phase, artifactDisplays: shared.artifactDisplays });
  const session = createCodexStudioSession({
    projectRoot,
    role,
    objective: task,
    phase,
    engine: studio.engine,
    contextFiles: shared.contextFilesForRun,
    verification: options.verifyCommand,
    allowFileEdits: gate.eligibility.allowFileEdits,
    sandbox: gate.eligibility.codexSandbox,
    writePolicy: gate.eligibility.writePolicy,
    eligibility: gate.eligibility
  });
  const runtimeContextBlock = renderRuntimeContextBlock(role, studio, task, modelRoute);
  const prompt = `${renderCodexPrompt({
    ...session,
    contextContract: renderContextContract({
      session,
      projectStage: studio.mode,
      studioMode: studio.studioMode,
      entries: shared.contextSelection.entries
    })
  })}${runtimeContextBlock}${shared.artifactBodies.join("")}`;
  const reviewPrompt = buildReviewPrompt({ projectRoot, studio, task, contextSelection: shared.contextSelection, reviewRoute, enabled: Boolean(options.review) });
  const fixSession = createCodexStudioSession({
    projectRoot,
    role,
    objective: `Fix verification failures or review blockers for: ${task}`,
    phase: "fix",
    engine: studio.engine,
    contextFiles: shared.contextFilesForRun,
    verification: options.verifyCommand,
    expectedOutputs: ["Fix changes", "Verification results", "Remaining blockers"],
    allowFileEdits: gate.eligibility.allowFileEdits,
    sandbox: gate.eligibility.codexSandbox,
    writePolicy: gate.eligibility.writePolicy,
    eligibility: gate.eligibility
  });
  const fixPrompt =
    options.fix && shared.maxFixPasses > 0
      ? `${renderCodexPrompt({
          ...fixSession,
          contextContract: renderContextContract({
            session: fixSession,
            projectStage: studio.mode,
            studioMode: studio.studioMode,
            entries: shared.contextSelection.entries,
            blockers: ["Review and verification blockers will be supplied at execution time."]
          })
        })}${renderRuntimeContextBlock(role, studio, task, fixRoute)}`
      : undefined;
  const nativeSurfaceSummary = [`Codex custom agent: .codex/agents/${role}.toml`, "Relevant skills:", "- .agents/skills/cgs-standards-gameplay/SKILL.md", "- .agents/skills/cgs-bugfix/SKILL.md"].join("\n");
  return finalizePreparedRun({
    cwd,
    projectRoot,
    roleId: role,
    roleReturn: role,
    task,
    studio,
    options,
    modelRoute,
    reviewRoute,
    fixRoute,
    contextFilesForRun: shared.contextFilesForRun,
    prompt,
    reviewPrompt,
    fixPrompt,
    maxFixPasses: shared.maxFixPasses,
    eligibility: gate.eligibility,
    approvalScopes: gate.approvalScopes,
    approvalDiagnosticResult: gate.approvalDiagnosticResult,
    runtime,
    extraDryRunSummary: nativeSurfaceSummary
  });
}

function runtimeOptionsFor(rt: CodexRuntime, projectRoot: string, options: RunOptions): Record<string, any> {
  if (rt === bitrouterRuntime) {
    return {
      projectRoot,
      broBin: options.broBin,
      broConfig: options.broConfig
    };
  }
  return options.runtimeOptions ?? {};
}
