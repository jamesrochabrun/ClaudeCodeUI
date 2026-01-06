import { FileContents, FileDiffMetadata, SupportedLanguages } from "../types.js";

//#region src/utils/setLanguageOverride.d.ts
declare function setLanguageOverride<T extends FileContents | FileDiffMetadata>(fileOrDiff: T, lang: SupportedLanguages): T;
//#endregion
export { setLanguageOverride };
//# sourceMappingURL=setLanguageOverride.d.ts.map