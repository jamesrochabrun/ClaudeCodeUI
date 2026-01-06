import { DiffLineAnnotation, FileContents, FileDiffMetadata } from "../types.js";
import { FileDiffOptions } from "../components/FileDiff.js";

//#region src/ssr/preloadDiffs.d.ts
interface PreloadDiffOptions<LAnnotation> {
  fileDiff?: FileDiffMetadata;
  oldFile?: FileContents;
  newFile?: FileContents;
  options?: FileDiffOptions<LAnnotation>;
  annotations?: DiffLineAnnotation<LAnnotation>[];
}
declare function preloadDiffHTML<LAnnotation = undefined>({
  fileDiff,
  oldFile,
  newFile,
  options,
  annotations
}: PreloadDiffOptions<LAnnotation>): Promise<string>;
interface PreloadMultiFileDiffOptions<LAnnotation> {
  oldFile: FileContents;
  newFile: FileContents;
  options?: FileDiffOptions<LAnnotation>;
  annotations?: DiffLineAnnotation<LAnnotation>[];
}
interface PreloadMultiFileDiffResult<LAnnotation> {
  oldFile: FileContents;
  newFile: FileContents;
  options?: FileDiffOptions<LAnnotation>;
  annotations?: DiffLineAnnotation<LAnnotation>[];
  prerenderedHTML: string;
}
declare function preloadMultiFileDiff<LAnnotation = undefined>({
  oldFile,
  newFile,
  options,
  annotations
}: PreloadMultiFileDiffOptions<LAnnotation>): Promise<PreloadMultiFileDiffResult<LAnnotation>>;
interface PreloadFileDiffOptions<LAnnotation> {
  fileDiff: FileDiffMetadata;
  options?: FileDiffOptions<LAnnotation>;
  annotations?: DiffLineAnnotation<LAnnotation>[];
}
interface PreloadFileDiffResult<LAnnotation> {
  fileDiff: FileDiffMetadata;
  options?: FileDiffOptions<LAnnotation>;
  annotations?: DiffLineAnnotation<LAnnotation>[];
  prerenderedHTML: string;
}
declare function preloadFileDiff<LAnnotation = undefined>({
  fileDiff,
  options,
  annotations
}: PreloadFileDiffOptions<LAnnotation>): Promise<PreloadFileDiffResult<LAnnotation>>;
interface PreloadPatchDiffOptions<LAnnotation> {
  patch: string;
  options?: FileDiffOptions<LAnnotation>;
  annotations?: DiffLineAnnotation<LAnnotation>[];
}
interface PreloadPatchDiffResult<LAnnotation> {
  patch: string;
  options?: FileDiffOptions<LAnnotation>;
  annotations?: DiffLineAnnotation<LAnnotation>[];
  prerenderedHTML: string;
}
declare function preloadPatchDiff<LAnnotation = undefined>({
  patch,
  options,
  annotations
}: PreloadPatchDiffOptions<LAnnotation>): Promise<PreloadPatchDiffResult<LAnnotation>>;
//#endregion
export { PreloadDiffOptions, PreloadFileDiffOptions, PreloadFileDiffResult, PreloadMultiFileDiffOptions, PreloadMultiFileDiffResult, PreloadPatchDiffOptions, PreloadPatchDiffResult, preloadDiffHTML, preloadFileDiff, preloadMultiFileDiff, preloadPatchDiff };
//# sourceMappingURL=preloadDiffs.d.ts.map