;;; portfile-ts-commands.el --- Port commands for MacPorts -*- lexical-binding: t; -*-

;;; Commentary:
;;; Code:

(require 'transient)
(require 'comint)
(require 'cl-lib)
(require 'vc)
(require 'subr-x)

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

;;; Process executing

(cl-defun portfile-ts--run (action &key sudo func options args)
  "Run port ACTION asynchronously.
When SUDO is non-nil, run the command through sudo.
Call FUNC when the process exits successfully.
OPTIONS is a list of MacPorts option values to pass to the
command.  ARGS is a list of additional arguments to pass to
the command."
  (let* ((transient-arguments (transient-args 'portfile-ts-menu))
         (port-opt (transient-arg-value "-o=" transient-arguments))
         (env-vars (transient-arg-value "-e=" transient-arguments))
         (port-name (portfile-ts--select-port))
         (cmd (mapconcat
               #'identity
               (delq nil
                     (append
                      (when env-vars
                        (split-string-and-unquote env-vars))
                      (when sudo '("sudo"))
                      (list "port" action)
                      args
                      (list port-name)
                      options
                      (when port-opt
                        (split-string-and-unquote port-opt))))
               " "))
         (buffer (get-buffer-create "*port*")))
    (when (and (buffer-file-name) (buffer-modified-p))
      (save-buffer))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (goto-char (point-max))
        (insert (format "\n$ %s\n" cmd)))
      (comint-mode)
      (local-set-key (kbd "q") #'delete-window)
      (goto-address-mode 1)
      (make-process
       :name "port"
       :buffer buffer
       :command (list shell-file-name shell-command-switch cmd)
       :connection-type 'pty
       :noquery t
       :filter #'comint-output-filter
       :sentinel
       (when func
         (lambda (process _event)
           (when (and (memq (process-status process)
                            '(exit signal))
                      (= (process-exit-status process) 0))
             (funcall func)))))
      (display-buffer buffer))))

;;; Port commands
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
  (portfile-ts--run "checksum"))

(defun portfile-ts-bump ()
  "Bump the port version and revert buffer when done."
  (interactive)
  (portfile-ts--run
   "bump"
   :sudo t :func (lambda () (revert-buffer :ignore-auto :noconfirm))))

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

(defun portfile-ts-clean-all ()
  "Clean all files for the port."
  (interactive)
  (portfile-ts--run "clean" :sudo t :args '("--all" "-f")))

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

;;;###autoload
(defun portfile-ts-edit (port)
  "Open the Portfile for PORT."
  (interactive (list (read-string "Port: ")))
  (let ((file
         (with-temp-buffer
           (unless (zerop (process-file "port" nil t nil
                                        "file" port))
             (user-error "Cannot find Portfile for %s" port))
           (string-trim (buffer-string)))))
    (unless (file-readable-p file)
      (user-error "Portfile is not readable: %s" file))
    (find-file file)))

(defun portfile-ts-commit-file ()
  "Commit the current file using VC."
  (interactive)
  (unless buffer-file-name
    (user-error "Current buffer is not visiting a file"))
  (let ((file buffer-file-name)
        (backend (vc-backend buffer-file-name)))
    (unless backend
      (user-error "File is not under version control"))
    (let ((message
           (read-string
            (format "Commit %s: " (file-name-nondirectory file)))))
      (when (string-empty-p (string-trim message))
        (user-error "Commit message cannot be empty"))
      (vc-checkin (list file) backend message)
      (message "Committed %s" (file-name-nondirectory file)))))

;;; Transient menu
;;  --------------

(transient-define-infix portfile-ts--infix-args ()
  "Additional arguments for the port command."
  :class 'transient-option
  :argument "-o="
  :description "Port options"
  :reader (lambda (prompt _initial _history)
            (read-from-minibuffer prompt "")))

(transient-define-infix portfile-ts--infix-env ()
  "Environment variable assignments for the port command."
  :class 'transient-option
  :argument "-e="
  :description "Environment"
  :reader (lambda (prompt _initial _history)
            (read-from-minibuffer prompt "")))

(transient-define-prefix portfile-ts-menu ()
  "Port commands for current Portfile."
  [["Portfile"
    ("e" "Edit" portfile-ts-edit)
    ("c" "Commit file" portfile-ts-commit-file)
    ("u" "Bump" portfile-ts-bump)]
   ["Checks"
    ("l" "Lint" portfile-ts-lint)
    ("L" "Livecheck" portfile-ts-livecheck)
    ("C" "Checksum" portfile-ts-checksum)]
   ["Build"
    ("f" "Fetch" portfile-ts-fetch)
    ("E" "Extract" portfile-ts-extract)
    ("b" "Build" portfile-ts-build)
    ("d" "Destroot" portfile-ts-destroot)
    ("x" "Clean all" portfile-ts-clean-all)]
   ["Install"
    ("i" "Install" portfile-ts-install)
    ("u" "Uninstall" portfile-ts-uninstall)
    ("a" "Activate" portfile-ts-activate)
    ("d" "Deactivate" portfile-ts-deactivate)]
   ["Arguments"
    ("-o" "Port options" portfile-ts--infix-args)
    ("-e" "Environment" portfile-ts--infix-env)]])

(provide 'portfile-ts-commands)

;;; portfile-ts-commands.el ends here
