//#region src/utils/createHoverContentNode.ts
function createHoverContentNode() {
	const hoverContent = document.createElement("div");
	hoverContent.slot = "hover-slot";
	hoverContent.style.position = "absolute";
	hoverContent.style.top = "0";
	hoverContent.style.bottom = "0";
	hoverContent.style.textAlign = "center";
	hoverContent.style.whiteSpace = "normal";
	return hoverContent;
}

//#endregion
export { createHoverContentNode };
//# sourceMappingURL=createHoverContentNode.js.map