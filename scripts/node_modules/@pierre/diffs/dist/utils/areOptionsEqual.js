import { DEFAULT_THEMES } from "../constants.js";
import { areThemesEqual } from "./areThemesEqual.js";
import { areObjectsEqual } from "./areObjectsEqual.js";

//#region src/utils/areOptionsEqual.ts
function areOptionsEqual(optionsA, optionsB) {
	return areThemesEqual(optionsA?.theme ?? DEFAULT_THEMES, optionsB?.theme ?? DEFAULT_THEMES) && areObjectsEqual(optionsA, optionsB, ["theme"]);
}

//#endregion
export { areOptionsEqual };
//# sourceMappingURL=areOptionsEqual.js.map