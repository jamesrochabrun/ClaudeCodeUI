import { SharedRenderState } from "../types.js";
import { Element, ElementContent } from "hast";

//#region src/utils/processLine.d.ts
declare function processLine(node: Element, line: number, state: SharedRenderState): ElementContent;
//#endregion
export { processLine };
//# sourceMappingURL=processLine.d.ts.map