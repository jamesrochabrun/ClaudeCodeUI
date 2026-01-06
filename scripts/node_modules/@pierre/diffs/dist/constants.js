//#region src/constants.ts
const DIFFS_TAG_NAME = "diffs-container";
const COMMIT_METADATA_SPLIT = /(?=^From [a-f0-9]+ .+$)/m;
const GIT_DIFF_FILE_BREAK_REGEX = /(?=^diff --git)/gm;
const UNIFIED_DIFF_FILE_BREAK_REGEX = /(?=^---\s+\S)/gm;
const FILE_CONTEXT_BLOB = /(?=^@@ )/gm;
const HUNK_HEADER = /^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@(?: (.*))?/m;
const SPLIT_WITH_NEWLINES = /(?<=\n)/;
const FILENAME_HEADER_REGEX = /^(---|\+\+\+)\s+([^\t\r\n]+)/;
const FILENAME_HEADER_REGEX_GIT = /^(---|\+\+\+)\s+[ab]\/([^\t\r\n]+)/;
const ALTERNATE_FILE_NAMES_GIT = /^diff --git (?:"a\/(.+?)"|a\/(.+?)) (?:"b\/(.+?)"|b\/(.+?))$/;
const FILE_MODE_FROM_INDEX = /^index (?:[0-9a-f]+)\.\.(?:[0-9a-f]+)(?: (\d+))?/;
const HEADER_METADATA_SLOT_ID = "header-metadata";
const DEFAULT_THEMES = {
	dark: "pierre-dark",
	light: "pierre-light"
};
const UNSAFE_CSS_ATTRIBUTE = "data-unsafe-css";
const CORE_CSS_ATTRIBUTE = "data-core-css";

//#endregion
export { ALTERNATE_FILE_NAMES_GIT, COMMIT_METADATA_SPLIT, CORE_CSS_ATTRIBUTE, DEFAULT_THEMES, DIFFS_TAG_NAME, FILENAME_HEADER_REGEX, FILENAME_HEADER_REGEX_GIT, FILE_CONTEXT_BLOB, FILE_MODE_FROM_INDEX, GIT_DIFF_FILE_BREAK_REGEX, HEADER_METADATA_SLOT_ID, HUNK_HEADER, SPLIT_WITH_NEWLINES, UNIFIED_DIFF_FILE_BREAK_REGEX, UNSAFE_CSS_ATTRIBUTE };
//# sourceMappingURL=constants.js.map