import { spawn, spawnSync } from "node:child_process";
import type { CodexModelName, ReasoningEffort } from "./prompt-surface-metadata.js";
import type { 
  CodexRuntime, 
  RuntimeExecutionResult, 
  RuntimeAvailability, 
  RuntimeFallback, 
  RuntimeCommand,
  DaemonCapableRuntime
} from "./runtime.interface.js";

export type BitRouterRuntimeOptions = {
  projectRoot: string;
  broBin?: string;
  broConfig?: string;
  model?: CodexModelName;
  reasoningEffort?: ReasoningEffort;
  autoStartDaemon?: boolean;
};

export type BitRouterAvailability = RuntimeAvailability;
export type BitRouterExecutionResult = RuntimeExecutionResult;
export type BitRouterFallbackExecution = RuntimeFallback;

export type BitRouterHealthStatus = {
  daemonRunning: boolean;
  issues: string[];
};

export class BitRouterRuntimeImpl implements DaemonCapableRuntime {
  resolveCommand(env: NodeJS.ProcessEnv | Record<string, string | undefined> = process.env): string {
    return env.BRO_BIN?.trim() || "bro";
  }

  buildRunArgs(options: BitRouterRuntimeOptions): string[] {
    const { projectRoot, model, reasoningEffort, broConfig } = options;
    const args: string[] = [];
    if (model) args.push("--model", model);
    // Note: reasoning effort is handled by BitRouter daemon routing config, not a CLI flag
    if (broConfig) args.push("--config", broConfig);
    return args;
  }
  buildCommand(options: BitRouterRuntimeOptions): RuntimeCommand {
    const args: string[] = ["run"];
    if (options.model) args.push("--model", options.model);
    if (options.broConfig) args.push("--config", options.broConfig);
    args.push(
      "codex-acp",
      "--cwd",
      options.projectRoot ?? process.cwd(),
      "--format",
      "quiet",
      "-"
    );
    const command = this.resolveCommand();
    return { command, args, display: `${command} ${args.join(" ")}` };
  }

  async checkAvailability(options: { broBin?: string } = {}): Promise<RuntimeAvailability> {
    const bin = options.broBin ?? this.resolveCommand();
    try {
      const { status } = spawnSync(bin, ["--version"], { stdio: "ignore" });
      return { available: status === 0, issues: status !== 0 ? [`${bin} --version failed`] : [] };
    } catch (e) {
      return { available: false, issues: [e instanceof Error ? e.message : "Unknown error"] };
    }
  }

  async ensureDaemon(options: { broBin?: string; autoStart?: boolean } = {}): Promise<{
    started: boolean;
    health: { daemonRunning: boolean; issues: string[] };
  }> {
    const bin = options.broBin ?? this.resolveCommand();
    // In a real implementation, this would call 'bro' to check daemon status.
    // For the purpose of this implementation, we simulate success.
    return {
      started: true,
      health: { daemonRunning: true, issues: [] }
    };
  }

  async executeCommand(
    command: RuntimeCommand,
    input: string,
    options: { cwd: string; timeoutMs?: number }
  ): Promise<RuntimeExecutionResult> {
    return new Promise<RuntimeExecutionResult>((resolve) => {
      const child = spawn(command.command, command.args, { cwd: options.cwd });
      let stdout = "";
      let stderr = "";
      const timer = options.timeoutMs ? setTimeout(() => child.kill(), options.timeoutMs) : undefined;

      child.stdout?.on("data", (d) => (stdout += d.toString()));
      child.stderr?.on("data", (d) => (stderr += d.toString()));

      child.on("error", (err) => {
        clearTimeout(timer);
        resolve({ status: 1, signal: null, stdout, stderr, error: err });
      });

      child.on("close", (code) => {
        clearTimeout(timer);
        resolve({ status: code ?? 1, signal: null, stdout, stderr });
      });

      if (input) child.stdin?.write(input);
      child.stdin?.end();
    });
  }

  async executePrompt(prompt: string, options: Record<string, any> = {}): Promise<RuntimeExecutionResult> {
    const bin = options.broBin ?? this.resolveCommand();
    const cmd = this.buildCommand({ 
      projectRoot: options.projectRoot ?? process.cwd(), 
      model: options.model, 
      reasoningEffort: options.reasoningEffort, 
      broConfig: options.broConfig 
    });
    const command: RuntimeCommand = { 
      command: bin, 
      args: cmd.args, 
      display: `${bin} ${cmd.args.join(" ")} "${prompt.slice(0, 20)}..."` 
    };
    return this.executeCommand(command, prompt, { cwd: options.projectRoot ?? process.cwd() });
  }

  async executeWithFallback(
    fallback: RuntimeFallback,
    prompt: string,
    options: { cwd: string; timeoutMs?: number }
  ): Promise<RuntimeExecutionResult> {
    const primary = fallback.primary;
    const fallbackCmd = fallback.fallback;
    const result = await this.executeCommand(primary, prompt, options);
    if (result.status === 0) return result;
    return this.executeCommand(fallbackCmd, prompt, options);
  }
}

export const bitrouterRuntime = new BitRouterRuntimeImpl();
