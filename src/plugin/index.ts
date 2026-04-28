import { execSync } from "child_process";

const SESH_BIN = process.env.SESH_BIN || `${process.env.HOME}/.local/bin/sesh`;

export const Sesh = async () => {
  return {
    tool: {
      "sessions-global": {
        description: "List sessions from ALL directories",
        args: {
          cmd: { type: "string", optional: true },
          q: { type: "string", optional: true },
        },
        execute(args: { cmd?: string; q?: string }) {
          const cmd = args.cmd || "list";
          const limit = args.q || "10";

          try {
            if (cmd === "list") {
              const result = execSync(`${SESH_BIN} list ${limit}`, {
                encoding: "utf-8",
              });
              return result || "No sessions found";
            }
            if (cmd === "search" && args.q) {
              const result = execSync(`${SESH_BIN} search ${args.q}`, {
                encoding: "utf-8",
              });
              return result || "No sessions found";
            }
            if (cmd === "show" && args.q) {
              const result = execSync(`${SESH_BIN} show ${args.q}`, {
                encoding: "utf-8",
              });
              return result || "Session not found";
            }
            if (cmd === "today") {
              const result = execSync(`${SESH_BIN} today`, {
                encoding: "utf-8",
              });
              return result || "No sessions found for today";
            }
            return "Usage: sessions-global [list|search|show|today] [query]";
          } catch (error: any) {
            if (error.code === "ENOENT") {
              return `Error: sesh binary not found at ${SESH_BIN}. Install it to ~/.local/bin or set SESH_BIN environment variable.`;
            }
            if (error.status === 1) {
              return (
                error.stderr?.toString() ||
                `Error executing command: ${error.message}`
              );
            }
            return `Error: ${error.message}`;
          }
        },
      },
    },
  };
};
