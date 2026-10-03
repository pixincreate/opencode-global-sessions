import { execFile } from "node:child_process";
import { existsSync } from "node:fs";
import { promisify } from "node:util";
import { fileURLToPath } from "node:url";
import type { Plugin } from "@opencode/plugin/tui";
import type { TuiPluginApi, TuiPluginModule, TuiToast } from "@opencode-ai/plugin/tui";
import type { Context } from "@opencode/plugin/tui/context";

const execFileAsync = promisify(execFile);
const DEFAULT_LIMIT = 50;

type SessionRow = {
  id: string;
  title: string | null;
  directory: string;
  updated: string;
  message_count: number;
};

// The npm package ships the sesh CLI next to dist/tui.js, so an npm install
// works without the curl installer. SESH_BIN still overrides everything.
const bundledSeshBin = () => {
  try {
    const bundled = fileURLToPath(new URL("../sesh", import.meta.url));
    return existsSync(bundled) ? bundled : undefined;
  } catch {
    return undefined;
  }
};

const getSeshBin = () =>
  process.env.SESH_BIN ||
  bundledSeshBin() ||
  `${process.env.HOME}/.local/bin/sesh`;

const parseLimit = (options: unknown): number => {
  if (!options || typeof options !== "object" || !("limit" in options)) {
    return DEFAULT_LIMIT;
  }

  const limit = Number((options as { limit?: unknown }).limit);
  return Number.isInteger(limit) && limit > 0 ? limit : DEFAULT_LIMIT;
};

export const parseSessionRows = (text: string): SessionRow[] => {
  const rows = JSON.parse(text) as unknown;
  if (!Array.isArray(rows)) return [];

  return rows.filter((row): row is SessionRow => {
    if (!row || typeof row !== "object") return false;
    const value = row as Partial<SessionRow>;
    return (
      typeof value.id === "string" &&
      (typeof value.title === "string" || value.title === null) &&
      typeof value.directory === "string" &&
      typeof value.updated === "string" &&
      typeof value.message_count === "number"
    );
  });
};

const loadSessions = async (limit: number): Promise<SessionRow[]> => {
  const { stdout } = await execFileAsync(
    getSeshBin(),
    ["list", String(limit), "--json"],
    { encoding: "utf8" },
  );

  return parseSessionRows(String(stdout));
};

const formatDirectory = (directory: string): string => {
  const parts = directory.split("/").filter(Boolean);
  return parts.at(-1) || directory || "unknown";
};

const sessionOption = (
  session: SessionRow,
): {
  title: string;
  value: SessionRow;
  description: string;
  footer: string;
  category: string;
} => ({
  title: session.title || "(untitled)",
  value: session,
  description: formatDirectory(session.directory),
  footer: `${session.updated} - ${session.message_count} messages - ${session.id}`,
  category: formatDirectory(session.directory),
});

const errorMessage = (error: unknown): string => {
  if (
    error &&
    typeof error === "object" &&
    "code" in error &&
    error.code === "ENOENT"
  ) {
    return `sesh binary not found at ${getSeshBin()}. Install it to ~/.local/bin or set SESH_BIN.`;
  }

  if (error && typeof error === "object" && "stderr" in error) {
    const stderr = (error as { stderr?: unknown }).stderr;
    const message = String(stderr || "").trim();
    if (message) return message;
  }

  return error instanceof Error ? error.message : String(error);
};

export interface PickerHost {
  pick(options: ReturnType<typeof sessionOption>[]): Promise<SessionRow | undefined>;
  navigate(sessionID: string): void;
  toast(input: TuiToast): void;
}

export const openRecentSessions = async (
  host: PickerHost,
  limit: number,
): Promise<void> => {
  try {
    const sessions = await loadSessions(limit);

    if (sessions.length === 0) {
      host.toast({
        variant: "info",
        title: "sesh",
        message: "No global sessions found.",
        duration: 3000,
      });
      return;
    }

    const selected = await host.pick(sessions.map(sessionOption));

    if (!selected) return;
    host.navigate(selected.id);
  } catch (error) {
    host.toast({
      variant: "error",
      title: "sesh",
      message: errorMessage(error),
      duration: 5000,
    });
  }
};

const v2Picker = (context: Context): PickerHost => ({
  pick(options) {
    context.ui.dialog.set({ size: "xlarge" });
    return context.ui.dialog.select<SessionRow>({ title: "Recent global sessions", placeholder: "Search sessions", options });
  },
  navigate: (sessionID) => context.ui.router.navigate({ type: "session", sessionID }),
  toast: (input) => context.ui.toast.show(input),
});

const v1Picker = (api: TuiPluginApi): PickerHost => ({
  pick: (options) => new Promise((resolve) => {
    api.ui.dialog.setSize("xlarge");
    api.ui.dialog.replace(() => api.ui.DialogSelect<SessionRow>({
      title: "Recent global sessions", placeholder: "Search sessions", options,
      onSelect(option) { resolve(option.value); api.ui.dialog.clear(); },
    }), () => resolve(undefined));
  }),
  navigate: (sessionID) => api.route.navigate("session", { sessionID }),
  toast: (input) => api.ui.toast(input),
});

export default {
  id: "opencode-global-sessions.tui",
  async tui(api, options) {
    const limit = parseLimit(options);
    api.keymap.registerLayer({ commands: [{
      name: "sesh.sessions.recent", title: "Sesh: recent sessions", category: "Sessions", namespace: "palette",
      slashName: "sessions-global", desc: "Open recent global OpenCode sessions",
      run: () => openRecentSessions(v1Picker(api), limit),
    }] });
  },
  async setup(context) {
    const limit = parseLimit(context.options);

    // The keymap layer needs a reactive owner, so claim an app slot and
    // register the command while the slot is mounted.
    const unregister = context.ui.slot({
      append: "app",
      render() {
        context.keymap.layer(() => ({
          mode: "global",
          commands: [
            {
              id: "sesh.sessions.recent",
              title: "Sesh: recent sessions",
              description: "Open recent global OpenCode sessions",
              group: "Sessions",
              palette: true,
              slash: { name: "sessions-global" },
              run: () => openRecentSessions(v2Picker(context), limit),
            },
          ],
          bindings: ["sesh.sessions.recent"],
        }));
        return null;
      },
    });

    return unregister;
  },
} satisfies TuiPluginModule & Plugin.Definition;
