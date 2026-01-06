import { ResolvedThemes } from "./constants.js";

//#region src/highlighter/themes/getResolvedThemes.ts
function getResolvedThemes(themeNames) {
	const resolvedThemes = [];
	for (const themeName of themeNames) {
		const theme = ResolvedThemes.get(themeName);
		if (theme == null) throw new Error(`getAllResolvedThemes: ${themeName} is unresolved, you must resolve all necessary themes before calling this function`);
		resolvedThemes.push(theme);
	}
	return resolvedThemes;
}

//#endregion
export { getResolvedThemes };
//# sourceMappingURL=getResolvedThemes.js.map