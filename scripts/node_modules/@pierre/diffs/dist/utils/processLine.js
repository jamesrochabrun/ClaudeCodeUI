import { createHastElement, createTextNodeElement } from "./hast_utils.js";

//#region src/utils/processLine.ts
function processLine(node, line, state) {
	const lineInfo = typeof state.lineInfo === "function" ? state.lineInfo(line) : state.lineInfo[line];
	if (lineInfo == null) {
		console.error({
			node,
			line,
			state
		});
		throw new Error(`processLine: line ${line}, contains no state.lineInfo`);
	}
	node.tagName = "span";
	node.properties["data-column-content"] = "";
	if (node.children.length === 0) node.children.push(createTextNodeElement("\n"));
	return createHastElement({
		tagName: "div",
		children: [createHastElement({
			tagName: "span",
			children: [createHastElement({
				tagName: "span",
				children: [{
					type: "text",
					value: `${lineInfo.lineNumber}`
				}],
				properties: { "data-line-number-content": "" }
			})],
			properties: { "data-column-number": "" }
		}), node],
		properties: {
			"data-line": lineInfo.lineNumber,
			"data-alt-line": lineInfo.altLineNumber,
			"data-line-type": lineInfo.type,
			"data-line-index": lineInfo.lineIndex
		}
	});
}

//#endregion
export { processLine };
//# sourceMappingURL=processLine.js.map