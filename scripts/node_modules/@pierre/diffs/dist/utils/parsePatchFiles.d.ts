import { ParsedPatch } from "../types.js";

//#region src/utils/parsePatchFiles.d.ts

/**
* Parses a patch file string into an array of parsed patches.
*
* @param data - The raw patch file content (supports multi-commit patches)
* @param cacheKeyPrefix - Optional prefix for generating cache keys. When provided,
*   each file in the patch will get a cache key in the format `prefix-patchIndex-fileIndex`.
*   This enables caching of rendered diff results in the worker pool.
*/
declare function parsePatchFiles(data: string, cacheKeyPrefix?: string): ParsedPatch[];
//#endregion
export { parsePatchFiles };
//# sourceMappingURL=parsePatchFiles.d.ts.map