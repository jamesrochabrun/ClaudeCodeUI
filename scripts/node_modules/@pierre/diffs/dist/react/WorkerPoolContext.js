'use client';


import { getOrCreateWorkerPoolSingleton, terminateWorkerPoolSingleton } from "../worker/getOrCreateWorkerPoolSingleton.js";
import { jsx } from "react/jsx-runtime";
import { createContext, useContext, useEffect, useInsertionEffect, useState } from "react";

//#region src/react/WorkerPoolContext.tsx
const WorkerPoolContext = createContext(void 0);
let instanceCount = 0;
function WorkerPoolContextProvider({ children, poolOptions, highlighterOptions }) {
	const [poolManager] = useState(() => {
		if (typeof window === "undefined") return;
		return getOrCreateWorkerPoolSingleton({
			poolOptions,
			highlighterOptions
		});
	});
	useInsertionEffect(() => {
		instanceCount++;
		return () => {
			instanceCount--;
		};
	}, []);
	useEffect(() => {
		return () => {
			if (instanceCount === 0) terminateWorkerPoolSingleton();
		};
	}, []);
	return /* @__PURE__ */ jsx(WorkerPoolContext.Provider, {
		value: poolManager,
		children
	});
}
function useWorkerPool() {
	return useContext(WorkerPoolContext);
}

//#endregion
export { WorkerPoolContext, WorkerPoolContextProvider, useWorkerPool };
//# sourceMappingURL=WorkerPoolContext.js.map