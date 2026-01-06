import { DEFAULT_THEMES } from "../constants.js";
import { areLanguagesAttached } from "../highlighter/languages/areLanguagesAttached.js";
import { getHighlighterIfLoaded, getSharedHighlighter } from "../highlighter/shared_highlighter.js";
import { getThemes } from "../utils/getThemes.js";
import { areThemesAttached } from "../highlighter/themes/areThemesAttached.js";
import { hasResolvedThemes } from "../highlighter/themes/hasResolvedThemes.js";
import { areThemesEqual } from "../utils/areThemesEqual.js";
import { createHastElement } from "../utils/hast_utils.js";
import { createAnnotationElement } from "../utils/createAnnotationElement.js";
import { createFileHeaderElement } from "../utils/createFileHeaderElement.js";
import { createPreElement } from "../utils/createPreElement.js";
import { getFiletypeFromFileName } from "../utils/getFiletypeFromFileName.js";
import { getHighlighterOptions } from "../utils/getHighlighterOptions.js";
import { getLineAnnotationName } from "../utils/getLineAnnotationName.js";
import { renderFileWithHighlighter } from "../utils/renderFileWithHighlighter.js";
import { toHtml } from "hast-util-to-html";

//#region src/renderers/FileRenderer.ts
var FileRenderer = class {
	highlighter;
	renderCache;
	computedLang = "text";
	lineAnnotations = {};
	constructor(options = { theme: DEFAULT_THEMES }, onRenderUpdate, workerManager) {
		this.options = options;
		this.onRenderUpdate = onRenderUpdate;
		this.workerManager = workerManager;
		if (workerManager?.isWorkingPool() !== true) this.highlighter = areThemesAttached(options.theme ?? DEFAULT_THEMES) ? getHighlighterIfLoaded() : void 0;
	}
	setOptions(options) {
		this.options = options;
	}
	mergeOptions(options) {
		this.options = {
			...this.options,
			...options
		};
	}
	setThemeType(themeType) {
		if ((this.options.themeType ?? "system") === themeType) return;
		this.mergeOptions({ themeType });
	}
	setLineAnnotations(lineAnnotations) {
		this.lineAnnotations = {};
		for (const annotation of lineAnnotations) {
			const arr = this.lineAnnotations[annotation.lineNumber] ?? [];
			this.lineAnnotations[annotation.lineNumber] = arr;
			arr.push(annotation);
		}
	}
	cleanUp() {
		this.renderCache = void 0;
		this.highlighter = void 0;
		this.workerManager = void 0;
		this.onRenderUpdate = void 0;
	}
	hydrate(file) {
		const { options } = this.getRenderOptions(file);
		let cache = this.workerManager?.getFileResultCache(file);
		if (cache != null && !areRenderOptionsEqual(options, cache.options)) cache = void 0;
		this.renderCache ??= {
			file,
			options,
			highlighted: true,
			result: cache?.result
		};
		if (this.workerManager?.isWorkingPool() === true && this.renderCache.result == null) this.workerManager.highlightFileAST(this, file);
		else this.asyncHighlight(file).then(({ result, options: options$1 }) => {
			this.onHighlightSuccess(file, result, options$1);
		});
	}
	getRenderOptions(file) {
		const options = (() => {
			if (this.workerManager?.isWorkingPool() === true) return this.workerManager.getFileRenderOptions();
			const { theme = DEFAULT_THEMES, tokenizeMaxLineLength = 1e3 } = this.options;
			return {
				theme,
				tokenizeMaxLineLength
			};
		})();
		const { renderCache } = this;
		if (renderCache?.result == null) return {
			options,
			forceRender: true
		};
		if (file !== renderCache.file || !areRenderOptionsEqual(options, renderCache.options)) return {
			options,
			forceRender: true
		};
		return {
			options,
			forceRender: false
		};
	}
	renderFile(file = this.renderCache?.file) {
		if (file == null) return;
		const cache = this.workerManager?.getFileResultCache(file);
		if (cache != null && this.renderCache == null) this.renderCache = {
			file,
			highlighted: true,
			...cache
		};
		const { options, forceRender } = this.getRenderOptions(file);
		this.renderCache ??= {
			file,
			highlighted: false,
			options,
			result: void 0
		};
		if (this.workerManager?.isWorkingPool() === true) {
			this.renderCache.result ??= this.workerManager.getPlainFileAST(file);
			if (!this.renderCache.highlighted || forceRender) this.workerManager.highlightFileAST(this, file);
		} else {
			this.computedLang = file.lang ?? getFiletypeFromFileName(file.name);
			const hasThemes = this.highlighter != null && areThemesAttached(options.theme);
			const hasLangs = this.highlighter != null && areLanguagesAttached(this.computedLang);
			if (this.highlighter != null && hasThemes && (forceRender || !this.renderCache.highlighted && hasLangs || this.renderCache.result == null)) {
				const { result, options: options$1 } = this.renderFileWithHighlighter(file, this.highlighter, !hasLangs);
				this.renderCache = {
					file,
					options: options$1,
					highlighted: hasLangs,
					result
				};
			}
			if (!hasThemes || !hasLangs) this.asyncHighlight(file).then(({ result, options: options$1 }) => {
				this.onHighlightSuccess(file, result, options$1);
			});
		}
		return this.renderCache.result != null ? this.processFileResult(this.renderCache.file, this.renderCache.result) : void 0;
	}
	async asyncRender(file) {
		const { result } = await this.asyncHighlight(file);
		return this.processFileResult(file, result);
	}
	async asyncHighlight(file) {
		this.computedLang = file.lang ?? getFiletypeFromFileName(file.name);
		const hasThemes = this.highlighter != null && hasResolvedThemes(getThemes(this.options.theme));
		const hasLangs = this.highlighter != null && areLanguagesAttached(this.computedLang);
		if (this.highlighter == null || !hasThemes || !hasLangs) this.highlighter = await this.initializeHighlighter();
		return this.renderFileWithHighlighter(file, this.highlighter);
	}
	renderFileWithHighlighter(file, highlighter, plainText = false) {
		const { options } = this.getRenderOptions(file);
		return {
			result: renderFileWithHighlighter(file, highlighter, options, plainText),
			options
		};
	}
	processFileResult(file, result) {
		const { disableFileHeader = false } = this.options;
		const codeAST = [];
		let lineIndex = 1;
		for (const line of result.code) {
			codeAST.push(line);
			const annotations = this.lineAnnotations[lineIndex];
			if (annotations != null) codeAST.push(createAnnotationElement({
				type: "annotation",
				hunkIndex: 0,
				lineIndex,
				annotations: annotations.map((annotation) => getLineAnnotationName(annotation))
			}));
			lineIndex++;
		}
		return {
			codeAST,
			preAST: this.createPreElement(result.code.length, result.themeStyles, result.baseThemeType),
			headerAST: !disableFileHeader ? this.renderHeader(file, result.themeStyles, result.baseThemeType) : void 0,
			totalLines: result.code.length,
			themeStyles: result.themeStyles,
			baseThemeType: result.baseThemeType,
			css: ""
		};
	}
	renderHeader(file, themeStyles, baseThemeType) {
		const { themeType = "system" } = this.options;
		return createFileHeaderElement({
			fileOrDiff: file,
			themeStyles,
			themeType: baseThemeType ?? themeType
		});
	}
	renderFullHTML(result) {
		return toHtml(this.renderFullAST(result));
	}
	renderFullAST(result, children = []) {
		children.push(createHastElement({
			tagName: "code",
			children: result.codeAST,
			properties: { "data-code": "" }
		}));
		return {
			...result.preAST,
			children
		};
	}
	renderPartialHTML(children, includeCodeNode = false) {
		if (!includeCodeNode) return toHtml(children);
		return toHtml(createHastElement({
			tagName: "code",
			children,
			properties: { "data-code": "" }
		}));
	}
	async initializeHighlighter() {
		this.highlighter = await getSharedHighlighter(getHighlighterOptions(this.computedLang, this.options));
		return this.highlighter;
	}
	onHighlightSuccess(file, result, options) {
		if (this.renderCache == null) return;
		const triggerRenderUpdate = this.renderCache.file !== file || !this.renderCache.highlighted || !areRenderOptionsEqual(options, this.renderCache.options);
		this.renderCache = {
			file,
			options,
			highlighted: true,
			result
		};
		if (triggerRenderUpdate) this.onRenderUpdate?.();
	}
	onHighlightError(error) {
		console.error(error);
	}
	createPreElement(totalLines, themeStyles, baseThemeType) {
		const { disableLineNumbers = false, overflow = "scroll", themeType = "system" } = this.options;
		return createPreElement({
			diffIndicators: "none",
			disableBackground: true,
			disableLineNumbers,
			overflow,
			themeStyles,
			themeType: baseThemeType ?? themeType,
			split: false,
			totalLines
		});
	}
};
function areRenderOptionsEqual(optionsA, optionsB) {
	return areThemesEqual(optionsA.theme, optionsB.theme) && optionsA.tokenizeMaxLineLength === optionsB.tokenizeMaxLineLength;
}

//#endregion
export { FileRenderer };
//# sourceMappingURL=FileRenderer.js.map