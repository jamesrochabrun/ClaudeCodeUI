import { DiffLineAnnotation, FileContents, FileDiffMetadata } from "../../types.js";
import { SelectedLineRange } from "../../managers/LineSelectionManager.js";
import { GetHoveredLineResult } from "../../managers/MouseEventManager.js";
import { FileDiffOptions } from "../../components/FileDiff.js";

//#region src/react/utils/useFileDiffInstance.d.ts
interface UseFileDiffInstanceProps<LAnnotation> {
  oldFile?: FileContents;
  newFile?: FileContents;
  fileDiff?: FileDiffMetadata;
  options: FileDiffOptions<LAnnotation> | undefined;
  lineAnnotations: DiffLineAnnotation<LAnnotation>[] | undefined;
  selectedLines: SelectedLineRange | null | undefined;
  prerenderedHTML: string | undefined;
}
interface UseFileDiffInstanceReturn {
  ref(node: HTMLElement | null): void;
  getHoveredLine(): GetHoveredLineResult<"diff"> | undefined;
}
declare function useFileDiffInstance<LAnnotation>({
  oldFile,
  newFile,
  fileDiff,
  options,
  lineAnnotations,
  selectedLines,
  prerenderedHTML
}: UseFileDiffInstanceProps<LAnnotation>): UseFileDiffInstanceReturn;
//#endregion
export { useFileDiffInstance };
//# sourceMappingURL=useFileDiffInstance.d.ts.map