# hcl-ts-mode

`hcl-ts-mode` provides a [tree-sitter](https://github.com/tree-sitter/tree-sitter) based major mode for [HCL structured configuration language](https://github.com/hashicorp/hcl). Requires Emacs >= 29.

## Installation

Run `M-x treesit-install-language-grammar` to install the [HCL parser](https://github.com/MichaHoffmann/tree-sitter-hcl).

Download the file and add the following configuration to init.el file:

```elisp
(load-path "hcl-ts-mode.el")
```

Or install with [straight.el](https://github.com/radian-software/straight.el):

```elisp
(use-package hcl-ts-mode
  :straight (hcl-ts-mode
             :type git
             :host github
             :repo "arkbriar/hcl-ts-mode"))
```

## License

[GPLv3](LICENSE)
