import { FileDiffMetadata } from "../types.js";

//#region src/utils/diffAcceptRejectHunk.d.ts
declare function diffAcceptRejectHunk(diff: FileDiffMetadata, hunkIndex: number, type: "accept" | "reject"): FileDiffMetadata;
//#endregion
export { diffAcceptRejectHunk };
//# sourceMappingURL=diffAcceptRejectHunk.d.ts.map