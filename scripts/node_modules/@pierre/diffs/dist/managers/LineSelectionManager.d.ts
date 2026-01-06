import { AnnotationSide } from "../types.js";

//#region src/managers/LineSelectionManager.d.ts
type SelectionSide = AnnotationSide;
interface SelectedLineRange {
  start: number;
  side?: SelectionSide;
  end: number;
  endSide?: SelectionSide;
}
interface LineSelectionOptions {
  enableLineSelection?: boolean;
  onLineSelected?: (range: SelectedLineRange | null) => void;
  onLineSelectionStart?: (range: SelectedLineRange | null) => void;
  onLineSelectionEnd?: (range: SelectedLineRange | null) => void;
}
/**
* Manages line selection state and interactions for code/diff viewers.
* Handles:
* - Click and drag selection
* - Shift-click to extend selection
* - DOM attribute updates (data-selected-line)
*/
declare class LineSelectionManager {
  private options;
  private pre;
  private selectedRange;
  private renderedSelectionRange;
  private anchor;
  private _queuedRender;
  constructor(options?: LineSelectionOptions);
  setOptions(options: LineSelectionOptions): void;
  cleanUp(): void;
  setup(pre: HTMLPreElement): void;
  setDirty(): void;
  isDirty(): boolean;
  setSelection(range: SelectedLineRange | null): void;
  getSelection(): SelectedLineRange | null;
  private attachEventListeners;
  private removeEventListeners;
  private handleMouseDown;
  private handleMouseMove;
  private handleMouseUp;
  private updateSelection;
  private updateSelection;
  private renderSelection;
  private deriveRowRangeFromDOM;
  private findRowIndexForLineNumber;
  private notifySelectionChange;
  private notifySelectionStart;
  private notifySelectionEnd;
  private getMouseEventDataForPath;
  private getLineNumber;
  private getLineIndex;
  private getLineSideFromElement;
}
declare function pluckLineSelectionOptions({
  enableLineSelection,
  onLineSelected,
  onLineSelectionStart,
  onLineSelectionEnd
}: LineSelectionOptions): LineSelectionOptions;
//#endregion
export { LineSelectionManager, LineSelectionOptions, SelectedLineRange, SelectionSide, pluckLineSelectionOptions };
//# sourceMappingURL=LineSelectionManager.d.ts.map