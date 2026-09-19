import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { createServer } from "node:http";
import { promisify } from "node:util";

const run = promisify(execFile);
const browser = process.argv[2];
const server = createServer((_request, response) => {
  response.end("<!doctype html><title>Firstmate smoke</title><p>Firstmate browser works</p>");
});
await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
try {
  const url = `http://127.0.0.1:${server.address().port}`;
  await run(browser, ["open", url], { timeout: 60000 });
  const { stdout } = await run(browser, ["snapshot"], { timeout: 30000 });
  assert.match(stdout, /Firstmate browser works/);
} finally {
  try {
    await run(browser, ["stop"], { timeout: 10000 });
  } finally {
    server.close();
  }
}
