import assert from "node:assert/strict";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { createServer } from "node:http";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import type { ExtensionAPI, ToolDefinition } from "@earendil-works/pi-coding-agent";
import playwright from "@browserRoot@/dist/index.js";

export default function (pi: ExtensionAPI) {
  const tools = new Map<string, ToolDefinition>();
  playwright(new Proxy(pi, {
    get(target, property) {
      if (property === "registerTool") return (tool: ToolDefinition) => {
        tools.set(tool.name, tool);
        target.registerTool(tool);
      };
      const value = Reflect.get(target, property);
      return typeof value === "function" ? value.bind(target) : value;
    },
  }));

  pi.registerCommand("dendritic-browser-smoke", {
    handler: async (_args, ctx) => {
      const call = (name: string, params = {}) => {
        const tool = tools.get(name);
        assert.ok(tool, `missing browser tool: ${name}`);
        return tool.execute("browser-smoke", params, undefined, undefined, ctx);
      };
      const evaluate = async (source: string, selector?: string) => {
        const result = await call("browser_evaluate", { function: source, selector });
        const block = result.content[0];
        assert.equal(block.type, "text");
        return block.text;
      };
      const server = createServer((_request, response) => {
        response.setHeader("Content-Type", "text/html");
        response.end('<title>Browser fixture</title><input id="value"><button onclick="document.title=\'Clicked\'">Submit</button>');
      });
      try {
        await new Promise<void>((resolve, reject) => {
          server.once("error", reject);
          server.listen(0, "127.0.0.1", resolve);
        });
        for (const url of ["file:///etc/passwd", "data:text/html,unsafe", "javascript:alert(1)"]) {
          await assert.rejects(call("browser_navigate", { url }));
        }
        await assert.rejects(call("browser_snapshot"));
        const address = server.address();
        assert.ok(address && typeof address !== "string");
        // Even a caller bypassing schema validation cannot choose a host executable.
        await call("browser_navigate", {
          url: `http://127.0.0.1:${address.port}`,
          executablePath: "/not-a-browser",
          headless: true,
        });
        assert.equal(await evaluate("() => document.title"), '"Browser fixture"');
        await call("browser_type", { selector: "#value", text: "compatible" });
        assert.equal(await evaluate("element => element.value", "#value"), '"compatible"');
        await call("browser_click", { text: "Submit" });
        assert.equal(await evaluate("() => document.title"), '"Clicked"');
        assert.equal(await evaluate("() => typeof process"), '"undefined"');
        assert.equal(await evaluate("() => undefined"), "undefined");
        await assert.rejects(evaluate("42"));
        await assert.rejects(evaluate("42", "#value"));
        const snapshot = await call("browser_snapshot");
        assert.ok(JSON.stringify(snapshot).includes("Clicked"));
        for (const filename of ["../escape.png", join(tmpdir(), "absolute.png")]) {
          const screenshot = await call("browser_screenshot", { filename });
          const path = (screenshot.details as { path: string }).path;
          assert.equal(dirname(path), join(tmpdir(), "pi-playwright-screenshots"));
          assert.ok(readFileSync(path).length > 0);
        }
        assert.ok(!existsSync(join(tmpdir(), "escape.png")));
        assert.ok(!existsSync(join(tmpdir(), "absolute.png")));
        await call("browser_close");
        await assert.rejects(call("browser_snapshot"));
        writeFileSync(process.env.DENDRITIC_BROWSER_MARKER!, "passed\n");
      } finally {
        await call("browser_close");
        await new Promise<void>((resolve, reject) => server.close(error => error ? reject(error) : resolve()));
        writeFileSync(process.env.DENDRITIC_BROWSER_DONE!, "done\n");
        ctx.shutdown();
      }
    },
  });
}
