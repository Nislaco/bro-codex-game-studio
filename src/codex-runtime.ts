import { spawn, spawnSync } from "node:child_process";
import type { CodexModelName, ReasoningEffort } from "./prompt-surface-metadata.js";

/** Execution surface: BitRouter bro CLI routing through local daemon. */
export type BitRouterRuntimeOptions = {
  projectRoot: string;
  broBin?: string;
  broConfig?: string;
  model?: CodexModelName;
  reasoningEffort?: ReasoningEffort;
  autoStartDaemon?: boolean;
};

export type BitRouterAvailability = {
  ok: boolean;
  command: string;
  reason?: string;
  stdout: string;
  stderr: string;
};

export type BitRouterHealthStatus = {
  cliOk: boolean;
  cliCommand: string;
  daemonRunning: boolean;
  daemonPid?: number;
  daemonAddress?: string;
  modelCount: number;
  modelResolved: boolean;
  resolvedModel?: string;
  issues: string[];
};

export type BitRouterExecutionResult = {
  status: number | null;
  signal: NodeJS.Signals | null;
  stdout: string;
  stderr: string;
  error?: Error;
  executedModel?: CodexModelName;
  fallbackFromModel?: CodexModelName;
};

export type BitRouterFallbackExecution = {
  primary: { command: string; args: string[] };
  fallback: { command: string; args: string[] };
  primaryModel: CodexModelName;
  fallbackModel: CodexModelName;
};

/** Resolve the bro binary (BitRouter CLI). */
export function resolveBroCommand(env: NodeJS.ProcessEnv | Record<string, string | undefined> = process.env): string {
  return env.BRO_BIN?.trim() || "bro";
}

/** Build args for `bro run codex-acp` — headless ACP prompt routed through BitRouter daemon. */
export function buildBroRunArgs(options: BitRouterRuntimeOptions): string[] {
  return [
    "run",
    "codex-acp",
    "--cwd",
    options.projectRoot,
    ...(options.broConfig ? ["--config", options.broConfig] : []),
    ...(options.model ? ["--model", options.model] : []),
    ...(options.reasoningEffort ? ["--model-reasoning-effort", options.reasoningEffort] : []),
    "--format",
    "quiet",
    "-"
  ];
}

/** Check BitRouter bro CLI availability (basic — CLI exists and responds). */
export async function checkBitRouterAvailability(options: { broBin?: string } = {}): Promise<BitRouterAvailability> {
  const command = options.broBin ?? resolveBroCommand();
  const result = spawnSync(command, ["status"], { encoding: "utf8", shell: false });
  if (result.error) {
    return { ok: false, command, reason: `BitRouter CLI (bro) unavailable or not found: ${result.error.message}`, stdout: result.stdout ?? "", stderr: result.stderr ?? "" };
  }
  if (result.status !== 0) {
    return { ok: false, command, reason: `BitRouter CLI exited with status ${result.status}`, stdout: result.stdout ?? "", stderr: result.stderr ?? "" };
  }
  return { ok: true, command, stdout: result.stdout ?? "", stderr: result.stderr ?? "" };
}

/** Check full BitRouter health: CLI + daemon + model resolution. */
export async function checkBitRouterHealth(options: {
  broBin?: string;
  broConfig?: string;
  model?: string;
} = {}): Promise<BitRouterHealthStatus> {
  const command = options.broBin ?? resolveBroCommand();
  const model = options.model ?? "bitrouter/auto";
  const issues: string[] = [];

  // 1. Check CLI
  const cliResult = spawnSync(command, ["--help"], { encoding: "utf8", shell: false, timeout: 5000 });
  if (cliResult.error) {
    return {
      cliOk: false, cliCommand: command, daemonRunning: false, modelCount: 0, modelResolved: false,
      issues: [`BitRouter CLI (bro) not found: ${cliResult.error.message}`]
    };
  }

  // 2. Check daemon status
  const statusArgs = ["status"];
  if (options.broConfig) statusArgs.push("--config", options.broConfig);
  const statusResult = spawnSync(command, statusArgs, { encoding: "utf8", shell: false, timeout: 10000 });
  let daemonRunning = false;
  let daemonPid: number | undefined;
  let daemonAddress: string | undefined;
  let modelCount = 0;

  if (statusResult.status === 0 && statusResult.stdout) {
    try {
      const status: { running?: boolean; pid?: number; listen?: string; models?: number } = JSON.parse(statusResult.stdout);
      daemonRunning = status.running === true;
      daemonPid = status.pid;
      daemonAddress = status.listen;
      modelCount = status.models ?? 0;
    } catch {
      issues.push("Daemon status returned non-JSON output");
    }
  } else {
    issues.push(`Daemon not running (exit ${statusResult.status})${statusResult.stderr ? ": " + statusResult.stderr.trim() : ""}`);
  }

  // 3. Check model resolution
  const routeArgs = ["route", model];
  if (options.broConfig) routeArgs.push("--config", options.broConfig);
  const routeResult = spawnSync(command, routeArgs, { encoding: "utf8", shell: false, timeout: 10000 });
  let modelResolved = false;
  let resolvedModel: string | undefined;

  if (routeResult.status === 0 && routeResult.stdout) {
    try {
      const route: { effective_model?: string } = JSON.parse(routeResult.stdout);
      if (route.effective_model) {
        modelResolved = true;
        resolvedModel = route.effective_model;
      }
    } catch {
      issues.push(`Model route returned non-JSON output for ${model}`);
    }
  } else {
    issues.push(`Model ${model} not resolved${routeResult.stderr ? ": " + routeResult.stderr.trim() : ""}`);
  }

  return {
    cliOk: true,
    cliCommand: command,
    daemonRunning,
    daemonPid,
    daemonAddress,
    modelCount,
    modelResolved,
    resolvedModel,
    issues
  };
}

/** Ensure the BitRouter daemon is running; auto-start if requested and not running. */
export async function ensureBitRouterDaemon(options: {
  broBin?: string;
  broConfig?: string;
  autoStart?: boolean;
} = {}): Promise<{ started: boolean; health: BitRouterHealthStatus }> {
  const health = await checkBitRouterHealth({ broBin: options.broBin, broConfig: options.broConfig });

  if (health.daemonRunning) {
    return { started: false, health };
  }

  if (!options.autoStart) {
    return { started: false, health };
  }

  // Attempt to start the daemon
  const command = options.broBin ?? resolveBroCommand();
  const startArgs = ["start"];
  if (options.broConfig) startArgs.push("--config", options.broConfig);

  const startResult = spawnSync(command, startArgs, { encoding: "utf8", shell: false, timeout: 30000 });
  if (startResult.error || startResult.status !== 0) {
    health.issues.push(`Failed to start daemon: ${startResult.error?.message ?? startResult.stderr ?? "unknown error"}`);
    return { started: false, health };
  }

  // Re-check after start
  const updatedHealth = await checkBitRouterHealth({ broBin: options.broBin, broConfig: options.broConfig });
  return { started: true, health: updatedHealth };
}

export async function executeBroCommand(
  command: { command: string; args: string[] },
  input: string,
  options: { cwd: string; timeoutMs?: number }
): Promise<BitRouterExecutionResult> {
  return await new Promise((resolve) => {
    const child = spawn(command.command, command.args, { cwd: options.cwd, shell: false, stdio: ["pipe", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";
    let settled = false;
    const finish = (result: BitRouterExecutionResult): void => {
      if (settled) return;
      settled = true;
      if (timer) clearTimeout(timer);
      resolve(result);
    };
    const timer = options.timeoutMs
      ? setTimeout(() => {
          child.kill("SIGTERM");
          finish({ status: null, signal: "SIGTERM", stdout, stderr, error: new Error(`BitRouter command timed out after ${options.timeoutMs}ms`) });
        }, options.timeoutMs)
      : undefined;
    child.stdout.setEncoding("utf8");
    child.stderr.setEncoding("utf8");
    child.stdout.on("data", (chunk: string) => {
      stdout += chunk;
    });
    child.stderr.on("data", (chunk: string) => {
      stderr += chunk;
    });
    child.on("error", (error) => finish({ status: null, signal: null, stdout, stderr, error }));
    child.on("close", (status, signal) => finish({ status, signal, stdout, stderr }));
    child.stdin.end(input);
  });
}

export function isModelUnavailableResult(result: BitRouterExecutionResult): boolean {
  if (!result.error && result.status === 0) return false;
  const message = `${result.error?.message ?? ""}\n${result.stderr}\n${result.stdout}`.toLowerCase();
  return /(?:model|access).*(?:not available|unavailable|not supported|unsupported|not found|unknown|no access|does not have access)|(?:not available|unavailable|not supported|unsupported|not found|unknown).*(?:model)/.test(message);
}

export async function executeBroCommandWithFallback(
  route: BitRouterFallbackExecution,
  input: string,
  options: { cwd: string; timeoutMs?: number }
): Promise<BitRouterExecutionResult> {
  const primary = await executeBroCommand(route.primary, input, options);
  if (!isModelUnavailableResult(primary)) return { ...primary, executedModel: route.primaryModel };
  const fallback = await executeBroCommand(route.fallback, input, options);
  return { ...fallback, executedModel: route.fallbackModel, fallbackFromModel: route.primaryModel };
}

export async function executeBroPrompt(prompt: string, options: BitRouterRuntimeOptions): Promise<BitRouterExecutionResult> {
  const command = options.broBin ?? resolveBroCommand();
  const args = buildBroRunArgs(options);
  return await executeBroCommand({ command, args }, prompt, { cwd: options.projectRoot });
}
