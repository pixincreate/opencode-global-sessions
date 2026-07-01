import { execFileSync } from "child_process";

const SESH_BIN = process.env.SESH_BIN || `${process.env.HOME}/.local/bin/sesh`;

type CommandHandler = (query?: string, opts?: string) => string;

const parseOptions = (opts?: string): string[] => {
  if (!opts) return [];

  const args: string[] = [];
  const pattern = /"([^"]*)"|'([^']*)'|(\S+)/g;
  let match: RegExpExecArray | null;

  while ((match = pattern.exec(opts)) !== null) {
    args.push(match[1] ?? match[2] ?? match[3]);
  }

  return args;
};

const executeCommand = (args: string[]): string => {
  const result = execFileSync(SESH_BIN, args, { encoding: "utf-8" });
  return result.trim();
};

const handleError = (
  error: Error & { code?: string; status?: number; stderr?: Buffer },
): string => {
  if (error.code === "ENOENT") {
    return `Error: sesh binary not found at ${SESH_BIN}. Install it to ~/.local/bin or set SESH_BIN environment variable.`;
  }
  if (error.status === 1) {
    return (
      error.stderr?.toString().trim() ||
      `Error executing command: ${error.message}`
    );
  }
  return `Error: ${error.message}`;
};

const commands: Record<
  string,
  { handler: CommandHandler; requiresArg: boolean }
> = {
  list: {
    handler: (query) => executeCommand(["list", query || "10"]),
    requiresArg: false,
  },
  search: {
    handler: (query, opts) =>
      executeCommand(["search", query || "", ...parseOptions(opts)]),
    requiresArg: true,
  },
  show: {
    handler: (query) => executeCommand(["show", query || ""]),
    requiresArg: true,
  },
  log: {
    handler: (query, opts) =>
      executeCommand(["log", query || "", ...parseOptions(opts)]),
    requiresArg: true,
  },
  prompts: {
    handler: (query, opts) =>
      executeCommand(["prompts", query || "", ...parseOptions(opts)]),
    requiresArg: true,
  },
  resume: {
    handler: (query) => executeCommand(["resume", query || ""]),
    requiresArg: true,
  },
  today: {
    handler: () => executeCommand(["today"]),
    requiresArg: false,
  },
  stats: {
    handler: () => executeCommand(["stats"]),
    requiresArg: false,
  },
  files: {
    handler: (query) => executeCommand(["files", query || ""]),
    requiresArg: true,
  },
  config: {
    handler: () => executeCommand(["config"]),
    requiresArg: false,
  },
  help: {
    handler: () => executeCommand(["help"]),
    requiresArg: false,
  },
};

export const Sesh = () => {
  return {
    tool: {
      "sessions-global": {
        description: "List sessions from ALL directories",
        args: {
          cmd: { type: "string", optional: true },
          q: { type: "string", optional: true },
          opts: { type: "string", optional: true },
        },
        execute(args: { cmd?: string; q?: string; opts?: string }): string {
          const cmd = args.cmd || "list";
          const commandConfig = commands[cmd];

          if (!commandConfig) {
            return `Usage: sessions-global [list|search|show|log|prompts|resume|today|stats|files|config] [query]\nOptions (search): --content --since <date> --until <date> --limit <n> --fuzzy --json\nOptions (log/prompts): --limit <n> --full`;
          }

          if (commandConfig.requiresArg && !args.q) {
            return `Error: ${cmd} requires a query argument`;
          }

          try {
            const result = commandConfig.handler(args.q, args.opts);
            return result || `No results found for ${cmd}`;
          } catch (error) {
            return handleError(
              error as Error & {
                code?: string;
                status?: number;
                stderr?: Buffer;
              },
            );
          }
        },
      },
    },
  };
};
