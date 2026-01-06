import { BaseCodeOptions, DiffsHighlighter, FileContents, LineAnnotation, RenderFileOptions, ThemeTypes, ThemedFileResult } from "../types.js";
import { WorkerPoolManager } from "../worker/WorkerPoolManager.js";
import "../worker/index.js";
import { Element, ElementContent } from "hast";

//#region src/renderers/FileRenderer.d.ts
interface FileRenderResult {
  codeAST: ElementContent[];
  preAST: Element;
  headerAST: Element | undefined;
  css: string;
  totalLines: number;
  themeStyles: string;
  baseThemeType: "light" | "dark" | undefined;
}
interface FileRendererOptions extends BaseCodeOptions {}
declare class FileRenderer<LAnnotation = undefined> {
  options: FileRendererOptions;
  private onRenderUpdate?;
  private workerManager?;
  private highlighter;
  private renderCache;
  private computedLang;
  private lineAnnotations;
  constructor(options?: FileRendererOptions, onRenderUpdate?: (() => unknown) | undefined, workerManager?: WorkerPoolManager | undefined);
  setOptions(options: FileRendererOptions): void;
  private mergeOptions;
  setThemeType(themeType: ThemeTypes): void;
  setLineAnnotations(lineAnnotations: LineAnnotation<LAnnotation>[]): void;
  cleanUp(): void;
  hydrate(file: FileContents): void;
  private getRenderOptions;
  renderFile(file?: FileContents | undefined): FileRenderResult | undefined;
  asyncRender(file: FileContents): Promise<FileRenderResult>;
  private asyncHighlight;
  private renderFileWithHighlighter;
  private processFileResult;
  private renderHeader;
  renderFullHTML(result: FileRenderResult): string;
  renderFullAST(result: FileRenderResult, children?: ElementContent[]): Element;
  renderPartialHTML(children: ElementContent[], includeCodeNode?: boolean): string;
  initializeHighlighter(): Promise<DiffsHighlighter>;
  onHighlightSuccess(file: FileContents, result: ThemedFileResult, options: RenderFileOptions): void;
  onHighlightError(error: unknown): void;
  private createPreElement;
}
//#endregion
export { FileRenderResult, FileRenderer, FileRendererOptions };
//# sourceMappingURL=FileRenderer.d.ts.map