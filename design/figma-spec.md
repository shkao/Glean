# Glean UI Design Spec (Figma)

## Figma Setup

### Design System
- Use Apple's official [iOS 18 & iPadOS 18 Design Kit](https://www.figma.com/community/file/1385659531316001292)
- Use Apple's [macOS Design Kit](https://www.figma.com/community/file/1248375255495415511) for Mac-specific screens
- Stick to SF Symbols for icons (searchable at developer.apple.com/sf-symbols)
- Use system semantic colors (label, secondaryLabel, separator, etc.)

### Figma File Structure
```
Glean UI
  Pages:
    - Components (reusable pieces)
    - Import Flow (screenshot + URL import)
    - Ollama Panel (summary, tags, Q&A)
    - Settings (Ollama config)
    - Full Layouts (screens in context)
```

---

## Screen 1: Screenshot Import Sheet

**Presentation:** Modal sheet (iOS) or sheet window (macOS)

### States

#### 1.1 Select Photos (initial)
- Centered layout, vertical stack
- Icon: `photo.on.rectangle.angled` (56pt, secondary color)
- Title: "Select Screenshots" (Title2 bold)
- Subtitle: "Glean will scan your screenshots for URLs and import them as articles." (body, secondary)
- CTA: "Choose Photos" bordered prominent button with `photo.badge.plus` icon
- No navigation bar back button (this is the first step)

#### 1.2 Processing (OCR in progress)
- Centered linear progress bar (300pt wide)
- Label above: "Scanning screenshots..." (headline)
- Label below: percentage (secondary)
- Caption: "Using on-device text recognition" (tertiary)

#### 1.3 Review URLs
Three zones, top to bottom:

**Header bar** (bar background):
- Left: `link` icon + "N URLs found" (subheadline bold)
- Right: "Select All" borderless button

**URL list** (plain list style):
Each row:
- Left: circle checkbox (checkmark.circle.fill when selected, circle when not)
- Middle: hostname (subheadline bold, 1 line) + path (caption, secondary, 1 line)
- Right: "Screenshot N" with photo icon (caption2, tertiary)

**Action bar** (bar background):
- Left: "N selected" (subheadline, secondary)
- Right: "Import Selected" bordered prominent button

#### 1.4 Importing
- Same layout as Processing but:
- Label: "Importing articles..."
- Progress: "3 of 5"
- Caption: "Fetching and extracting content"

#### 1.5 Done
- Centered layout
- Icon: `checkmark.circle.fill` (56pt, green)
- Title: "Import Complete" (Title2 bold)
- Subtitle: "N articles imported to Saved Pages." (body, secondary)
- CTA: "Done" bordered prominent button

---

## Screen 2: URL Import Sheet (Chrome Tabs / Clipboard)

**Presentation:** Modal sheet (iOS) or window (macOS, 500x480)

### Layout (top to bottom)

**Input area:**
- Header row: `doc.on.clipboard` icon + "Paste URLs or text containing URLs" (subheadline bold) + "Paste from Clipboard" bordered small button
- TextEditor (monospaced font, 120-160pt height, rounded border overlay)

**Divider**

**URL preview** (takes remaining space):
- Empty + no input: ContentUnavailableView with `arrow.down.doc`, "Paste URLs"
- Empty + has input: ContentUnavailableView with `link.badge.plus`, "No URLs Found"
- Has URLs: plain list, section header "N URLs detected"
  - Each row: blue `link` icon + hostname (subheadline bold) + path (caption, secondary)

**Divider**

**Action bar** (bar background):
- Left: "N URLs ready to import" (subheadline, secondary)
- Right: "Import All" bordered prominent button

---

## Screen 3: Ollama Article Panel

**Presentation:** Below the article detail WebView. Collapsible. 240-300pt height.

### Tab Bar (bar background)
Left side, three tab buttons:
- `text.quote` Summary
- `tag` Tags
- `bubble.left.and.text.bubble.right` Ask

Right side:
- Green/red dot (6pt) + "Ollama" or "Offline" (caption2, secondary)

Active tab gets `accentColor.opacity(0.1)` background with 6pt corner radius.

### 3.1 Summary Tab

**Empty state:**
- Center text: "Generate a 2-3 sentence summary of this article." (subheadline, secondary)
- Button: "Summarize" with `sparkles` icon (bordered prominent, small)

**Loading:**
- ProgressView (small) + "Generating summary..." (subheadline, secondary)
- Text streams in word by word below

**Complete:**
- Summary text (subheadline, selectable)
- Bottom bar: "Regenerate" (borderless, arrow.clockwise) left, "Copy" (borderless, doc.on.doc) right

### 3.2 Tags Tab

**Empty state:**
- Center text + "Generate Tags" button with `tag` icon

**Loading:**
- ProgressView + "Generating tags..."

**Complete:**
- Flow layout of tag chips
- Each chip: capsule shape, blue text on blue.opacity(0.1) background, blue.opacity(0.2) stroke
- Font: caption, horizontal padding 10, vertical padding 4

### 3.3 Ask Tab

**Upper area** (scrollable):
- Empty: centered `bubble.left.and.text.bubble.right` icon (title2, tertiary) + "Ask a question about this article" (subheadline, secondary)
- With answer: answer text (subheadline, selectable), streams in word by word

**Divider**

**Input bar:**
- TextField "Ask about this article..." (rounded border) + `arrow.up.circle.fill` send button (title2)

### 3.4 Unavailable State (any tab)
- `exclamationmark.triangle` icon (title2, secondary)
- "Ollama is not running" (subheadline bold)
- "Start Ollama on your Mac to use AI features." (caption, secondary)

---

## Screen 4: Ollama Settings

**Presentation:** Tab in Preferences (macOS) or row in Settings (iOS)

### Form Layout

**Section: Connection**
- TextField "Server URL" (rounded border, monospaced URL, no autocorrect)
- HStack: "Check Connection" button + status indicator
  - Checking: ProgressView (small)
  - Connected: green checkmark.circle.fill + "Connected"
  - Failed: red xmark.circle.fill + "Not reachable"

**Section: Model**
- If no models loaded: TextField "Model name"
- If models loaded: Picker dropdown with available model names

**Section: (no header)**
- "Save" bordered prominent button

---

## Color Tokens

| Token | Usage |
|-------|-------|
| `.accentColor` | Primary buttons, active tab highlight |
| `.blue` | Tag chips, URL link icons |
| `.green` | Success states, Ollama online indicator |
| `.red` | Error states, Ollama offline indicator |
| `.orange` | Partial success (some imports failed) |
| `.secondary` | Subtitles, descriptions |
| `.tertiary` | Captions, source labels |
| `.separator` | Dividers, panel border |
| `.bar` | Header/footer backgrounds |

## Typography

All system fonts. No custom typefaces.

| Style | Usage |
|-------|-------|
| `.title2.bold()` | Sheet titles, completion headings |
| `.headline` | Progress labels |
| `.subheadline.bold()` | Section headers, hostnames, tab labels |
| `.subheadline` | Body content, summaries, answers |
| `.caption` | Secondary details, paths, tag text |
| `.caption2` | Source labels, status text |
| `.system(.body, design: .monospaced)` | URL input text editor |

## Spacing

- Panel corner radius: 12pt
- Tag chip corner radius: capsule
- Tab button corner radius: 6pt
- Standard padding: 16pt (system default)
- Compact vertical padding: 4-8pt
- Icon-to-text spacing: 8-12pt

## Animation

- Summary/answer text: word-by-word streaming (40ms per word for summary, 35ms for Q&A)
- Tag chips: appear together after loading
- Progress bars: smooth linear interpolation
- Tab switching: instant (no transition)
