import { FileDiff } from "../../components/FileDiff.js";
import { areOptionsEqual } from "../../utils/areOptionsEqual.js";
import { WorkerPoolContext } from "../WorkerPoolContext.js";
import { useStableCallback } from "./useStableCallback.js";
import { useCallback, useContext, useEffect, useLayoutEffect, useRef } from "react";

//#region src/react/utils/useFileDiffInstance.ts
const useIsometricEffect = typeof window === "undefined" ? useEffect : useLayoutEffect;
function useFileDiffInstance({ oldFile, newFile, fileDiff, options, lineAnnotations, selectedLines, prerenderedHTML }) {
	const poolManager = useContext(WorkerPoolContext);
	const instanceRef = useRef(null);
	const ref = useStableCallback((fileContainer) => {
		if (fileContainer != null) {
			if (instanceRef.current != null) throw new Error("useFileDiffInstance: An instance should not already exist when a node is created");
			instanceRef.current = new FileDiff(options, poolManager, true);
			instanceRef.current.hydrate({
				fileDiff,
				oldFile,
				newFile,
				fileContainer,
				lineAnnotations,
				prerenderedHTML
			});
		} else {
			if (instanceRef.current == null) throw new Error("useFileDiffInstance: A FileDiff instance should exist when unmounting");
			instanceRef.current.cleanUp();
			instanceRef.current = null;
		}
	});
	useIsometricEffect(() => {
		if (instanceRef.current == null) return;
		const instance = instanceRef.current;
		const forceRender = !areOptionsEqual(instance.options, options);
		instance.setOptions(options);
		instance.render({
			forceRender,
			fileDiff,
			oldFile,
			newFile,
			lineAnnotations
		});
		if (selectedLines !== void 0) instance.setSelectedLines(selectedLines);
	});
	return {
		ref,
		getHoveredLine: useCallback(() => {
			return instanceRef.current?.getHoveredLine();
		}, [])
	};
}

//#endregion
export { useFileDiffInstance };
//# sourceMappingURL=useFileDiffInstance.js.map