import type { Plugin } from "@opencode-ai/plugin"

export const Sesh: Plugin = async ({ client }) => {
  return {
    tool: {
      sesh: {
        description: "Search OpenCode sessions across ALL directories",
        args: {
          cmd: client.schema.enum(["list", "search", "show", "today", "range"]).optional("list"),
          q: client.schema.string().optional(""),
        },
        async execute(args, context) {
          const db = `${process.env.HOME}/.local/share/opencode/opencode.db`
          const limit = args.q || "10"

          if (args.cmd === "list") {
            return await context.$(`sqlite3 "${db}" "SELECT id, directory, title, datetime(time_created, 'unixepoch') as created FROM session ORDER BY time_created DESC LIMIT ${limit};"`)
          }

          if (args.cmd === "search" && args.q) {
            return await context.$(`sqlite3 "${db}" "SELECT id, directory, title, datetime(time_created, 'unixepoch') as created FROM session WHERE title LIKE '%${args.q}%' OR directory LIKE '%${args.q}%' ORDER BY time_created DESC LIMIT 20;"`)
          }

          if (args.cmd === "show" && args.q) {
            return await context.$(`sqlite3 "${db}" "SELECT id, directory, title, datetime(time_created, 'unixepoch') as created, datetime(time_updated, 'unixepoch') as updated FROM session WHERE id = '${args.q}';"`)
          }

          if (args.cmd === "today") {
            return await context.$(`sqlite3 "${db}" "SELECT id, directory, title, datetime(time_created, 'unixepoch') as created FROM session WHERE time_created > strftime('%s', 'now') - 86400 ORDER BY time_created DESC LIMIT 20;"`)
          }

          if (args.cmd === "range" && args.q) {
            return await context.$(`sqlite3 "${db}" "SELECT id, directory, title, datetime(time_created, 'unixepoch') as created FROM session WHERE time_created > strftime('%s', 'now') - (${args.q} * 86400) ORDER BY time_created DESC LIMIT 20;"`)
          }

          return `Usage: sesh <list|search|show|today|range> [query]

Examples:
  sesh list 20
  sesh search keywatch
  sesh show ses_24505ac96ffemL7ijB336Ccrt0
  sesh today
  sesh range 7`
        },
      },
    },
  }
}