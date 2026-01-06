import { SPLIT_WITH_NEWLINES } from "../constants.js";
import { parsePatchFiles } from "./parsePatchFiles.js";
import { createTwoFilesPatch } from "diff";

//#region src/utils/parseDiffFromFile.ts
/**
* Parses a diff from two file contents objects.
*
* If both `oldFile` and `newFile` have a `cacheKey`, the resulting diff will
* automatically get a combined cache key in the format `oldKey:newKey`.
*/
function parseDiffFromFile(oldFile, newFile, options) {
	const fileData = parsePatchFiles(createTwoFilesPatch(oldFile.name, newFile.name, oldFile.contents, newFile.contents, oldFile.header, newFile.header, options))[0]?.files[0];
	if (fileData == null) throw new Error("parseDiffFrom: FileInvalid diff -- probably need to fix something -- if the files are the same maybe?");
	fileData.oldLines = oldFile.contents.split(SPLIT_WITH_NEWLINES);
	fileData.newLines = newFile.contents.split(SPLIT_WITH_NEWLINES);
	if (oldFile.cacheKey != null && newFile.cacheKey != null) fileData.cacheKey = `${oldFile.cacheKey}:${newFile.cacheKey}`;
	return fileData;
}

//#endregion
export { parseDiffFromFile };
//# sourceMappingURL=parseDiffFromFile.js.map