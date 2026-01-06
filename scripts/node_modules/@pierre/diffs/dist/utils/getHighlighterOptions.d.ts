import { DiffsThemeNames, SupportedLanguages, ThemesType } from "../types.js";

//#region src/utils/getHighlighterOptions.d.ts
interface HighlighterOptionsShape {
  theme?: DiffsThemeNames | ThemesType;
}
interface GetHighlighterOptionsReturn {
  langs: SupportedLanguages[];
  themes: DiffsThemeNames[];
}
declare function getHighlighterOptions(lang: SupportedLanguages | undefined, options: HighlighterOptionsShape): GetHighlighterOptionsReturn;
//#endregion
export { getHighlighterOptions };
//# sourceMappingURL=getHighlighterOptions.d.ts.map