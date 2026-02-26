# emacs-fe

Tree-sitter major mode for the [Fe language](https://fe-lang.org/) in Emacs.

## Prerequisites

1. **`fe` CLI** (includes the language server) must be installed and available in your PATH:

   ```sh
   curl -fsSL https://raw.githubusercontent.com/argotorg/fe/master/feup/feup.sh | bash
   ```

   Or build from source:

   ```sh
   cargo install --git https://github.com/argotorg/fe.git fe
   ```

2. **Emacs 29.1 or later** (for built-in tree-sitter support)

3. **C compiler** (GCC or Clang, for building the tree-sitter grammar on first use)

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

The package auto-registers `fe lsp` with both Eglot and `lsp-mode` when either is loaded — no manual client registration needed.

To auto-start **Eglot**:

```elisp
(use-package fe
  :vc (:url "https://github.com/fe-lang/emacs-fe"
       :branch "main")
  :custom
  (fe-mode-eglot-auto t))
```

To auto-start **lsp-mode**:

```elisp
(use-package fe
  :vc (:url "https://github.com/fe-lang/emacs-fe"
       :branch "main")
  :custom
  (fe-mode-lsp-auto t))
```

Use either Eglot or `lsp-mode` per buffer, not both at once.

### Emacs distros (Doom, Spacemacs, etc.)

```elisp
(use-package! fe
  :mode ("\\.fe\\'" . fe-mode)
  :custom
  (fe-mode-lsp-auto t))
```
