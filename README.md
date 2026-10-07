<div align="center">

# portfile-ts-mode

![GitHub License](https://badgen.net/github/license/judaew/dotfiles)
![Github Tag](https://badgen.net/github/tag/judaew/portfile-ts-mode)

</div>

A major mode for editing [MacPorts](https://www.macports.org/)
Portfiles, powered by Emacs's built-in tree-sitter support.

Parser: [tree-sitter-portfile](https://github.com/judaew/tree-sitter-portfile)

## Features

- Syntax highlighting (tree-sitter-based)
- Indentation and alignment
- Completion for options
- Syntax-aware navigation
- Support `outline-minor-mode`

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

**Completion:**

Completion candidates are generated from the Portfile language
definitions (see `portfile-language.json`) and include:

- Portfile options including options provided by PortGroups
- Phases and pre-post- phase hooks
- Built-in Tcl and MacPorts commands

The mode adds `portfile-ts-completion-at-point` to Emacs's standard
`completion-at-point-functions`. Completion therefore works out of
thebox with Corfu, and with Company through its `company-capf`
backend.
