These SVGs contain the world and overhead artwork added for Playground Classics.

Drag the .svg files into a Figma Design canvas. All labels and emoji remain live text; backgrounds, outlines and groups remain editable vector objects. Fonts required: Luckiest Guy, Fredoka One and Arimo. The two runtime emoji bubbles use Roblox's LegacyArial family, backed by Arimo-Regular.ttf in the installed Roblox build.

20 SVG files cover:
- 3 overhead status templates: TAGGED, YOU'RE IT!, STUCK!
- 2 runtime emoji bubbles: star and heart
- 1 shared British Bulldog arena title
- 3 lobby voting stand titles
- 1 shared ROOM 4 plaque
- 2 shared noticeboard papers: CLASS 4B and SPORTS DAY
- 8 shared hopscotch squares

WorldUIManifest.json lists every one of the 30 original native GUI objects and the SVG used for it. Repeated instance names are disambiguated with sibling-indexed locator paths. Identical art is shared across British Bulldog and Tag.

Surface label files include their host part's surface color as a separate editable group for visual context. Billboards are exported visibly, including templates disabled in Studio. Lighting and 3D perspective are omitted.

NativeWorldUISnapshot.json was captured from the Edit data model of Studio a6fea703-0c19-4811-ba3e-0e9f90090fe9 without changing Studio. CaptureWorldUI.luau is the read-only reproducible capture source. ExportWorldUI.py regenerates the SVGs from that snapshot and locally installed Roblox font files. RenderWorldUI.cjs creates optional PNG previews using sharp/libvips.

WorldUI-ContactSheet.png and Preview/*.png are inspection renders. They are not embedded in the SVGs. WorldUIRenderValidation.json records successful rendering of all 20 files.

Text sizing uses the installed Roblox TrueType advance widths to keep SVG lettering inside its authored label boxes. Figma and Roblox can differ slightly in font shaping and baseline placement. Native measurement samples, fonts, colors, positions and size constraints are preserved in the snapshot.

Each SVG also contains optional metadata named playground-text-layers. It lists one record per rendered text line, with viewport-relative coordinates, line-box top, size, font, colors, stroke and alignment. A local text importer can use this data to recreate native Figma TextNodes if drag-import outlines the text. The helper has not been executed by us. Adding this metadata preserved all 20 rendered preview PNG hashes, recorded in WorldUITextMetadataValidation.json.

