import { FileContents } from "../../types.js";
import { GetHoveredLineResult } from "../../managers/MouseEventManager.js";
import { FileProps } from "../types.js";
import { ReactNode } from "react";

//#region src/react/utils/renderFileChildren.d.ts
interface RenderFileChildrenProps<LAnnotation> {
  file: FileContents;
  renderHeaderMetadata: FileProps<LAnnotation>["renderHeaderMetadata"];
  renderAnnotation: FileProps<LAnnotation>["renderAnnotation"];
  lineAnnotations: FileProps<LAnnotation>["lineAnnotations"];
  renderHoverUtility: FileProps<LAnnotation>["renderHoverUtility"];
  getHoveredLine(): GetHoveredLineResult<"file"> | undefined;
}
declare function renderFileChildren<LAnnotation>({
  file,
  renderHeaderMetadata,
  renderAnnotation,
  lineAnnotations,
  renderHoverUtility,
  getHoveredLine
}: RenderFileChildrenProps<LAnnotation>): ReactNode;
//#endregion
export { renderFileChildren };
//# sourceMappingURL=renderFileChildren.d.ts.map