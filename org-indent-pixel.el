;;; org-indent-pixel.el --- Pixel-accurate wrap-prefix for variable-pitch Org buffers -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Pablo Stafforini

;; Author: Pablo Stafforini <pablo@stafforini.com>
;; Maintainer: Pablo Stafforini <pablo@stafforini.com>
;; URL: https://github.com/benthamite/org-indent-pixel
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1") (org "9.6"))
;; Keywords: outlines, faces

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Fix misaligned wrapped lines in variable-pitch Org buffers.
;;
;; When `org-indent-mode' and `buffer-face-mode' (with a variable-pitch
;; face) are both active, list item continuation lines become progressively
;; misaligned at deeper nesting levels.  This happens because `org-indent'
;; sets `wrap-prefix' using fixed-width space characters, but
;; variable-pitch fonts have different space widths.
;;
;; `org-indent-pixel-mode' fixes this by advising
;; `org-indent-set-line-properties' to replace the space-based
;; `wrap-prefix' with a pixel-accurate specification.  It measures the
;; actual rendered width of the line-prefix and buffer content (including
;; display properties from packages like `org-modern') in the
;; variable-pitch font, then sets `wrap-prefix' to an exact pixel value.

;;; Code:

(require 'org)
(require 'org-indent)

(defgroup org-indent-pixel nil
  "Pixel-accurate wrap-prefix for variable-pitch Org buffers."
  :group 'org-indent
  :prefix "org-indent-pixel-")

(defun org-indent-pixel--string-pixel-width (string)
  "Like `string-pixel-width' but with the calling buffer's face remapping.
`string-pixel-width' uses an internal work buffer that lacks the
calling buffer's `face-remapping-alist', so faces that inherit from
`default' resolve to the monospace font instead of the variable-pitch
font of `buffer-face-mode'."
  (if (zerop (length string))
      0
    (let ((remapping face-remapping-alist))
      (with-current-buffer (get-buffer-create " *org-indent-pixel*")
        (setq face-remapping-alist remapping
              line-prefix nil
              wrap-prefix nil)
        (setq-local display-line-numbers nil)
        (delete-region (point-min) (point-max))
        (insert (propertize string 'line-prefix nil 'wrap-prefix nil))
        (car (buffer-text-pixel-size nil nil t))))))

(defun org-indent-pixel--fix-line (_level indentation &optional heading)
  "Fix `wrap-prefix' on the current line.
Replace the space-based `wrap-prefix' set by
`org-indent-set-line-properties' with a pixel-accurate specification.

_LEVEL is ignored.  INDENTATION is the target column for the body text.
When HEADING is non-nil the line is a heading and is skipped."
  (when (and (bound-and-true-p org-indent-pixel-mode)
             (bound-and-true-p buffer-face-mode)
             (not heading)
             (> indentation 0))
    (save-excursion
      ;; `org-indent-set-line-properties' calls `forward-line' at the end,
      ;; so point is now at the beginning of the NEXT line.
      (forward-line -1)
      (let ((lp (get-text-property (point) 'line-prefix))
            (wp (get-text-property (point) 'wrap-prefix)))
        (when (and (stringp wp) (stringp lp)
                   (> (length wp) (length lp)))
          (let* ((bol (line-beginning-position))
                 (next-bol (line-beginning-position 2))
                 (body-start (save-excursion
                               (goto-char bol)
                               (move-to-column indentation)
                               (point)))
                 (s (buffer-substring bol body-start))
                 (len (length s)))
            (when (> len 0)
              (remove-text-properties
               0 len '(line-prefix nil wrap-prefix nil fontified nil) s)
              (let* ((text-px (org-indent-pixel--string-pixel-width s))
                     (lp-px (org-indent-pixel--string-pixel-width lp))
                     (total-px (+ lp-px text-px)))
                (when (> total-px 0)
                  (put-text-property
                   bol (min next-bol (point-max))
                   'wrap-prefix
                   (propertize " " 'display
                               `(space :width (,total-px)))))))))))))

;;;###autoload
(define-minor-mode org-indent-pixel-mode
  "Pixel-accurate wrap-prefix for variable-pitch Org buffers.

When enabled, replace the space-based `wrap-prefix' from
`org-indent-mode' with pixel specifications so that list item
continuation lines align correctly in variable-pitch fonts."
  :lighter nil
  (if org-indent-pixel-mode
      (if (not (display-graphic-p))
          (progn
            (setq org-indent-pixel-mode nil)
            (message "org-indent-pixel-mode requires a graphical display"))
        (advice-add 'org-indent-set-line-properties
                    :after #'org-indent-pixel--fix-line)
        (when org-indent-mode
          (org-indent-add-properties (point-min) (point-max))))
    (advice-remove 'org-indent-set-line-properties
                   #'org-indent-pixel--fix-line)
    (when org-indent-mode
      (org-indent-add-properties (point-min) (point-max)))))

(defun org-indent-pixel--maybe-activate ()
  "Activate `org-indent-pixel-mode' when conditions are met.
Intended for use in `org-mode-hook' and `buffer-face-mode-hook'."
  (when (and (bound-and-true-p org-indent-mode)
             (bound-and-true-p buffer-face-mode)
             (not (bound-and-true-p org-indent-pixel-mode)))
    (org-indent-pixel-mode 1)))

;;;###autoload
(defun org-indent-pixel-setup ()
  "Set up hooks to activate `org-indent-pixel-mode' automatically.
Call this once in your init file to enable `org-indent-pixel-mode'
in all Org buffers that use both `org-indent-mode' and
`buffer-face-mode'."
  (when (display-graphic-p)
    (add-hook 'org-mode-hook #'org-indent-pixel--maybe-activate 90)
    (add-hook 'buffer-face-mode-hook #'org-indent-pixel--maybe-activate)))

(provide 'org-indent-pixel)
;;; org-indent-pixel.el ends here
