import { resolveTheme } from "./resolveTheme.js";
import { getResolvedOrResolveTheme } from "./getResolvedOrResolveTheme.js";

//#region src/highlighter/themes/resolveThemes.ts
async function resolveThemes(themes) {
	const resolvedThemes = [];
	const themesToResolve = [];
	for (const themeName of themes) {
		const themeData = getResolvedOrResolveTheme(themeName) ?? resolveTheme(themeName);
		if ("then" in themeData) themesToResolve.push(themeData);
		else resolvedThemes.push(themeData);
	}
	if (themesToResolve.length > 0) await Promise.all(themesToResolve).then((resolved) => {
		for (const theme of resolved) if (theme != null) resolvedThemes.push(theme);
	});
	return resolvedThemes;
}

//#endregion
export { resolveThemes };
//# sourceMappingURL=resolveThemes.js.map