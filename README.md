# emacs-fe

Tree-sitter major mode for the [Fe language](https://fe-lang.org/) in Emacs.

## Install

Add this to your `~/.emacs.d/init.el`:

```elisp
(use-package fe
  :vc (:url "https://github.com/fe-lang/emacs-fe"
       :branch "main"))
```

## Usage

- Open a `.fe` file to enable `fe-mode` automatically.
- `fe-mode` provides tree-sitter syntax highlighting, indentation, and imenu.

## LSP (optional)

To auto-start Eglot with `fe lsp` in Fe buffers:

```elisp
(use-package fe
  :vc (:url "https://github.com/fe-lang/emacs-fe"
       :branch "main")
  :custom
  (fe-mode-eglot-auto t))
```
