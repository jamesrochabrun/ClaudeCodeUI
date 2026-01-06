import { SharedRenderState, ShikiTransformer } from "../types.js";
import { ShikiTransformerStyleToClass } from "@shikijs/transformers";

//#region src/utils/createTransformerWithState.d.ts
interface CreateTransformerWithStateReturn {
  state: SharedRenderState;
  transformers: ShikiTransformer[];
  toClass: ShikiTransformerStyleToClass;
}
declare function createTransformerWithState(useCSSClasses?: boolean): CreateTransformerWithStateReturn;
//#endregion
export { createTransformerWithState };
//# sourceMappingURL=createTransformerWithState.d.ts.map