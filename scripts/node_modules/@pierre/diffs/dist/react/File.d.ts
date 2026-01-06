import { FileOptions } from "../components/File.js";
import { FileProps } from "./types.js";

//#region src/react/File.d.ts
declare function File<LAnnotation = undefined>({
  file,
  lineAnnotations,
  selectedLines,
  options,
  className,
  style,
  renderAnnotation,
  renderHeaderMetadata,
  prerenderedHTML,
  renderHoverUtility
}: FileProps<LAnnotation>): React.JSX.Element;
//#endregion
export { File, type FileOptions };
//# sourceMappingURL=File.d.ts.map