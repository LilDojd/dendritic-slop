import assert from "node:assert/strict";

export default function (pi) {
  pi.on("session_start", (_event, ctx) => {
    assert(pi.getAllTools().some((tool) => tool.name === "jev_ask"));
    console.log("Pi Jev smoke passed");
    ctx.shutdown();
  });
}
