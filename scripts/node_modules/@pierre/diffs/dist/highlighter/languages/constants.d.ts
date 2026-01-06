import { SupportedLanguages } from "../../types.js";
import { ResolvedLanguage } from "../../worker/types.js";
import "../../worker/index.js";

//#region src/highlighter/languages/constants.d.ts
declare const ResolvedLanguages: Map<SupportedLanguages, ResolvedLanguage>;
declare const ResolvingLanguages: Map<SupportedLanguages, Promise<ResolvedLanguage>>;
declare const AttachedLanguages: Set<string>;
//#endregion
export { AttachedLanguages, ResolvedLanguages, ResolvingLanguages };
//# sourceMappingURL=constants.d.ts.map