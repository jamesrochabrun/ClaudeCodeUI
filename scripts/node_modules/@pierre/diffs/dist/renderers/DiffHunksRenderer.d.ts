import { BaseDiffOptions, DiffLineAnnotation, DiffsHighlighter, ExpansionDirections, FileDiffMetadata, HunkData, RenderDiffOptions, ThemeTypes, ThemedDiffResult } from "../types.js";
import { WorkerPoolManager } from "../worker/WorkerPoolManager.js";
import "../worker/index.js";
import { Element, ElementContent } from "hast";

//#region src/renderers/DiffHunksRenderer.d.ts
type OptionsWithDefaults = Required<Omit<BaseDiffOptions, "lang" | "unsafeCSS">>;
interface HunksRenderResult {
  additionsAST: ElementContent[] | undefined;
  deletionsAST: ElementContent[] | undefined;
  unifiedAST: ElementContent[] | undefined;
  hunkData: HunkData[];
  css: string;
  preNode: Element;
  headerElement: Element | undefined;
  totalLines: number;
  themeStyles: string;
  baseThemeType: "light" | "dark" | undefined;
}
declare class DiffHunksRenderer<LAnnotation = undefined> {
  options: BaseDiffOptions;
  private onRenderUpdate?;
  private workerManager?;
  private highlighter;
  private diff;
  private expandedHunks;
  private deletionAnnotations;
  private additionAnnotations;
  private computedLang;
  private renderCache;
  constructor(options?: BaseDiffOptions, onRenderUpdate?: (() => unknown) | undefined, workerManager?: WorkerPoolManager | undefined);
  cleanUp(): void;
  setOptions(options: BaseDiffOptions): void;
  private mergeOptions;
  setThemeType(themeType: ThemeTypes): void;
  expandHunk(index: number, direction: ExpansionDirections): void;
  setLineAnnotations(lineAnnotations: DiffLineAnnotation<LAnnotation>[]): void;
  getOptionsWithDefaults(): OptionsWithDefaults;
  initializeHighlighter(): Promise<DiffsHighlighter>;
  hydrate(diff: FileDiffMetadata | undefined): void;
  private getRenderOptions;
  renderDiff(diff?: FileDiffMetadata | undefined): HunksRenderResult | undefined;
  asyncRender(diff: FileDiffMetadata): Promise<HunksRenderResult>;
  private createPreElement;
  private asyncHighlight;
  private renderDiffWithHighlighter;
  onHighlightSuccess(diff: FileDiffMetadata, result: ThemedDiffResult, options: RenderDiffOptions): void;
  onHighlightError(error: unknown): void;
  private processDiffResult;
  renderFullAST(result: HunksRenderResult, children?: ElementContent[]): Element;
  renderFullHTML(result: HunksRenderResult, tempChildren?: ElementContent[]): string;
  renderPartialHTML(children: ElementContent[], columnType?: "unified" | "deletions" | "additions"): string;
  private renderCollapsedHunks;
  private renderHunks;
  private pushLineWithAnnotation;
  private getAnnotations;
  private getAnnotations;
  private renderHeader;
}
//#endregion
export { DiffHunksRenderer, HunksRenderResult };
//# sourceMappingURL=DiffHunksRenderer.d.ts.map