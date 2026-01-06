import { FileDiffMetadata } from "../types.js";
import { DiffBasePropsReact } from "./types.js";

//#region src/react/FileDiff.d.ts
interface FileDiffProps<LAnnotation> extends DiffBasePropsReact<LAnnotation> {
  fileDiff: FileDiffMetadata;
}
declare function FileDiff<LAnnotation = undefined>({
  fileDiff,
  options,
  lineAnnotations,
  selectedLines,
  className,
  style,
  prerenderedHTML,
  renderAnnotation,
  renderHeaderMetadata,
  renderHoverUtility
}: FileDiffProps<LAnnotation>): React.JSX.Element;
//#endregion
export { FileDiff, type FileDiffMetadata, FileDiffProps };
//# sourceMappingURL=FileDiff.d.ts.map