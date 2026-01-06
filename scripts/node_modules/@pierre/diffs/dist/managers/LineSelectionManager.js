import { areSelectionsEqual } from "../utils/areSelectionsEqual.js";

//#region src/managers/LineSelectionManager.ts
/**
* Manages line selection state and interactions for code/diff viewers.
* Handles:
* - Click and drag selection
* - Shift-click to extend selection
* - DOM attribute updates (data-selected-line)
*/
var LineSelectionManager = class {
	pre;
	selectedRange = null;
	renderedSelectionRange;
	anchor;
	_queuedRender;
	constructor(options = {}) {
		this.options = options;
	}
	setOptions(options) {
		this.options = {
			...this.options,
			...options
		};
		this.removeEventListeners();
		if (this.options.enableLineSelection === true) this.attachEventListeners();
	}
	cleanUp() {
		this.removeEventListeners();
		if (this._queuedRender != null) {
			cancelAnimationFrame(this._queuedRender);
			this._queuedRender = void 0;
		}
		if (this.pre != null) delete this.pre.dataset.interactiveLineNumbers;
		this.pre = void 0;
	}
	setup(pre) {
		this.setDirty();
		if (this.pre !== pre) this.cleanUp();
		this.pre = pre;
		const { enableLineSelection = false } = this.options;
		if (enableLineSelection) {
			this.pre.dataset.interactiveLineNumbers = "";
			this.attachEventListeners();
		} else {
			this.removeEventListeners();
			delete this.pre.dataset.interactiveLineNumbers;
		}
		this.setSelection(this.selectedRange);
	}
	setDirty() {
		this.renderedSelectionRange = void 0;
	}
	isDirty() {
		return this.renderedSelectionRange === void 0;
	}
	setSelection(range) {
		const isRangeChange = !(range === this.selectedRange || areSelectionsEqual(range ?? void 0, this.selectedRange ?? void 0));
		if (!this.isDirty() && !isRangeChange) return;
		this.selectedRange = range;
		this.renderSelection();
		if (isRangeChange) this.notifySelectionChange();
	}
	getSelection() {
		return this.selectedRange;
	}
	attachEventListeners() {
		if (this.pre == null) return;
		this.removeEventListeners();
		this.pre.addEventListener("pointerdown", this.handleMouseDown);
	}
	removeEventListeners() {
		if (this.pre == null) return;
		this.pre.removeEventListener("pointerdown", this.handleMouseDown);
		document.removeEventListener("pointermove", this.handleMouseMove);
		document.removeEventListener("pointerup", this.handleMouseUp);
	}
	handleMouseDown = (event) => {
		const mouseEventData = event.button === 0 ? this.getMouseEventDataForPath(event.composedPath(), "click") : void 0;
		if (mouseEventData == null) return;
		event.preventDefault();
		const { lineNumber, eventSide, lineIndex } = mouseEventData;
		if (event.shiftKey && this.selectedRange != null) {
			const range = this.deriveRowRangeFromDOM(this.selectedRange, this.pre?.dataset.type === "split");
			if (range == null) return;
			const useStart = range.start <= range.end ? lineIndex >= range.start : lineIndex <= range.end;
			this.anchor = {
				line: useStart ? this.selectedRange.start : this.selectedRange.end,
				side: (useStart ? this.selectedRange.side : this.selectedRange.endSide ?? this.selectedRange.side) ?? "additions"
			};
			this.updateSelection(lineNumber, eventSide);
			this.notifySelectionStart(this.selectedRange);
		} else {
			if (this.selectedRange?.start === lineNumber && this.selectedRange?.end === lineNumber) {
				this.updateSelection(null);
				this.notifySelectionEnd(null);
				this.notifySelectionChange();
				return;
			}
			this.selectedRange = null;
			this.anchor = {
				line: lineNumber,
				side: eventSide
			};
			this.updateSelection(lineNumber, eventSide);
			this.notifySelectionStart(this.selectedRange);
		}
		document.addEventListener("pointermove", this.handleMouseMove);
		document.addEventListener("pointerup", this.handleMouseUp);
	};
	handleMouseMove = (event) => {
		const mouseEventData = this.getMouseEventDataForPath(event.composedPath(), "move");
		if (mouseEventData == null || this.anchor == null) return;
		const { lineNumber, eventSide } = mouseEventData;
		this.updateSelection(lineNumber, eventSide);
	};
	handleMouseUp = () => {
		this.anchor = void 0;
		document.removeEventListener("pointermove", this.handleMouseMove);
		document.removeEventListener("pointerup", this.handleMouseUp);
		this.notifySelectionEnd(this.selectedRange);
		this.notifySelectionChange();
	};
	updateSelection(currentLine, side) {
		if (currentLine == null) this.selectedRange = null;
		else {
			const anchorSide = this.anchor?.side ?? side;
			this.selectedRange = {
				start: this.anchor?.line ?? currentLine,
				end: currentLine,
				side: anchorSide,
				endSide: anchorSide !== side ? side : void 0
			};
		}
		this._queuedRender ??= requestAnimationFrame(this.renderSelection);
	}
	renderSelection = () => {
		if (this._queuedRender != null) {
			cancelAnimationFrame(this._queuedRender);
			this._queuedRender = void 0;
		}
		if (this.pre == null || this.renderedSelectionRange === this.selectedRange) return;
		const allSelected = this.pre.querySelectorAll("[data-selected-line]");
		for (const element of allSelected) element.removeAttribute("data-selected-line");
		this.renderedSelectionRange = this.selectedRange;
		if (this.selectedRange == null) return;
		const codeElements = this.pre.querySelectorAll("[data-code]");
		if (codeElements.length === 0) return;
		if (codeElements.length > 2) {
			console.error(codeElements);
			throw new Error("LineSelectionManager.applySelectionToDOM: Somehow there are more than 2 code elements...");
		}
		const split = this.pre.dataset.type === "split";
		const rowRange = this.deriveRowRangeFromDOM(this.selectedRange, split);
		if (rowRange == null) {
			console.error({
				rowRange,
				selectedRange: this.selectedRange
			});
			throw new Error("LineSelectionManager.renderSelection: No valid rowRange");
		}
		const isSingle = rowRange.start === rowRange.end;
		const first = Math.min(rowRange.start, rowRange.end);
		const last = Math.max(rowRange.start, rowRange.end);
		for (const code of codeElements) for (const element of code.children) {
			if (!(element instanceof HTMLElement)) continue;
			const lineIndex = this.getLineIndex(element, split);
			if ((lineIndex ?? 0) > last) break;
			if (lineIndex == null || lineIndex < first) continue;
			let attributeValue = isSingle ? "single" : lineIndex === first ? "first" : lineIndex === last ? "last" : "";
			element.setAttribute("data-selected-line", attributeValue);
			if (element.nextSibling instanceof HTMLElement && element.nextSibling.hasAttribute("data-line-annotation")) {
				if (isSingle) {
					attributeValue = "last";
					element.setAttribute("data-selected-line", "first");
				} else if (lineIndex === first) attributeValue = "";
				else if (lineIndex === last) element.setAttribute("data-selected-line", "");
				element.nextSibling.setAttribute("data-selected-line", attributeValue);
			}
		}
	};
	deriveRowRangeFromDOM(range, split) {
		if (range == null) return void 0;
		const start = this.findRowIndexForLineNumber(range.start, range.side, split);
		const end = range.end === range.start && (range.endSide == null || range.endSide === range.side) ? start : this.findRowIndexForLineNumber(range.end, range.endSide ?? range.side, split);
		return start != null && end != null ? {
			start,
			end
		} : void 0;
	}
	findRowIndexForLineNumber(lineNumber, targetSide = "additions", split) {
		if (this.pre == null) return void 0;
		const elements = Array.from(this.pre.querySelectorAll(`[data-line="${lineNumber}"]`));
		elements.push(...Array.from(this.pre.querySelectorAll(`[data-alt-line="${lineNumber}"]`)));
		if (elements.length === 0) return void 0;
		for (const element of elements) {
			if (!(element instanceof HTMLElement)) continue;
			if (this.getLineSideFromElement(element) === targetSide) return this.getLineIndex(element, split);
			else if (parseInt(element.dataset.altLine ?? "") === lineNumber) return this.getLineIndex(element, split);
		}
		console.error("LineSelectionManager.findRowIndexForLineNumber: Invalid selection", lineNumber, targetSide);
	}
	notifySelectionChange() {
		const { onLineSelected } = this.options;
		if (onLineSelected == null) return;
		onLineSelected(this.selectedRange ?? null);
	}
	notifySelectionStart(range) {
		const { onLineSelectionStart } = this.options;
		if (onLineSelectionStart == null) return;
		onLineSelectionStart(range);
	}
	notifySelectionEnd(range) {
		const { onLineSelectionEnd } = this.options;
		if (onLineSelectionEnd == null) return;
		onLineSelectionEnd(range);
	}
	getMouseEventDataForPath(path, eventType) {
		let lineNumber;
		let lineIndex;
		let isNumberColumn = false;
		let eventSide;
		for (const element of path) {
			if (!(element instanceof HTMLElement)) continue;
			if (element.hasAttribute("data-column-number")) {
				isNumberColumn = true;
				continue;
			}
			if (element.hasAttribute("data-line")) {
				lineNumber = this.getLineNumber(element);
				lineIndex = this.getLineIndex(element, this.pre?.dataset.type === "split");
				if (element.dataset.lineType === "change-deletion") eventSide = "deletions";
				else if (element.dataset.lineType === "change-additions") eventSide = "additions";
				if (lineIndex == null || lineNumber == null) {
					lineIndex = void 0;
					lineNumber = void 0;
					break;
				}
				if (eventSide != null) break;
				continue;
			}
			if (element.hasAttribute("data-code")) {
				eventSide ??= element.hasAttribute("data-deletions") ? "deletions" : "additions";
				break;
			}
		}
		if (eventType === "click" && !isNumberColumn || lineIndex == null || lineNumber == null) return;
		return {
			lineIndex,
			lineNumber,
			eventSide: eventSide ?? "additions"
		};
	}
	getLineNumber(element) {
		const lineNumber = parseInt(element.dataset.line ?? "", 10);
		return !Number.isNaN(lineNumber) ? lineNumber : void 0;
	}
	getLineIndex(element, split) {
		const lineIndexes = (element.dataset.lineIndex ?? "").split(",").map((value) => parseInt(value)).filter((value) => !Number.isNaN(value));
		if (split && lineIndexes.length === 2) return lineIndexes[1];
		else if (!split) return lineIndexes[0];
	}
	getLineSideFromElement(element) {
		if (element.dataset.lineType === "change-deletion") return "deletions";
		if (element.dataset.lineType === "change-addition") return "additions";
		const parent = element.closest("[data-code]");
		if (!(parent instanceof HTMLElement)) return "additions";
		return parent.hasAttribute("data-deletions") ? "deletions" : "additions";
	}
};
function pluckLineSelectionOptions({ enableLineSelection, onLineSelected, onLineSelectionStart, onLineSelectionEnd }) {
	return {
		enableLineSelection,
		onLineSelected,
		onLineSelectionStart,
		onLineSelectionEnd
	};
}

//#endregion
export { LineSelectionManager, pluckLineSelectionOptions };
//# sourceMappingURL=LineSelectionManager.js.map