import { AnnotationSide, DiffLineEventBaseProps, ExpansionDirections, LineEventBaseProps } from "../types.js";

//#region src/managers/MouseEventManager.d.ts
type LogTypes = "click" | "move" | "both" | "none";
type MouseEventManagerMode = "file" | "diff";
interface OnLineClickProps extends LineEventBaseProps {
  event: PointerEvent;
}
interface OnLineEnterLeaveProps extends LineEventBaseProps {
  event: PointerEvent;
}
interface OnDiffLineClickProps extends DiffLineEventBaseProps {
  event: PointerEvent;
}
interface OnDiffLineEnterLeaveProps extends DiffLineEventBaseProps {
  event: PointerEvent;
}
type EventClickProps<TMode extends MouseEventManagerMode> = TMode extends "file" ? OnLineClickProps : OnDiffLineClickProps;
type MouseEventEnterLeaveProps<TMode extends MouseEventManagerMode> = TMode extends "file" ? OnLineEnterLeaveProps : OnDiffLineEnterLeaveProps;
type GetHoveredLineResult<TMode extends MouseEventManagerMode> = TMode extends "file" ? {
  lineNumber: number;
} : {
  lineNumber: number;
  side: AnnotationSide;
};
interface MouseEventManagerBaseOptions<TMode extends MouseEventManagerMode> {
  enableHoverUtility?: boolean;
  onLineClick?(props: EventClickProps<TMode>): unknown;
  onLineNumberClick?(props: EventClickProps<TMode>): unknown;
  onLineEnter?(props: MouseEventEnterLeaveProps<TMode>): unknown;
  onLineLeave?(props: MouseEventEnterLeaveProps<TMode>): unknown;
  __debugMouseEvents?: LogTypes;
}
interface MouseEventManagerOptions<TMode extends MouseEventManagerMode> extends MouseEventManagerBaseOptions<TMode> {
  onHunkExpand?(hunkIndex: number, direction: ExpansionDirections): unknown;
}
declare class MouseEventManager<TMode extends MouseEventManagerMode> {
  private mode;
  private options;
  private hoveredLine;
  private pre;
  private hoverSlot;
  constructor(mode: TMode, options: MouseEventManagerOptions<TMode>);
  setOptions(options: MouseEventManagerOptions<TMode>): void;
  cleanUp(): void;
  setup(pre: HTMLPreElement): void;
  getHoveredLine: () => GetHoveredLineResult<TMode> | undefined;
  handleMouseClick: (event: PointerEvent) => void;
  handleMouseMove: (event: PointerEvent) => void;
  handleMouseLeave: (event: PointerEvent) => void;
  private handleMouseEvent;
  private getLineData;
}
declare function pluckMouseEventOptions<TMode extends MouseEventManagerMode>({
  onLineClick,
  onLineNumberClick,
  onLineEnter,
  onLineLeave,
  enableHoverUtility,
  __debugMouseEvents
}: MouseEventManagerBaseOptions<TMode>, onHunkExpand?: (hunkIndex: number, direction: ExpansionDirections) => unknown): MouseEventManagerOptions<TMode>;
//#endregion
export { GetHoveredLineResult, LogTypes, MouseEventManager, MouseEventManagerBaseOptions, MouseEventManagerMode, MouseEventManagerOptions, OnDiffLineClickProps, OnDiffLineEnterLeaveProps, OnLineClickProps, OnLineEnterLeaveProps, pluckMouseEventOptions };
//# sourceMappingURL=MouseEventManager.d.ts.map