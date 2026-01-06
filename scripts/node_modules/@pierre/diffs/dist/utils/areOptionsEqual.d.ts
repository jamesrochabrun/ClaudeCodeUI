import { FileOptions } from "../components/File.js";
import { FileDiffOptions } from "../components/FileDiff.js";
import "../react/index.js";

//#region src/utils/areOptionsEqual.d.ts
declare function areOptionsEqual<LAnnotation>(optionsA: FileOptions<LAnnotation> | FileDiffOptions<LAnnotation> | undefined, optionsB: FileOptions<LAnnotation> | FileDiffOptions<LAnnotation> | undefined): boolean;
//#endregion
export { areOptionsEqual };
//# sourceMappingURL=areOptionsEqual.d.ts.map