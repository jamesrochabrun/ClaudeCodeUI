import { createHastElement } from "./hast_utils.js";

//#region src/utils/createPreElement.ts
function createPreElement(options) {
	return createHastElement({
		tagName: "pre",
		properties: createPreWrapperProperties(options)
	});
}
function createPreWrapperProperties({ diffIndicators, disableBackground, disableLineNumbers, overflow, split, themeType, themeStyles, totalLines }) {
	const properties = {
		"data-diffs": "",
		"data-type": split ? "split" : "file",
		"data-overflow": overflow,
		"data-disable-line-numbers": disableLineNumbers ? "" : void 0,
		"data-background": !disableBackground ? "" : void 0,
		"data-indicators": diffIndicators === "bars" || diffIndicators === "classic" ? diffIndicators : void 0,
		"data-theme-type": themeType !== "system" ? themeType : void 0,
		style: themeStyles,
		tabIndex: 0
	};
	properties.style += `--diffs-min-number-column-width-default:${`${totalLines}`.length}ch;`;
	return properties;
}

//#endregion
export { createPreElement, createPreWrapperProperties };
//# sourceMappingURL=createPreElement.js.map