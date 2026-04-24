// src/plugin/index.ts
var SESH_BIN = `${process.env.HOME}/dev/forge/scripts/sesh/sesh`;
var Sesh = async ({ client }) => {
  return {
    tool: {
      "sessions-global": {
        description: "List sessions from ALL directories",
        args: {
          cmd: client.schema.enum(["list", "search", "show", "today"]).optional("list"),
          q: client.schema.string().optional("")
        },
        async execute(args) {
          if (!args.cmd || args.cmd === "list") {
            return await Bun.spawn([SESH_BIN, args.q || "10"]).text();
          }
          if (args.cmd === "search" && args.q) {
            const result = await Bun.spawn([SESH_BIN, "search", args.q]).text();
            return result || "No sessions found";
          }
          if (args.cmd === "show" && args.q) {
            return await Bun.spawn([SESH_BIN, "show", args.q]).text();
          }
          if (args.cmd === "today") {
            return await Bun.spawn([SESH_BIN, "today"]).text();
          }
          return `Usage: sessions-global [list|search|show|today] [query]`;
        }
      }
    }
  };
};
export {
  Sesh
};
//# sourceMappingURL=index.js.map
