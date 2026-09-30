import assert from "node:assert/strict";
import { createCodemodeExtension } from "@earendil-works/pi-coding-agent";

export default async function (pi) {
  let codemode;
  createCodemodeExtension({ models: false })({
    ...pi,
    registerTool(tool) {
      codemode = tool;
    },
  });
  assert(codemode, "Codemode extension did not register its tool");
  const result = await codemode.execute("smoke", {
    code: "return await Promise.resolve(6 * 7);",
  });
  assert(
    result.content.some((item) => item.type === "text" && item.text === "42"),
    JSON.stringify(result),
  );
  console.log("Pi codemode smoke passed");
}
