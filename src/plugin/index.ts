import { execSync } from "child_process"

const SESH_BIN = `${process.env.HOME}/dev/forge/scripts/sesh/sesh`

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
          const cmd = args.cmd || "list"
          const limit = args.q || "10"

          if (cmd === "list") {
            return execSync(`${SESH_BIN} list ${limit}`, { encoding: "utf-8" })
          }
          if (cmd === "search" && args.q) {
            return execSync(`${SESH_BIN} search ${args.q}`, { encoding: "utf-8" }) || "No sessions found"
          }
          if (cmd === "show" && args.q) {
            return execSync(`${SESH_BIN} show ${args.q}`, { encoding: "utf-8" })
          }
          if (cmd === "today") {
            return execSync(`${SESH_BIN} today`, { encoding: "utf-8" })
          }
          return "Usage: sessions-global [list|search|show|today] [query]"
        },
      },
    },
  }
}