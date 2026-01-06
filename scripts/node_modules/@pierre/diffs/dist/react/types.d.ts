import { DiffLineAnnotation, FileContents, LineAnnotation, RenderHeaderMetadataProps } from "../types.js";
import { SelectedLineRange } from "../managers/LineSelectionManager.js";
import { GetHoveredLineResult } from "../managers/MouseEventManager.js";
import { FileOptions } from "../components/File.js";
import { FileDiffOptions } from "../components/FileDiff.js";
import { CSSProperties, ReactNode } from "react";

//#region src/react/types.d.ts
interface DiffBasePropsReact<LAnnotation> {
  options?: FileDiffOptions<LAnnotation>;
  lineAnnotations?: DiffLineAnnotation<LAnnotation>[];
  selectedLines?: SelectedLineRange | null;
  renderAnnotation?(annotations: DiffLineAnnotation<LAnnotation>): ReactNode;
  renderHeaderMetadata?(props: RenderHeaderMetadataProps): ReactNode;
  renderHoverUtility?(getHoveredLine: () => GetHoveredLineResult<"diff"> | undefined): ReactNode;
  className?: string;
  style?: CSSProperties;
  prerenderedHTML?: string;
}
interface FileProps<LAnnotation> {
  file: FileContents;
  options?: FileOptions<LAnnotation>;
  lineAnnotations?: LineAnnotation<LAnnotation>[];
  selectedLines?: SelectedLineRange | null;
  renderAnnotation?(annotations: LineAnnotation<LAnnotation>): ReactNode;
  renderHeaderMetadata?(file: FileContents): ReactNode;
  renderHoverUtility?(getHoveredLine: () => GetHoveredLineResult<"file"> | undefined): ReactNode;
  className?: string;
  style?: CSSProperties;
  prerenderedHTML?: string;
}
//#endregion
export { DiffBasePropsReact, FileProps };
//# sourceMappingURL=types.d.ts.map