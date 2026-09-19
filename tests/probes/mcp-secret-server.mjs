import { Server } from "@adapterRoot@/node_modules/@modelcontextprotocol/sdk/dist/esm/server/index.js";
import { StdioServerTransport } from "@adapterRoot@/node_modules/@modelcontextprotocol/sdk/dist/esm/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema } from "@adapterRoot@/node_modules/@modelcontextprotocol/sdk/dist/esm/types.js";

const server = new Server(
  { name: "dendritic-secret-fixture", version: "1.0.0" },
  { capabilities: { tools: {} } },
);
server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [{
    name: "read_secret",
    description: "Return the child-scoped fake secret.",
    inputSchema: { type: "object", properties: {} },
  }],
}));
server.setRequestHandler(CallToolRequestSchema, async () => ({
  content: [{ type: "text", text: process.env.FAKE_SECRET ?? "" }],
}));
await server.connect(new StdioServerTransport());
