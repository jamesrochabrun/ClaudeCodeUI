import { ExtensionFormatMap, SupportedLanguages } from "../types.js";

//#region src/utils/getFiletypeFromFileName.d.ts
declare const EXTENSION_TO_FILE_FORMAT: ExtensionFormatMap;
declare function getFiletypeFromFileName(fileName: string): SupportedLanguages;
declare function extendFileFormatMap(map: ExtensionFormatMap): void;
//#endregion
export { EXTENSION_TO_FILE_FORMAT, extendFileFormatMap, getFiletypeFromFileName };
//# sourceMappingURL=getFiletypeFromFileName.d.ts.map