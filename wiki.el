;;; wiki.el --- hypertext authoring the WikiWay

;; Derived from orginal wiki mode by Alex Schroeder.
;; See: https://www.emacswiki.org/emacs/WikiMode
;; Uses font-lock to highlight buffer.
;; All publishing related functions are removed.

;;; Code:

(require 'info); for info-xref face
(require 'thingatpt); for thing-at-point-looking-at and other things

;; Options

(defvar wiki-name-regexp "\\<[A-Z][a-z]+\\([A-Z][a-z]+\\)+\\>"
  "Regexp matching WikiNames.
Whenever the regexp is searched for, case is never ignored:
`case-fold-search' will allways be bound to nil.")
  
(defun wiki-name-p (&optional shortcut)
  "Return non-nil when `point' is at a wiki name.
This modifies the data returned by `match-data'."
  (let ((case-fold-search nil))
    (thing-at-point-looking-at wiki-name-regexp)))

(defun wiki-maybe ()
  "Maybe turn `wiki-mode' on for this file.
This happens when the buffer-file-name matches `wiki-name-regexp'."
  (let ((case-fold-search nil))
    (when (string-match wiki-name-regexp buffer-file-name)
      (wiki-mode))))

(add-hook 'find-file-hooks 'wiki-maybe)

(defun wiki-follow-name-at-point ()
  "Find wiki name at point.
See `wiki-name-p' and `wiki-follow-name'."
  (interactive)
  (if (wiki-name-p)
      (find-file (match-string 0))
    (error "Point is not at a WikiName")))

(defun wiki-follow-name-at-mouse (event)
  "Find wiki name at the mouse position.
See `wiki-follow-name-at-point'."
  (interactive "e")
  (save-excursion
    (mouse-set-point event)
    (wiki-follow-name-at-point)))

(defvar wiki-name-map (make-sparse-keymap)
  "Local keymap used by wiki minor mode while on a WikiName.")
(define-key wiki-name-map (kbd "RET") 'wiki-follow-name-at-point)
(define-key wiki-name-map (kbd "<mouse-2>") 'wiki-follow-name-at-mouse)

(defun wiki-mode ()
  (interactive)
  (push 'mouse-face font-lock-extra-managed-props)
  (push 'keymap font-lock-extra-managed-props)
  (font-lock-add-keywords
   nil
   `((,wiki-name-regexp
      (0 '(face info-xref
		mouse-face highlight
		keymap ,wiki-name-map))))))

;;; wiki.el ends here
