import { writeFileSync } from "node:fs";

export default function (pi: any) {
  pi.registerCommand("dendritic-offline-smoke", {
    handler: async (_args: string, ctx: any) => {
      const tools = new Map(pi.getAllTools().map((tool: any) => [tool.name, tool]));
      const expected = @expectedTools@;
      for (const [name, root] of Object.entries(expected)) {
        const tool: any = tools.get(name);
        if (!tool) throw new Error(`missing tool: ${name}`);
        if (!tool.sourceInfo?.path?.startsWith(root as string)) {
          throw new Error(`wrong source for ${name}: ${tool.sourceInfo?.path}`);
        }
      }
      for (const name of ["mcp", "goal", "starship"]) {
        if (!pi.getCommands().some((command: any) => command.name === name)) {
          throw new Error(`missing command: ${name}`);
        }
      }
      writeFileSync(process.env.DENDRITIC_SLOP_SMOKE_MARKER!, "loaded\n");
      ctx.shutdown();
    },
  });
}
