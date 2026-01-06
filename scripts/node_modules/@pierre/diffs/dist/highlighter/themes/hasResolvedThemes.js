import { ResolvedThemes } from "./constants.js";

//#region src/highlighter/themes/hasResolvedThemes.ts
function hasResolvedThemes(themeNames) {
	for (const themeName of themeNames) if (!ResolvedThemes.has(themeName)) return false;
	return true;
}

//#endregion
export { hasResolvedThemes };
//# sourceMappingURL=hasResolvedThemes.js.map