import { PrePropertiesConfig } from "../types.js";

//#region src/utils/setWrapperNodeProps.d.ts
interface SetPreNodePropertiesProps extends PrePropertiesConfig {
  pre: HTMLPreElement;
}
declare function setPreNodeProperties({
  diffIndicators,
  disableBackground,
  disableLineNumbers,
  overflow,
  pre,
  split,
  themeStyles,
  themeType,
  totalLines
}: SetPreNodePropertiesProps): HTMLPreElement;
//#endregion
export { SetPreNodePropertiesProps, setPreNodeProperties };
//# sourceMappingURL=setWrapperNodeProps.d.ts.map