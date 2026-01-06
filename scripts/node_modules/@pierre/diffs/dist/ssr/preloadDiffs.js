import { DiffHunksRenderer } from "../renderers/DiffHunksRenderer.js";
import { parseDiffFromFile } from "../utils/parseDiffFromFile.js";
import { createStyleElement } from "../utils/createStyleElement.js";
import { getSingularPatch } from "../utils/getSingularPatch.js";
import { renderHTML } from "./renderHTML.js";

//#region src/ssr/preloadDiffs.ts
async function preloadDiffHTML({ fileDiff, oldFile, newFile, options, annotations }) {
	if (fileDiff == null && oldFile != null && newFile != null) fileDiff = parseDiffFromFile(oldFile, newFile);
	if (fileDiff == null) throw new Error("preloadFileDiff: You must pass at least a fileDiff prop or oldFile/newFile props");
	const diffHunksRenderer = new DiffHunksRenderer({
		...options,
		hunkSeparators: typeof options?.hunkSeparators === "function" ? "custom" : options?.hunkSeparators
	});
	if (annotations !== void 0 && annotations.length > 0) diffHunksRenderer.setLineAnnotations(annotations);
	const hunkResult = await diffHunksRenderer.asyncRender(fileDiff);
	const children = [createStyleElement(hunkResult.css, true)];
	if (options?.unsafeCSS != null) children.push(createStyleElement(options.unsafeCSS));
	if (hunkResult.headerElement != null) children.push(hunkResult.headerElement);
	const code = diffHunksRenderer.renderFullAST(hunkResult);
	code.properties["data-dehydrated"] = "";
	children.push(code);
	return renderHTML(children);
}
async function preloadMultiFileDiff({ oldFile, newFile, options, annotations }) {
	return {
		newFile,
		oldFile,
		options,
		annotations,
		prerenderedHTML: await preloadDiffHTML({
			oldFile,
			newFile,
			options,
			annotations
		})
	};
}
async function preloadFileDiff({ fileDiff, options, annotations }) {
	return {
		fileDiff,
		options,
		annotations,
		prerenderedHTML: await preloadDiffHTML({
			fileDiff,
			options,
			annotations
		})
	};
}
async function preloadPatchDiff({ patch, options, annotations }) {
	return {
		patch,
		options,
		annotations,
		prerenderedHTML: await preloadDiffHTML({
			fileDiff: getSingularPatch(patch),
			options,
			annotations
		})
	};
}

//#endregion
export { preloadDiffHTML, preloadFileDiff, preloadMultiFileDiff, preloadPatchDiff };
//# sourceMappingURL=preloadDiffs.js.map