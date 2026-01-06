import { DiffsThemeNames, FileContents, FileDiffMetadata, LanguageRegistration, LineDiffTypes, RenderDiffOptions, RenderFileOptions, SupportedLanguages, ThemeRegistrationResolved, ThemedDiffResult, ThemedFileResult, ThemesType } from "../types.js";

//#region src/worker/types.d.ts
type WorkerRequestId = string;
interface WorkerRenderingOptions {
  theme: DiffsThemeNames | ThemesType;
  tokenizeMaxLineLength: number;
  lineDiffType: LineDiffTypes;
}
interface FileRendererInstance {
  onHighlightSuccess(file: FileContents, result: ThemedFileResult, options: RenderFileOptions): unknown;
  onHighlightError(error: unknown): unknown;
}
interface DiffRendererInstance {
  onHighlightSuccess(diff: FileDiffMetadata, result: ThemedDiffResult, options: RenderDiffOptions): unknown;
  onHighlightError(error: unknown): unknown;
}
interface RenderFileRequest {
  type: "file";
  id: WorkerRequestId;
  file: FileContents;
  resolvedLanguages?: ResolvedLanguage[];
}
interface RenderDiffRequest {
  type: "diff";
  id: WorkerRequestId;
  diff: FileDiffMetadata;
  resolvedLanguages?: ResolvedLanguage[];
}
interface InitializeWorkerRequest {
  type: "initialize";
  id: WorkerRequestId;
  renderOptions: WorkerRenderingOptions;
  resolvedThemes: ThemeRegistrationResolved[];
  resolvedLanguages?: ResolvedLanguage[];
}
interface ResolvedLanguage {
  name: Exclude<SupportedLanguages, "text">;
  data: LanguageRegistration[];
}
interface SetRenderOptionsWorkerRequest {
  type: "set-render-options";
  id: WorkerRequestId;
  renderOptions: WorkerRenderingOptions;
  resolvedThemes: ThemeRegistrationResolved[];
}
type SubmitRequest = Omit<RenderFileRequest, "id"> | Omit<RenderDiffRequest, "id">;
type WorkerRequest = RenderFileRequest | RenderDiffRequest | InitializeWorkerRequest | SetRenderOptionsWorkerRequest;
interface RenderFileSuccessResponse {
  type: "success";
  requestType: "file";
  id: WorkerRequestId;
  result: ThemedFileResult;
  options: RenderFileOptions;
  sentAt: number;
}
interface RenderDiffSuccessResponse {
  type: "success";
  requestType: "diff";
  id: WorkerRequestId;
  result: ThemedDiffResult;
  options: RenderDiffOptions;
  sentAt: number;
}
interface InitializeSuccessResponse {
  type: "success";
  requestType: "initialize";
  id: WorkerRequestId;
  sentAt: number;
}
interface RegisterThemeSuccessResponse {
  type: "success";
  requestType: "set-render-options";
  id: WorkerRequestId;
  sentAt: number;
}
interface RenderErrorResponse {
  type: "error";
  id: WorkerRequestId;
  error: string;
  stack?: string;
}
type RenderSuccessResponse = RenderFileSuccessResponse | RenderDiffSuccessResponse;
type WorkerResponse = RenderSuccessResponse | RenderErrorResponse | InitializeSuccessResponse | RegisterThemeSuccessResponse;
interface WorkerPoolOptions {
  /**
  * Factory function that creates a new Web Worker instance for the pool.
  * This is called once per worker in the pool during initialization.
  */
  workerFactory: () => Worker;
  /**
  * Number of workers to create in the pool.
  * @default 8
  */
  poolSize?: number;
  totalASTLRUCacheSize?: number;
}
interface WorkerInitializationRenderOptions extends Partial<WorkerRenderingOptions> {
  langs?: SupportedLanguages[];
}
interface InitializeWorkerTask {
  type: "initialize";
  id: WorkerRequestId;
  request: InitializeWorkerRequest;
  resolve(value?: undefined): void;
  reject(error: Error): void;
  requestStart: number;
}
interface SetRenderOptionsWorkerTask {
  type: "set-render-options";
  id: WorkerRequestId;
  request: SetRenderOptionsWorkerRequest;
  resolve(value?: undefined): void;
  reject(error: Error): void;
  requestStart: number;
}
interface RenderFileTask {
  type: "file";
  id: WorkerRequestId;
  request: RenderFileRequest;
  instance: FileRendererInstance;
  requestStart: number;
}
interface RenderDiffTask {
  type: "diff";
  id: WorkerRequestId;
  request: RenderDiffRequest;
  instance: DiffRendererInstance;
  requestStart: number;
}
type AllWorkerTasks = InitializeWorkerTask | SetRenderOptionsWorkerTask | RenderFileTask | RenderDiffTask;
interface WorkerStats {
  totalWorkers: number;
  busyWorkers: number;
  queuedTasks: number;
  pendingTasks: number;
}
//#endregion
export { AllWorkerTasks, DiffRendererInstance, FileRendererInstance, InitializeSuccessResponse, InitializeWorkerRequest, InitializeWorkerTask, RegisterThemeSuccessResponse, RenderDiffRequest, RenderDiffSuccessResponse, RenderDiffTask, RenderErrorResponse, RenderFileRequest, RenderFileSuccessResponse, RenderFileTask, RenderSuccessResponse, ResolvedLanguage, SetRenderOptionsWorkerRequest, SetRenderOptionsWorkerTask, SubmitRequest, WorkerInitializationRenderOptions, WorkerPoolOptions, WorkerRenderingOptions, WorkerRequest, WorkerRequestId, WorkerResponse, WorkerStats };
//# sourceMappingURL=types.d.ts.map