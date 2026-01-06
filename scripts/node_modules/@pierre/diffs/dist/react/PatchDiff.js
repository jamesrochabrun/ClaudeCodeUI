'use client';


import { DIFFS_TAG_NAME } from "../constants.js";
import { getSingularPatch } from "../utils/getSingularPatch.js";
import { templateRender } from "./utils/templateRender.js";
import { renderDiffChildren } from "./utils/renderDiffChildren.js";
import { useFileDiffInstance } from "./utils/useFileDiffInstance.js";
import { jsx } from "react/jsx-runtime";
import { useMemo } from "react";

//#region src/react/PatchDiff.tsx
function PatchDiff({ patch, options, lineAnnotations, selectedLines, className, style, prerenderedHTML, renderAnnotation, renderHeaderMetadata, renderHoverUtility }) {
	const fileDiff = usePatch(patch);
	const { ref, getHoveredLine } = useFileDiffInstance({
		fileDiff,
		options,
		lineAnnotations,
		selectedLines,
		prerenderedHTML
	});
	return /* @__PURE__ */ jsx(DIFFS_TAG_NAME, {
		ref,
		className,
		style,
		children: templateRender(renderDiffChildren({
			fileDiff,
			renderHeaderMetadata,
			renderAnnotation,
			lineAnnotations,
			renderHoverUtility,
			getHoveredLine
		}), prerenderedHTML)
	});
}
function usePatch(patch) {
	return useMemo(() => getSingularPatch(patch), [patch]);
}

//#endregion
export { PatchDiff };
//# sourceMappingURL=PatchDiff.js.map