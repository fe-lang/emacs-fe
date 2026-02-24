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

To use `lsp-mode` instead:

```elisp
(use-package lsp-mode
  :hook (fe-mode . lsp-deferred)
  :config
  (add-to-list 'lsp-language-id-configuration '(fe-mode . "fe"))
  (lsp-register-client
   (make-lsp-client
    :new-connection (lsp-stdio-connection '("fe" "lsp"))
    :activation-fn (lsp-activate-on "fe")
    :server-id 'fe-lsp)))
```

Use either Eglot or `lsp-mode` per buffer, not both at once.
