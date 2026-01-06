import { RegisteredCustomThemes } from "./constants.js";

//#region src/highlighter/themes/registerCustomTheme.ts
function registerCustomTheme(themeName, loader) {
	if (RegisteredCustomThemes.has(themeName)) {
		console.error("SharedHighlight.registerCustomTheme: theme name already registered", themeName);
		return;
	}
	RegisteredCustomThemes.set(themeName, loader);
}

//#endregion
export { registerCustomTheme };
//# sourceMappingURL=registerCustomTheme.js.map