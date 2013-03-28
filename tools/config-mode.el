
(require 'cl)

(defconst config-version          "0.01")
(defconst config-author           "Bruce Ravel")
(defconst config-maintainer-email "bravel@bnl.gov")
(defconst config-url              "http://bruceravel.github.com/demeter/exafs/")

(defgroup config nil
  "Ifeffit macro editing mode for Emacs."
  :prefix "config-"
  :group 'local)

(defcustom config-mode-hook nil
  "*Hook run when config minor mode is entered."
  :group 'config
  :type 'hook)
(defcustom config-load-hook nil
  "*Hook run when ifeffit-macro.el is first loaded."
  :group 'config
  :type 'hook)

(defcustom config-description-indent 2
  "*Amount to indent description text."
  :group 'config
  :type 'integer)

(defvar config-mode-map nil)
(if config-mode-map
    ()
  (setq config-mode-map (make-sparse-keymap))
  ;(define-key config-mode-map "\t"       'ifm-indent-line)
  )


(defvar config-font-lock-keywords nil)
(defvar config-font-lock-keywords-1 nil)
(defvar config-font-lock-keywords-2 nil)

(if (featurep 'font-lock)
    (setq config-font-lock-keywords
	  (list
					; comments
	   (list "#.*$" 0 font-lock-comment-face)
	   (list "^  .+$" 0 font-lock-doc-face)
	   (list "^  \..+$" 0 font-lock-doc-face)
					; quoted strings
	   (list "\\(section_description\\|description\\)" 0 font-lock-keyword-face )
	   '("\\(section\\|variable\\)=" 1 font-lock-keyword-face)
	   '("\\(include\\)" 0 font-lock-reference-face)
					; everything else
	   (list (concat "\\("
			 "type\\|options\\|default\\|units\\|"
			 "onvalue\\|offvalue\\|maxint\\|minint\\|"
			 "restart\\|variable_width"
			 "\\)=")
		 1 font-lock-variable-name-face)
	   ))
  (setq config-font-lock-keywords-1 config-font-lock-keywords)
  (setq config-font-lock-keywords-2 config-font-lock-keywords))


(defun config-mode ()
  "Major mode for editing demeter and horae config files.

Key bindings:
\\{config-mode-map}"
  (interactive)
  (kill-all-local-variables)
  (use-local-map config-mode-map)
  ;;(easy-menu-define
  ;; config-mode-menu config-mode-map "Menu used in config-mode"
  ;; config-menu)
  ;;(easy-menu-add config-mode-menu config-mode-map)
  (setq major-mode 'config-mode
	mode-name "Conf")
  (set (make-local-variable 'comment-start) "## ")
  (set (make-local-variable 'comment-end) "")
  ;;(set (make-local-variable 'indent-line-function) 'config-indent-line)
  ;;(if (featurep 'comment)
  ;;    (setq comment-mode-alist
  ;;	    (append comment-mode-alist '((config-mode "## ")) )))
  ;;(set-syntax-table config-mode-syntax-table)
  (make-local-variable 'font-lock-defaults)
  (setq font-lock-defaults '(config-font-lock-keywords t t))
  ;;(setq config-commands (config-make-commands-list))
  (turn-on-font-lock)
  (auto-fill-mode 1)
  (message "config mode %s -- send bugs to %s" config-version config-maintainer-email)
  (run-hooks 'config-mode-hook))



;;;--- any final chores before leaving
(provide 'config)
(run-hooks 'config-load-hook)

;;;============================================================================
;;;
;;; config-mode.el ends here
