import { HEADER_METADATA_SLOT_ID } from "../../constants.js";
import { getLineAnnotationName } from "../../utils/getLineAnnotationName.js";
import { HoverSlotStyles } from "../constants.js";
import { Fragment, jsx, jsxs } from "react/jsx-runtime";

//#region src/react/utils/renderDiffChildren.tsx
function renderDiffChildren({ fileDiff, oldFile, newFile, renderHeaderMetadata, renderAnnotation, renderHoverUtility, lineAnnotations, getHoveredLine }) {
	const metadata = renderHeaderMetadata?.({
		fileDiff,
		oldFile,
		newFile
	});
	return /* @__PURE__ */ jsxs(Fragment, { children: [
		metadata != null && /* @__PURE__ */ jsx("div", {
			slot: HEADER_METADATA_SLOT_ID,
			children: metadata
		}),
		renderAnnotation != null && lineAnnotations?.map((annotation, index) => /* @__PURE__ */ jsx("div", {
			slot: getLineAnnotationName(annotation),
			children: renderAnnotation(annotation)
		}, index)),
		renderHoverUtility != null && /* @__PURE__ */ jsx("div", {
			slot: "hover-slot",
			style: HoverSlotStyles,
			children: renderHoverUtility(getHoveredLine)
		})
	] });
}

//#endregion
export { renderDiffChildren };
//# sourceMappingURL=renderDiffChildren.js.map