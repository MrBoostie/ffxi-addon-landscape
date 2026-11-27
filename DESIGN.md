---
name: FFXI Addon Landscape
description: Community Windower addons from across GitHub, browsed like an in-game menu window.
colors:
  ground: "#060a1c"
  window-top: "#2c418f"
  window-mid: "#1b2868"
  window-bottom: "#141d52"
  frame: "#93a7f5"
  field: "#0b1238"
  field-line: "#8fa3ee"
  field-hover: "#18225c"
  ink: "#f2f5ff"
  ink-2: "#c8d1f5"
  ink-3: "#aeb9e6"
  placeholder: "#a8b3df"
  gold: "#ffe08a"
  link: "#a9d4ff"
  warn: "#ffb4a8"
  warn-2: "#ffcfc7"
  band: "rgba(170,195,255,.26)"
  hover: "rgba(160,185,255,.16)"
  rule: "rgba(160,185,255,.35)"
  crystal-light: "#f4f5ff"
  crystal-earth: "#e9c25b"
  crystal-lightning: "#c78dff"
  crystal-water: "#5f8fff"
  crystal-fire: "#ff6d52"
  crystal-ice: "#93ddff"
  crystal-wind: "#72e294"
  crystal-dark: "#8e93ae"
  set-mint: "#9ff0b8"
typography:
  display:
    fontFamily: "'M PLUS Rounded 1c', ui-rounded, 'Hiragino Maru Gothic ProN', system-ui, sans-serif"
    fontSize: "clamp(28px, 3.4vw, 42px)"
    fontWeight: 800
    lineHeight: 1.1
    letterSpacing: "0.01em"
  headline:
    fontFamily: "'M PLUS Rounded 1c', ui-rounded, 'Hiragino Maru Gothic ProN', system-ui, sans-serif"
    fontSize: "26px"
    fontWeight: 800
    lineHeight: 1.15
  title:
    fontFamily: "'M PLUS Rounded 1c', ui-rounded, 'Hiragino Maru Gothic ProN', system-ui, sans-serif"
    fontSize: "20px"
    fontWeight: 800
    lineHeight: 1.3
  body:
    fontFamily: "'M PLUS Rounded 1c', ui-rounded, 'Hiragino Maru Gothic ProN', system-ui, sans-serif"
    fontSize: "17px"
    fontWeight: 400
    lineHeight: 1.6
    fontFeature: "tnum"
  menu-line:
    fontFamily: "'M PLUS Rounded 1c', ui-rounded, 'Hiragino Maru Gothic ProN', system-ui, sans-serif"
    fontSize: "17px"
    fontWeight: 500
    lineHeight: 1.5
    fontFeature: "tnum"
  label:
    fontFamily: "'M PLUS Rounded 1c', ui-rounded, 'Hiragino Maru Gothic ProN', system-ui, sans-serif"
    fontSize: "14px"
    fontWeight: 700
    lineHeight: 1.5
  meta:
    fontFamily: "'M PLUS Rounded 1c', ui-rounded, 'Hiragino Maru Gothic ProN', system-ui, sans-serif"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.5
    fontFeature: "tnum"
  fine:
    fontFamily: "'M PLUS Rounded 1c', ui-rounded, 'Hiragino Maru Gothic ProN', system-ui, sans-serif"
    fontSize: "13px"
    fontWeight: 400
    lineHeight: 1.5
rounded:
  badge: "4px"
  line: "5px"
  field: "6px"
  window: "8px"
spacing:
  hairline: "1px"
  xs: "6px"
  sm: "10px"
  md: "14px"
  gutter: "18px"
  lg: "20px"
  page: "28px"
  cursor-indent: "34px"
components:
  window:
    backgroundColor: "{colors.window-mid}"
    textColor: "{colors.ink}"
    rounded: "{rounded.window}"
    padding: "14px 10px 16px 8px"
  window-title:
    textColor: "{colors.gold}"
    typography: "{typography.title}"
  menu-line:
    textColor: "{colors.ink}"
    typography: "{typography.menu-line}"
    rounded: "{rounded.line}"
    padding: "8px 10px 8px 4px"
    height: "40px"
  menu-line-hover:
    backgroundColor: "{colors.hover}"
  menu-line-selected:
    backgroundColor: "{colors.band}"
    textColor: "{colors.gold}"
  search-field:
    backgroundColor: "{colors.field}"
    textColor: "{colors.ink}"
    rounded: "{rounded.field}"
    padding: "11px 14px"
    height: "48px"
  select-field:
    backgroundColor: "{colors.field}"
    textColor: "{colors.ink}"
    rounded: "{rounded.field}"
    padding: "6px 8px"
    height: "38px"
  button:
    backgroundColor: "{colors.field}"
    textColor: "{colors.ink}"
    rounded: "{rounded.field}"
    padding: "9px 16px"
    height: "40px"
  button-hover:
    backgroundColor: "{colors.field-hover}"
  chip:
    backgroundColor: "rgba(11,18,56,.6)"
    textColor: "{colors.ink}"
    rounded: "{rounded.line}"
    padding: "5px 9px"
    height: "32px"
  chip-hover:
    backgroundColor: "{colors.hover}"
  auto-badge:
    textColor: "{colors.warn}"
    rounded: "{rounded.badge}"
    padding: "1px 6px"
---

# Design System: FFXI Addon Landscape

## Overview

**Creative North Star: "The Menu Window"**

The catalog is a set of in-game menu windows floating on a night-navy ground. Every region of the page (title, categories, addon list, help, starter sets, research) is the same object: a translucent, top-lit blue panel with a thin periwinkle frame and a faint inner highlight. The player moves a white pointing-hand cursor down a dense list of names, and a help window explains whichever line the cursor rests on. The page is navigated the way a game menu is navigated, arrow keys included.

Density is high and calm: 40px menu lines, a single rounded face at a few weights, gold reserved for window titles, field labels and the selected line, and colour otherwise carried only by the eight elemental crystal marks that identify categories. There is no imagery, no game art, no logo; the world is built entirely from panels, type, a cursor and crystals. The build refuses the category default of a flat dark table with tag pills: category is a crystal glyph drawn in SVG, never a coloured pill on the row.

**Key Characteristics:**
- Every region is a window: same gradient, frame, inner highlight and 8px radius.
- One typeface (M PLUS Rounded 1c) at 400/500/700/800, tabular numerals throughout.
- Gold marks titles and the current selection; nothing else competes with it.
- A bobbing white pointing hand marks the selected category and the selected addon.
- Categories are faceted SVG crystals in eight elemental colours.
- Three-column desktop menu collapses at 900px to stacked windows with the help text opening inline under the picked line.

## Colors

A night-sky field of blues with one warm gold for attention, a coral reserved for risk, and eight crystal hues that only ever appear as small category marks.

### Primary
- **Menu Gold** (`gold`): window titles, the Search label, help sub-lines and section heads ("Get it from"), the selected addon's name, star icons, the "All addons" crystal, text selection background and every focus ring. It is the cursor's colour of attention.

### Secondary
- **Sky Link** (`link`): all hyperlinks (underlined, 3px offset, 1px thickness; white on hover). Also the Advanced starter-set title.

### Tertiary
- **Risk Coral** (`warn`): the outlined "Auto" badge on automation rows, the load-error message, and the "Trying to get banned" set title. **Pale Coral** (`warn-2`) is the softer help-window risk note.
- **Elemental Crystals** (`crystal-*`): one hue per category. Light/QoL (`crystal-light`), Earth/Inventory and gil (`crystal-earth`), Lightning/Automation (`crystal-lightning`), Water/UI and gear (`crystal-water`), Fire/Combat automation (`crystal-fire`), Ice/Diagnostics (`crystal-ice`), Wind/Travel (`crystal-wind`), Dark/Utility (`crystal-dark`). Drawn as a filled gem with a 1px `rgba(255,255,255,.7)` stroke.
- **Set Mint** (`set-mint`): the Beginner starter-set title only.

### Neutral
- **Night Ground** (`ground`): page background and `theme-color`; never used inside a window.
- **Window Blues** (`window-top`, `window-mid`, `window-bottom`): the three stops of the 180deg window gradient (0%, 48%, 100%). `window-bottom` doubles as the hand cursor's outline.
- **Periwinkle Frame** (`frame`): the 1px border of every window.
- **Well Navy** (`field`) with **Field Line** (`field-line`): inputs, selects and buttons sit in a darker recessed well framed in a light blue line. `field-hover` deepens buttons on hover.
- **Ink** (`ink`, `ink-2`, `ink-3`): primary text, secondary text (counts, dates, taglines, set notes), and fine print. `placeholder` is the search placeholder.
- **Band, Hover, Rule** (`band`, `hover`, `rule`): translucent periwinkle overlays for the selected line, hover state, and 1px dividers inside windows.

### Named Rules
**The Gold Is The Cursor Rule.** Gold marks a title or the thing the cursor is on. A new surface gets gold for its window title and its selected item; body copy, metadata and decoration do not.

**The Crystals Only Rule.** The eight elemental hues appear only as crystal marks (9-14px) beside category and addon names. They never fill backgrounds, tint text, or become pills.

## Typography

**Display Font:** M PLUS Rounded 1c (with ui-rounded, Hiragino Maru Gothic ProN, system-ui)
**Body Font:** M PLUS Rounded 1c
**Label/Mono Font:** M PLUS Rounded 1c; numerals are tabular page-wide (`font-variant-numeric: tabular-nums`).

**Character:** A soft, rounded Japanese-UI sans used at heavy weights for titles and medium for menu lines, so the page reads like game interface text rather than a document.

### Hierarchy
- **Display** (800, clamp(28px, 3.4vw, 42px), 1.1, +0.01em): the site name in the title window only.
- **Headline** (800, 26px, 1.15; 21px when the name exceeds 16 characters): the addon name in the help window.
- **Title** (800, 20px, 1.3, gold): window titles; also starter-set names (20px/800, coloured per set).
- **Menu line** (500, 17px addon names / 16px category labels): the list lines. Names truncate with an ellipsis on one line.
- **Body** (400, 17px, 1.6): the help description. Tagline and status text run at 16px.
- **Label** (700, 14-15px, gold): Search label, help sub-line, "Get it from".
- **Meta** (400, 14px, `ink-2`): counts, dates, stars, confidence line, set notes, select text (15px).
- **Fine** (400, 13px, `ink-3`): the affiliation disclaimer.

### Named Rules
**The One Face Rule.** M PLUS Rounded 1c is the only family; hierarchy comes from weight (400/500/700/800) and size, never from a second face.

## Layout

A centred column (max 1380px, 28px padding, 18px gaps) of windows. Desktop: the title window spans the top with the search field right-aligned (flex 1 1 380px, max 560px). Below it a flex row of three windows: Categories (basis 270px, max 300px), the Addon list (dominant, flex-grow 999, basis 460px), and Help (basis 320px, max 420px, `position: sticky; top: 18px`). A lower row holds Starter sets (dominant; an auto-fit grid of 220px-minimum columns, 18px gap) and Research.

The list head is two fixed rows: title plus live tally ("40 of 1,298") on the first, the Updated and Sort selects on the second, so the head never reflows while typing. The list pages in 40s with a "Next N" button.

**The Cursor Gutter Rule.** Every menu line reserves a 24px cursor column plus a 10px gap; window titles and list-head content are indented 34px so text aligns with the line labels, not the cursor.

**Responsive (900px and below).** Page padding drops to 14px; the search label stacks over a full-width input; Categories becomes a single horizontally scrolling row of lines with a right-edge fade mask (cursor shown only on the current category); the Help window is hidden and the help content opens inline beneath the picked line inside the list, behind a 1px rule; the stars column is hidden; the selects split the row width.

## Elevation & Depth

Depth is a single layer: windows float on the night ground, and everything inside a window is flat or recessed. Each window carries a 1px inner white highlight and one soft ambient drop shadow; fields are recessed by colour (a darker well), not by shadow. Selection and hover are translucent tonal bands, not lifts.

### Shadow Vocabulary
- **Window float** (`box-shadow: inset 0 0 0 1px rgba(255,255,255,.14), 0 8px 22px rgba(0,0,0,.5)`): every window, and only windows.

### Named Rules
**The One Float Rule.** Only windows cast a shadow. Lines, chips, buttons and fields never lift; state is shown with `band`/`hover` fills.

## Shapes

Gently rounded, nested by size: windows 8px, fields and buttons 6px, menu lines and chips 5px, the Auto badge 4px. Borders are always 1px: periwinkle on windows, field-line on wells, a 55%-alpha periwinkle on chips, coral on the badge. Internal dividers are 1px `rule` lines. The only non-rectangular forms are the SVG hand cursor, the faceted crystal gem (also the favicon, gold with a window-bottom stroke) and the five-point star.

## Components

### Window
- **Character:** the universal container; title in gold at the top-left, content below.
- **Shape:** 8px radius, 1px `frame` border, gradient `window-top` to `window-mid` (48%) to `window-bottom`, window-float shadow.
- **Padding:** 14-20px depending on the window (list 14/10/16/8; help 18/20/20; sets and research 16/20/18).

### Menu Lines (signature)
- **Character:** the cursor's track; one button per category or addon.
- **Layout:** cursor column (24px), crystal, label (flex 1), then right-aligned metadata (date 76px, stars 58px with a gold star icon). Minimum 40px tall, 5px radius, 1px gaps between lines.
- **States:** hover fills `hover`; selected (`aria-current="true"`) fills `band`, turns the addon name gold, and shows the white hand cursor bobbing +/-2px on a 0.7s alternate loop; focus-visible is a 2px gold outline inset by 2px. Background transitions 0.18s on the house ease.
- **Keyboard:** roving tabindex; ArrowUp/Down, Home, End move the cursor through the list.
- **Auto badge:** a 12px/700 coral-outlined tag on automation and combat-automation rows; the only inline badge a line may carry.

### Help Window (signature)
- Crystal plus headline name, gold sub-line (category, updated date, stars), 17px description, pale-coral risk note on automation categories, a ruled "Get it from" block of repo links, and a 14px confidence/source line. On content change it fades in from 0.4 opacity and 2px blur over 0.25s. Empty state: "Pick an addon to read what it does."

### Buttons
- **Shape:** 6px radius, 1px `field-line` border, `field` fill, 15px text, 9px 16px padding, 40px minimum.
- **Hover / Focus:** fill deepens to `field-hover`; gold focus ring (2px, 2px offset).
- Used for "Next 40" and "Clear search and filters".

### Chips
- **Style:** starter-set addon picks; translucent well fill, 55%-alpha periwinkle border, 5px radius, 14px text, 32px minimum.
- **State:** hover fills `hover`. A chip runs a search for that addon and selects it.

### Inputs / Fields
- **Style:** `field` well, 1px `field-line`, 6px radius. Search: 18px text, 48px tall. Selects: 15px, 38px tall.
- **Focus:** the global 2px gold outline at 2px offset.

### Navigation
- Categories window is the navigation: menu lines with crystal, label and count; "All addons" carries a gold crystal. State is mirrored to the URL hash (`q`, `cat`, `a`). On mobile it becomes a horizontal scroller.

## Do's and Don'ts

### Do:
- **Do** put every new region in a window: gradient, 1px `frame`, inner highlight, 8px radius, gold 20px/800 title.
- **Do** mark the current item with the white pointing-hand cursor and the `band` fill, and keep arrow-key movement.
- **Do** identify a category with its crystal colour and the faceted gem shape.
- **Do** flag automation honestly: the coral Auto badge on the line and the risk note in help.
- **Do** keep numerals tabular and metadata in `ink-2` at 14px.
- **Do** stop the cursor bob, help fade and hover transitions under `prefers-reduced-motion: reduce`.

### Don't:
- **Don't** render categories as coloured tag pills on list rows; the crystal is the category mark.
- **Don't** use gold for body copy or decoration; it belongs to titles, labels and the selection.
- **Don't** add shadows to anything inside a window.
- **Don't** introduce a second typeface, game art, or Square Enix / Windower logos.
