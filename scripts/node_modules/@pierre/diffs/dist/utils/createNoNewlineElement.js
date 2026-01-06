import { createHastElement, createTextNodeElement } from "./hast_utils.js";

//#region src/utils/createNoNewlineElement.ts
function createNoNewlineElement(type) {
	return createHastElement({
		tagName: "div",
		children: [createHastElement({
			tagName: "span",
			properties: { "data-column-number": "" }
		}), createHastElement({
			tagName: "span",
			children: [createTextNodeElement("No newline at end of file")],
			properties: { "data-column-content": "" }
		})],
		properties: {
			"data-no-newline": "",
			"data-line-type": type
		}
	});
}

//#endregion
export { createNoNewlineElement };
//# sourceMappingURL=createNoNewlineElement.js.map