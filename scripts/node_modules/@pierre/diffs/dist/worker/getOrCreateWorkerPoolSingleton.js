import { WorkerPoolManager } from "./WorkerPoolManager.js";

//#region src/worker/getOrCreateWorkerPoolSingleton.ts
let workerPoolSingletone;
function getOrCreateWorkerPoolSingleton({ poolOptions, highlighterOptions }) {
	if (workerPoolSingletone == null) {
		workerPoolSingletone = new WorkerPoolManager(poolOptions, highlighterOptions);
		workerPoolSingletone.initialize();
	}
	return workerPoolSingletone;
}
function terminateWorkerPoolSingleton() {
	if (workerPoolSingletone == null) return;
	workerPoolSingletone.terminate();
	workerPoolSingletone = void 0;
}

//#endregion
export { getOrCreateWorkerPoolSingleton, terminateWorkerPoolSingleton };
//# sourceMappingURL=getOrCreateWorkerPoolSingleton.js.map