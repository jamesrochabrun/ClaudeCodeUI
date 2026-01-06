import { HEADER_METADATA_SLOT_ID } from "../../constants.js";
import { getLineAnnotationName } from "../../utils/getLineAnnotationName.js";
import { HoverSlotStyles } from "../constants.js";
import { Fragment, jsx, jsxs } from "react/jsx-runtime";

//#region src/react/utils/renderFileChildren.tsx
function renderFileChildren({ file, renderHeaderMetadata, renderAnnotation, lineAnnotations, renderHoverUtility, getHoveredLine }) {
	const metadata = renderHeaderMetadata?.(file);
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
export { renderFileChildren };
//# sourceMappingURL=renderFileChildren.js.map