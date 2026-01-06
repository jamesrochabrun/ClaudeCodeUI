import { FileContents, FileDiffMetadata, ThemeTypes } from "../types.js";
import { Element } from "hast";

//#region src/utils/createFileHeaderElement.d.ts
interface CreateFileHeaderElementProps {
  fileOrDiff: FileDiffMetadata | FileContents;
  themeStyles: string;
  themeType: ThemeTypes;
}
declare function createFileHeaderElement({
  fileOrDiff,
  themeStyles,
  themeType
}: CreateFileHeaderElementProps): Element;
//#endregion
export { CreateFileHeaderElementProps, createFileHeaderElement };
//# sourceMappingURL=createFileHeaderElement.d.ts.map