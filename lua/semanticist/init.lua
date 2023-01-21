-- derived from https://github.com/jdrouhard/dotfiles/blob/try_lazy/home/dot_config/nvim/lua/plugins/lsp/semantic_tokens.lua

local api = vim.api
local util = vim.lsp.util
local semantic_tokens = vim.lsp.semantic_tokens

local M = {}

-- A list of custom highlighters by filetype
M.highlighters = {}

-- from jdrouhard: `strict = false` is necessary here for the 1% of cases where
-- the current result doesn't actually match the buffer contents. Some LSP
-- servers can respond with stale tokens on requests if they are still
-- processing changes from a didChange notification.
--
-- LSP servers that do this _should_ follow up known stale responses with a
-- refresh notification once they've finished processing the didChange
-- notification, which would re-synchronize the tokens from our end.
--
-- The server I know of that does this is clangd when the preamble of a file
-- changes and the token request is processed with a stale preamble while the
-- new one is still being built. Once the preamble finishes, clangd sends a
-- refresh request which lets the client re-synchronize the tokens.
--
-- We can't use ephemeral extmarks because the buffer updates are not in sync
-- with the list of semantic tokens. There's a delay between the buffer
-- changing and when the LSP server can respond with updated tokens, and we
-- don't want to "blink" the token highlights while updates are in flight, and
-- we don't want to use stale tokens because they likely won't line up right
-- with the actual buffer.
--
-- Instead, we have to use normal extmarks that can attach to locations in the
-- buffer and are persisted between redraws.

function M.default_highlighter(bufnr, namespace, token)
  api.nvim_buf_set_extmark(bufnr, namespace, token.line, token.start_col, {
    hl_group = '@' .. token.type,
    end_col = token.end_col,
    priority = vim.highlight.priorities.semantic_tokens,
    strict = false,
  })

  if #token.modifiers > 0 then
    for _, modifier in pairs(token.modifiers) do
      api.nvim_buf_set_extmark(bufnr, namespace, token.line, token.start_col, {
        hl_group = '@' .. modifier,
        end_col = token.end_col,
        priority = vim.highlight.priorities.semantic_tokens + 1,
        strict = false,
      })
    end
  end
end

setmetatable(M.highlighters, {
  __index = function()
    return M.default_highlighter
  end,
})

local function binary_search(tokens, line)
  local lo = 1
  local hi = #tokens
  while lo < hi do
    local mid = math.floor((lo + hi) / 2)
    if tokens[mid].line < line then
      lo = mid + 1
    else
      hi = mid
    end
  end
  return lo
end

local function on_win(self, topline, botline)
  for _, state in pairs(self.client_state) do
    local current_result = state.current_result
    if current_result.version and current_result.version == util.buf_versions[self.bufnr] then
      if not current_result.namespace_cleared then
        api.nvim_buf_clear_namespace(self.bufnr, state.namespace, 0, -1)
        current_result.namespace_cleared = true
      end

      local highlights = current_result.highlights
      local idx = binary_search(highlights, topline)

      local ft = vim.bo[self.bufnr].filetype
      local highlighter = M.highlighters[ft]

      for i = idx, #highlights do
        local token = highlights[i]

        if token.line > botline then
          break
        end

        if not token.extmark_added then
          highlighter(self.bufnr, state.namespace, token)
          token.extmark_added = true
        end
      end
    end
  end
end

function M.setup()
  -- override the on_win decorator function in the semantic tokens built-in module
  semantic_tokens.__STHighlighter.on_win = on_win
end

return M
