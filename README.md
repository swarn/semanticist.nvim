# Semanticist.nvim

## NO LONGER REQUIRED

Just a note for the handful of people who used this: you don't need it after
2023-03-06, when [this PR](https://github.com/neovim/neovim/pull/22022) was
merged into neovim nightly. See:

- `:h lsp-semantic-highlight`
- `:h LspTokenUpdate`


Control how neovim uses LSP semantic tokens to apply highlights. Requires
neovim nightly.

> **Warning**
>
> This is experimental, unstable, etc.


## Use

Set up the plugin as usual:
``` lua
require('semanticist').setup()
```

Then add a custom highlighter for a filetype:
``` lua
require('semanticist').highlighters[ft] = function(bufnr, ns, token)
  -- Add extmarks here
end
```

Or change the default:
``` lua
require('semanticist').default_highlighter = function(bufnr, ns, token)
  -- Add extmarks here
end
```


### An example with clangd

Here are the types of semantic tokens sent by clangd:

    variable        parameter       function        method
    function        property        class           interface
    enum            enumMember      type            unknown
    namespace       typeParameter   concept         type
    macro           modifier        operator        comment

The modifiers clangd uses are:

    functionScope   classScope      fileScope       globalScope
    declaration     definition      deprecated      readonly
    static          deduced         abstract        virtual
    dependentName   usedAsMutableReference
    userDefined     usedAsMutablePointer
    defaultLibrary  constructorOrDestructor

Some of the modifiers are mutually exclusive, like `functionScope` and
`classScope`. Others can be combined, like `static` and `readonly`.

For this example, I want to differentiate scopes, then apply an additional
highlight for deprecated tokens.
``` lua
semanticist.highlighters["cpp"] = function(bufnr, ns, token)

  local mark = function(hl_group, delta)
    delta = delta or 0
    vim.api.nvim_buf_set_extmark(bufnr, ns, token.line, token.start_col, {
      hl_group = hl_group,
      end_col = token.end_col,
      priority = vim.highlight.priorities.semantic_tokens + delta,
      strict = false,
    })
  end

  local mods = token.modifiers
  vim.tbl_add_reverse_lookup(mods)

  local scope = mods.functionScope and ".functionScope"
    or mods.globalScope and ".globalScope"
    or mods.classScope and ".classScope"
    or mods.fileScope and ".fileScope"
    or ""
  mark(string.format("@%s.cpp%s", token.type, scope))

  if mods.deprecated then mark("LspDeprecated", 1) end
end
```

Then add highlight groups as desired:
``` vim
hi @variable.cpp.functionScope ...
hi @variable.cpp.localScope ...
...
hi LspDeprecated gui=strikethrough
```
