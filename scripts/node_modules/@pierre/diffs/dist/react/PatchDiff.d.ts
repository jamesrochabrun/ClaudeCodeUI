import { DiffBasePropsReact } from "./types.js";

//#region src/react/PatchDiff.d.ts
interface PatchDiffProps<LAnnotation> extends DiffBasePropsReact<LAnnotation> {
  patch: string;
}
declare function PatchDiff<LAnnotation = undefined>({
  patch,
  options,
  lineAnnotations,
  selectedLines,
  className,
  style,
  prerenderedHTML,
  renderAnnotation,
  renderHeaderMetadata,
  renderHoverUtility
}: PatchDiffProps<LAnnotation>): React.JSX.Element;
//#endregion
export { PatchDiff, PatchDiffProps };
//# sourceMappingURL=PatchDiff.d.ts.map