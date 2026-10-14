;;; portfile-ts-livecheck.el --- Maintainer livecheck sidebar -*- lexical-binding: t; -*-

;; Copyright (C) 2026
;;
;; Author: Vadym-Valdis Yudaiev <judaew@outlook.com>
;; URL: https://github.com/judaew/portfile-ts-mode
;; SPDX-License-Identifier: MIT
;; Version: 0.3.1
;; Package-Requires: ((emacs "30.1"))
;; Keywords: languages, macports, portfile

;;; Commentary:
;;
;; Provides a sidebar for displaying MacPorts livecheck results for ports
;; maintained by a specified maintainer.
;;
;; The maintainer is configured through
;; `portfile-ts-livecheck-maintainer'.  If empty, the user is prompted
;; to enter a maintainer when opening the sidebar.
;;
;; Results include old and new versions, with errors highlighted.  The
;; following keybindings are available in the sidebar:
;; RET  Open the Portfile for the selected port.
;; q    Stop livecheck and close the sidebar
;; u    Refresh the results
;; w    Copy the value of the current cell
;; m    Copy an update message in the format
;;      "<port>: update to <version>"
;;
;; `portfile-ts-livecheck-toggle' toggles the visibility of the livecheck
;; sidebar and can be bound to a key.

;;; Code:

(require 'tabulated-list)
(require 'subr-x)

(defcustom portfile-ts-livecheck-maintainer ""
  "Maintainer used by `portfile-ts-livecheck'.
When empty, prompt for a maintainer."
  :type 'string
  :group 'portfile-ts-mode)

(defcustom portfile-ts-livecheck-port-width 17
  "Width of the Port column in the livecheck table."
  :type 'integer
  :group 'portfile-ts-mode)

(defcustom portfile-ts-livecheck-version-width 10
  "Width of the Old or New column in the livecheck table."
  :type 'integer
  :group 'portfile-ts-mode)

(defface portfile-ts-livecheck-error-face
  '((t :inherit error))
  "Face used for livecheck errors."
  :group 'portfile-ts-mode)

(defvar-local portfile-ts-livecheck--rows nil
  "Livecheck results keyed by port name.")

(defvar-local portfile-ts-livecheck--maintainer nil
  "Maintainer used for the current livecheck buffer.")

;;; Table formatting

(defun portfile-ts-livecheck--display-cell (value width &optional face)
  "Format VALUE to WIDTH display columns, optionally using FACE.
Keep the full value available through the `help-echo' text property."
  (propertize
   (truncate-string-to-width (or value "") width 0 nil "~")
   'help-echo value 'face face))

(defun portfile-ts-livecheck--entries ()
  "Return the current results as tabulated-list entries."
  (mapcar
   (lambda (row)
     (let* ((port (car row))
            (data (cdr row))
            (error (plist-get data :error)))
       (list
        port
        (vector
         (portfile-ts-livecheck--display-cell
          port portfile-ts-livecheck-port-width)
         (portfile-ts-livecheck--display-cell
          (plist-get data :old)
          portfile-ts-livecheck-version-width
          (when error 'portfile-ts-livecheck-error-face))
         (portfile-ts-livecheck--display-cell
          (plist-get data :new)
          portfile-ts-livecheck-version-width
          (when error 'portfile-ts-livecheck-error-face))))))
   portfile-ts-livecheck--rows))

(defun portfile-ts-livecheck--put-row (port old new &optional error)
  "Store PORT's OLD and NEW versions.
When ERROR is non-nil, highlight both version columns."
  (let ((row (assoc-string port portfile-ts-livecheck--rows)))
    (if row
        (setcdr row (list :old old :new new :error error))
      (setq portfile-ts-livecheck--rows
            (append portfile-ts-livecheck--rows
                    (list (cons port
                                (list :old old :new new :error error))))))
    (setq tabulated-list-entries
          (portfile-ts-livecheck--entries))
    (tabulated-list-print t)))

(defun portfile-ts-livecheck--window-width ()
  "Return the desired width of the livecheck sidebar in columns."
  (+ portfile-ts-livecheck-port-width
     portfile-ts-livecheck-version-width
     portfile-ts-livecheck-version-width
     (* 2 tabulated-list-padding)
     6))

;;; Output parsing

(defun portfile-ts-livecheck--parse-line (line)
  "Parse a livecheck output LINE and update the results."
  (setq line (string-trim line))
  (cond
   ((string-match
     "\\`\\(.+\\) seems to have been updated (port version: \\(.+\\), new version: \\(.+\\))\\'"
     line)
    (portfile-ts-livecheck--put-row
     (match-string 1 line)
     (match-string 2 line)
     (match-string 3 line)))

   ((string-match
     "\\`Error: cannot check if \\(.+\\) was updated (\\(.*\\))\\'"
     line)
    (let ((port (match-string 1 line))
          (reason (match-string 2 line)))
      (cond
       ((string-match-p "\\`regex didn't match\\'" reason)
        (portfile-ts-livecheck--put-row port "regex" "---" t))

       ((string-match "\\b\\([45][0-9][0-9]\\)\\b" reason)
        (portfile-ts-livecheck--put-row
         port (concat "HTTP " (match-string 1 reason)) "---" t))

       (t
        (portfile-ts-livecheck--put-row port "error" reason t)))))))

(defun portfile-ts-livecheck--filter (process output)
  "Parse complete lines from PROCESS OUTPUT incrementally."
  (let ((pending (concat (or (process-get process 'pending) "") output))
        (start 0) newline)
    (while (setq newline (string-match "\n" pending start))
      (let ((line (substring pending start newline)))
        (when (buffer-live-p (process-buffer process))
          (with-current-buffer (process-buffer process)
            (portfile-ts-livecheck--parse-line
             (string-remove-suffix "\r" line)))))
      (setq start (1+ newline)))
    (process-put process 'pending (substring pending start))))

;;; Process executing (livecheck)

(defun portfile-ts-livecheck--sentinel (process _event)
  "Handle PROCESS termination and parse any remaining output."
  (when (memq (process-status process) '(exit signal))
    (let ((buffer (process-buffer process)))
      (when (buffer-live-p buffer)
        (with-current-buffer buffer
          (let ((pending (process-get process 'pending)))
            (when (and pending (not (string-empty-p pending)))
              (portfile-ts-livecheck--parse-line
               (string-remove-suffix "\r" pending))
              (process-put process 'pending "")))))
      (unless (process-get process 'portfile-ts-livecheck-quiet)
        (message "Livecheck %s"
                 (if (and (eq (process-status process) 'exit)
                          (zerop (process-exit-status process)))
                     "finished"
                   "finished with errors"))))))

(defun portfile-ts-livecheck--stop-process ()
  "Stop the livecheck process associated with the current buffer."
  (let ((process (get-buffer-process (current-buffer))))
    (when (and process (process-live-p process))
      (process-put process 'portfile-ts-livecheck-quiet t)
      (delete-process process))))

(defun portfile-ts-livecheck-refresh ()
  "Clear the current results and run livecheck again."
  (interactive)
  (unless (derived-mode-p 'portfile-ts-livecheck-mode)
    (user-error "Not in a Port Livecheck buffer"))
  (unless (and portfile-ts-livecheck--maintainer
               (not (string-empty-p portfile-ts-livecheck--maintainer)))
    (user-error "No maintainer configured for this buffer"))
  (portfile-ts-livecheck--stop-process)
  (setq portfile-ts-livecheck--rows nil
        tabulated-list-entries nil)
  (tabulated-list-print t)
  (make-process
   :name "portfile-ts-livecheck"
   :buffer (current-buffer)
   :command
   (list "port" "livecheck" (concat "maintainer:" portfile-ts-livecheck--maintainer))
   :connection-type 'pipe
   :noquery t
   :filter #'portfile-ts-livecheck--filter
   :sentinel #'portfile-ts-livecheck--sentinel))

;;; Interactive commands

(defun portfile-ts-livecheck--row-data ()
  "Return raw data for the port at point."
  (let ((port (tabulated-list-get-id)))
    (when port (assoc-string port portfile-ts-livecheck--rows))))

(declare-function portfile-ts-edit "portfile-ts-commands" (port))

(defun portfile-ts-livecheck-edit-port ()
  "Open the Portfile for the port at point."
  (interactive)
  (let ((row (portfile-ts-livecheck--row-data)))
    (unless row
      (user-error "No port on this line"))
    (let ((window (get-mru-window nil nil t)))
      (with-selected-window (or window (selected-window))
        (portfile-ts-edit (car row))))))

(defun portfile-ts-livecheck-copy-field ()
  "Copy the full value of the column at point."
  (interactive)
  (let ((row (portfile-ts-livecheck--row-data)))
    (unless row
      (user-error "No port on this line"))
    (let* ((data (cdr row))
           (column (current-column))
           (port-width portfile-ts-livecheck-port-width)
           (version-width portfile-ts-livecheck-version-width)
           (first-end (+ port-width tabulated-list-padding))
           (second-end (+ first-end version-width
                          tabulated-list-padding))
           (value (cond
                   ((< column port-width) (car row))
                   ((< column first-end) (car row))
                   ((< column second-end) (plist-get data :old))
                   (t (plist-get data :new)))))
      (kill-new (or value ""))
      (message "Copied: %s" (or value "")))))

(defun portfile-ts-livecheck-copy-update ()
  "Copy a commit-style update message for the port at point."
  (interactive)
  (let* ((row (portfile-ts-livecheck--row-data))
         (data (and row (cdr row))))
    (unless row
      (user-error "No port on this line"))
    (let ((new (plist-get data :new)))
      (when (or (null new) (equal new "---"))
        (user-error "No new version available for %s" (car row)))
      (let ((message (format "%s: update to %s" (car row) new)))
        (kill-new message)
        (message "Copied: %s" message)))))

(defun portfile-ts-livecheck-quit ()
  "Stop livecheck and close its window, preserving the results buffer."
  (interactive)
  (portfile-ts-livecheck--stop-process)
  (quit-window))

;;;###autoload
(defun portfile-ts-livecheck-toggle ()
  "Toggle the Port Livecheck sidebar."
  (interactive)
  (if-let* ((window (get-buffer-window "*Port Livecheck*")))
      (quit-window nil window)
    (portfile-ts-livecheck)))

;;; Major mode

(define-derived-mode portfile-ts-livecheck-mode
  tabulated-list-mode "Port Livecheck"
  "Major mode for maintainer livecheck results."
  (setq tabulated-list-format
        (vector
         (list "Port" portfile-ts-livecheck-port-width t)
         (list "Old" portfile-ts-livecheck-version-width t)
         (list "New" portfile-ts-livecheck-version-width t))
        tabulated-list-padding 1
        tabulated-list-entries nil)
  (tabulated-list-init-header)
  (keymap-set portfile-ts-livecheck-mode-map
              "RET" #'portfile-ts-livecheck-edit-port)
  (keymap-set portfile-ts-livecheck-mode-map
              "q" #'portfile-ts-livecheck-quit)
  (keymap-set portfile-ts-livecheck-mode-map
              "u" #'portfile-ts-livecheck-refresh)
  (keymap-set portfile-ts-livecheck-mode-map
              "w" #'portfile-ts-livecheck-copy-field)
  (keymap-set portfile-ts-livecheck-mode-map
              "m" #'portfile-ts-livecheck-copy-update))

;;;###autoload
(defun portfile-ts-livecheck ()
  "Open the maintainer livecheck sidebar.
If its buffer already exists, preserve and display the existing results."
  (interactive)
  (let ((buffer (get-buffer "*Port Livecheck*")))
    (unless (buffer-live-p buffer)
      (let ((maintainer
             (if (string-empty-p portfile-ts-livecheck-maintainer)
                 (read-string "Maintainer: ")
               portfile-ts-livecheck-maintainer)))
        (when (string-empty-p maintainer)
          (user-error "Maintainer must not be empty"))
        (setq buffer (get-buffer-create "*Port Livecheck*"))
        (with-current-buffer buffer
          (portfile-ts-livecheck-mode)
          (setq portfile-ts-livecheck--maintainer maintainer)
          (portfile-ts-livecheck-refresh))))
    (display-buffer-in-side-window
     buffer
     `((side . right)
       (slot . 0)
       (window-width
        . ,(with-current-buffer buffer (portfile-ts-livecheck--window-width)))))))

(provide 'portfile-ts-livecheck)
;;; portfile-ts-livecheck.el ends here
