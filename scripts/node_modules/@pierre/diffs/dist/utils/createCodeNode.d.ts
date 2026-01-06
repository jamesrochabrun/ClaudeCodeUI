//#region src/utils/createCodeNode.d.ts
interface CreateCodeNodeProps {
  pre?: HTMLPreElement;
  columnType?: "additions" | "deletions" | "unified";
}
declare function createCodeNode({
  pre,
  columnType
}?: CreateCodeNodeProps): HTMLElement;
//#endregion
export { createCodeNode };
//# sourceMappingURL=createCodeNode.d.ts.map