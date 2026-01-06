//#region src/managers/UniversalRenderingManager.ts
const queuedCallbacks = /* @__PURE__ */ new Set();
let callbacks = /* @__PURE__ */ new Set();
let frameId = null;
let isRendering = false;
function queueRender(callback) {
	if (isRendering) {
		queuedCallbacks.add(callback);
		return;
	}
	callbacks.add(callback);
	frameId ??= requestAnimationFrame(render);
}
function render(time) {
	isRendering = true;
	for (const callback of callbacks) try {
		callback(time);
	} catch (error) {
		console.error(error);
	}
	callbacks.clear();
	if (queuedCallbacks.size > 0) {
		callbacks = new Set(queuedCallbacks);
		queuedCallbacks.clear();
		frameId = requestAnimationFrame(render);
	} else frameId = null;
	isRendering = false;
}

//#endregion
export { queueRender };
//# sourceMappingURL=UniversalRenderingManager.js.map