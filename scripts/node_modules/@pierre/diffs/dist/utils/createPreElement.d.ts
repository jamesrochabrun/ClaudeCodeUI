import { PrePropertiesConfig } from "../types.js";
import { Element, Properties } from "hast";

//#region src/utils/createPreElement.d.ts
declare function createPreElement(options: PrePropertiesConfig): Element;
declare function createPreWrapperProperties({
  diffIndicators,
  disableBackground,
  disableLineNumbers,
  overflow,
  split,
  themeType,
  themeStyles,
  totalLines
}: PrePropertiesConfig): Properties;
//#endregion
export { createPreElement, createPreWrapperProperties };
//# sourceMappingURL=createPreElement.d.ts.map