import { ThemesType } from "./types.js";

//#region src/constants.d.ts
declare const DIFFS_TAG_NAME: "diffs-container";
declare const COMMIT_METADATA_SPLIT: RegExp;
declare const GIT_DIFF_FILE_BREAK_REGEX: RegExp;
declare const UNIFIED_DIFF_FILE_BREAK_REGEX: RegExp;
declare const FILE_CONTEXT_BLOB: RegExp;
declare const HUNK_HEADER: RegExp;
declare const SPLIT_WITH_NEWLINES: RegExp;
declare const FILENAME_HEADER_REGEX: RegExp;
declare const FILENAME_HEADER_REGEX_GIT: RegExp;
declare const ALTERNATE_FILE_NAMES_GIT: RegExp;
declare const FILE_MODE_FROM_INDEX: RegExp;
declare const HEADER_METADATA_SLOT_ID = "header-metadata";
declare const DEFAULT_THEMES: ThemesType;
declare const UNSAFE_CSS_ATTRIBUTE = "data-unsafe-css";
declare const CORE_CSS_ATTRIBUTE = "data-core-css";
//#endregion
export { ALTERNATE_FILE_NAMES_GIT, COMMIT_METADATA_SPLIT, CORE_CSS_ATTRIBUTE, DEFAULT_THEMES, DIFFS_TAG_NAME, FILENAME_HEADER_REGEX, FILENAME_HEADER_REGEX_GIT, FILE_CONTEXT_BLOB, FILE_MODE_FROM_INDEX, GIT_DIFF_FILE_BREAK_REGEX, HEADER_METADATA_SLOT_ID, HUNK_HEADER, SPLIT_WITH_NEWLINES, UNIFIED_DIFF_FILE_BREAK_REGEX, UNSAFE_CSS_ATTRIBUTE };
//# sourceMappingURL=constants.d.ts.map