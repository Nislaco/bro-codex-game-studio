import type { CodexModelName, ReasoningEffort } from "./prompt-surface-metadata.js";

export interface RuntimeExecutionResult {
  status: number | null;
  signal: NodeJS.Signals | null;
  stdout: string;
  stderr: string;
  error?: Error;
  executedModel?: string;
  fallbackFromModel?: string;
}

export interface RuntimeAvailability {
  available: boolean;
  issues: string[];
}

export interface RuntimeFallback {
  primary: {
    command: string;
    args: string[];
    display: string;
    model: CodexModelName;
    effort: ReasoningEffort;
  };
  fallback: {
    command: string;
    args: string[];
    display: string;
    model: CodexModelName;
    effort: ReasoningEffort;
  };
}

export interface RuntimeCommand {
  command: string;
  args: string[];
  display: string;
}

export interface CodexRuntime {
  checkAvailability(options: Record<string, any>): Promise<RuntimeAvailability>;
  executePrompt(prompt: string, options: any): Promise<RuntimeExecutionResult>;
  executeWithFallback(
    fallback: RuntimeFallback,
    prompt: string,
    options: { cwd: string; timeoutMs?: number }
  ): Promise<RuntimeExecutionResult>;
  buildCommand(options: any): RuntimeCommand;
}

/**
 * Extension for runtimes that require a daemon (like BitRouter).
 */
export interface DaemonCapableRuntime extends CodexRuntime {
  ensureDaemon(options: Record<string, any>): Promise<{
    started: boolean;
    health: {
      daemonRunning: boolean;
      issues: string[];
    };
  }>;
}
