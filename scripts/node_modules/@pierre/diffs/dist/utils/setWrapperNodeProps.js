//#region src/utils/setWrapperNodeProps.ts
function setPreNodeProperties({ diffIndicators, disableBackground, disableLineNumbers, overflow, pre, split, themeStyles, themeType, totalLines }) {
	if (themeType === "system") delete pre.dataset.themeType;
	else pre.dataset.themeType = themeType;
	switch (diffIndicators) {
		case "bars":
		case "classic":
			pre.dataset.indicators = diffIndicators;
			break;
		case "none":
			delete pre.dataset.indicators;
			break;
	}
	if (disableLineNumbers) pre.dataset.disableLineNumbers = "";
	else delete pre.dataset.disableLineNumbers;
	if (disableBackground) delete pre.dataset.background;
	else pre.dataset.background = "";
	pre.dataset.type = split ? "split" : "file";
	pre.dataset.overflow = overflow;
	pre.dataset.diffs = "";
	pre.tabIndex = 0;
	pre.style = themeStyles;
	pre.style.setProperty("--diffs-min-number-column-width-default", `${`${totalLines}`.length}ch`);
	return pre;
}

//#endregion
export { setPreNodeProperties };
//# sourceMappingURL=setWrapperNodeProps.js.map