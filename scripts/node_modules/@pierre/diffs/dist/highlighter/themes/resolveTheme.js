import { isWorkerContext } from "../../utils/isWorkerContext.js";
import { RegisteredCustomThemes, ResolvedThemes, ResolvingThemes } from "./constants.js";
import { bundledThemes, normalizeTheme } from "shiki";

//#region src/highlighter/themes/resolveTheme.ts
async function resolveTheme(themeName) {
	if (isWorkerContext()) throw new Error(`resolveTheme("${themeName}") cannot be called from a worker context. Themes must be pre-resolved on the main thread and passed to the worker via the resolvedLanguages parameter.`);
	const resolver = ResolvingThemes.get(themeName);
	if (resolver != null) return resolver;
	try {
		const loader = RegisteredCustomThemes.get(themeName) ?? bundledThemes[themeName];
		if (loader == null) throw new Error(`resolveTheme: No valid loader for ${themeName}`);
		const resolver$1 = loader().then((result) => {
			return normalizeAndCacheResolvedTheme(themeName, "default" in result ? result.default : result);
		});
		ResolvingThemes.set(themeName, resolver$1);
		const theme = await resolver$1;
		if (theme.name !== themeName) throw new Error(`resolvedTheme: themeName: ${themeName} does not match theme.name: ${theme.name}`);
		ResolvedThemes.set(theme.name, theme);
		return theme;
	} finally {
		ResolvingThemes.delete(themeName);
	}
}
function normalizeAndCacheResolvedTheme(themeName, themeData) {
	const resolvedTheme = ResolvedThemes.get(themeName);
	if (resolvedTheme != null) return resolvedTheme;
	themeData = normalizeTheme(themeData);
	ResolvedThemes.set(themeName, themeData);
	return themeData;
}

//#endregion
export { resolveTheme };
//# sourceMappingURL=resolveTheme.js.map