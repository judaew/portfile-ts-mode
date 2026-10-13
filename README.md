<div align="center">

# portfile-ts-mode

![GitHub License](https://badgen.net/github/license/judaew/portfile-ts-mode)
![Github Tag](https://badgen.net/github/tag/judaew/portfile-ts-mode)

</div>

A tree-sitter-based major mode for editing [MacPorts](https://www.macports.org/)
Portfiles, using Emacs's built-in tree-sitter support.

![portfile-ts-mode](https://github.com/user-attachments/assets/3043ec8c-6636-4a9f-a250-0160e1fabebc)

Parser: [tree-sitter-portfile](https://github.com/judaew/tree-sitter-portfile)

## Features

- Syntax highlighting (tree-sitter-based)
- Indentation and alignment
- Completion for options (built-in and PortGroups)
- Syntax-aware navigation and outline support
- Commands and commands menu for common MacPorts operations
- Maintainer livecheck sidebar for checking port version

## Installation

**Requirements:** Emacs 30.1 or newer with tree-sitter support, plus
git and a C compiler to build the grammar.

**Elpaca:**

```emacs-lisp
(use-package portfile-ts-mode
   :ensure (:host github :repo "judaew/portfile-ts-mode"
                  :files ("*.el" "portfile-language.json")))
```

**Manual:**

Clone this repository into your `load-path` and make sure
`portfile-ts-mode.el` and `portfile-language.json` are available in
the same directory.

## Usage

`portfile-ts-mode` is automatically enabled for files named `Portfile` and
can also be enabled with `M-x portfile-ts-mode`.

### Completion

Completion candidates are generated from `portfile-language.json` and
include:

- Portfile options including options provided by PortGroups
- Phases and pre-/post- phase hooks
- Built-in Tcl and MacPorts commands

The mode integrates with Emacs's standard `completion-at-point-functions`,
so completion works with built-in completion and packages such as Corfu.
Company can use it's `company-capf` backend

### MacPorts commands

Press `C-x c` in a Portfile to open `portfile-ts-menu`.

The transient menu provides commands for common operations:

![portfile-ts-menu](https://github.com/user-attachments/assets/13eec0b0-3b62-468d-a084-14336ac779dc)

When a Portfile defines subports, the relevant commands prompt for the
port to operate on.

The menu also provides two options:

| Option              | Description                                               |
|---------------------|-----------------------------------------------------------|
| `-e` (Environment)  | Pass environment variable assignments, such as `CC=clang` |
| `-o` (Port options) | Override Portfile options, such as `build_arch=arm64`     |

Use `portfile-ts-output-toggle` to show or hide the \*port\* output buffer.

### Maintainer livecheck

Run `M-x portfile-ts-livecheck` or select Livecheck from the transient menu
to open the livecheck sidebar.

Set `portfile-ts-livecheck-maintainer` to your MacPorts maintainer
handle. If it is empty, the mode prompts for a maintainer when the
sidebar is opened.

The sidebar displays the old and new versions reported by `port livecheck`,
highighting errors when a check fails.

<img src="https://github.com/user-attachments/assets/cc2c8a24-64de-4f93-aa0c-523b83e6d2f0" alt="portfile-ts-livecheck" width="50%">

Available keybindings:

| Key | Action                                                             |
|-----|--------------------------------------------------------------------|
| RET | Open the Portfile for the selected port                            |
| q   | Stop livecheck and close the sidebar                               |
| u   | Refresh the results                                                |
| w   | Copy the full value of the current cell                            |
| m   | Copy an update message in the format `<port>: update to <version>` |

Use `portfile-ts-livecheck-toggle` to show or hide the sidebar.
