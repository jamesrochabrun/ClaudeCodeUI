import style_default from "../style.js";

//#region src/utils/cssWrappers.ts
const LAYER_ORDER = `@layer base, theme, unsafe;`;
function wrapCoreCSS(mainCSS) {
	return `${LAYER_ORDER}
${style_default}
@layer theme {
  ${mainCSS}
}`;
}
function wrapUnsafeCSS(unsafeCSS) {
	return `${LAYER_ORDER}
@layer unsafe {
  ${unsafeCSS}
}`;
}

//#endregion
export { wrapCoreCSS, wrapUnsafeCSS };
//# sourceMappingURL=cssWrappers.js.map