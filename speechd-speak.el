;;; speechd-speak.el --- simple speechd-el based Emacs client

;; Copyright (C) 2003 Brailcom, o.p.s.

;; COPYRIGHT NOTICE
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; if not, write to the Free Software
;; Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

;;; Commentary:

;; This is a simple experimental Emacs client to speechd.  Many ideas taken
;; from the Emacspeak package (http://emacspeak.sourceforge.net) by
;; T. V. Raman.

;;; Code:


(eval-when-compile (require 'cl))
(require 'speechd)


(defconst speechd-speak-version "$Id: speechd-speak.el,v 1.6 2003-06-26 11:03:44 pdm Exp $"
  "Version of the speechd-speak file.")


;;; User options


(defgroup speechd-speak nil
  "Speechd-el user client customization."
  :group 'speechd-el)

(defcustom speechd-speak-startup-hook nil
  "Hook to run after starting speechd-speak."
  :type 'sexp
  :group 'speechd-speak)

(defcustom speechd-speak-deleted-char t
  "If non-nil, speak the deleted char, otherwise speak the adjacent char."
  :type 'boolean
  :group 'speechd-speak)

(defcustom speechd-speak-buffer-name t
  "If non-nil, speak buffer name on a buffer change, otherwise speak a line."
  :type 'boolean
  :group 'speechd-speak)

(defcustom speechd-speak-prefix "\C-e"
  "Default prefix key used for speechd-speak commands."
  :type 'sexp
  :group 'speechd-speak)


;;; Control functions

(defvar speechd-speak-quiet t
  "If non-nil in the current buffer, no speech output is produced.")

(defun speechd-speak-toggle-quiet (&optional prefix quiet)
  "Turn speaking on or off.
Without the PREFIX argument, toggle speaking globally, except for the buffers
with previously explicitly toggled speaking.
With the universal PREFIX argument, toggle speaking in all buffers.
With the PREFIX argument 1, toggle speaking in the current buffer only.

If the optional argument QUIET is a positive number, turn speaking on; if it
is a non-positive number, turn speaking off."
  (interactive "P")
  (let ((new-state (if (numberp quiet) (<= quiet 0) (not speechd-speak-quiet)))
	prompt)
    (cond
     ((not prefix)
      (setq-default speechd-speak-quiet new-state)
      (setq speechd-speak-quiet new-state
	    prompt "globally"))
     ((listp prefix)
      (save-excursion
	(mapc #'(lambda (buffer)
		  (when (local-variable-p 'speechd-speak-quiet buffer)
		    (set-buffer buffer)
		    (kill-local-variable 'speechd-speak-quiet)))
	      (buffer-list)))
      (setq speechd-speak-quiet new-state
	    prompt "everywhere"))
     (t
      (make-local-variable 'speechd-speak-quiet)
      (setq speechd-speak-quiet new-state
	    prompt "in the current buffer")))
    (when speechd-speak-quiet
      (speechd-cancel))
    (let ((speechd-speak-quiet nil))
      (message "Speaking turned %s %s" (if new-state "off" "on") prompt))))

(defvar speechd-speak--predefined-rates
  '((1 . -100)
    (2 . -75)
    (3 . -50)
    (4 . -25)
    (5 . 0)
    (6 . 25)
    (7 . 50)
    (8 . 75)
    (9 . 100)))
(defun speechd-speak-set-predefined-rate (level)
  "Set speech rate to one of nine predefined levels.
Level 1 is the slowest, level 9 is the fastest."
  (interactive "nSpeech rate level (1-9): ")
  (setq level (min (max level 1) 9))
  (let ((rate (cdr (assoc level speechd-speak--predefined-rates))))
    (speechd-set-rate rate)
    (message "Speech rate set to %d" rate)))

(defvar speechd-speak--char-to-number
  '((?1 . 1) (?2 . 2) (?3 . 3) (?4 . 4) (?5 . 5)
    (?6 . 6) (?7 . 7) (?8 . 8) (?9 . 9)))
(defun speechd-speak-key-set-predefined-rate ()
  "Set speech rate to one of nine predefined levels via a key binding.
Level 1 is the slowest, level 9 is the fastest."
  (interactive)
  (let ((level (cdr (assoc last-input-char speechd-speak--char-to-number))))
    (when level
      (speechd-speak-set-predefined-rate level))))


;;; Supporting functions and options


(defmacro* speechd-speak--maybe-speak (&body body)
  `(unless speechd-speak-quiet
     ,@body))

(defun speechd-speak--text (text &rest args)
  (speechd-speak--maybe-speak
   ;; TODO: skip invisible text
   ;; TODO: replace repeating patterns
   ;; TODO: handle selective display
   (apply #'speechd-say-text text args)))

(defun speechd-speak--char (&rest args)
  (speechd-speak--maybe-speak
   (apply #'speechd-say-char args)))

(defun speechd-speak--key (&rest args)
  (speechd-speak--maybe-speak
   (apply #'speechd-say-key args)))

(defun speechd-speak--sound (&rest args)
  (speechd-speak--maybe-speak
   (apply #'speechd-say-sound args)))

(defun speechd-speak-read-char (&optional char)
  (interactive)
  (speechd-speak--char (or char (following-char))))

(defun speechd-speak-read-region (&optional beg end)
  (interactive "r")
  (speechd-speak--text (buffer-substring (or beg (mark)) (or end (point)))
		       :priority :text))

(defun speechd-speak-read-line ()
  (interactive)
  (speechd-speak-read-region (line-beginning-position) (line-end-position)))

(defun speechd-speak-read-next-line ()
  (interactive)
  (save-excursion
    (forward-line 1)
    (speechd-speak-read-line)))

(defun speechd-speak-read-previous-line ()
  (interactive)
  (save-excursion
    (forward-line -1)
    (speechd-speak-read-line)))

(defun speechd-speak-read-buffer (&optional buffer)
  (interactive)
  (save-excursion
    (when buffer
      (set-buffer buffer))
    (speechd-speak-read-region (point-min) (point-max))))

(defun speechd-speak-read-rest-of-buffer ()
  (interactive)
  (speechd-speak-read-region (point) (point-max)))

(defun speechd-speak-read-other-window ()
  (interactive)
  (speechd-speak-read-buffer (window-buffer (get-lru-window))))

(defun speechd-speak--window-contents ()
  (speechd-speak-read-region (window-start) (window-end)))

(defun speechd-speak--speak-piece (start)
  (let ((point (point)))
    (if (> (count-lines start point) 1)
	(speechd-speak-read-line)
      (speechd-speak-read-region start point))))

(defun speechd-speak--speak-current-column ()
  (speechd-speak--text (format "Column %d" (current-column))))

(defmacro speechd-speak--def-speak-object (type)
  (let* ((name (symbol-name type))
	 (function-name (intern (format "speechd-speak-read-%s" name)))
	 (backward-function (intern (format "backward-%s" name)))
	 (forward-function (intern (format "forward-%s" name))))
    `(defun ,function-name ()
       (interactive)
       (save-excursion
	 (let ((end (progn (,forward-function 1) (point)))
	       (beg (progn (,backward-function 1) (point))))
	   (speechd-speak-read-region beg end))))))

(speechd-speak--def-speak-object word)
(speechd-speak--def-speak-object sentence)
(speechd-speak--def-speak-object paragraph)
(speechd-speak--def-speak-object page)
(speechd-speak--def-speak-object sexp)

(defvar speechd-speak--command-start-info (make-vector 5 nil))

(defmacro* speechd-speak--with-minibuffer-depth (&body body)
  `(let ((depth (minibuffer-depth)))
     (when (>= depth (length speechd-speak--command-start-info))
       (setq speechd-speak--command-start-info
	     (vconcat speechd-speak--command-start-info
		      (make-vector
		       (- (1+ depth)
			  (length speechd-speak--command-start-info))
		       nil))))
     ,@body))

(defun speechd-speak--command-start-info ()
  (speechd-speak--with-minibuffer-depth
    (aref speechd-speak--command-start-info depth)))

(defun speechd-speak--set-command-start-info (&optional reset)
  (speechd-speak--with-minibuffer-depth
    (aset speechd-speak--command-start-info depth
	  (if reset nil (ignore-errors (list (current-buffer) (point)))))))

(defun speechd-speak--reset-command-start-info ()
  (speechd-speak--set-command-start-info t))

(defmacro* speechd-speak--defadvice (function class &body body)
  `(defadvice ,function (,class speechd-speak activate preactivate compile)
     ,@body))

(defmacro* speechd-speak--command-feedback (commands position &body body)
  (let ((commands* (if (listp commands) commands (list commands)))
	(position* position)
	(body* `(progn (speechd-speak--reset-command-start-info) ,@body))
	(c (gensym)))
    `(progn
       ,@(mapcar #'(lambda (command)
		     `(speechd-speak--defadvice ,command ,position*
			,(if (eq position* 'around)
			     `(if (interactive-p)
				  ,body*
				ad-do-it)
			   `(when (interactive-p)
			      ,body*))))
		 commands*))))

(defmacro* speechd-speak--command-feedback-region (commands &key (move nil))
  `(speechd-speak--command-feedback ,commands around
     (let ((start (save-excursion ,move (point))))
       ad-do-it
       (speechd-speak--speak-piece start))))



;;; Basic speaking


;; These two simply don't work in Emacs 21.3 when invoked via key binding.
;; They're called directly in Emacs 21, to speed them up; no advice is invoked
;; in such a case.

;; (speechd-speak--command-feedback (self-insert-command) after
;;   (speechd-speak--char (preceding-char)))

;; (speechd-speak--command-feedback (forward-char backward-char) after
;;   (speechd-speak-read-char))

(speechd-speak--command-feedback (next-line previous-line) after
  (speechd-speak-read-line))

(speechd-speak--command-feedback (forward-word backward-word) after
  (speechd-speak-read-word))

(speechd-speak--command-feedback (beginning-of-buffer end-of-buffer) after
  (speechd-speak-read-line))

(speechd-speak--command-feedback (forward-sentence backward-sentence) after
  (speechd-speak-read-sentence))

(speechd-speak--command-feedback (forward-paragraph backward-paragraph) after
  (speechd-speak-read-paragraph))

(speechd-speak--command-feedback (forward-page backward-page) after
  (speechd-speak-read-page))

(speechd-speak--command-feedback (beginning-of-defun end-of-defun) after
  (speechd-speak-read-line))

(speechd-speak--command-feedback (scroll-up scroll-down) after
  (speechd-speak--window-contents))

(speechd-speak--command-feedback-region
 (backward-sexp forward-sexp forward-list backward-list up-list
  backward-up-list down-list))

(speechd-speak--command-feedback (upcase-word downcase-word capitalize-word)
				 after
  (speechd-speak-read-word))

(speechd-speak--command-feedback (delete-backward-char backward-delete-char
				  backward-delete-char-untabify)
				 around
  (when speechd-speak-deleted-char
    (speechd-speak-read-char (preceding-char)))
  ad-do-it
  (unless speechd-speak-deleted-char
    (speechd-speak-read-char (preceding-char))))

(speechd-speak--command-feedback (delete-char) around
  (when speechd-speak-deleted-char
    (speechd-speak-read-char (following-char)))
  ad-do-it
  (unless speechd-speak-deleted-char
    (speechd-speak-read-char (following-char))))

(speechd-speak--command-feedback (quoted-insert) after
  (speechd-speak-read-char (preceding-char)))

(speechd-speak--command-feedback (newline newline-and-indent) before
  (speechd-speak-read-line))

(speechd-speak--command-feedback (undo) after
  (speechd-speak-read-line))


;;; Killing and yanking


(speechd-speak--command-feedback (kill-word) before
  (speechd-speak-read-word))

(speechd-speak--command-feedback (backward-kill-word) before
  (save-excursion
    (forward-word -1)
    (speechd-speak-read-word)))

(speechd-speak--command-feedback (kill-line) before
  (speechd-speak-read-line))

(speechd-speak--command-feedback (kill-sexp) before
  (speechd-speak-read-sexp))

(speechd-speak--command-feedback (kill-sentence) before
  (speechd-speak-read-sentence))

(speechd-speak--command-feedback (zap-to-char) after
  (speechd-speak-read-line))

(speechd-speak--command-feedback (yank yank-pop) after
  (speechd-speak-read-region))

(speechd-speak--command-feedback (kill-region completion-kill-region) around
  (let ((nlines (count-lines (region-beginning) (region-end))))
    ad-do-it
    (message "Killed region containing %s lines" nlines)))

(speechd-speak--command-feedback (kill-ring-save) around
  (let ((nlines (count-lines (region-beginning) (region-end))))
    ad-do-it
    (message "Region containing %s lines copied to kill ring" nlines)))


;;; Messages


(defvar speechd-speak--last-message "")
(defvar speechd-speak--last-spoken-message "")

(defun speechd-speak-last-message ()
  (interactive)
  (speechd-speak--text speechd-speak--last-message))

(defun speechd-speak--current-message ()
  (let ((message (current-message)))
    (when (and message
	       (not (string= message speechd-speak--last-spoken-message)))
      (setq speechd-speak--last-message message
	    speechd-speak--last-spoken-message message)
      (speechd-speak--text message :priority :progress))))

(speechd-speak--defadvice message after
  (speechd-speak--current-message))


;;; Minibuffer


(defun speechd-speak--prompt (prompt)
  (speechd-speak--text prompt :priority :message))

(defun speechd-speak--speak-minibuffer-prompt ()
  (speechd-speak--prompt (minibuffer-prompt))
  (speechd-speak--prompt (minibuffer-contents)))
(add-hook 'minibuffer-setup-hook 'speechd-speak--speak-minibuffer-prompt)

(defun speechd-speak--speak-minibuffer ()
  (speechd-speak--text (minibuffer-contents)))

(speechd-speak--command-feedback (previous-history-element next-history-element
				  previous-matching-history-element
				  next-matching-history-element
				  minibuffer-complete minibuffer-complete-word)
				 after
  (speechd-speak--speak-minibuffer))

(speechd-speak--command-feedback minibuffer-message after
  (speechd-speak--text (ad-get-arg 0) :priority :notification))

;; The following functions don't invoke `minibuffer-setup-hook'
(speechd-speak--defadvice y-or-n-p before
  (speechd-speak--text (concat (ad-get-arg 0) "(y or n)") :priority :message))
(speechd-speak--defadvice read-key-sequence before
  (let ((prompt (ad-get-arg 0)))
    (when prompt
      (speechd-speak--text prompt :priority :message))))


;;; Commands


(defun speechd-speak--pre-command-hook ()
  (speechd-speak--set-command-start-info)
  ;; Some parameters of interactive commands don't set up the minibuffer, so we
  ;; have to speak the prompt in an extra way.
  (let ((interactive (cadr (interactive-form this-command))))
    (when (and (stringp interactive)
	       (string-match "^[@*]*\\([eipPmnr]\n\\)*[ckK]\\(.+\\)"
			     interactive))
      (speechd-speak--prompt (match-string 2 interactive))))
  (add-hook 'pre-command-hook 'speechd-speak--pre-command-hook))

(defun speechd-speak--post-command-hook ()
  ;; Messages should be handled by an after change function.  Unfortunately, in
  ;; Emacs 21 after change functions in the *Messages* buffer don't work in
  ;; many situations.  This is a property of the Emacs implementation, so the
  ;; mechanism can't be used.
  (speechd-speak--current-message)
  (setq speechd-speak--last-spoken-message "")
  (let ((command-info (speechd-speak--command-start-info)))
    (when command-info
      ;(speechd-speak--text (symbol-name this-command) :priority :notice)
      (multiple-value-bind (buffer position) command-info
	(cond
	 ((eq this-command 'self-insert-command)
	  (speechd-speak-read-char (preceding-char)))
	 ((memq this-command '(forward-char backward-char))
	  (speechd-speak-read-char))
	 ((not (eq buffer (current-buffer)))
	  (if speechd-speak-buffer-name
	      (speechd-speak--text (buffer-name) :priority :message)
	    (speechd-speak-read-line)))
	 ((not (= position (point)))
	  (speechd-speak-read-line))))))
  (add-hook 'post-command-hook 'speechd-speak--post-command-hook))


;;; Comint


(speechd-speak--command-feedback (comint-next-matching-input-from-input
				  comint-previous-matching-input-from-input
				  shell-forward-command shell-backward-command
				  comint-copy-old-input
				  comint-next-input comint-next-matching-input
				  comint-previous-input
				  comint-previous-matching-input)
				 after
  (speechd-speak-read-line))

(speechd-speak--command-feedback comint-show-output after
  (speechd-speak-read-region))
  
(speechd-speak--command-feedback-region comint-dynamic-complete)

(speechd-speak--defadvice comint-output-filter around
  ;; TODO:
  ad-do-it)


;;; Completions, menus, etc.


(defun speechd-speak--speak-completion ()
  ;; Taken from `choose-completion'
  (let (beg end completion (buffer completion-reference-buffer)
	(base-size completion-base-size))
    (if (and (not (eobp)) (get-text-property (point) 'mouse-face))
	(setq end (point) beg (1+ (point))))
    (if (and (not (bobp)) (get-text-property (1- (point)) 'mouse-face))
	(setq end (1- (point)) beg (point)))
    (if (null beg)
	(error "No completion here"))
    (setq beg (previous-single-property-change beg 'mouse-face))
    (setq end (or (next-single-property-change end 'mouse-face) (point-max)))
    (setq completion (buffer-substring beg end))
    (speechd-speak--text completion)))

(speechd-speak--command-feedback-region (expand-abbrev complete-symbol)
  :move (backward-word 1))

(speechd-speak--command-feedback-region (lisp-complete-symbol))

(speechd-speak--command-feedback dabbrev-expand after
  (speechd-speak--text dabbrev--last-expansion))

(speechd-speak--command-feedback (next-completion previous-completion) after
  (speechd-speak--speak-completion))

(speechd-speak--command-feedback choose-completion before
  (speechd-speak--speak-completion))

;; The `widget-choose' function is written in a non-extensible way.  So before
;; this is fixed, we have to use some dirty hacks.
(defconst speechd-speak--widget-choose-buffer-name " widget-choose")
(speechd-speak--defadvice scroll-other-window after
  (when (string= (buffer-name (window-buffer (next-window)))
		 speechd-speak--widget-choose-buffer-name)
    (speechd-speak-read-buffer speechd-speak--widget-choose-buffer-name)))


;;; Other functions and packages


(speechd-speak--command-feedback (isearch-search isearch-delete-char) after
  (speechd-speak--text isearch-string)
  (speechd-speak-read-line))

(speechd-speak--command-feedback (occur-prev occur-next
				  occur-mode-goto-occurence)
				 after
  (speechd-speak-read-line))

(speechd-speak--command-feedback transpose-chars after
  (speechd-speak--char (following-char)))

(speechd-speak--command-feedback transpose-lines after
  (speechd-speak-read-line))

(speechd-speak--command-feedback transpose-words after
  (speechd-speak-read-word))

(speechd-speak--command-feedback transpose-sexps after
  (speechd-speak-read-sexp))

(speechd-speak--command-feedback undefined after
  (speechd-speak--text "No command on this key"))

(speechd-speak--command-feedback indent-for-tab-command after
  (speechd-speak--speak-current-column))



;;; The startup function


(defun speechd-speak ()
  "Start or restart speaking."
  (interactive)
  (speechd-reopen)
  (add-hook 'pre-command-hook 'speechd-speak--pre-command-hook)
  (add-hook 'post-command-hook 'speechd-speak--post-command-hook)
  (speechd-speak-toggle-quiet nil 'on)
  (run-hooks 'speechd-speak-startup-hook)
  (message "Speechd-speak started"))


;;; Keymap


(defvar speechd-speak-keymap nil
  "Keymap used by speechd-speak.")

(define-prefix-command 'speechd-speak-prefix-command 'speechd-speak-keymap)
(global-set-key speechd-speak-prefix 'speechd-speak-prefix-command)

(define-key speechd-speak-keymap "e" 'end-of-line)
(define-key speechd-speak-keymap "\C-e" 'end-of-line)

(define-key speechd-speak-keymap "a" 'speechd-speak-last-message)
(define-key speechd-speak-keymap "b" 'speechd-speak-read-buffer)
(define-key speechd-speak-keymap "c" 'speechd-speak-read-char)
(define-key speechd-speak-keymap "l" 'speechd-speak-read-line)
(define-key speechd-speak-keymap "n" 'speechd-speak-read-rest-of-buffer)
(define-key speechd-speak-keymap "p" 'speechd-pause)
(define-key speechd-speak-keymap "q" 'speechd-speak-toggle-quiet)
(define-key speechd-speak-keymap "r" 'speechd-speak-read-region)
(define-key speechd-speak-keymap "s" 'speechd-stop)
(define-key speechd-speak-keymap "w" 'speechd-speak-read-word)
(define-key speechd-speak-keymap "{" 'speechd-speak-read-paragraph)
(define-key speechd-speak-keymap " " 'speechd-resume)
(define-key speechd-speak-keymap "'" 'speechd-speak-speak-sexp)
(define-key speechd-speak-keymap "[" 'speechd-speak-read-page)
(define-key speechd-speak-keymap "\C-n" 'speechd-speak-read-other-window)
(define-key speechd-speak-keymap "\C-s" 'speechd-reopen)
(define-key speechd-speak-keymap "\M-\C-k" 'kill-emacs)
(define-key speechd-speak-keymap '[down] 'speechd-speak-read-next-line)
(define-key speechd-speak-keymap '[up]  'speechd-speak-read-previous-line)
(dotimes (i 9)
  (define-key speechd-speak-keymap (format "%s" (1+ i))
              'speechd-speak-key-set-predefined-rate))


;;; Announce


(provide 'speechd-speak)


;;; speechd-speak.el ends here
