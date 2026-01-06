import { CORE_CSS_ATTRIBUTE, UNSAFE_CSS_ATTRIBUTE } from "../constants.js";
import { createHastElement, createTextNodeElement } from "./hast_utils.js";
import { wrapCoreCSS, wrapUnsafeCSS } from "./cssWrappers.js";

//#region src/utils/createStyleElement.ts
function createStyleElement(content, isCoreCSS = false) {
	return createHastElement({
		tagName: "style",
		children: [createTextNodeElement(isCoreCSS ? wrapCoreCSS(content) : wrapUnsafeCSS(content))],
		properties: {
			[CORE_CSS_ATTRIBUTE]: isCoreCSS ? "" : void 0,
			[UNSAFE_CSS_ATTRIBUTE]: !isCoreCSS ? "" : void 0
		}
	});
}

//#endregion
export { createStyleElement };
//# sourceMappingURL=createStyleElement.js.map