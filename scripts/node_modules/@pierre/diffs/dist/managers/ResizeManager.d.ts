//#region src/managers/ResizeManager.d.ts
declare class ResizeManager {
  private observedNodes;
  cleanUp(): void;
  private resizeObserver;
  setup(pre: HTMLPreElement): void;
  private handleResizeObserver;
}
//#endregion
export { ResizeManager };
//# sourceMappingURL=ResizeManager.d.ts.map