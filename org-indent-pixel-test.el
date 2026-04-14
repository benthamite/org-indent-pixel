;;; org-indent-pixel-test.el --- Tests for org-indent-pixel -*- lexical-binding: t; -*-

;;; Commentary:

;; ERT test suite for `org-indent-pixel'.

;;; Code:

(require 'ert)
(require 'org-indent-pixel)

;;;; Helpers

(defmacro org-indent-pixel-test--with-org-buffer (content &rest body)
  "Insert CONTENT into a temporary Org buffer and evaluate BODY."
  (declare (indent 1))
  `(with-temp-buffer
     (org-mode)
     (insert ,content)
     (goto-char (point-min))
     ,@body))

;;;; org-indent-pixel--string-pixel-width

(ert-deftest org-indent-pixel-test-string-pixel-width-empty ()
  "Return zero for an empty string."
  (should (= 0 (org-indent-pixel--string-pixel-width ""))))

(ert-deftest org-indent-pixel-test-string-pixel-width-nonempty ()
  "Return a positive integer for a non-empty string in batch mode."
  (let ((w (org-indent-pixel--string-pixel-width "hello")))
    (should (integerp w))
    (should (> w 0))))

(ert-deftest org-indent-pixel-test-string-pixel-width-longer-is-wider ()
  "A longer string should produce a wider pixel measurement."
  (let ((short (org-indent-pixel--string-pixel-width "hi"))
        (long (org-indent-pixel--string-pixel-width "hello world")))
    (should (> long short))))

;;;; org-indent-pixel--kill-work-buffer

(ert-deftest org-indent-pixel-test-kill-work-buffer-when-exists ()
  "Kill the work buffer when it exists."
  (get-buffer-create org-indent-pixel--work-buffer-name)
  (should (get-buffer org-indent-pixel--work-buffer-name))
  (org-indent-pixel--kill-work-buffer)
  (should-not (get-buffer org-indent-pixel--work-buffer-name)))

(ert-deftest org-indent-pixel-test-kill-work-buffer-when-absent ()
  "Do nothing when the work buffer does not exist."
  (when (get-buffer org-indent-pixel--work-buffer-name)
    (kill-buffer org-indent-pixel--work-buffer-name))
  (org-indent-pixel--kill-work-buffer)
  (should-not (get-buffer org-indent-pixel--work-buffer-name)))

;;;; org-indent-pixel--fix-line

(ert-deftest org-indent-pixel-test-fix-line-skips-headings ()
  "Do not modify wrap-prefix when HEADING is non-nil."
  (org-indent-pixel-test--with-org-buffer "* Heading\n"
    (let ((org-indent-pixel-mode t)
          (buffer-face-mode t))
      (goto-char (point-min))
      (put-text-property (point) (line-end-position) 'wrap-prefix "  ")
      (put-text-property (point) (line-end-position) 'line-prefix " ")
      (forward-line 1)
      (org-indent-pixel--fix-line 1 2 t)
      (goto-char (point-min))
      (should (equal "  " (get-text-property (point) 'wrap-prefix))))))

(ert-deftest org-indent-pixel-test-fix-line-skips-zero-indentation ()
  "Do not modify wrap-prefix when INDENTATION is zero."
  (org-indent-pixel-test--with-org-buffer "some text\n"
    (let ((org-indent-pixel-mode t)
          (buffer-face-mode t))
      (goto-char (point-min))
      (put-text-property (point) (line-end-position) 'wrap-prefix "  ")
      (put-text-property (point) (line-end-position) 'line-prefix " ")
      (forward-line 1)
      (org-indent-pixel--fix-line 1 0)
      (goto-char (point-min))
      (should (equal "  " (get-text-property (point) 'wrap-prefix))))))

(ert-deftest org-indent-pixel-test-fix-line-skips-without-buffer-face-mode ()
  "Do not modify wrap-prefix when `buffer-face-mode' is off."
  (org-indent-pixel-test--with-org-buffer "  - item\n"
    (let ((org-indent-pixel-mode t)
          (buffer-face-mode nil))
      (goto-char (point-min))
      (put-text-property (point) (line-end-position) 'wrap-prefix "    ")
      (put-text-property (point) (line-end-position) 'line-prefix "  ")
      (forward-line 1)
      (org-indent-pixel--fix-line 1 4)
      (goto-char (point-min))
      (should (equal "    " (get-text-property (point) 'wrap-prefix))))))

(ert-deftest org-indent-pixel-test-fix-line-skips-without-mode ()
  "Do not modify wrap-prefix when `org-indent-pixel-mode' is off."
  (org-indent-pixel-test--with-org-buffer "  - item\n"
    (let ((org-indent-pixel-mode nil)
          (buffer-face-mode t))
      (goto-char (point-min))
      (put-text-property (point) (line-end-position) 'wrap-prefix "    ")
      (put-text-property (point) (line-end-position) 'line-prefix "  ")
      (forward-line 1)
      (org-indent-pixel--fix-line 1 4)
      (goto-char (point-min))
      (should (equal "    " (get-text-property (point) 'wrap-prefix))))))

(ert-deftest org-indent-pixel-test-fix-line-skips-equal-prefix-lengths ()
  "Do not modify wrap-prefix when it equals line-prefix length.
The function only acts when wrap-prefix is longer than line-prefix."
  (org-indent-pixel-test--with-org-buffer "  - item\n"
    (let ((org-indent-pixel-mode t)
          (buffer-face-mode t))
      (goto-char (point-min))
      (put-text-property (point) (line-end-position) 'wrap-prefix "  ")
      (put-text-property (point) (line-end-position) 'line-prefix "  ")
      (forward-line 1)
      (org-indent-pixel--fix-line 1 2)
      (goto-char (point-min))
      (should (equal "  " (get-text-property (point) 'wrap-prefix))))))

;;;; org-indent-pixel--maybe-activate

(ert-deftest org-indent-pixel-test-maybe-activate-non-org-buffer ()
  "Do not activate in a non-Org buffer."
  (with-temp-buffer
    (fundamental-mode)
    (let ((org-indent-mode t)
          (buffer-face-mode t)
          (org-indent-pixel-mode nil))
      (org-indent-pixel--maybe-activate)
      (should-not (bound-and-true-p org-indent-pixel-mode)))))

;;;; org-indent-pixel-setup / org-indent-pixel-teardown

(ert-deftest org-indent-pixel-test-setup-adds-hooks ()
  "Verify `org-indent-pixel-setup' adds hooks to `org-mode-hook'
and `buffer-face-mode-hook'."
  (unwind-protect
      (progn
        (remove-hook 'org-mode-hook #'org-indent-pixel--maybe-activate)
        (remove-hook 'buffer-face-mode-hook #'org-indent-pixel--maybe-activate)
        (cl-letf (((symbol-function 'display-graphic-p) (lambda (&rest _) t)))
          (org-indent-pixel-setup))
        (should (memq #'org-indent-pixel--maybe-activate org-mode-hook))
        (should (memq #'org-indent-pixel--maybe-activate
                      buffer-face-mode-hook)))
    (remove-hook 'org-mode-hook #'org-indent-pixel--maybe-activate)
    (remove-hook 'buffer-face-mode-hook #'org-indent-pixel--maybe-activate)))

(ert-deftest org-indent-pixel-test-teardown-removes-hooks ()
  "Verify `org-indent-pixel-teardown' removes hooks."
  (unwind-protect
      (progn
        (add-hook 'org-mode-hook #'org-indent-pixel--maybe-activate)
        (add-hook 'buffer-face-mode-hook #'org-indent-pixel--maybe-activate)
        (org-indent-pixel-teardown)
        (should-not (memq #'org-indent-pixel--maybe-activate org-mode-hook))
        (should-not (memq #'org-indent-pixel--maybe-activate
                          buffer-face-mode-hook)))
    (remove-hook 'org-mode-hook #'org-indent-pixel--maybe-activate)
    (remove-hook 'buffer-face-mode-hook #'org-indent-pixel--maybe-activate)))

;;;; Buffer count tracking

(ert-deftest org-indent-pixel-test-buffer-count-initial ()
  "Buffer count starts at zero."
  (should (= 0 org-indent-pixel--buffer-count)))

;;;; Work buffer constant

(ert-deftest org-indent-pixel-test-work-buffer-name-is-hidden ()
  "The work buffer name starts with a space, making it hidden."
  (should (string-prefix-p " " org-indent-pixel--work-buffer-name)))

;;;; Work buffer creation via string-pixel-width

(ert-deftest org-indent-pixel-test-string-pixel-width-creates-work-buffer ()
  "Calling `org-indent-pixel--string-pixel-width' creates the work buffer."
  (when (get-buffer org-indent-pixel--work-buffer-name)
    (kill-buffer org-indent-pixel--work-buffer-name))
  (org-indent-pixel--string-pixel-width "test")
  (should (get-buffer org-indent-pixel--work-buffer-name))
  (kill-buffer org-indent-pixel--work-buffer-name))

;;;; Empty buffer edge case

(ert-deftest org-indent-pixel-test-fix-line-empty-buffer ()
  "Do not error on an empty Org buffer."
  (org-indent-pixel-test--with-org-buffer ""
    (let ((org-indent-pixel-mode t)
          (buffer-face-mode t))
      (goto-char (point-min))
      (org-indent-pixel--fix-line 1 2))))

;;;; Feature provision

(ert-deftest org-indent-pixel-test-feature-provided ()
  "The `org-indent-pixel' feature is provided."
  (should (featurep 'org-indent-pixel)))

(provide 'org-indent-pixel-test)
;;; org-indent-pixel-test.el ends here
