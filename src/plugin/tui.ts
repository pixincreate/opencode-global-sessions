import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);
const DEFAULT_LIMIT = 50;

type SessionRow = {
  id: string;
  title: string | null;
  directory: string;
  updated: string;
  message_count: number;
};

type DialogSelectOption<Value> = {
  title: string;
  value: Value;
  description?: string;
  footer?: string;
  category?: string;
};

type TuiApi = {
  keymap: {
    registerLayer(layer: {
      commands: Array<{
        name: string;
        title: string;
        category: string;
        namespace: string;
        slashName: string;
        desc: string;
        run: () => Promise<void>;
      }>;
    }): () => void;
  };
  route: {
    navigate(name: string, params?: Record<string, unknown>): void;
  };
  ui: {
    DialogSelect<Value>(props: {
      title: string;
      placeholder: string;
      options: DialogSelectOption<Value>[];
      onSelect(option: DialogSelectOption<Value>): void;
    }): unknown;
    dialog: {
      setSize(size: "medium" | "large" | "xlarge"): void;
      replace(render: () => unknown): void;
      clear(): void;
    };
    toast(input: {
      variant: "info" | "error";
      title: string;
      message: string;
      duration: number;
    }): void;
  };
};

type TuiPlugin = (
  api: TuiApi,
  options: unknown,
  meta: unknown,
) => Promise<void>;

const getSeshBin = () =>
  process.env.SESH_BIN || `${process.env.HOME}/.local/bin/sesh`;

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
): DialogSelectOption<SessionRow> => ({
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

export const openRecentSessions = async (
  api: TuiApi,
  limit: number,
): Promise<void> => {
  try {
    const sessions = await loadSessions(limit);

    if (sessions.length === 0) {
      api.ui.toast({
        variant: "info",
        title: "sesh",
        message: "No global sessions found.",
        duration: 3000,
      });
      return;
    }

    api.ui.dialog.replace(() =>
      api.ui.DialogSelect<SessionRow>({
        title: "Recent global sessions",
        placeholder: "Search sessions",
        options: sessions.map(sessionOption),
        onSelect: (option) => {
          api.ui.dialog.clear();
          api.route.navigate("session", { sessionID: option.value.id });
        },
      }),
    );
    api.ui.dialog.setSize("xlarge");
  } catch (error) {
    api.ui.toast({
      variant: "error",
      title: "sesh",
      message: errorMessage(error),
      duration: 5000,
    });
  }
};

const tui: TuiPlugin = async (api, options) => {
  const limit = parseLimit(options);

  api.keymap.registerLayer({
    commands: [
      {
        name: "sesh.sessions.recent",
        title: "Sesh: recent sessions",
        category: "Sessions",
        namespace: "palette",
        slashName: "sessions-global",
        desc: "Open recent global OpenCode sessions",
        run: () => openRecentSessions(api, limit),
      },
    ],
  });
};

export default { id: "opencode-global-sessions.tui", tui };
