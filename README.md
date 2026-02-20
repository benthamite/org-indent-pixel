# org-indent-pixel

Pixel-accurate `wrap-prefix` for variable-pitch Org buffers.

## The problem

When `org-indent-mode` and `buffer-face-mode` (with a variable-pitch face) are both active, list item continuation lines become progressively misaligned at deeper nesting levels:

```
- Level 1 text that wraps to the next
  line aligns correctly (small error)
  - Level 2 text that wraps starts to
     drift rightward
    - Level 3 text wraps even further
        off from where it should be
```

This happens because `org-indent-mode` sets `wrap-prefix` using fixed-width space characters, but variable-pitch fonts have different space widths. The error compounds with each nesting level.

## The fix

`org-indent-pixel-mode` advises `org-indent-set-line-properties` to replace the space-based `wrap-prefix` with a pixel-accurate specification. It measures the actual rendered width of the line content (including display properties from packages like [org-modern](https://github.com/minad/org-modern)) in the variable-pitch font, then sets `wrap-prefix` to an exact pixel value.

## Requirements

- GUI Emacs (the mode is a no-op in terminal Emacs, where all characters have the same width)
- Emacs 29.1 or later (for `string-pixel-width`)
- Org 9.6 or later
- `buffer-face-mode` or `variable-pitch-mode` active in the Org buffer

**Note**: users of [mixed-pitch](https://gitlab.com/jabranham/mixed-pitch) do not need this package. `mixed-pitch` applies variable-pitch faces to individual text runs rather than setting `buffer-face-mode`, so the indentation area stays fixed-pitch and the space-based prefix from `org-indent-mode` remains accurate.

## Installation

### With `use-package` and `elpaca`

```elisp
(use-package org-indent-pixel
  :ensure (:host github :repo "benthamite/org-indent-pixel")
  :init
  (org-indent-pixel-setup))
```

### With `use-package` and `package-vc`

```elisp
(use-package org-indent-pixel
  :vc (:url "https://github.com/benthamite/org-indent-pixel")
  :init
  (org-indent-pixel-setup))
```

### Manual

Clone this repository and add it to your `load-path`:

```elisp
(add-to-list 'load-path "/path/to/org-indent-pixel")
(require 'org-indent-pixel)
(org-indent-pixel-setup)
```

## Usage

`org-indent-pixel-setup` (shown in the installation examples above) is the recommended way to activate the mode. It hooks into `org-mode-hook` and `buffer-face-mode-hook` so that `org-indent-pixel-mode` is enabled automatically whenever both `org-indent-mode` and `buffer-face-mode` are active in an Org buffer.

If you prefer manual control, you can enable the mode directly:

```
M-x org-indent-pixel-mode
```

Or use an unconditional hook (only appropriate if all your Org buffers use both `org-indent-mode` and `buffer-face-mode`):

```elisp
(add-hook 'org-mode-hook #'org-indent-pixel-mode)
```

## How it works

1. Advises `org-indent-set-line-properties` with `:after` advice
2. For each non-heading line with indentation, extracts the buffer text from the beginning of the line to the body start column
3. Preserves display properties (e.g., org-modern's bullet replacements) for accurate measurement
4. Applies the buffer's variable-pitch face to the extracted string
5. Measures pixel widths using `string-pixel-width`
6. Sets `wrap-prefix` to `(space :width (N))` where N is the exact pixel width

When the mode is deactivated, it removes the advice and triggers `org-indent` to reprocess all lines, restoring the original space-based prefixes.
