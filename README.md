# Semanticist.nvim

Control how neovim uses LSP semantic tokens to apply highlights. This simply
takes the code from neovim/neovim#21804, with almost no changes, and makes it
available as a plugin.

Because it duplicates the semantic token engine from the in-development neovim
9, `semanticist` works with the current release (8.2).

> **Warning**
>
> This is experimental, unstable, etc.


## Install

This only provides a module, so no `require('semanticist').setup()` is needed.


## Use

Three steps are required:

1. Register a handler for `workspace/semanticTokens/refresh` for a server you
   want to customize.

2. Start a `sematicist` highlighter for every buffer that server attaches to.

3. If using neovim nightly (9.0), disable the built-in semantic highlighter for
   those buffers.

The tokens found by `semanticist` are not shown by the excellent `:Inspect`
command added to neovim 9. Instead, you can print them using:
``` lua
    require('semanticist').inspect()
```


### An example of use semanticist with clangd:

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

For this example, I want to set up highlighting to differentiate variable
storage classes and function scopes. First, I write a callback to apply
highlights.

``` lua
local clangd_cb = function(bufnr, ns, token)
  local mods = token.modifiers
  vim.tbl_add_reverse_lookup(mods)

  local hl_group
  if token.type == "variable" then
    if mods.functionScope then
      hl_group = "@variable.cpp.functionScope"
    elseif mods.fileScope then
      hl_group = "@variable.cpp.fileScope"
    elseif mods.classScope then
      hl_group = "@variable.cpp.classScope"
    else
      hl_group = "@variable.cpp.globalScope"
    end
  elseif token.type == "function" then
    if mods.globalScope then
      hl_group = "@function.cpp.globalScope"
    elseif mods.classScope and mods.static then
      hl_group = "@function.cpp.static"
    else
      hl_group = "@function.cpp.fileScope"
    end
  else
    hl_group = string.format("@%s.cpp", token.type)
  end

  vim.api.nvim_buf_set_extmark(bufnr, ns, token.line, token.start_col, {
    hl_group = hl_group,
    end_col = token.end_col,
    priority = vim.highlight.priorities.treesitter + 25,
    strict = false,
  })
end
```

Then, to configure With lspconfig:
``` lua
require('lspconfig')['clangd'].setup{
  handlers = {
    ["workspace/semanticTokens/refresh"] = require("semanticist").handler,
  },
  on_attach = function(client, buffer)
    on_attach(client, buffer)
    require("semanticist").start(buffer, client.id, { hl_cb = clangd_cb })

    -- Disable the built-in token engine, if it exists.
    if not vim.lsp.semantic_tokens then return end
    vim.defer_fn(function() vim.lsp.semantic_tokens.stop(buffer, client.id) end, 50)
  end,
}
```
