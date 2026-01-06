import { SVGSpriteNames } from "../sprite.js";
import { Element, ElementContent, Properties, Root, Text } from "hast";

//#region src/utils/hast_utils.d.ts
declare function createTextNodeElement(value: string): Text;
interface CreateHastElementProps {
  tagName: "span" | "div" | "code" | "pre" | "slot" | "svg" | "use" | "style" | "template";
  children?: ElementContent[];
  properties?: Properties;
}
declare function createHastElement({
  tagName,
  children,
  properties
}: CreateHastElementProps): Element;
interface CreateIconProps {
  name: SVGSpriteNames;
  width?: number;
  height?: number;
  properties?: Properties;
}
declare function createIconElement({
  name,
  width,
  height,
  properties
}: CreateIconProps): Element;
declare function findCodeElement(nodes: Root | Element): Element | undefined;
//#endregion
export { createHastElement, createIconElement, createTextNodeElement, findCodeElement };
//# sourceMappingURL=hast_utils.d.ts.map