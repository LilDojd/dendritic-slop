import assert from "node:assert/strict";
import { writeFileSync } from "node:fs";

export default function (pi: any) {
  pi.registerCommand("dendritic-firstmate-smoke", {
    handler: async (_args: string, ctx: any) => {
      const tools = new Set(pi.getAllTools().map((tool: any) => tool.name));
      for (const name of ["fm_watch_arm_pi", "fm_branch_outcomes", "fm_branch_processed"]) {
        assert(tools.has(name), `missing Firstmate tool: ${name}`);
      }
      const commands = new Set(pi.getCommands().map((command: any) => command.name));
      for (const name of ["calm", "supervision-model", "fm-watch-arm-pi"]) {
        assert(commands.has(name), `missing Firstmate command: ${name}`);
      }
      writeFileSync(process.env.FIRSTMATE_SMOKE_MARKER!, "loaded\n");
      ctx.shutdown();
    },
  });
}
