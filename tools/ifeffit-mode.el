;;; ifeffit-macro.el --- a major mode for editing ifeffit macro files
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Author:  Bruce Ravel <ravel@phys.washington.edu>
;; Maintainer:  Bruce Ravel <ravel@phys.washington.edu>
;; Created:  23 December 1999
;; Updated:  31 December 2006
;; Version:  see `ifm-cvs-version'
;; Keywords:  ifeffit, macro
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; This file is not part of GNU Emacs.
;;
;; Copyright (C) 1999-2007 Bruce Ravel
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, 675 Massachusettes Ave,
;; Cambridge, MA 02139, USA.
;;
;; Everyone is granted permission to copy, modify and redistribute this
;; and related files provided:
;;   1. All copies contain this copyright notice.
;;   2. All modified copies shall carry a prominant notice stating who
;;      made modifications and the date of such modifications.
;;   3. The name of the modified file be changed.
;;   4. No charge is made for this software or works derived from it.
;;      This clause shall not be construed as constraining other software
;;      distributed on the same medium as this software, nor is a
;;      distribution fee considered a charge.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Installation:
;;
;;  Put this file in your lisp load-path and byte compile it.  Add the
;;  following to your .emacs file
;;
;;     (autoload 'ifm-mode "ifeffit-macro" "ifm mode." t)
;;
;;  then put something like
;;      ## -*- mode: ifm -*-
;;  as the first line in a file containing ifeffit macro definitions
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; Commentary:
;;
;;  This is a simple editing mode for files containing ifeffit-macros.
;;  It just defines some syntax colorization and some indentation
;;  rules and provides command completion and some simple information
;;  about commands.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; History:
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;; To do:
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Code:

(require 'cl)

(eval-and-compile
  (condition-case ()
      (require 'custom)
    (error nil))
  (if (and (featurep 'custom) (fboundp 'custom-declare-variable))
      nil ;; We've got what we needed
    ;; We have the old custom-library, hack around it!
    (if (fboundp 'defgroup)
        nil
      (defmacro defgroup (&rest args)
        nil))
    (if (fboundp 'defface)
        nil
      (defmacro defface (var values doc &rest args)
        (` (progn
             (defvar (, var) (quote (, var)))
             ;; To make colors for your faces you need to set your .Xdefaults
             ;; or set them up ahead of time in your .emacs file.
             (make-face (, var))
             ))))
    (if (fboundp 'defcustom)
        nil
      (defmacro defcustom (var value doc &rest args)
        (` (defvar (, var) (, value) (, doc)))))))

(defconst ifm-cvs-version
  "$Id:$ ")
(defconst ifm-version          "pre-release")
  ;;(substring ifm-cvs-version 14 17) )
(defconst ifm-author           "Bruce Ravel")
(defconst ifm-maintainer-email "ravel@phys.washington.edu")
(defconst ifm-url              "http://cars.uchicago.edu/~newville/ifeffit")

(defgroup ifm nil
  "Ifeffit macro editing mode for Emacs."
  :prefix "ifm-"
  :group 'local)

(defcustom ifm-mode-hook nil
  "*Hook run when ifm minor mode is entered."
  :group 'ifm
  :type 'hook)
(defcustom ifm-load-hook nil
  "*Hook run when ifeffit-macro.el is first loaded."
  :group 'ifm
  :type 'hook)

(defcustom ifm-macro-indent 0
  "*Amount to indent macro begin and end lines."
  :group 'ifm
  :type 'integer)
(defcustom ifm-macro-contents-indent 3
  "*Amount to indent macro contents."
  :group 'ifm
  :type 'integer)
(defcustom ifm-macro-continuation-additional-indent 8
  "*Additional indentation for continuation lines."
  :group 'ifm
  :type 'integer)
(defcustom ifm-commands-buffer-name "*Ifeffit-commands*"
  "Name of buffer used to display list of Ifeffit commands."
  :group 'atp
  :type 'string)


(defvar ifm-mode-map nil)
(if ifm-mode-map
    ()
  (setq ifm-mode-map (make-sparse-keymap))
  (define-key ifm-mode-map "\t"       'ifm-indent-line)
  (define-key ifm-mode-map "\C-c\C-m" 'ifm-insert-block)
  (define-key ifm-mode-map "\M-\t"    'ifm-complete-command)
  (define-key ifm-mode-map "\M-?"     'ifm-describe-command)
  (define-key ifm-mode-map "\C-c\C-k" 'ifm-display-commands)
  )

(defvar ifm-mode-menu nil)
(defvar ifm-menu nil
  "Menu for ifeffit-macros mode.")
(setq ifm-menu
      '("IFM"
	["Insert macro block"   ifm-insert-block       t]
	["Describe command"     ifm-describe-command   t]
	["Display all commands" ifm-display-commands   t]
	"---"
	["Version"              ifm-identify           t]
	))


(defvar ifm-mode-syntax-table nil
  "Syntax table in use in `ifm-mode' buffers.")
(if ifm-mode-syntax-table
    ()
  (setq ifm-mode-syntax-table (make-syntax-table))
  (modify-syntax-entry ?_  "w"   ifm-mode-syntax-table)
  (modify-syntax-entry ?.  "w"   ifm-mode-syntax-table)
  (modify-syntax-entry ?$  "w"   ifm-mode-syntax-table)
  )


;; (insert (regexp-quote (make-regexp '("color" "comment" "cursor" "echo"
;; 		       "erase" "exit" "feffit" "ff2chi" "fftf"
;; 		       "fftr" "findee" "guess" "history" "load"
;; 		       "minimize" "newplot" "path" "pause"
;; 		       "plot" "print" "quit" "reset" "set"
;; 		       "show" "sync" "rename" "zoom" "spline"
;; 		       "pre_edge" "read_data"
;; 		       "write_data" "exit" "quit" "cursor"
;; 		       "minimize")))	)


(defvar ifm-font-lock-keywords nil)
(defvar ifm-font-lock-keywords-1 nil)
(defvar ifm-font-lock-keywords-2 nil)

(if (featurep 'font-lock)
    (setq ifm-font-lock-keywords
	  (list
					; commentd
	   (list "#.*$" 0 font-lock-comment-face)
					; template blocks
	   (list "{[^}]*}" 0 font-lock-type-face)
					; quoted strings
	   (list "\"[^\"]*\"" 0 font-lock-string-face)
	   (list "<<[^>]*>>" 0 font-lock-string-face)
					; macro ... ; end macro
	   '("^\\s-*\\(macro\\)\\s-+\\(\\b[^ \t]+\\b\\)"
	     (1 font-lock-reference-face)
	     (2 font-lock-function-name-face nil t))
	   (list "^\\s-*end\\s-+macro" 0 font-lock-reference-face)
					; everything else
	   (list (concat "\\b\\(c\\(o\\(lor\\|mment\\)\\|ursor\\)\\|"
			 "e\\(cho\\|rase\\|xit\\)\\|"
			 "f\\(effit\\|f\\(2chi\\|t\[fr\]\\)\\|indee\\)\\|"
			 "guess\\|history\\|load\\|minimize\\|newplot\\|"
			 "p\\(a\\(th\\|use\\)\\|lot\\|"
			 "r\\(e_edge\\|int\\)\\)\\|"
			 "quit\\|re\\(ad_data\\|name\\|set\\)\\|"
			 "s\\(et\\|how\\|pline\\|ync\\)\\|"
			 "write_data\\|zoom\\)\\b")
		 0 font-lock-keyword-face)
	   ))
  (setq ifm-font-lock-keywords-1 ifm-font-lock-keywords)
  (setq ifm-font-lock-keywords-2 ifm-font-lock-keywords))


(defvar ifm-commands-alist ())
(setq ifm-commands-alist
      (list '("color"      "Manipulate the plotting color table.")
	    '("comment"    "Write a comment line to the command history buffer. ")
	    '("cursor"     "Get x and y values from the graphics screen.")
	    '("echo"       "Echo a string to the screen without interpolation.")
	    '("end"        "\"end macro\" ends a macro definition.")
	    '("erase"      "Erase one or more Program Variables.")
	    '("exit"       "Exit Ifeffit.")
	    '("feffit"     "Fit chi(k) data to a sum of paths.")
	    '("ff2chi"     "Sum a set of paths to make a theoretical chi(k).")
	    '("fftf"       "Forward XAFS Fourier Transform of an array.")
	    '("fftr"       "Reverse XAFS Fourier Transform of an array.")
	    '("findee"     "Determine the energy origin E_0 from mu(E) data.")
	    '("guess"      "Define a fitting variable and set it's initial value.")
	    '("history"    "Open a file to save a record of Ifeffit commands.")
	    '("load"       "Load and execute a file of Ifeffit commands.")
	    '("macro"      "Begin a macro definition.")
	    '("minimize"   "Minimize an array by optimizing variables.")
	    '("newplot"    "Erase the old plot and draw a new one.")
	    '("path"       "Define a feff path and its path parameters.")
	    '("pause"      "Write a message and suspend Ifeffit waiting for input.")
	    '("plot"       "Plot (or overplot) and array.")
	    '("pre_edge"   "Calculate the pre-edge line through mu(E) data.")
	    '("print"      "Evaluate a program variable and write it out.")
	    '("quit"       "Exit Ifeffit.")
	    '("read_data"  "Read array data from an ASCII file")
	    '("rename"     "Rename one or more Program Variables.")
	    '("reset"      "Reset all Ifeffit Program Variables.")
	    '("set"        "Set Program Variables.")
	    '("show"       "Show information about something in Ifeffit.")
	    '("spline"     "Calculate mu0(E) and chi(k) from mu(E).")
	    '("sync"       "Synchronize numeric Program Variables dependencies.")
	    '("write_data" "Write arrays and other data to an ASCII data file.")
	    '("zoom"       "Zoom in on a region of the plot window with the mouse.")
	    ))

(defsubst ifm-command-description (obj) (elt (assoc obj ifm-commands-alist) 1))

(defvar ifm-commands nil
  "A list of Ifeffit commands built from ifm-commands-alist.")
(defun ifm-make-commands-list ()
  (let ((list ()) (alist ifm-commands-alist))
    (while alist
      (setq list  (append list (list (caar alist)))
	    alist (cdr alist)))
    list))

(defun ifm-complete-command ()
  "Perform completion on the Ifeffit command preceding point.
This is a pretty simple minded completion function.  It is loosely
adapted from `lisp-complete-symbol'."
  (interactive)
  (let* ((end (point))
	 (beg (unwind-protect (save-excursion (backward-sexp 1) (point))))
	 (patt (buffer-substring beg end))
	 (pattern (if (string-match "\\([^ \t]*\\)\\s-+$" patt)
		      (match-string 1 patt) patt))
	 (alist (mapcar 'list ifm-commands))
	 (completion (try-completion pattern alist)))
    (cond ((eq completion t))
	  ((null completion)
	   (message "No Ifeffit commands complete \"%s\"" pattern))
	  (t
	   (when (not (string= pattern completion))
	     (delete-region beg end)
	     (insert completion)
	     (ifm-describe-command completion))
	   (let* ((list (all-completions pattern alist))
		  (mess (format "\"%s\" could be one of %S" pattern list))
		  (orig (current-buffer))
		  (buff (get-buffer-create "*ifm-completions*")))
	     (if (< (length mess) (frame-width))
		 (if (> (length list) 1) (message mess))
	       (switch-to-buffer-other-window buff)
	       (insert mess)
	       (fill-region (point-min) (point-max))
	       (goto-char (point-min))
	       (enlarge-window
		(+ 2 (- (count-lines (point-min) (point-max))
			(window-height))))
	       (sit-for (max (length list) 15))
	       (switch-to-buffer orig)
	       (kill-buffer buff)
	       (delete-other-windows) ))) )))


(defun ifm-this-word ()
  "Return the word near point."
  (let (begin)
    (save-excursion
      (or (looking-at "\\<") (= (current-column) 0) (forward-word -1))
      (if (looking-at (regexp-quote "<")) (forward-char 1))
      (setq begin (point-marker))
      (forward-word 1)
      (buffer-substring-no-properties begin (point)))))


(defun ifm-describe-command (&optional word)
  "Issue a message describing the Ifeffit command WORD."
  (interactive)
  (let (desc)
    (setq word (or word (ifm-this-word)))
    (setq desc (or (ifm-command-description word)
		   "<not an ifeffit command>"))
    (message "%S : %s" word desc)))


(defun ifm-display-commands ()
  "Open a buffer displaying all Ifeffit commands.
Bound to \\[ifm-display-commands]"
  (interactive)
  (let* (keyword arg-descr
	 (keyword-alist (copy-alist ifm-commands-alist))
	 (keyword-buffer-name ifm-commands-buffer-name))
    (if (get-buffer keyword-buffer-name)
	(switch-to-buffer-other-window keyword-buffer-name)
      (switch-to-buffer-other-window keyword-buffer-name)
      ;;(erase-buffer)
      (insert "\tIfeffit Commands\n\n")
      (insert "Command\t\tdescription\n"
	      (concat (make-string 75 ?\-) "\n"))
      (while keyword-alist
	(setq keyword    (caar keyword-alist)
	      arg-descr  (cadar keyword-alist))
	(insert (format "%-14s %s\n" keyword arg-descr))
	(setq keyword-alist (cdr keyword-alist)))
      (help-mode)
      (setq truncate-lines t
	    buffer-read-only t) )
    (goto-char (point-min)) ))


(defun ifm-indent-line ()
  "Set indentation in ifeffit-macros buffer.
Align macro and end macro lines, indent macro contents, indent
continuation lines further."
  (interactive)
  (save-excursion
    (let (indent within
	  (prev-start (save-excursion
			(re-search-backward "^\\s-*macro" (point-min) t)
			(point-marker) ))
	  (prev-end   (save-excursion
			(re-search-backward "^\\s-*end\\s-+macro"
					    (point-min) "to-lim")
			(point-marker) ))
	  (next-start (save-excursion
			(re-search-forward "^\\s-*macro" (point-max) "to-lim")
			(point-marker) ))
	  (next-end   (save-excursion
			(re-search-forward "^\\s-*end\\s-+macro" (point-max) t)
			(point-marker) )) )
      (setq within (and (> (point) prev-start)
			(< (point) next-end)
			(> prev-start prev-end)
			(< next-end next-start)))
      (beginning-of-line)
      (cond ((looking-at "^\\s-*\\(\\(end\\s-+\\)?macro\\)")
	     (setq indent ifm-macro-indent
		   within nil))
	    (within
	     (setq indent ifm-macro-contents-indent)))
      (when within
	(save-excursion
	  (end-of-line 0)
	  (delete-horizontal-space)
	  (backward-char 1)
	  (when (looking-at "[-+*/=,]")
	    (setq indent (+ indent ifm-macro-continuation-additional-indent)))))
      (delete-horizontal-space)
      (insert (make-string indent ? )) )))

(defun ifm-insert-block ()
  "Insert a 'macro -- end macro' block."
  (interactive)
  (let (goto name)
    (setq name (read-from-minibuffer "name of macro: "))
    (newline)
    (insert "macro " name)
    (ifm-indent-line)
    (insert "\n")
    (setq goto (point-marker))
    (insert "\nend macro\n")
    (ifm-indent-line)
    (goto-char goto)
    (insert (make-string ifm-macro-contents-indent ? )) ))


(defun ifm-identify ()
  "Print an identifier message in the echo area."
  (interactive)
  (message "ifm-mode %s by %s <%s>"
	   ifm-version ifm-author ifm-maintainer-email)
  (sleep-for 3)
  (message "The Ifeffit homepage is: %s" ifm-url) )

(defun ifm-mode ()
  "Major mode for editing Ifeffit macro files.

Key bindings:
\\{ifm-mode-map}"
  (interactive)
  (kill-all-local-variables)
  (use-local-map ifm-mode-map)
  (easy-menu-define
   ifm-mode-menu ifm-mode-map "Menu used in ifm-mode"
   ifm-menu)
  (easy-menu-add ifm-mode-menu ifm-mode-map)
  (setq major-mode 'ifm-mode
	mode-name "IFM")
  (set (make-local-variable 'comment-start) "## ")
  (set (make-local-variable 'comment-end) "")
  (set (make-local-variable 'indent-line-function) 'ifm-indent-line)
  (if (featurep 'comment)
      (setq comment-mode-alist
	    (append comment-mode-alist '((ifm-mode "## ")) )))
  (set-syntax-table ifm-mode-syntax-table)
  (make-variable-buffer-local 'font-lock-defaults)
  (setq font-lock-defaults '(ifm-font-lock-keywords t t))
  (setq ifm-commands (ifm-make-commands-list))
  (turn-on-font-lock)
  (message "ifm mode %s -- send bugs to %s" ifm-version ifm-maintainer-email)
  (run-hooks 'ifm-mode-hook))





;;; That's it! ----------------------------------------------------------------


;;;--- any final chores before leaving
(provide 'ifm)
(run-hooks 'ifm-load-hook)

;;;============================================================================
;;;
;;; ifeffit-macro.el ends here
