import { HEADER_METADATA_SLOT_ID } from "../constants.js";
import { createHastElement, createIconElement, createTextNodeElement } from "./hast_utils.js";
import { getIconForType } from "./getIconForType.js";

//#region src/utils/createFileHeaderElement.ts
function createFileHeaderElement({ fileOrDiff, themeStyles, themeType }) {
	const fileDiff = "type" in fileOrDiff ? fileOrDiff : void 0;
	const properties = {
		"data-diffs-header": "",
		"data-change-type": fileDiff?.type,
		"data-theme-type": themeType !== "system" ? themeType : void 0,
		style: themeStyles
	};
	return createHastElement({
		tagName: "div",
		children: [createHeaderElement({
			name: fileOrDiff.name,
			prevName: "prevName" in fileOrDiff ? fileOrDiff.prevName : void 0,
			iconType: fileDiff?.type ?? "file"
		}), createMetadataElement(fileDiff)],
		properties
	});
}
function createHeaderElement({ name, prevName, iconType }) {
	const children = [createIconElement({
		name: getIconForType(iconType),
		properties: { "data-change-icon": iconType }
	})];
	if (prevName != null) {
		children.push(createHastElement({
			tagName: "div",
			children: [createTextNodeElement(prevName)],
			properties: { "data-prev-name": "" }
		}));
		children.push(createIconElement({
			name: "diffs-icon-arrow-right-short",
			properties: { "data-rename-icon": "" }
		}));
	}
	children.push(createHastElement({
		tagName: "div",
		children: [createTextNodeElement(name)],
		properties: { "data-title": "" }
	}));
	return createHastElement({
		tagName: "div",
		children,
		properties: { "data-header-content": "" }
	});
}
function createMetadataElement(fileDiff) {
	const children = [];
	if (fileDiff != null) {
		let additions = 0;
		let deletions = 0;
		for (const hunk of fileDiff.hunks) {
			additions += hunk.additionLines;
			deletions += hunk.deletionLines;
		}
		if (deletions > 0 || additions === 0) children.push(createHastElement({
			tagName: "span",
			children: [createTextNodeElement(`-${deletions}`)],
			properties: { "data-deletions-count": "" }
		}));
		if (additions > 0 || deletions === 0) children.push(createHastElement({
			tagName: "span",
			children: [createTextNodeElement(`+${additions}`)],
			properties: { "data-additions-count": "" }
		}));
	}
	children.push(createHastElement({
		tagName: "slot",
		properties: { name: HEADER_METADATA_SLOT_ID }
	}));
	return createHastElement({
		tagName: "div",
		children,
		properties: { "data-metadata": "" }
	});
}

//#endregion
export { createFileHeaderElement };
//# sourceMappingURL=createFileHeaderElement.js.map