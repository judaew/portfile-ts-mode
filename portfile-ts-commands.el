;;; portfile-ts-commands.el --- TODOs -*- lexical-binding: t; -*-

;;; Commentary:
;;; Code:

(require 'transient)
(require 'flymake)
(require 'cl-lib)
;; (require 'treesit)

(defcustom portfile-ts-port-execute "port"
  "Path to the port executable."
  :type 'string)

(defcustom portfile-ts-cmd-output-buffer "*port*"
  "Buffer name for port command output."
  :type 'string)

(defcustom portfile-ts-lint-on-save nil
  "If non-nil, run port lint automatically via flymake."
  :type 'boolean)

(defun portfile-ts--port-name ()
  "Extract port name from current buffer."
  (let ((file (buffer-file-name)))
    (if (and file (string-match-p "/Portfile\\'" file))
        (file-name-nondirectory
         (directory-file-name
          (file-name-directory buffer-file-name)))
      (user-error "Cannot determine port name"))))

(defun portfile-ts--detect-subports ()
  "Detect available subports from current buffer."
  (let ((port-name (portfile-ts--port-name))
        (subports '()))
    (save-excursion
      ;; python.versions pattern
      (goto-char (point-min))
      (when (re-search-forward
             "^python\\.versions[[:space:]]+\\(.+\\)$" nil t)
        (dolist (v (split-string (match-string 1)))
          (push (format "py%s-%s" v port-name) subports)))
      ;; TODO: ruby.branches pattern
      ;; (goto-char (point-min))

      ;; subport pattern
      (goto-char (point-min))
      (while (re-search-forward
              "^subport[[:space:]]+\\([^[:space:]]+\\)[[:space:]]+{" nil t)
        (let ((subport-name (match-string 1)))
          (unless (string= subport-name port-name)
            (push subport-name subports)))))
    (delete-dups (nreverse subports))))

(defun portfile-ts--select-port ()
  "Interactively select a port or subport."
  (let* ((port-name (portfile-ts--port-name))
         (subports (portfile-ts--detect-subports)))
    (if subports
        (completing-read "Port: "
                         (cons port-name subports)
                         nil nil nil nil port-name)
      port-name)))

(provide 'portfile-ts-commands)

;;; portfile-ts-commands.el ends here
