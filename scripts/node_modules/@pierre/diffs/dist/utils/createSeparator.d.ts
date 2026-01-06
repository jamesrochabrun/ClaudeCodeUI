import { HunkSeparators } from "../types.js";
import { Element } from "hast";

//#region src/utils/createSeparator.d.ts
interface CreateSeparatorProps {
  type: HunkSeparators;
  content?: string;
  expandIndex?: number;
  chunked?: boolean;
  slotName?: string;
  isFirstHunk: boolean;
  isLastHunk: boolean;
}
declare function createSeparator({
  type,
  content,
  expandIndex,
  chunked,
  slotName,
  isFirstHunk,
  isLastHunk
}: CreateSeparatorProps): Element;
//#endregion
export { createSeparator };
//# sourceMappingURL=createSeparator.d.ts.map