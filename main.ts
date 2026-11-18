// Steal a Snack v2 — one-command build + test.
// Usage: bun main.ts        (or: node --experimental-strip-types main.ts)
// Runs the headless Luau tests, then builds game.rbxl with Rojo and
// prints its size + sha256. Exits non-zero if either step fails.
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { statSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const ROOT = import.meta.dir;
const ROJO = join(homedir(), "workspace/tools/rojo/rojo");

function run(label: string, cmd: string, args: string[]): void {
  console.log(`\n== ${label} ==`);
  const r = spawnSync(cmd, args, { cwd: ROOT, stdio: "inherit" });
  if (r.status !== 0) {
    console.error(`${label} FAILED (exit ${r.status})`);
    process.exit(r.status ?? 1);
  }
}

run("tests", "sh", ["tests/run.sh"]);
run("rojo build", ROJO, ["build", "default.project.json", "-o", "game.rbxl"]);

const buf = readFileSync(join(ROOT, "game.rbxl"));
const sha = createHash("sha256").update(buf).digest("hex");
console.log(`\ngame.rbxl: ${statSync(join(ROOT, "game.rbxl")).size} bytes`);
console.log(`sha256: ${sha}`);
console.log("OK — build + tests passed.");
