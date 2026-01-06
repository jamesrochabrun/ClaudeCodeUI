import { getThemes } from "./getThemes.js";

//#region src/utils/getHighlighterOptions.ts
function getHighlighterOptions(lang, options) {
	return {
		langs: [lang ?? "text"],
		themes: getThemes(options.theme)
	};
}

//#endregion
export { getHighlighterOptions };
//# sourceMappingURL=getHighlighterOptions.js.map