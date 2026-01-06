'use client';


import { DIFFS_TAG_NAME } from "../constants.js";
import { templateRender } from "./utils/templateRender.js";
import { renderDiffChildren } from "./utils/renderDiffChildren.js";
import { useFileDiffInstance } from "./utils/useFileDiffInstance.js";
import { jsx } from "react/jsx-runtime";

//#region src/react/MultiFileDiff.tsx
function MultiFileDiff({ oldFile, newFile, options, lineAnnotations, selectedLines, className, style, prerenderedHTML, renderAnnotation, renderHeaderMetadata, renderHoverUtility }) {
	const { ref, getHoveredLine } = useFileDiffInstance({
		oldFile,
		newFile,
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
			oldFile,
			newFile,
			renderHeaderMetadata,
			renderAnnotation,
			lineAnnotations,
			renderHoverUtility,
			getHoveredLine
		}), prerenderedHTML)
	});
}

//#endregion
export { MultiFileDiff };
//# sourceMappingURL=MultiFileDiff.js.map