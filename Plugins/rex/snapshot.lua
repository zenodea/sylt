local terminal = "com.superlogical.terminal"
local panes = {}

local function record(status)
  for _, r in ipairs(status.records or {}) do
    if r.id == nil then return r end
  end
  return (status.records or {})[1]
end

for _, session in ipairs((rex.call("session.list") or {}).sessions or {}) do
  local attached = rex.call("session.attach", { session_id = session.session_id })
  local windows = {}
  for _, w in ipairs(attached and attached.view.windows or {}) do windows[w.window_id] = w end
  for _, block in ipairs((rex.call("session.list_blocks", { session_id = session.session_id }) or {}).blocks or {}) do
    if block.creator_name == terminal then
      local ids = { session_id = session.session_id, block_id = block.block_id }
      local r = record(rex.block.call(terminal, "program_status", ids) or {})
      if r then
        local window = windows[block.window_id] or {}
        panes[#panes + 1] = {
          session_id = session.session_id, session = session.label,
          window_id = block.window_id, window = window.label,
          block_id = block.block_id, label = block.label,
          title = (rex.block.call(terminal, "title", ids) or {}).title,
          state = r.state, kind = r.kind, app = r.effective_app or r.app, msg = r.msg,
        }
      end
    end
  end
end

local app
for _, client in ipairs((rex.call("client.list") or {}).clients or {}) do
  if client.info and client.info.kind == "app" then app = client.client_id end
end

return { panes = panes, app = app }
