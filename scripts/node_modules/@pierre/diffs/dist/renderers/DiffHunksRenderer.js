import { DEFAULT_THEMES } from "../constants.js";
import { areLanguagesAttached } from "../highlighter/languages/areLanguagesAttached.js";
import { getHighlighterIfLoaded, getSharedHighlighter } from "../highlighter/shared_highlighter.js";
import { areThemesAttached } from "../highlighter/themes/areThemesAttached.js";
import { areThemesEqual } from "../utils/areThemesEqual.js";
import { createHastElement } from "../utils/hast_utils.js";
import { createAnnotationElement } from "../utils/createAnnotationElement.js";
import { createFileHeaderElement } from "../utils/createFileHeaderElement.js";
import { createPreElement } from "../utils/createPreElement.js";
import { getFiletypeFromFileName } from "../utils/getFiletypeFromFileName.js";
import { getHighlighterOptions } from "../utils/getHighlighterOptions.js";
import { getLineAnnotationName } from "../utils/getLineAnnotationName.js";
import { createEmptyRowBuffer } from "../utils/createEmptyRowBuffer.js";
import { createNoNewlineElement } from "../utils/createNoNewlineElement.js";
import { createSeparator } from "../utils/createSeparator.js";
import { getHunkSeparatorSlotName } from "../utils/getHunkSeparatorSlotName.js";
import { getTotalLineCountFromHunks } from "../utils/getTotalLineCountFromHunks.js";
import { renderDiffWithHighlighter } from "../utils/renderDiffWithHighlighter.js";
import { toHtml } from "hast-util-to-html";

//#region src/renderers/DiffHunksRenderer.ts
const EXPANDED_REGION = {
	fromStart: 0,
	fromEnd: 0
};
var DiffHunksRenderer = class {
	highlighter;
	diff;
	expandedHunks = /* @__PURE__ */ new Map();
	deletionAnnotations = {};
	additionAnnotations = {};
	computedLang = "text";
	renderCache;
	constructor(options = { theme: DEFAULT_THEMES }, onRenderUpdate, workerManager) {
		this.options = options;
		this.onRenderUpdate = onRenderUpdate;
		this.workerManager = workerManager;
		if (workerManager?.isWorkingPool() !== true) this.highlighter = areThemesAttached(options.theme ?? DEFAULT_THEMES) ? getHighlighterIfLoaded() : void 0;
	}
	cleanUp() {
		this.highlighter = void 0;
		this.diff = void 0;
		this.renderCache = void 0;
		this.workerManager = void 0;
		this.onRenderUpdate = void 0;
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
		if (this.getOptionsWithDefaults().themeType === themeType) return;
		this.mergeOptions({ themeType });
	}
	expandHunk(index, direction) {
		const { expansionLineCount } = this.getOptionsWithDefaults();
		const region = this.expandedHunks.get(index) ?? {
			fromStart: 0,
			fromEnd: 0
		};
		if (direction === "up" || direction === "both") region.fromStart += expansionLineCount;
		if (direction === "down" || direction === "both") region.fromEnd += expansionLineCount;
		this.expandedHunks.set(index, region);
	}
	setLineAnnotations(lineAnnotations) {
		this.additionAnnotations = {};
		this.deletionAnnotations = {};
		for (const annotation of lineAnnotations) {
			const map = (() => {
				switch (annotation.side) {
					case "deletions": return this.deletionAnnotations;
					case "additions": return this.additionAnnotations;
				}
			})();
			const arr = map[annotation.lineNumber] ?? [];
			map[annotation.lineNumber] = arr;
			arr.push(annotation);
		}
	}
	getOptionsWithDefaults() {
		const { diffIndicators = "bars", diffStyle = "split", disableBackground = false, disableFileHeader = false, disableLineNumbers = false, expandUnchanged = false, expansionLineCount = 100, hunkSeparators = "line-info", lineDiffType = "word-alt", maxLineDiffLength = 1e3, overflow = "scroll", theme = DEFAULT_THEMES, themeType = "system", tokenizeMaxLineLength = 1e3, useCSSClasses = false } = this.options;
		return {
			diffIndicators,
			diffStyle,
			disableBackground,
			disableFileHeader,
			disableLineNumbers,
			expandUnchanged,
			expansionLineCount,
			hunkSeparators,
			lineDiffType,
			maxLineDiffLength,
			overflow,
			theme: this.workerManager?.getDiffRenderOptions().theme ?? theme,
			themeType,
			tokenizeMaxLineLength,
			useCSSClasses
		};
	}
	async initializeHighlighter() {
		this.highlighter = await getSharedHighlighter(getHighlighterOptions(this.computedLang, this.options));
		return this.highlighter;
	}
	hydrate(diff) {
		if (diff == null) return;
		this.diff = diff;
		const { options } = this.getRenderOptions(diff);
		let cache = this.workerManager?.getDiffResultCache(diff);
		if (cache != null && !areRenderOptionsEqual(options, cache.options)) cache = void 0;
		this.renderCache ??= {
			diff,
			highlighted: true,
			options,
			result: cache?.result
		};
		if (this.workerManager?.isWorkingPool() === true && this.renderCache.result == null) this.workerManager.highlightDiffAST(this, this.diff);
		else this.asyncHighlight(diff).then(({ result, options: options$1 }) => {
			this.onHighlightSuccess(diff, result, options$1);
		});
	}
	getRenderOptions(diff) {
		const options = (() => {
			if (this.workerManager?.isWorkingPool() === true) return this.workerManager.getDiffRenderOptions();
			const { theme, tokenizeMaxLineLength, lineDiffType } = this.getOptionsWithDefaults();
			return {
				theme,
				tokenizeMaxLineLength,
				lineDiffType
			};
		})();
		this.getOptionsWithDefaults();
		const { renderCache } = this;
		if (renderCache?.result == null) return {
			options,
			forceRender: true
		};
		if (diff !== renderCache.diff || !areRenderOptionsEqual(options, renderCache.options)) return {
			options,
			forceRender: true
		};
		return {
			options,
			forceRender: false
		};
	}
	renderDiff(diff = this.renderCache?.diff) {
		if (diff == null) return;
		const cache = this.workerManager?.getDiffResultCache(diff);
		if (cache != null && this.renderCache == null) this.renderCache = {
			diff,
			highlighted: true,
			...cache
		};
		const { options, forceRender } = this.getRenderOptions(diff);
		this.renderCache ??= {
			diff,
			highlighted: false,
			options,
			result: void 0
		};
		if (this.workerManager?.isWorkingPool() === true) {
			this.renderCache.result ??= this.workerManager.getPlainDiffAST(diff);
			if (!this.renderCache.highlighted || forceRender) this.workerManager.highlightDiffAST(this, diff);
		} else {
			this.computedLang = diff.lang ?? getFiletypeFromFileName(diff.name);
			const hasThemes = this.highlighter != null && areThemesAttached(options.theme);
			const hasLangs = this.highlighter != null && areLanguagesAttached(this.computedLang);
			if (this.highlighter != null && hasThemes && (forceRender || !this.renderCache.highlighted && hasLangs || this.renderCache.result == null)) {
				const { result, options: options$1 } = this.renderDiffWithHighlighter(diff, this.highlighter, !hasLangs);
				this.renderCache = {
					diff,
					options: options$1,
					highlighted: hasLangs,
					result
				};
			}
			if (!hasThemes || !hasLangs) this.asyncHighlight(diff).then(({ result, options: options$1 }) => {
				this.onHighlightSuccess(diff, result, options$1);
			});
		}
		return this.renderCache.result != null ? this.processDiffResult(this.renderCache.diff, this.renderCache.result) : void 0;
	}
	async asyncRender(diff) {
		const { result } = await this.asyncHighlight(diff);
		return this.processDiffResult(diff, result);
	}
	createPreElement(split, totalLines, themeStyles, baseThemeType) {
		const { diffIndicators, disableBackground, disableLineNumbers, overflow, themeType } = this.getOptionsWithDefaults();
		return createPreElement({
			diffIndicators,
			disableBackground,
			disableLineNumbers,
			overflow,
			themeStyles,
			split,
			themeType: baseThemeType ?? themeType,
			totalLines
		});
	}
	async asyncHighlight(diff) {
		this.computedLang = diff.lang ?? getFiletypeFromFileName(diff.name);
		const hasThemes = this.highlighter != null && areThemesAttached(this.options.theme ?? DEFAULT_THEMES);
		const hasLangs = this.highlighter != null && areLanguagesAttached(this.computedLang);
		if (this.highlighter == null || !hasThemes || !hasLangs) this.highlighter = await this.initializeHighlighter();
		return this.renderDiffWithHighlighter(diff, this.highlighter);
	}
	renderDiffWithHighlighter(diff, highlighter, plainText = false) {
		const { options } = this.getRenderOptions(diff);
		return {
			result: renderDiffWithHighlighter(diff, highlighter, options, plainText),
			options
		};
	}
	onHighlightSuccess(diff, result, options) {
		if (this.renderCache == null) return;
		const triggerRenderUpdate = this.renderCache.diff !== diff || !this.renderCache.highlighted || !areRenderOptionsEqual(this.renderCache.options, options);
		this.renderCache = {
			diff,
			options,
			highlighted: true,
			result
		};
		if (triggerRenderUpdate) this.onRenderUpdate?.();
	}
	onHighlightError(error) {
		console.error(error);
	}
	processDiffResult(fileDiff, { code, themeStyles, baseThemeType }) {
		const { diffStyle, disableFileHeader } = this.getOptionsWithDefaults();
		this.diff = fileDiff;
		const unified = diffStyle === "unified";
		let additionsAST = [];
		let deletionsAST = [];
		let unifiedAST = [];
		let hunkIndex = 0;
		const hunkData = [];
		let prevHunk;
		let lineIndex = 0;
		for (const hunk of fileDiff.hunks) {
			lineIndex += hunk.collapsedBefore;
			lineIndex = this.renderHunks({
				ast: code,
				hunk,
				prevHunk,
				hunkIndex,
				isLastHunk: hunkIndex === fileDiff.hunks.length - 1,
				additionsAST,
				deletionsAST,
				unifiedAST,
				hunkData,
				lineIndex
			});
			hunkIndex++;
			prevHunk = hunk;
		}
		const totalLines = Math.max(getTotalLineCountFromHunks(fileDiff.hunks), fileDiff.newLines?.length ?? 0, fileDiff.oldLines?.length ?? 0);
		additionsAST = !unified && (code.hunks != null || code.newLines.length > 0) ? additionsAST : void 0;
		deletionsAST = !unified && (code.hunks != null || code.oldLines.length > 0) ? deletionsAST : void 0;
		unifiedAST = unifiedAST.length > 0 ? unifiedAST : void 0;
		const preNode = this.createPreElement(deletionsAST != null && additionsAST != null, totalLines, themeStyles, baseThemeType);
		return {
			additionsAST,
			deletionsAST,
			unifiedAST,
			hunkData,
			preNode,
			themeStyles,
			baseThemeType,
			headerElement: !disableFileHeader ? this.renderHeader(this.diff, themeStyles, baseThemeType) : void 0,
			totalLines,
			css: ""
		};
	}
	renderFullAST(result, children = []) {
		if (result.unifiedAST != null) children.push(createHastElement({
			tagName: "code",
			children: result.unifiedAST,
			properties: {
				"data-code": "",
				"data-unified": ""
			}
		}));
		if (result.deletionsAST != null) children.push(createHastElement({
			tagName: "code",
			children: result.deletionsAST,
			properties: {
				"data-code": "",
				"data-deletions": ""
			}
		}));
		if (result.additionsAST != null) children.push(createHastElement({
			tagName: "code",
			children: result.additionsAST,
			properties: {
				"data-code": "",
				"data-additions": ""
			}
		}));
		return {
			...result.preNode,
			children
		};
	}
	renderFullHTML(result, tempChildren = []) {
		return toHtml(this.renderFullAST(result, tempChildren));
	}
	renderPartialHTML(children, columnType) {
		if (columnType == null) return toHtml(children);
		return toHtml(createHastElement({
			tagName: "code",
			children,
			properties: {
				"data-code": "",
				[`data-${columnType}`]: ""
			}
		}));
	}
	renderCollapsedHunks({ ast, hunkData, hunkIndex, hunkSpecs, isFirstHunk, isLastHunk, rangeSize, lineIndex, additionLineNumber, deletionLineNumber, unifiedAST, deletionsAST, additionsAST }) {
		if (rangeSize <= 0) return;
		const { hunkSeparators, expandUnchanged, diffStyle, expansionLineCount } = this.getOptionsWithDefaults();
		const expandable = ast.hunks == null && ast.newLines.length > 0 && ast.oldLines.length > 0;
		const expandedRegion = this.expandedHunks.get(hunkIndex) ?? EXPANDED_REGION;
		const chunked = rangeSize > expansionLineCount;
		const collapsedLines = Math.max(!expandUnchanged ? rangeSize - (expandedRegion.fromEnd + expandedRegion.fromStart) : 0, 0);
		const pushHunkSeparator = ({ type, linesAST }) => {
			if (hunkSeparators === "line-info" || hunkSeparators === "custom") {
				const slotName = getHunkSeparatorSlotName(type, hunkIndex);
				linesAST.push(createSeparator({
					type: hunkSeparators,
					content: getModifiedLinesString(collapsedLines),
					expandIndex: expandable ? hunkIndex : void 0,
					chunked,
					slotName,
					isFirstHunk,
					isLastHunk
				}));
				hunkData.push({
					slotName,
					hunkIndex,
					lines: collapsedLines,
					type,
					expandable: expandable ? {
						up: expandable && !isFirstHunk,
						down: expandable,
						chunked
					} : void 0
				});
			} else if (hunkSeparators === "metadata" && hunkSpecs != null) linesAST.push(createSeparator({
				type: "metadata",
				content: hunkSpecs,
				isFirstHunk,
				isLastHunk
			}));
			else if (hunkSeparators === "simple" && hunkIndex > 0) linesAST.push(createSeparator({
				type: "simple",
				isFirstHunk,
				isLastHunk: false
			}));
		};
		const renderRange = ({ rangeLen, fromStart }) => {
			if (ast.newLines == null || ast.oldLines == null) return;
			const offset = isLastHunk ? 0 : fromStart ? rangeSize : rangeLen;
			let dLineNumber = deletionLineNumber - offset;
			let aLineNumber = additionLineNumber - offset;
			let lIndex = lineIndex - offset;
			for (let i = 0; i < rangeLen; i++) {
				const oldLine = ast.oldLines[dLineNumber];
				const newLine = ast.newLines[aLineNumber];
				if (oldLine == null || newLine == null) {
					console.error({
						aLineNumber,
						dLineNumber,
						ast
					});
					throw new Error("DiffHunksRenderer.renderHunks prefill context invalid. Must include data for old and new lines");
				}
				dLineNumber++;
				aLineNumber++;
				if (diffStyle === "unified") this.pushLineWithAnnotation({
					newLine,
					unifiedAST,
					unifiedSpan: this.getAnnotations("unified", dLineNumber, aLineNumber, hunkIndex, lIndex)
				});
				else this.pushLineWithAnnotation({
					newLine,
					oldLine,
					additionsAST,
					deletionsAST,
					...this.getAnnotations("split", dLineNumber, aLineNumber, hunkIndex, lIndex)
				});
				lIndex++;
			}
		};
		if (expandable) renderRange({
			rangeLen: Math.min(collapsedLines === 0 || expandUnchanged ? rangeSize : expandedRegion.fromStart, rangeSize),
			fromStart: true
		});
		if (collapsedLines > 0) if (diffStyle === "unified") pushHunkSeparator({
			type: "unified",
			linesAST: unifiedAST
		});
		else {
			pushHunkSeparator({
				type: "deletions",
				linesAST: deletionsAST
			});
			pushHunkSeparator({
				type: "additions",
				linesAST: additionsAST
			});
		}
		if (collapsedLines > 0 && expandedRegion.fromEnd > 0 && !isLastHunk) renderRange({
			rangeLen: Math.min(expandedRegion.fromEnd, rangeSize),
			fromStart: false
		});
	}
	renderHunks({ hunk, hunkData, hunkIndex, lineIndex, isLastHunk, prevHunk, ast, deletionsAST, additionsAST, unifiedAST }) {
		const { diffStyle } = this.getOptionsWithDefaults();
		const unified = diffStyle === "unified";
		let additionLineNumber = hunk.additionStart - 1;
		let deletionLineNumber = hunk.deletionStart - 1;
		this.renderCollapsedHunks({
			additionLineNumber,
			additionsAST,
			ast,
			deletionLineNumber,
			deletionsAST,
			hunkData,
			hunkIndex,
			hunkSpecs: hunk.hunkSpecs,
			isFirstHunk: prevHunk == null,
			isLastHunk: false,
			lineIndex,
			rangeSize: Math.max(hunk.collapsedBefore, 0),
			unifiedAST
		});
		let { oldLines, newLines, oldIndex, newIndex } = (() => {
			if (ast.hunks != null) {
				const lineHunk = ast.hunks[hunkIndex];
				if (lineHunk == null) {
					console.error({
						ast,
						hunkIndex
					});
					throw new Error(`DiffHunksRenderer.renderHunks: lineHunk doesn't exist`);
				}
				return {
					oldLines: lineHunk.oldLines,
					newLines: lineHunk.newLines,
					oldIndex: 0,
					newIndex: 0
				};
			}
			return {
				oldLines: ast.oldLines,
				newLines: ast.newLines,
				oldIndex: deletionLineNumber,
				newIndex: additionLineNumber
			};
		})();
		for (const hunkContent of hunk.hunkContent) if (hunkContent.type === "context") {
			const { length: len } = hunkContent.lines;
			for (let i = 0; i < len; i++) {
				const oldLine = oldLines[oldIndex];
				const newLine = newLines[newIndex];
				oldIndex++;
				newIndex++;
				additionLineNumber++;
				deletionLineNumber++;
				if (unified) {
					if (newLine == null) throw new Error("DiffHunksRenderer.renderHunks: newLine doesnt exist for context...");
					this.pushLineWithAnnotation({
						newLine,
						unifiedAST,
						unifiedSpan: this.getAnnotations("unified", deletionLineNumber, additionLineNumber, hunkIndex, lineIndex)
					});
				} else {
					if (newLine == null || oldLine == null) throw new Error("DiffHunksRenderer.renderHunks: newLine or oldLine doesnt exist for context...");
					this.pushLineWithAnnotation({
						oldLine,
						newLine,
						deletionsAST,
						additionsAST,
						...this.getAnnotations("split", deletionLineNumber, additionLineNumber, hunkIndex, lineIndex)
					});
				}
				lineIndex++;
			}
			if (hunkContent.noEOFCR) {
				const node = createNoNewlineElement("context");
				if (unified) unifiedAST.push(node);
				else {
					deletionsAST.push(node);
					additionsAST.push(node);
				}
			}
		} else {
			const { length: dLen } = hunkContent.deletions;
			const { length: aLen } = hunkContent.additions;
			const len = unified ? dLen + aLen : Math.max(dLen, aLen);
			let spanSize = 0;
			for (let i = 0; i < len; i++) {
				const { oldLine, newLine } = (() => {
					let oldLine$1 = oldLines[oldIndex];
					let newLine$1 = newLines[newIndex];
					if (unified) if (i < dLen) newLine$1 = void 0;
					else oldLine$1 = void 0;
					else {
						if (i >= dLen) oldLine$1 = void 0;
						if (i >= aLen) newLine$1 = void 0;
					}
					if (oldLine$1 == null && newLine$1 == null) {
						console.error({
							i,
							len,
							ast,
							hunkContent
						});
						throw new Error("renderHunks: oldLine and newLine are null, something is wrong");
					}
					return {
						oldLine: oldLine$1,
						newLine: newLine$1
					};
				})();
				if (oldLine != null) {
					oldIndex++;
					deletionLineNumber++;
				}
				if (newLine != null) {
					newIndex++;
					additionLineNumber++;
				}
				if (unified) {
					this.pushLineWithAnnotation({
						oldLine,
						newLine,
						unifiedAST,
						unifiedSpan: this.getAnnotations("unified", oldLine != null ? deletionLineNumber : void 0, newLine != null ? additionLineNumber : void 0, hunkIndex, lineIndex)
					});
					lineIndex++;
				} else {
					if (oldLine == null || newLine == null) spanSize++;
					const annotationSpans = this.getAnnotations("split", oldLine != null ? deletionLineNumber : void 0, newLine != null ? additionLineNumber : void 0, hunkIndex, lineIndex);
					if (annotationSpans != null) {
						if (spanSize > 0) {
							if (aLen > dLen) deletionsAST.push(createEmptyRowBuffer(spanSize));
							else additionsAST.push(createEmptyRowBuffer(spanSize));
							spanSize = 0;
						}
					}
					this.pushLineWithAnnotation({
						newLine,
						oldLine,
						deletionsAST,
						additionsAST,
						...annotationSpans
					});
					lineIndex++;
				}
			}
			if (!unified) {
				if (spanSize > 0) {
					if (aLen > dLen) deletionsAST.push(createEmptyRowBuffer(spanSize));
					else additionsAST.push(createEmptyRowBuffer(spanSize));
					spanSize = 0;
				}
				if (hunkContent.noEOFCRDeletions) {
					deletionsAST.push(createNoNewlineElement("change-deletion"));
					if (!hunkContent.noEOFCRAdditions) additionsAST.push(createEmptyRowBuffer(1));
				}
				if (hunkContent.noEOFCRAdditions) {
					additionsAST.push(createNoNewlineElement("change-addition"));
					if (!hunkContent.noEOFCRDeletions) deletionsAST.push(createEmptyRowBuffer(1));
				}
			}
		}
		if (isLastHunk && ast.newLines != null && ast.newLines.length > 0) this.renderCollapsedHunks({
			additionLineNumber,
			additionsAST,
			ast,
			deletionLineNumber,
			deletionsAST,
			hunkData,
			hunkIndex: hunkIndex + 1,
			hunkSpecs: void 0,
			isFirstHunk: false,
			isLastHunk: true,
			lineIndex,
			rangeSize: Math.max(ast.newLines.length - Math.max(hunk.additionStart + hunk.additionCount - 1, 0), 0),
			unifiedAST
		});
		return lineIndex;
	}
	pushLineWithAnnotation({ newLine, oldLine, unifiedAST, additionsAST, deletionsAST, unifiedSpan, deletionSpan, additionSpan }) {
		if (unifiedAST != null) {
			if (oldLine != null) unifiedAST.push(oldLine);
			else if (newLine != null) unifiedAST.push(newLine);
			if (unifiedSpan != null) unifiedAST.push(createAnnotationElement(unifiedSpan));
		} else if (deletionsAST != null && additionsAST != null) {
			if (oldLine != null) deletionsAST.push(oldLine);
			if (newLine != null) additionsAST.push(newLine);
			if (deletionSpan != null) deletionsAST.push(createAnnotationElement(deletionSpan));
			if (additionSpan != null) additionsAST.push(createAnnotationElement(additionSpan));
		}
	}
	getAnnotations(type, oldLineNumber, newLineNumber, hunkIndex, lineIndex) {
		const deletionSpan = {
			type: "annotation",
			hunkIndex,
			lineIndex,
			annotations: []
		};
		if (oldLineNumber != null) for (const anno of this.deletionAnnotations[oldLineNumber] ?? []) deletionSpan.annotations.push(getLineAnnotationName(anno));
		const additionSpan = {
			type: "annotation",
			hunkIndex,
			lineIndex,
			annotations: []
		};
		if (newLineNumber != null) for (const anno of this.additionAnnotations[newLineNumber] ?? []) (type === "unified" ? deletionSpan : additionSpan).annotations.push(getLineAnnotationName(anno));
		if (type === "unified") {
			if (deletionSpan.annotations.length > 0) return deletionSpan;
			return;
		}
		if (additionSpan.annotations.length === 0 && deletionSpan.annotations.length === 0) return;
		return {
			deletionSpan,
			additionSpan
		};
	}
	renderHeader(diff, themeStyles, baseThemeType) {
		const { themeType } = this.getOptionsWithDefaults();
		return createFileHeaderElement({
			fileOrDiff: diff,
			themeStyles,
			themeType: baseThemeType ?? themeType
		});
	}
};
function areRenderOptionsEqual(optionsA, optionsB) {
	return areThemesEqual(optionsA.theme, optionsB.theme) && optionsA.tokenizeMaxLineLength === optionsB.tokenizeMaxLineLength && optionsA.lineDiffType === optionsB.lineDiffType;
}
function getModifiedLinesString(lines) {
	return `${lines} unmodified line${lines > 1 ? "s" : ""}`;
}

//#endregion
export { DiffHunksRenderer };
//# sourceMappingURL=DiffHunksRenderer.js.map