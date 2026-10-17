import { registerWebTools } from "@webSource@/extension.ts";

export default function (pi) {
  registerWebTools(pi, {
    searchEndpoint: "https://ukko.tail2fc4c2.ts.net/api/search",
    python: "@python@",
    extractScript: "@webSource@/extract.py",
  });
}
