import { spawn } from "node:child_process";

export default {
  id: "rtk",
  async setup(ctx) {
    await ctx.tool.hook("execute.before", async (event) => {
      const tool = String(event.tool ?? "").toLowerCase();
      if (tool !== "bash" && tool !== "shell") return;

      const input = event.input as Record<string, unknown> | undefined;
      const command = input?.command;
      if (typeof command !== "string" || !command.trim()) return;

      const rewritten = await new Promise<string>((resolve) => {
        const proc = spawn("rtk", ["rewrite", command], {
          shell: false,
          stdio: ["ignore", "pipe", "ignore"],
        });

        let stdout = "";
        proc.stdout?.on("data", (chunk) => {
          stdout += chunk;
        });

        proc.on("close", () => resolve(stdout.trim()));
        proc.on("error", () => resolve(""));
      });

      if (rewritten && rewritten !== command) {
        event.input = { ...event.input, command: rewritten };
      }
    });
  },
};
