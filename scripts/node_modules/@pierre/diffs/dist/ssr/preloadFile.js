import { FileRenderer } from "../renderers/FileRenderer.js";
import { createStyleElement } from "../utils/createStyleElement.js";
import { renderHTML } from "./renderHTML.js";

//#region src/ssr/preloadFile.ts
async function preloadFile({ file, options, annotations }) {
	const fileRenderer = new FileRenderer(options);
	if (annotations !== void 0 && annotations.length > 0) fileRenderer.setLineAnnotations(annotations);
	const fileResult = await fileRenderer.asyncRender(file);
	const children = [createStyleElement(fileResult.css, true)];
	if (options?.unsafeCSS != null) children.push(createStyleElement(options.unsafeCSS));
	if (fileResult.headerAST != null) children.push(fileResult.headerAST);
	const code = fileRenderer.renderFullAST(fileResult);
	code.properties["data-dehydrated"] = "";
	children.push(code);
	return {
		file,
		options,
		annotations,
		prerenderedHTML: renderHTML(children)
	};
}

//#endregion
export { preloadFile };
//# sourceMappingURL=preloadFile.js.map