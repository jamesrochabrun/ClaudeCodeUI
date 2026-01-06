import { FileContents, LineAnnotation } from "../../types.js";
import { SelectedLineRange } from "../../managers/LineSelectionManager.js";
import { GetHoveredLineResult } from "../../managers/MouseEventManager.js";
import { FileOptions } from "../../components/File.js";

//#region src/react/utils/useFileInstance.d.ts
interface UseFileInstanceProps<LAnnotation> {
  file: FileContents;
  options: FileOptions<LAnnotation> | undefined;
  lineAnnotations: LineAnnotation<LAnnotation>[] | undefined;
  selectedLines: SelectedLineRange | null | undefined;
  prerenderedHTML: string | undefined;
}
interface UseFileInstanceReturn {
  ref(node: HTMLElement | null): void;
  getHoveredLine(): GetHoveredLineResult<"file"> | undefined;
}
declare function useFileInstance<LAnnotation>({
  file,
  options,
  lineAnnotations,
  selectedLines,
  prerenderedHTML
}: UseFileInstanceProps<LAnnotation>): UseFileInstanceReturn;
//#endregion
export { useFileInstance };
//# sourceMappingURL=useFileInstance.d.ts.map