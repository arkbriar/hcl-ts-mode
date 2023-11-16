;;; hcl-ts-mode.el --- tree-sitter support for HCL  -*- lexical-binding: t; -*-

;; Copyright (C) 2023 arkbriar.

;; Author     : Shunjie Ding <arkbriar@gmail.com>
;; Maintainer : Shunjie Ding <arkbriar@gmail.com>
;; Created    : November 2023
;; Keywords   : HCL language tree-sitter

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;;

;;; Code:

(require 'treesit)
(eval-when-compile (require 'rx))

(declare-function treesit-parser-create "treesit.c")

(defcustom hcl-ts-mode-indent-offset 2
  "Number of spaces for each indentation step in `hcl-ts-mode'."
  :version "29.1"
  :type 'integer
  :safe 'integerp
  :group 'hcl)

(defvar hcl-ts-mode--syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?+   "."      table)
    (modify-syntax-entry ?-   "."      table)
    (modify-syntax-entry ?=   "."      table)
    (modify-syntax-entry ?%   "."      table)
    (modify-syntax-entry ?&   "."      table)
    (modify-syntax-entry ?|   "."      table)
    (modify-syntax-entry ?!   "."      table)    
    (modify-syntax-entry ?<   "."      table)
    (modify-syntax-entry ?>   "."      table)
    (modify-syntax-entry ??   "."      table)
    (modify-syntax-entry ?:   "."      table)
    (modify-syntax-entry ?\\  "\\"     table)
    (modify-syntax-entry ?\'  "\""     table)
    (modify-syntax-entry ?/   ". 124b" table)
    (modify-syntax-entry ?*   ". 23b"  table)
    (modify-syntax-entry ?\n  ">"      table)
    (modify-syntax-entry ?#   "<"      table)
    table)
  "Syntax table for `hcl-ts-mode'.")

(defvar hcl-ts-mode--indent-rules
  `((hcl
     ((node-is "block_end") parent-bol 0)  ; }
     ((node-is "object_end") parent-bol 0) ; }
     ((node-is "tuple_end") parent-bol 0)  ; ]
     ((node-is ")") parent-bol 0)          ; )
     ((parent-is "block") parent-bol hcl-ts-mode-indent-offset)
     ((parent-is "object") parent-bol hcl-ts-mode-indent-offset)
     ((parent-is "tuple") parent-bol hcl-ts-mode-indent-offset)
     ((parent-is "function_call") parent-bol hcl-ts-mode-indent-offset)
     (no-node parent-bol 0)))
  "Tree-sitter indent rules for `hcl-ts-mode'.")

;; In fact, there's no global kerwords in HCL but I'd prefer to mark
;; them globally and remind users not to use them as identifiers.
(defvar hcl-ts-mode--keywords
  '("for" "endfor" "in" "if" "else" "endif")
  "HCL keywords for tree-sitter font-locking.")

(defvar hcl-ts-mode--operators
  '("!" "*" "/" "%" "+" "-" ">" ">=" "<" "<="
    "==" "!=" "&&" "||")
  "HCL operators for tree-sitter font-locking.")


(defvar hcl-ts-mode--font-lock-settings
  (treesit-font-lock-rules
   :language 'hcl
   :feature 'operator
   `([,@hcl-ts-mode--operators] @font-lock-operator-face)

   :language 'hcl
   :feature 'operator
   '((ellipsis) @font-lock-operator-face)
   
   :language 'hcl
   :feature 'bracket
   '((["(" ")" "[" "]" "{" "}"]) @font-lock-bracket-face)

   :language 'hcl
   :feature 'delimiter
   '(["," "." ".*" "[*]"
      (heredoc_identifier)
      (heredoc_start)] @font-lock-delimiter-face)

   :language 'hcl
   :feature 'punctuation
   '(["?" "=>"
      (template_interpolation_start)
      (template_interpolation_end)
      (template_directive_start)
      (template_directive_end)
      (strip_marker)] @font-lock-punctation-face)

   :language 'hcl
   :feature 'keyword
   `([,@hcl-ts-mode--keywords] @font-lock-keyword-face)

   :language 'hcl
   :feature 'comment
   '((comment) @font-lock-comment-face)

   :language 'hcl
   :feature 'constant
   '([(bool_lit) (null_lit)] @font-lock-constant-face)

   :language 'hcl
   :feature 'number
   '((numeric_lit) @font-lock-number-face)

   :language 'hcl
   :feature 'string
   '([(quoted_template_start)
      (quoted_template_end)
      (template_literal)] @font-lock-string-face)

   ;; Identifier of a first-level block.
   :language 'hcl
   :feature 'definition
   '((config_file (body (block (identifier) @font-lock-keyword-face))))

   ;; Identifier of a nested block. 
   :language 'hcl
   :feature 'type
   '((body (block (body (block (identifier) @font-lock-type-face)))))

   ;; Identifier of a function call (function name).
   :language 'hcl
   :feature 'function
   '((function_call (identifier) @font-lock-function-call-face))

   :language 'hcl
   :feature 'variable
   '((variable_expr (identifier) @font-lock-variable-use-face)
     (expression (variable_expr (identifier) @font-lock-variable-use-face)))

   :language 'hcl
   :feature 'property
   '((attribute (identifier) @font-lock-property-name-face)
     ;; { key: val }
     ;; highlight identifier keys as though they were block attributes
     (object_elem key: (expression (variable_expr (identifier) @font-lock-property-name-face)))
     ;; var.foo, data.bar
     ;; first element in get_attr is a variable.builtin or a reference to a variable.builtin
     (get_attr (identifier) @font-lock-property-use-face)
     ;; var.*.foo
     (attr_splat (get_attr (identifier) @font-lock-property-use-face))
     ;; var[*].foo
     (full_splat (get_attr (identifier) @font-lock-property-use-face)))

   :language 'hcl
   :feature 'error
   :override t
   '((ERROR) @font-lock-warning-face))
  "Tree-sitter font-lock settings for `hcl-ts-mode'.")

;;;###autoload
(define-derived-mode hcl-ts-mode prog-mode "HCL"
  "Major mode for editing HCL, powered by tree-sitter."
  :group 'hcl
  :syntax-table hcl-ts-mode--syntax-table

  (when (treesit-ready-p 'hcl)
    (treesit-parser-create 'hcl)

    ;; Comments.
    (setq-local comment-start "// ")
    (setq-local comment-end "")
    (setq-local comment-start-skip (rx "//" (* (syntax whitespace))))

    ;; Indent.
    (setq-local indent-tabs-mode nil
                treesit-simple-indent-rules hcl-ts-mode--indent-rules)

    ;; Electric.
    (setq-local electric-indent-chars
                (append "{}[]()" electric-indent-chars))

    ;; Font-lock.
    (setq-local treesit-font-lock-settings hcl-ts-mode--font-lock-settings)

    ;; Feature list.
    (setq-local treesit-font-lock-feature-list
                '((comment definition)
                  (keyword string type)
                  (constant number function)
                  (bracket delimiter punctuation error property variable operator)))

    (treesit-major-mode-setup)))

(if (treesit-ready-p 'hcl)
    (add-to-list 'auto-mode-alist '("\\.\\(tf\\|hcl\\)\\'" . hcl-ts-mode)))

(provide 'hcl-ts-mode)

;;; hcl-ts-mode.el ends here
