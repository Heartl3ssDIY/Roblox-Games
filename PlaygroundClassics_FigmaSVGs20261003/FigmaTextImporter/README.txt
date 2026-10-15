Optional helper: real editable text in Figma

The SVG files can be dragged into Figma directly. Their shapes remain vectors.
If that import converts the lettering into outlines, use this local development
plugin to rebuild labels as native editable TextNodes.

1. In Figma Design, open Plugins > Development > Import plugin from manifest.
   Select manifest.json in this folder.
   If Figma asks for a plugin ID, create a new development plugin and copy its
   Figma-assigned "id" into this manifest. No publishing is required.
2. Run Playground Classics · Editable Text Importer in your desired file.
3. Choose one or more SVGs from this package, then click Import.

Import creates frames on the current page and places editable text over the
original vector shapes. It does not replace existing artwork. Undo reverses an
import. Multiline labels remain separate text layers for each rendered line.
You can select every frame or label in Figma and edit its appearance.

A temporary viewport rectangle prevents Figma from shrinking a sparse SVG
after text is removed. The helper deletes that rectangle before completing
the import, and keeps the frame at the SVG's original width and height. If
Figma does not retain its marker name, that file is skipped and reported.

Scroll and panel clipping stays editable as nested transparent frames with
Clip content enabled. Labels outside those frames remain hidden until you
move them or change the clipping. Countdown rotation uses its original SVG
center, rather than rotating around a text layer's top-left corner.

For matching typography, make Luckiest Guy Regular, Fredoka One Regular and
Arimo Regular available to Figma. Missing fonts use Inter Regular and are
reported in the plugin. Font metrics can differ, so inspect line placement
after importing, especially when a fallback was used.

This helper reads only the SVG files you choose. Its manifest forbids external
network access. It does not send data or create new pages. No Figma actions
occur until you click Import. SVG text metadata is required; older SVGs without
it should use ordinary drag-and-drop import.

The plugin was checked locally for JavaScript syntax and mocked import behavior.
It has not been run inside Figma in this task.

API references:
https://developers.figma.com/docs/plugins/api/figma/
https://developers.figma.com/docs/plugins/api/TextNode/
https://developers.figma.com/docs/plugins/manifest/
