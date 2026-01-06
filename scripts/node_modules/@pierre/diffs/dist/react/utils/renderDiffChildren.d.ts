import { FileContents, FileDiffMetadata } from "../../types.js";
import { GetHoveredLineResult } from "../../managers/MouseEventManager.js";
import { DiffBasePropsReact } from "../types.js";
import { ReactNode } from "react";

//#region src/react/utils/renderDiffChildren.d.ts
interface RenderDiffChildrenProps<LAnnotation> {
  fileDiff?: FileDiffMetadata;
  oldFile?: FileContents;
  newFile?: FileContents;
  renderHeaderMetadata: DiffBasePropsReact<LAnnotation>["renderHeaderMetadata"];
  renderAnnotation: DiffBasePropsReact<LAnnotation>["renderAnnotation"];
  renderHoverUtility: DiffBasePropsReact<LAnnotation>["renderHoverUtility"];
  lineAnnotations: DiffBasePropsReact<LAnnotation>["lineAnnotations"];
  getHoveredLine(): GetHoveredLineResult<"diff"> | undefined;
}
declare function renderDiffChildren<LAnnotation>({
  fileDiff,
  oldFile,
  newFile,
  renderHeaderMetadata,
  renderAnnotation,
  renderHoverUtility,
  lineAnnotations,
  getHoveredLine
}: RenderDiffChildrenProps<LAnnotation>): ReactNode;
//#endregion
export { renderDiffChildren };
//# sourceMappingURL=renderDiffChildren.d.ts.map