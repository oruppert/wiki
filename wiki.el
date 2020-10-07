;;; wiki.el --- hypertext authoring the WikiWay

;; Copyright (C) 2001, 2002, 2012  Alex Schroeder <alex@gnu.org>

;; Emacs Lisp Archive Entry
;; Filename: wiki.el
;; Version: 2.1.10
;; Keywords: hypermedia
;; Author: Alex Schroeder <alex@gnu.org>
;; Maintainer: Alex Schroeder <alex@gnu.org>
;; Description: Hypertext authoring the WikiWay
;; URL: http://www.emacswiki.org/cgi-bin/wiki.pl?WikiMode

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify it under
;; the terms of the GNU General Public License as published by the Free Software
;; Foundation, either version 3 of the License, or (at your option) any later
;; version.
;;
;; This program is distributed in the hope that it will be useful, but WITHOUT
;; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
;; FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
;; details.
;;
;; You should have received a copy of the GNU General Public License along with
;; GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Wiki is a hypertext and a content management system: Normal users are
;; encouraged to enhance the hypertext by editing and refactoring
;; existing pages and by adding more pages.  This is made easy by
;; requiring a certain way of writing pages.  It is not as complicated
;; as a markup language such as HTML.  The general idea is to write
;; plain ASCII.  Word with mixed case such as ThisOne are WikiNames --
;; they may be a Link or they may not.  If they are, clicking them will
;; take you to the page with that WikiName; if they are not, clicking
;; them will create an empty page for you to fill out.

;; This mode does all of this for you without using a web browser, cgi
;; scripts, databases, etc.  All you need is Emacs!  In order to
;; install, put wiki.el on you load-path, and add the following to your
;; .emacs file:

;; (require 'wiki)

;; This will activate WikiMode for all files in `wiki-directories' as soon
;; as they are opened.  This works by adding `wiki-maybe' to
;; `find-file-hooks'.

;; Emacs provides the functionality usually found on Wiki web sites
;; automatically: To find out how many pages have links to your page,
;; use `grep' or `dired-do-search'.  To get an index of all wikis, use
;; `dired'.  To keep old versions around, use `version-control' or use
;; `vc-next-action'.  To edit wikis, use Emacs!

;; You can publish a wiki using `wiki-publish', or you can use
;; `dired-do-wiki-publish' to publish marked wikis from dired, or you
;; can use `wiki-publish-all' to publish all wikis and write an index
;; file.  This will translate your plain text wikis into HTML according
;; to the rules defined in `wiki-pub-rules'.

;; Find out more: Take a look at http://c2.com/cgi/wiki?StartingPoints

;;; What about a Major Mode?

;; By default, wiki files will be in `fundamental-mode'.  I prefer to be
;; in `text-mode', instead.  You can do this either for all files that
;; have WikiNames by changing `auto-mode-alist', or you can make
;; text-mode the default mode instead of fundamental mode.  Example:

;; (setq default-major-mode 'text-mode)

;; This puts wiki files in `text-mode'.  One problem remains, however.
;; Text mode usually means that the apostrophe is considered to be part
;; of words, and some WikiNames will not be highlighted correctly, such
;; as "WikiName''''s".  In that case, change the syntax table, if you
;; don't mind the side effects.  Example:

;; (modify-syntax-entry ?' "." text-mode-syntax-table)

;;; Thanks

;; Frank Gerhardt <Frank.Gerhardt@web.de>, author of the original wiki-mode.
;;   His latest version is here: http://www.s.netic.de/fg/wiki-mode/wiki.el
;; Thomas Link <t.link@gmx.at>
;; John Wiegley <johnw@gnu.org>, author of emacs-wiki.el.
;;   His latest version is here: http://www.emacswiki.org/emacs/EmacsWikiMode
;; and evolved into Emacs Muse: http://www.emacswiki.org/emacs/EmacsMuse

 

;;; Code:

(require 'easy-mmode); for easy-mmode-define-minor-mode
(require 'info); for info-xref face
(require 'thingatpt); for thing-at-point-looking-at and other things
(require 'compile); for grep-command
(load "goto-addr" t t); optional, for goto-address-mail-regexp

;; Options

(defgroup wiki nil
  "Options controlling the behaviour of Wiki Mode.
See `wiki-mode' for more information.")

;; Paste from rcirc, whatever
(defvar wiki-url-regexp
  (concat
   "\\b\\(\\(www\\.\\|\\(s?https?\\|ftp\\|file\\|gopher\\|"
   "nntp\\|news\\|telnet\\|wais\\|mailto\\|info\\):\\)"
   "\\(//[-a-z0-9_.]+:[0-9]*\\)?"
   (if (string-match "[[:digit:]]" "1") ;; Support POSIX?
       (let ((chars "-a-z0-9_=#$@~%&*+\\/[:word:]")
	     (punct "!?:;.,"))
	 (concat
	  "\\(?:"
	  ;; Match paired parentheses, e.g. in Wikipedia URLs:
	  "[" chars punct "]+" "(" "[" chars punct "]+" "[" chars "]*)" "[" chars "]"
	  "\\|"
	  "[" chars punct     "]+" "[" chars "]"
	  "\\)"))
     (concat ;; XEmacs 21.4 doesn't support POSIX.
      "\\([-a-z0-9_=!?#$@~%&*+\\/:;.,]\\|\\w\\)+"
      "\\([-a-z0-9_=#$@~%&*+\\/]\\|\\w\\)"))
   "\\)")
  "Regexp matching URLs.")

(defcustom wiki-name-regexp "\\<[A-Z][a-z]+\\([A-Z][a-z]+\\)+\\>"
  "Regexp matching WikiNames.
Whenever the regexp is searched for, case is never ignored:
`case-fold-search' will allways be bound to nil.

See `wiki-no-name-p' if you want to exclude certain matches.
See `wiki-name-no-more' if highlighting is not removed correctly."
  :group 'wiki-link
  :type 'regexp)
  
(defun wiki-name-p (&optional shortcut)
  "Return non-nil when `point' is at a true wiki name.
A true wiki name matches `wiki-name-regexp' and doesn't trigger
`wiki-no-name-p'.  In addition to that, it may not be equal to the
current filename.  This modifies the data returned by `match-data'.

If optional argument SHORTCUT is non-nil, we assume that
`wiki-name-regexp' has just been searched for.  Note that the potential
wiki name must be available via `match-string'."
  (let ((case-fold-search nil))
    (and (or shortcut (thing-at-point-looking-at wiki-name-regexp))
	 (or (not buffer-file-name)
	     (not (string-equal (wiki-page-name) (match-string 0))))
	 (not (save-match-data
		(save-excursion
		  (wiki-no-name-p)))))))

(defun wiki-maybe ()
  "Maybe turn `wiki-mode' on for this file.
This happens when the buffer-file-name matches `wiki-name-regexp'."
  (let ((case-fold-search nil))
    (if (string-match wiki-name-regexp buffer-file-name)
	(wiki-mode 1)
      (wiki-mode 0))))

(add-hook 'find-file-hooks 'wiki-maybe)

;; The minor mode (this is what you get)

(defvar wiki-local-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") 'wiki-follow-name-at-point)
    (define-key map (kbd "<mouse-2>") 'wiki-follow-name-at-mouse)
    map)
  "Local keymap used by wiki minor mode while on a WikiName.")

(defvar wiki-mode-map
  (let ((map (make-sparse-keymap)))
    map)
  "Keymap used by wiki minor mode.")

(easy-mmode-define-minor-mode
 wiki-mode
 "Wiki mode transform all WikiNames into links.

Wiki is a hypertext and a content management system: Normal users are
encouraged to enhance the hypertext by editing and refactoring existing
wikis and by adding more.  This is made easy by requiring a certain way
of writing the wikis.  It is not as complicated as a markup language
such as HTML.  The general idea is to write plain ASCII.

Words with mixed case such as ThisOne are WikiNames.  WikiNames are
links you can follow.  If a wiki with that name exists, you will be
taken there.  If such a does not exist, following the link will create a
new wiki for you to fill.  WikiNames for non-existing wikis have a `?'
appended so that you can see wether following the link will give you any
informatin or not.

In order to follow a link, hit RET when point is on the link, or use
mouse-2.

All wikis reside in `wiki-directories'.

\\{wiki-mode-map}"
 nil
 " Wiki"
 wiki-mode-map)

(add-hook 'wiki-mode-on-hook 'wiki-install)
(add-hook 'wiki-mode-on-hook 'wiki-highlight-buffer)
(add-hook 'wiki-mode-on-hook (lambda () (setq indent-tabs-mode nil)))

(add-hook 'wiki-mode-off-hook 'wiki-deinstall)
(add-hook 'wiki-mode-off-hook 'wiki-remove-overlays)

(when (fboundp 'goto-address)
  (add-hook 'wiki-highlight-buffer-hook 'goto-address))

;; Following hyperlinks

(defun wiki-follow-name (name)
  "Follow the link NAME by invoking `wiki-follow-name-action'."
  (find-file name))
  
(defun wiki-follow-name-at-point ()
  "Find wiki name at point.
See `wiki-name-p' and `wiki-follow-name'."
  (interactive)
  (if (wiki-name-p)
      (wiki-follow-name (match-string 0))
    (error "Point is not at a WikiName")))

(defun wiki-follow-name-at-mouse (event)
  "Find wiki name at the mouse position.
See `wiki-follow-name-at-point'."
  (interactive "e")
  (save-excursion
    (mouse-set-point event)
    (wiki-follow-name-at-point)))



;; Overlays

(defun wiki-make-overlay (from to map)
  "Make an overlay for the range [FROM, TO) in the current buffer.
MAP is the local keymap to use, if any."
  (let ((overlay (make-overlay from to)))
    (overlay-put overlay 'face 'info-xref)
    (overlay-put overlay 'mouse-face 'highlight)
    (when map
      (overlay-put overlay 'local-map map))
    (overlay-put overlay 'evaporate t)
    (overlay-put overlay 'wikiname t)
    overlay))


(defun wiki-remove-overlays (&optional start end)
  "Delete all extents/overlays created by `wiki-make-overlay'.
If optional arguments START and END are given, only the overlays in that
region will be deleted."
  (unless start (setq start (point-min)))
  (unless end (setq end (point-max)))
  (let (overlay (overlays (overlays-in start end)))
    (while overlays
      (setq overlay (car overlays)
	    overlays (cdr overlays))
      (when (overlay-get overlay 'wikiname)
	(delete-overlay overlay)))))

(provide 'wiki)

;;; wiki.el ends here
