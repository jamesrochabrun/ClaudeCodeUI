import { ResolvedThemes } from "./constants.js";
import { resolveTheme } from "./resolveTheme.js";

//#region src/highlighter/themes/getResolvedOrResolveTheme.ts
function getResolvedOrResolveTheme(themeName) {
	return ResolvedThemes.get(themeName) ?? resolveTheme(themeName);
}

//#endregion
export { getResolvedOrResolveTheme };
//# sourceMappingURL=getResolvedOrResolveTheme.js.map