import * as esbuild from "esbuild";

await esbuild.build({
  entryPoints: ["./src/plugin/index.ts"],
  bundle: true,
  outfile: "./dist/index.js",
  format: "esm",
  platform: "node",
  sourcemap: true,
});

console.log("Built!");
