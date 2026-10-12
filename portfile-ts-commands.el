;;; portfile-ts-commands.el --- Port commands for MacPorts -*- lexical-binding: t; -*-

;;; Commentary:
;;; Code:

(require 'transient)
(require 'cl-lib)

(defun portfile-ts--port-name ()
  "Return the port name from current Portfile buffer."
  (let ((file (buffer-file-name)))
    (unless (and file (string-match-p "/Portfile\\'" file))
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

(cl-defun portfile-ts--run (action &key sudo func)
  "Run port ACTION async.
When SUDO is non-nil, run the command through sudo.
Call FUNC when the process status changes."
  (let* ((args (transient-args 'portfile-ts-menu))
         (port-args (transient-arg-value "-a" args))
         (env-vars (transient-arg-value "-e" args))
         (port-name (portfile-ts--select-port))
         (cmd (mapconcat
               #'identity
               (delq nil
                     (append
                      (when env-vars
                        (split-string-and-unquote env-vars))
                      (when sudo '("sudo"))
                      (list "port" action port-name)
                      (when port-args
                        (split-string-and-unquote port-args))))
               " "))
         (buffer (get-buffer-create "*port*"))
         proc)
    (when (and (buffer-file-name) (buffer-modified-p))
      (save-buffer))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (goto-char (point-max))
        (insert (format "\n$ %s\n" cmd)))
      (comint-mode)
      (goto-address-mode 1)
      (let ((process-connection-type t))
        (setq proc (start-file-process
                    "port" buffer shell-file-name
                    shell-command-switch cmd)))
      (set-process-filter proc #'comint-output-filter)
      (when func
        (set-process-sentinel
         proc
         (lambda (_proc _event)
           (funcall func))))
      (display-buffer buffer))))

;;; Commands
;;  --------

(defun portfile-ts-lint ()
  "Lint the port."
  (interactive)
  (portfile-ts--run "lint"))

(defun portfile-ts-fetch ()
  "Fetch the port's distfiles."
  (interactive)
  (portfile-ts--run "fetch" :sudo t))

(defun portfile-ts-checksum ()
  "Generate checksums for the port's distfiles."
  (interactive)
  (portfile-ts--run "checksum" :sudo t))

(defun portfile-ts-bump ()
  "Bump the port version and revert buffer when done."
  (interactive)
  (portfile-ts--run
   "bump"
   :func (lambda () (revert-buffer :ignore-auto :noconfirm))))

(defun portfile-ts-extract ()
  "Extract the port's distfiles."
  (interactive)
  (portfile-ts--run "extract" :sudo t))

(defun portfile-ts-build ()
  "Build the port."
  (interactive)
  (portfile-ts--run "build" :sudo t))

(defun portfile-ts-destroot ()
  "Create the port's destroot."
  (interactive)
  (portfile-ts--run "destroot" :sudo t))

(defun portfile-ts-install ()
  "Install the port."
  (interactive)
  (portfile-ts--run "install" :sudo t))

(defun portfile-ts-uninstall ()
  "Uninstall the port."
  (interactive)
  (portfile-ts--run "uninstall" :sudo t))

(defun portfile-ts-activate ()
  "Activate the port."
  (interactive)
  (portfile-ts--run "activate" :sudo t))

(defun portfile-ts-deactivate ()
  "Deactivate the port."
  (interactive)
  (portfile-ts--run "deactivate" :sudo t))

;;; Transient
;;  ---------

(transient-define-infix portfile-ts--infix-args ()
  "Additional arguments for the port command."
  :class 'transient-option
  :argument "-a="
  :description "Port args"
  :reader (lambda (prompt _initial _history)
            (read-from-minibuffer prompt "")))

(transient-define-infix portfile-ts--infix-env ()
  "Environment variable assignments for the port command."
  :class 'transient-option
  :argument "-e="
  :description "Environment"
  :reader (lambda (prompt _initial _history)
            (read-from-minibuffer prompt "")))

;;;###autoload (autoload 'portfile-ts-menu "portfile-ts-commands" nil t)
(transient-define-prefix portfile-ts-menu ()
  "Port commands for current Portfile."
  [["Maintenance"
    ("l" "Lint" portfile-ts-lint)
    ("B" "Bump" portfile-ts-bump)
    ("C" "Checksum" portfile-ts-checksum)]
   ["Build"
    ("f" "Fetch" portfile-ts-fetch)
    ("e" "Extract" portfile-ts-extract)
    ("b" "Build" portfile-ts-build)
    ("d" "Destroot" portfile-ts-destroot)]
   ["Install"
    ("i" "Install" portfile-ts-install)
    ("u" "Uninstall" portfile-ts-uninstall)]
   ["Activate"
    ("a" "Activate" portfile-ts-activate)
    ("d" "Deactivate" portfile-ts-deactivate)]
   ["Arguments"
    ("-a" "Port args" portfile-ts--infix-args)
    ("-e" "Environment" portfile-ts--infix-env)]])

(defun portfile-ts-commands-setup ()
  "Setup port commands."
  (define-key portfile-ts-mode-map (kbd "C-x c") #'portfile-ts-menu))

;;;###autoload
(add-hook 'portfile-ts-mode-hook #'portfile-ts-commands-setup)

(provide 'portfile-ts-commands)

;;; portfile-ts-commands.el ends here
