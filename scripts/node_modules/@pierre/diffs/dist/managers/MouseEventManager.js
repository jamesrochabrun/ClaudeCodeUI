//#region src/managers/MouseEventManager.ts
function isLineEventData(data, mode) {
	if (data == null) return false;
	if (mode === "file") return data.type === "line";
	else return data.type === "diff-line";
}
function isExpandoEventData(data) {
	return data?.type === "line-info";
}
var MouseEventManager = class {
	hoveredLine;
	pre;
	hoverSlot;
	constructor(mode, options) {
		this.mode = mode;
		this.options = options;
	}
	setOptions(options) {
		this.options = options;
	}
	cleanUp() {
		this.pre?.removeEventListener("click", this.handleMouseClick);
		this.pre?.removeEventListener("pointermove", this.handleMouseMove);
		this.pre?.removeEventListener("pointerout", this.handleMouseLeave);
		delete this.pre?.dataset.interactiveLines;
		delete this.pre?.dataset.interactiveLineNumbers;
		this.pre = void 0;
	}
	setup(pre) {
		const { __debugMouseEvents, onLineClick, onLineNumberClick, onLineEnter, onLineLeave, onHunkExpand, enableHoverUtility = false } = this.options;
		this.cleanUp();
		this.pre = pre;
		if (enableHoverUtility && this.hoverSlot == null) {
			this.hoverSlot = document.createElement("div");
			this.hoverSlot.dataset.hoverSlot = "";
			const slotElement = document.createElement("slot");
			slotElement.name = "hover-slot";
			this.hoverSlot.appendChild(slotElement);
		} else if (!enableHoverUtility && this.hoverSlot != null) {
			this.hoverSlot.parentNode?.removeChild(this.hoverSlot);
			this.hoverSlot = void 0;
		}
		if (onLineClick != null || onLineNumberClick != null || onHunkExpand != null) {
			pre.addEventListener("click", this.handleMouseClick);
			if (onLineClick != null) pre.dataset.interactiveLines = "";
			else if (onLineNumberClick != null) pre.dataset.interactiveLineNumbers = "";
			debugLogIfEnabled(__debugMouseEvents, "click", "FileDiff.DEBUG.attachEventListeners: Attaching click events for:", (() => {
				const reasons = [];
				if (__debugMouseEvents === "both" || __debugMouseEvents === "click") {
					if (onLineClick != null) reasons.push("onLineClick");
					if (onLineNumberClick != null) reasons.push("onLineNumberClick");
					if (onHunkExpand != null) reasons.push("expandable hunk separators");
				}
				return reasons;
			})());
		}
		if (onLineEnter != null || onLineLeave != null || enableHoverUtility) {
			pre.addEventListener("pointermove", this.handleMouseMove);
			debugLogIfEnabled(__debugMouseEvents, "move", "FileDiff.DEBUG.attachEventListeners: Attaching pointer move event");
			pre.addEventListener("pointerleave", this.handleMouseLeave);
			debugLogIfEnabled(__debugMouseEvents, "move", "FileDiff.DEBUG.attachEventListeners: Attaching pointer leave event");
		}
	}
	getHoveredLine = () => {
		if (this.hoveredLine != null) {
			if (this.mode === "diff" && this.hoveredLine.type === "diff-line") return {
				lineNumber: this.hoveredLine.lineNumber,
				side: this.hoveredLine.annotationSide
			};
			if (this.mode === "file" && this.hoveredLine.type === "line") return { lineNumber: this.hoveredLine.lineNumber };
		}
	};
	handleMouseClick = (event) => {
		debugLogIfEnabled(this.options.__debugMouseEvents, "click", "FileDiff.DEBUG.handleMouseClick:", event);
		this.handleMouseEvent({
			eventType: "click",
			event
		});
	};
	handleMouseMove = (event) => {
		debugLogIfEnabled(this.options.__debugMouseEvents, "move", "FileDiff.DEBUG.handleMouseMove:", event);
		this.handleMouseEvent({
			eventType: "move",
			event
		});
	};
	handleMouseLeave = (event) => {
		const { __debugMouseEvents } = this.options;
		debugLogIfEnabled(__debugMouseEvents, "move", "FileDiff.DEBUG.handleMouseLeave: no event");
		if (this.hoveredLine == null) {
			debugLogIfEnabled(__debugMouseEvents, "move", "FileDiff.DEBUG.handleMouseLeave: returned early, no .hoveredLine");
			return;
		}
		this.hoverSlot?.parentElement?.removeChild(this.hoverSlot);
		this.options.onLineLeave?.({
			...this.hoveredLine,
			event
		});
		this.hoveredLine = void 0;
	};
	handleMouseEvent({ eventType, event }) {
		const { __debugMouseEvents } = this.options;
		const composedPath = event.composedPath();
		debugLogIfEnabled(__debugMouseEvents, eventType, "FileDiff.DEBUG.handleMouseEvent:", {
			eventType,
			composedPath
		});
		const data = this.getLineData(composedPath);
		debugLogIfEnabled(__debugMouseEvents, eventType, "FileDiff.DEBUG.handleMouseEvent: getLineData result:", data);
		const { onLineClick, onLineNumberClick, onLineEnter, onLineLeave, onHunkExpand } = this.options;
		switch (eventType) {
			case "move":
				if (isLineEventData(data, this.mode) && this.hoveredLine?.lineElement === data.lineElement) {
					debugLogIfEnabled(__debugMouseEvents, "move", "FileDiff.DEBUG.handleMouseEvent: switch, 'move', returned early because same line");
					break;
				}
				if (this.hoveredLine != null) {
					debugLogIfEnabled(__debugMouseEvents, "move", "FileDiff.DEBUG.handleMouseEvent: switch, 'move', clearing an existing hovered line and firing onLineLeave");
					this.hoverSlot?.parentElement?.removeChild(this.hoverSlot);
					onLineLeave?.({
						...this.hoveredLine,
						event
					});
					this.hoveredLine = void 0;
				}
				if (isLineEventData(data, this.mode)) {
					debugLogIfEnabled(__debugMouseEvents, "move", "FileDiff.DEBUG.handleMouseEvent: switch, 'move', setting up a new hoveredLine and firing onLineEnter");
					this.hoveredLine = data;
					if (this.hoverSlot != null) data.numberElement?.appendChild(this.hoverSlot);
					onLineEnter?.({
						...this.hoveredLine,
						event
					});
				}
				break;
			case "click":
				debugLogIfEnabled(__debugMouseEvents, "click", "FileDiff.DEBUG.handleMouseEvent: switch, 'click', with data:", data);
				if (data == null) break;
				if (isExpandoEventData(data) && onHunkExpand != null) {
					debugLogIfEnabled(__debugMouseEvents, "click", "FileDiff.DEBUG.handleMouseEvent: switch, 'click', expanding a hunk");
					onHunkExpand(data.hunkIndex, data.direction);
					break;
				}
				if (isLineEventData(data, this.mode)) if (onLineNumberClick != null && data.numberColumn) {
					debugLogIfEnabled(__debugMouseEvents, "click", "FileDiff.DEBUG.handleMouseEvent: switch, 'click', firing 'onLineNumberClick'");
					onLineNumberClick({
						...data,
						event
					});
				} else if (onLineClick != null) {
					debugLogIfEnabled(__debugMouseEvents, "click", "FileDiff.DEBUG.handleMouseEvent: switch, 'click', firing 'onLineClick'");
					onLineClick({
						...data,
						event
					});
				} else debugLogIfEnabled(__debugMouseEvents, "click", "FileDiff.DEBUG.handleMouseEvent: switch, 'click', fell through, no event to fire");
				break;
		}
	}
	getLineData(path) {
		let numberColumn = false;
		const lineElement = path.find((element) => {
			if (!(element instanceof HTMLElement)) return false;
			numberColumn = numberColumn || "columnNumber" in element.dataset;
			return "line" in element.dataset || "expandIndex" in element.dataset;
		});
		if (!(lineElement instanceof HTMLElement)) return void 0;
		if (lineElement.dataset.expandIndex != null) {
			const hunkIndex = parseInt(lineElement.dataset.expandIndex);
			if (isNaN(hunkIndex)) return;
			let direction;
			for (const element of path) {
				if (element === lineElement) break;
				if (element instanceof HTMLElement) {
					direction = direction ?? ("expandUp" in element.dataset ? "up" : void 0) ?? ("expandDown" in element.dataset ? "down" : void 0) ?? ("expandBoth" in element.dataset ? "both" : void 0);
					if (direction != null) break;
				}
			}
			return direction != null ? {
				type: "line-info",
				hunkIndex,
				direction
			} : void 0;
		}
		const lineNumber = parseInt(lineElement.dataset.line ?? "");
		if (isNaN(lineNumber)) return;
		const lineType = lineElement.dataset.lineType;
		if (lineType !== "context" && lineType !== "context-expanded" && lineType !== "change-deletion" && lineType !== "change-addition") return;
		const numberElement = (() => {
			const numberElement$1 = lineElement.children[0];
			return numberElement$1 instanceof HTMLElement && numberElement$1.dataset.columnNumber != null ? numberElement$1 : void 0;
		})();
		if (this.mode === "file") return {
			type: "line",
			lineElement,
			lineNumber,
			numberElement,
			numberColumn
		};
		return {
			type: "diff-line",
			annotationSide: (() => {
				if (lineType === "change-deletion") return "deletions";
				if (lineType === "change-addition") return "additions";
				const parent = lineElement.closest("[data-code]");
				if (!(parent instanceof HTMLElement)) return "additions";
				return "deletions" in parent.dataset ? "deletions" : "additions";
			})(),
			lineType,
			lineElement,
			numberElement,
			lineNumber,
			numberColumn
		};
	}
};
function debugLogIfEnabled(debugLogType = "none", logIfType, ...args) {
	switch (debugLogType) {
		case "none": return;
		case "both": break;
		case "click":
			if (logIfType !== "click") return;
			break;
		case "move":
			if (logIfType !== "move") return;
			break;
	}
	console.log(...args);
}
function pluckMouseEventOptions({ onLineClick, onLineNumberClick, onLineEnter, onLineLeave, enableHoverUtility, __debugMouseEvents }, onHunkExpand) {
	return {
		onLineClick,
		onLineNumberClick,
		onLineEnter,
		onLineLeave,
		enableHoverUtility,
		__debugMouseEvents,
		onHunkExpand
	};
}

//#endregion
export { MouseEventManager, pluckMouseEventOptions };
//# sourceMappingURL=MouseEventManager.js.map