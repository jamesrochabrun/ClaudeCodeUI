import { AttachedThemes, ResolvedThemes } from "./constants.js";

//#region src/highlighter/themes/attachResolvedThemes.ts
function attachResolvedThemes(themes, highlighter) {
	themes = Array.isArray(themes) ? themes : [themes];
	for (let themeRef of themes) {
		let resolvedTheme;
		if (typeof themeRef === "string") {
			resolvedTheme = ResolvedThemes.get(themeRef);
			if (resolvedTheme == null) throw new Error(`loadResolvedThemes: ${themeRef} is not resolved, you must resolve it before calling loadResolvedThemes`);
		} else {
			resolvedTheme = themeRef;
			themeRef = themeRef.name;
			if (!ResolvedThemes.has(themeRef)) ResolvedThemes.set(themeRef, resolvedTheme);
		}
		if (AttachedThemes.has(themeRef)) continue;
		AttachedThemes.add(themeRef);
		highlighter.loadThemeSync(resolvedTheme);
	}
}

//#endregion
export { attachResolvedThemes };
//# sourceMappingURL=attachResolvedThemes.js.map