//#region src/utils/hast_utils.ts
function createTextNodeElement(value) {
	return {
		type: "text",
		value
	};
}
function createHastElement({ tagName, children = [], properties = {} }) {
	return {
		type: "element",
		tagName,
		properties,
		children
	};
}
function createIconElement({ name, width = 16, height = 16, properties }) {
	return createHastElement({
		tagName: "svg",
		properties: {
			width,
			height,
			viewBox: "0 0 16 16",
			...properties
		},
		children: [createHastElement({
			tagName: "use",
			properties: { href: `#${name.replace(/^#/, "")}` }
		})]
	});
}
function findCodeElement(nodes) {
	let firstChild = nodes.children[0];
	while (firstChild != null) {
		if (firstChild.type === "element" && firstChild.tagName === "code") return firstChild;
		if ("children" in firstChild) firstChild = firstChild.children[0];
		else firstChild = null;
	}
}

//#endregion
export { createHastElement, createIconElement, createTextNodeElement, findCodeElement };
//# sourceMappingURL=hast_utils.js.map