//#region src/utils/createCodeNode.ts
function createCodeNode({ pre, columnType } = {}) {
	const code = document.createElement("code");
	code.dataset.code = "";
	if (columnType != null) code.dataset[columnType] = "";
	pre?.appendChild(code);
	return code;
}

//#endregion
export { createCodeNode };
//# sourceMappingURL=createCodeNode.js.map