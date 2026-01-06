import { FileContents } from "../types.js";
import { DiffBasePropsReact } from "./types.js";

//#region src/react/MultiFileDiff.d.ts
interface MultiFileDiffProps<LAnnotation> extends DiffBasePropsReact<LAnnotation> {
  oldFile: FileContents;
  newFile: FileContents;
}
declare function MultiFileDiff<LAnnotation = undefined>({
  oldFile,
  newFile,
  options,
  lineAnnotations,
  selectedLines,
  className,
  style,
  prerenderedHTML,
  renderAnnotation,
  renderHeaderMetadata,
  renderHoverUtility
}: MultiFileDiffProps<LAnnotation>): React.JSX.Element;
//#endregion
export { type FileContents, MultiFileDiff, MultiFileDiffProps };
//# sourceMappingURL=MultiFileDiff.d.ts.map