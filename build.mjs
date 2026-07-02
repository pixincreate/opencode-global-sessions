import * as esbuild from "esbuild";
import { rm } from "node:fs/promises";

await rm("./dist", { force: true, recursive: true });

await esbuild.build({
  bundle: true,
  format: "esm",
  platform: "node",
  sourcemap: true,
  entryPoints: ["./src/plugin/tui.ts"],
  outfile: "./dist/tui.js",
});

console.log("Built!");
