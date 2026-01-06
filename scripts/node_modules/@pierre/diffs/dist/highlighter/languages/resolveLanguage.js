import { ResolvedLanguages, ResolvingLanguages } from "./constants.js";
import { isWorkerContext } from "../../utils/isWorkerContext.js";
import { bundledLanguages } from "shiki";

//#region src/highlighter/languages/resolveLanguage.ts
async function resolveLanguage(lang) {
	if (isWorkerContext()) throw new Error(`resolveLanguage("${lang}") cannot be called from a worker context. Languages must be pre-resolved on the main thread and passed to the worker via the resolvedLanguages parameter.`);
	const resolver = ResolvingLanguages.get(lang);
	if (resolver != null) return resolver;
	try {
		const loader = bundledLanguages[lang];
		if (loader == null) throw new Error(`resolveLanguage: "${lang}" not found in bundled languages`);
		const resolver$1 = loader().then(({ default: data }) => {
			const resolvedLang = {
				name: lang,
				data
			};
			if (!ResolvedLanguages.has(lang)) ResolvedLanguages.set(lang, resolvedLang);
			return resolvedLang;
		});
		ResolvingLanguages.set(lang, resolver$1);
		return await resolver$1;
	} finally {
		ResolvingLanguages.delete(lang);
	}
}

//#endregion
export { resolveLanguage };
//# sourceMappingURL=resolveLanguage.js.map