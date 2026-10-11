;;; portfile-ts-commands.el --- Port commands for MacPorts -*- lexical-binding: t; -*-

;;; Commentary:
;;; Code:

(require 'transient)
(require 'cl-lib)

(defun portfile-ts--port-name ()
  "Return the port name from current Portfile buffer."
  (let ((file (buffer-file-name)))
    (unless (and file (string-match-p "/Portfile\'" file))
      (user-error "Cannot determine port name"))
    (file-name-nondirectory
     (directory-file-name (file-name-directory file)))))

(defun portfile-ts--detect-subports ()
  "Return subports defined in the current buffer."
  (let ((port (portfile-ts--port-name))
        subports)
    (save-excursion
      (goto-char (point-min))
      (when (re-search-forward
             "^python\.versions[[:space:]]+\(.+\)$" nil t)
        (dolist (version (split-string (match-string 1)))
          (push (format "py%s-%s" version port) subports)))
      ;; TODO: ruby.branches pattern
      ;; (goto-char (point-min))
      ;; (when (re-search-forward
      ;;        "^ruby\.branches[[:space:]]+\(.+\)$" nil t)
      (goto-char (point-min))
      (while (re-search-forward
              "^subport[[:space:]]+\([^[:space:]]+\)[[:space:]]+{" nil t)
        (let ((name (match-string 1)))
          (unless (equal name port)
            (push name subports)))))
    (delete-dups (nreverse subports))))

(defun portfile-ts--select-port ()
  "Prompt for a port or subport, defaulting to the current port."
  (let ((port (portfile-ts--port-name))
        (subports (portfile-ts--detect-subports)))
    (if (null subports)
        port
      (completing-read "Port: " (cons port subports)
                       nil t nil nil port))))

(provide 'portfile-ts-commands)

;;; portfile-ts-commands.el ends here
