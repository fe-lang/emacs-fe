;;; fe-mode.el --- Tree-sitter major mode for the Fe language -*- lexical-binding: t; -*-

;; Author: Fe Contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages fe
;; URL: https://github.com/argotorg/emacs-fe

;;; Commentary:

;; A tree-sitter based major mode for editing Fe smart contract files.
;; Provides syntax highlighting, indentation, imenu, and LSP integration
;; via eglot.
;;
;; Requirements:
;;   - Emacs 29.1+ (built-in treesit support)
;;   - C compiler (for building the tree-sitter grammar on first use)
;;   - `fe' CLI on PATH (for LSP and project root detection)
;;
;; Usage:
;;   (require 'fe-mode)
;;
;; The mode automatically associates with *.fe files.  If eglot is
;; available, it registers `fe lsp' as the language server.

;;; Code:

(require 'treesit)
(require 'project)

(eval-when-compile
  (require 'rx))

(declare-function eglot-ensure "eglot")

;;; Customization

(defgroup fe nil
  "Settings for `fe-mode'."
  :group 'languages
  :prefix "fe-mode-")

(defcustom fe-mode-indent-offset 4
  "Number of spaces for each indentation level in Fe."
  :type 'integer
  :safe #'integerp)

(defcustom fe-mode-eglot-auto nil
  "When non-nil, automatically start eglot in `fe-mode' buffers."
  :type 'boolean
  :safe #'booleanp)

;;; Syntax table

(defvar fe-mode--syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?/ ". 124" table)
    (modify-syntax-entry ?* ". 23b" table)
    (modify-syntax-entry ?\n ">" table)
    (modify-syntax-entry ?\' "\"" table)
    (modify-syntax-entry ?\" "\"" table)
    (modify-syntax-entry ?_ "_" table)
    table)
  "Syntax table for `fe-mode'.")

;;; Font-lock

(defvar fe-mode--keywords
  '("as" "const" "contract" "else" "enum" "extern" "fn" "for"
    "if" "impl" "in" "init" "ingot" "match" "mod" "msg" "mut"
    "recv" "self" "struct" "super" "trait" "type" "unsafe" "use"
    "uses" "where" "while" "with")
  "Fe language keywords for font-lock.")

(defvar fe-mode--operators
  '("!=" "%" "%=" "&" "&=" "&&" "*" "*=" "**" "**="
    "+" "+=" "-" "-=" "->" ".." "/=" ":" "<<"
    "<<=" "<=" "=" "==" "=>" ">" ">=" ">>" ">>="
    "^" "^=" "|" "|=" "||" "~")
  "Fe operator tokens.")

(defun fe-mode--font-lock-settings ()
  "Return tree-sitter font-lock settings for Fe."
  (treesit-font-lock-rules
   ;; Level 1: comments
   :language 'fe
   :feature 'comment
   '((line_comment) @font-lock-comment-face
     (block_comment) @font-lock-comment-face
     (doc_comment) @font-lock-doc-face)

   ;; Level 1: keywords
   :language 'fe
   :feature 'keyword
   `([,@fe-mode--keywords] @font-lock-keyword-face
     (break_statement) @font-lock-keyword-face
     (continue_statement) @font-lock-keyword-face
     (return_statement "return" @font-lock-keyword-face)
     (let_statement "let" @font-lock-keyword-face)
     (visibility) @font-lock-keyword-face)

   ;; Level 2: strings
   :language 'fe
   :feature 'string
   '((string_literal) @font-lock-string-face
     (escape_sequence) @font-lock-escape-face)

   ;; Level 2: types
   :language 'fe
   :feature 'type
   '((self_type) @font-lock-type-face
     (struct_definition name: (identifier) @font-lock-type-face)
     (enum_definition name: (identifier) @font-lock-type-face)
     (contract_definition name: (identifier) @font-lock-type-face)
     (msg_definition name: (identifier) @font-lock-type-face)
     (trait_definition name: (identifier) @font-lock-type-face)
     (impl_trait trait: (trait_ref (path (path_segment (identifier) @font-lock-type-face))))
     (super_trait_list (trait_ref (path (path_segment (identifier) @font-lock-type-face))))
     (type_bound (path (path_segment (identifier) @font-lock-type-face)))
     (variant_def name: (identifier) @font-lock-type-face)
     (msg_variant name: (identifier) @font-lock-type-face)
     ((identifier) @font-lock-type-face
      (:match "^[A-Z]" @font-lock-type-face)))

   ;; Level 2: constants
   :language 'fe
   :feature 'constant
   '((boolean_literal) @font-lock-constant-face
     (integer_literal) @font-lock-number-face
     ((identifier) @font-lock-constant-face
      (:match "^_*[A-Z][A-Z0-9_]*$" @font-lock-constant-face)))

   ;; Level 3: functions
   :language 'fe
   :feature 'function
   '((function_definition name: (identifier) @font-lock-function-name-face)
     (call_expression function: (identifier) @font-lock-function-call-face)
     (call_expression function: (scoped_path name: (identifier) @font-lock-function-call-face))
     (method_call_expression method: (identifier) @font-lock-function-call-face))

   ;; Level 3: properties
   :language 'fe
   :feature 'property
   '((field_expression field: (identifier) @font-lock-property-use-face)
     (record_field_def name: (identifier) @font-lock-property-use-face)
     (record_field name: (identifier) @font-lock-property-use-face)
     (record_pattern_field name: (identifier) @font-lock-property-use-face))

   ;; Level 4: variables (parameters)
   :language 'fe
   :feature 'variable
   '((parameter name: (identifier) @font-lock-variable-name-face)
     (uses_param name: (identifier) @font-lock-variable-name-face))

   ;; Level 4: operators
   :language 'fe
   :feature 'operator
   `([,@fe-mode--operators] @font-lock-operator-face
     (unary_expression "!" @font-lock-operator-face))

   ;; Level 4: punctuation
   :language 'fe
   :feature 'punctuation
   '(["(" ")" "{" "}" "[" "]"] @font-lock-bracket-face
     ["." "," "::"] @font-lock-delimiter-face
     ["#"] @font-lock-misc-punctuation-face)

   ;; Level 4: attributes
   :language 'fe
   :feature 'attribute
   '((attribute name: (identifier) @font-lock-preprocessor-face))))

;;; Indentation

(defvar fe-mode--indent-rules
  `((fe
     ((parent-is "source_file") column-0 0)
     ((node-is ")") parent-bol 0)
     ((node-is "]") parent-bol 0)
     ((node-is "}") parent-bol 0)
     ((parent-is "block") parent-bol fe-mode-indent-offset)
     ((parent-is "function_body") parent-bol fe-mode-indent-offset)
     ((parent-is "struct_definition") parent-bol fe-mode-indent-offset)
     ((parent-is "enum_definition") parent-bol fe-mode-indent-offset)
     ((parent-is "contract_definition") parent-bol fe-mode-indent-offset)
     ((parent-is "msg_definition") parent-bol fe-mode-indent-offset)
     ((parent-is "trait_definition") parent-bol fe-mode-indent-offset)
     ((parent-is "impl_block") parent-bol fe-mode-indent-offset)
     ((parent-is "match_expression") parent-bol fe-mode-indent-offset)
     ((parent-is "match_arm") parent-bol fe-mode-indent-offset)
     ((parent-is "if_expression") parent-bol fe-mode-indent-offset)
     ((parent-is "record_expression") parent-bol fe-mode-indent-offset)
     ((parent-is "record_field_def_list") parent-bol fe-mode-indent-offset)
     ((parent-is "variant_def_list") parent-bol fe-mode-indent-offset)
     ((parent-is "parameter_list") parent-bol fe-mode-indent-offset)
     ((parent-is "argument_list") parent-bol fe-mode-indent-offset)
     ((parent-is "array_expression") parent-bol fe-mode-indent-offset)
     ((parent-is "tuple_expression") parent-bol fe-mode-indent-offset)
     ((parent-is "use_tree_list") parent-bol fe-mode-indent-offset)
     (no-node parent-bol 0)))
  "Tree-sitter indentation rules for Fe.")

;;; Imenu

(defvar fe-mode--imenu-settings
  '(("Function" "\\`function_definition\\'" nil nil)
    ("Struct" "\\`struct_definition\\'" nil nil)
    ("Enum" "\\`enum_definition\\'" nil nil)
    ("Contract" "\\`contract_definition\\'" nil nil)
    ("Trait" "\\`trait_definition\\'" nil nil)
    ("Impl" "\\`impl_block\\'" nil nil))
  "Imenu categories for `fe-mode'.")

;;; Project root detection via `fe root'

(defun fe-mode-project-find-function (dir)
  "Find the Fe project root for DIR by calling `fe root'.
Returns a project instance or nil."
  (when-let* ((fe-file (or (buffer-file-name)
                           (expand-file-name "dummy.fe" dir)))
              (default-directory dir)
              (root (with-temp-buffer
                      (when (zerop (call-process "fe" nil t nil "root" fe-file))
                        (string-trim (buffer-string))))))
    (when (and (not (string-empty-p root))
               (file-directory-p root))
      (cons 'fe root))))

(cl-defmethod project-root ((project (head fe)))
  "Return the root directory of a Fe PROJECT."
  (cdr project))

;;; Eglot integration

(defun fe-mode--setup-eglot ()
  "Register Fe language server with eglot."
  (when (require 'eglot nil t)
    (add-to-list 'eglot-server-programs
                 '(fe-mode . ("fe" "lsp")))))

;;; Grammar installation

(defvar fe-mode--grammar-source
  '("https://github.com/argotorg/fe" "master" "crates/tree-sitter-fe/src")
  "Source for the Fe tree-sitter grammar.
Format: (URL REVISION SOURCE-DIR) — passed to `treesit-language-source-alist'.")

(defun fe-mode--ensure-grammar-source ()
  "Register the Fe grammar in `treesit-language-source-alist'."
  (unless (assq 'fe treesit-language-source-alist)
    (add-to-list 'treesit-language-source-alist
                 (cons 'fe fe-mode--grammar-source))))

(defun fe-mode--ensure-grammar ()
  "Ensure the Fe tree-sitter grammar is installed.
If missing, offer to install it automatically."
  (fe-mode--ensure-grammar-source)
  (unless (treesit-language-available-p 'fe)
    (if (y-or-n-p "Fe tree-sitter grammar is not installed.  Install it now?")
        (progn
          (treesit-install-language-grammar 'fe)
          (unless (treesit-language-available-p 'fe)
            (user-error "Grammar installation failed")))
      (user-error "Fe tree-sitter grammar is required for fe-mode"))))

;;;###autoload
(define-derived-mode fe-mode prog-mode "Fe"
  "Major mode for editing Fe files, powered by tree-sitter.

\\{fe-mode-map}"
  :syntax-table fe-mode--syntax-table
  :group 'fe

  (fe-mode--ensure-grammar)

  ;; Comment settings
  (setq-local comment-start "// ")
  (setq-local comment-end "")
  (setq-local comment-start-skip "\\(?://+\\|/\\*+\\)\\s-*")
  (setq-local comment-multi-line t)

  ;; Tree-sitter setup
  (treesit-parser-create 'fe)

  ;; Font-lock
  (setq-local treesit-font-lock-settings (fe-mode--font-lock-settings))
  (setq-local treesit-font-lock-feature-list
              '((comment keyword)
                (string type constant)
                (function property)
                (variable operator punctuation attribute)))

  ;; Indentation
  (setq-local treesit-simple-indent-rules fe-mode--indent-rules)

  ;; Imenu
  (setq-local treesit-simple-imenu-settings fe-mode--imenu-settings)

  ;; Electric pairs
  (setq-local electric-pair-pairs
              '((?{ . ?}) (?\( . ?\)) (?\[ . ?\]) (?\" . ?\")))

  (treesit-major-mode-setup))

;;; Autoloads and hooks

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.fe\\'" . fe-mode))

;; Register project backend
(add-hook 'fe-mode-hook
          (lambda ()
            (add-hook 'project-find-functions #'fe-mode-project-find-function nil t)))

;; Eglot setup (register server programs once, auto-start per config)
(with-eval-after-load 'eglot
  (fe-mode--setup-eglot))

(add-hook 'fe-mode-hook
          (lambda ()
            (when (and fe-mode-eglot-auto
                       (require 'eglot nil t))
              (eglot-ensure))))

(provide 'fe-mode)
;;; fe-mode.el ends here
