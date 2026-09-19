import { writeFileSync } from "node:fs";
import { createMcpAdapter } from "@adapterRoot@/index.ts";

export default function (pi: any) {
  const registeredTools = new Map<string, any>();
  const adapterApi = new Proxy(pi, {
    get(target, property) {
      if (property === "registerTool") {
        return (tool: any) => {
          registeredTools.set(tool.name, tool);
          return target.registerTool(tool);
        };
      }
      const value = target[property];
      return typeof value === "function" ? value.bind(target) : value;
    },
  });

  createMcpAdapter({
    config: {
      mcpServers: {
        secret: {
          command: "@node@",
          args: ["@server@"],
          env: { FAKE_SECRET: "${CONTEXT7_API_KEY}" },
          lifecycle: "lazy",
        },
      },
    },
  })(adapterApi);

  pi.registerCommand("dendritic-mcp-secret-smoke", {
    handler: async (_args: string, ctx: any) => {
      const proxy = registeredTools.get("mcp");
      if (!proxy) throw new Error("MCP proxy tool was not registered");
      const result = await proxy.execute(
        "dendritic-secret-smoke",
        { tool: "secret_read_secret" },
        undefined,
        undefined,
        ctx,
      );
      const text = result.content
        .filter((block: any) => block.type === "text")
        .map((block: any) => block.text)
        .join("\n");
      const expected = process.env.CONTEXT7_API_KEY;
      if (!expected || !text.includes(expected)) {
        throw new Error("MCP adapter did not interpolate the fake Pi-process secret into the child environment");
      }
      writeFileSync(process.env.DENDRITIC_SLOP_MCP_SECRET_MARKER!, "invoked\n");
    },
  });
}
