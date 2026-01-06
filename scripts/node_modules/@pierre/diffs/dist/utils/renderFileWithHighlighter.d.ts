import { DiffsHighlighter, FileContents, RenderFileOptions, ThemedFileResult } from "../types.js";

//#region src/utils/renderFileWithHighlighter.d.ts
declare function renderFileWithHighlighter(file: FileContents, highlighter: DiffsHighlighter, {
  theme,
  tokenizeMaxLineLength
}: RenderFileOptions, forcePlainText?: boolean): ThemedFileResult;
//#endregion
export { renderFileWithHighlighter };
//# sourceMappingURL=renderFileWithHighlighter.d.ts.map