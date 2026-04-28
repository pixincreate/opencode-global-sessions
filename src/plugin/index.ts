import { execSync } from "child_process";

const SESH_BIN = process.env.SESH_BIN || `${process.env.HOME}/.local/bin/sesh`;

type CommandHandler = (query?: string) => string;

const executeCommand = (command: string, arg?: string): string => {
  const fullCommand = arg ? `${SESH_BIN} ${command} "${arg.replace(/"/g, '\\"')}"` : `${SESH_BIN} ${command}`;
  const result = execSync(fullCommand, { encoding: "utf-8" });
  return result.trim();
};

const handleError = (error: Error & { code?: string; status?: number; stderr?: Buffer }): string => {
  if (error.code === "ENOENT") {
    return `Error: sesh binary not found at ${SESH_BIN}. Install it to ~/.local/bin or set SESH_BIN environment variable.`;
  }
  if (error.status === 1) {
    return error.stderr?.toString().trim() || `Error executing command: ${error.message}`;
  }
  return `Error: ${error.message}`;
};

const commands: Record<string, { handler: CommandHandler; requiresArg: boolean }> = {
  list: {
    handler: (query) => {
      const limit = query || "10";
      return executeCommand(`list ${limit}`);
    },
    requiresArg: false,
  },
  search: {
    handler: (query) => executeCommand("search", query),
    requiresArg: true,
  },
  show: {
    handler: (query) => executeCommand("show", query),
    requiresArg: true,
  },
  today: {
    handler: () => executeCommand("today"),
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
        },
        execute(args: { cmd?: string; q?: string }): string {
          const cmd = args.cmd || "list";
          const commandConfig = commands[cmd];

          if (!commandConfig) {
            return "Usage: sessions-global [list|search|show|today] [query]";
          }

          if (commandConfig.requiresArg && !args.q) {
            return `Error: ${cmd} requires a query argument`;
          }

          try {
            const result = commandConfig.handler(args.q);
            return result || `No results found for ${cmd}`;
          } catch (error) {
            return handleError(error as Error & { code?: string; status?: number; stderr?: Buffer });
          }
        },
      },
    },
  };
};
