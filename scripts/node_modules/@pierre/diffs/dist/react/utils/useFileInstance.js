import { File } from "../../components/File.js";
import { areOptionsEqual } from "../../utils/areOptionsEqual.js";
import { WorkerPoolContext } from "../WorkerPoolContext.js";
import { useStableCallback } from "./useStableCallback.js";
import { useCallback, useContext, useEffect, useLayoutEffect, useRef } from "react";

//#region src/react/utils/useFileInstance.ts
const useIsometricEffect = typeof window === "undefined" ? useEffect : useLayoutEffect;
function useFileInstance({ file, options, lineAnnotations, selectedLines, prerenderedHTML }) {
	const poolManager = useContext(WorkerPoolContext);
	const instanceRef = useRef(null);
	const ref = useStableCallback((node) => {
		if (node != null) {
			if (instanceRef.current != null) throw new Error("File: An instance should not already exist when a node is created");
			instanceRef.current = new File(options, poolManager, true);
			instanceRef.current.hydrate({
				file,
				fileContainer: node,
				lineAnnotations,
				prerenderedHTML
			});
		} else {
			if (instanceRef.current == null) throw new Error("File: A File instance should exist when unmounting");
			instanceRef.current.cleanUp();
			instanceRef.current = null;
		}
	});
	useIsometricEffect(() => {
		if (instanceRef.current == null) return;
		const forceRender = !areOptionsEqual(instanceRef.current.options, options);
		instanceRef.current.setOptions(options);
		instanceRef.current.render({
			file,
			lineAnnotations,
			forceRender
		});
		if (selectedLines !== void 0) instanceRef.current.setSelectedLines(selectedLines);
	});
	return {
		ref,
		getHoveredLine: useCallback(() => {
			return instanceRef.current?.getHoveredLine();
		}, [])
	};
}

//#endregion
export { useFileInstance };
//# sourceMappingURL=useFileInstance.js.map