local unicode = require("unicode")

local util = {}

function util.rect_intersect(ax1, ay1, ax2, ay2, bx1, by1, bx2, by2)
  if bx1 <= ax2 and by1 <= ay2 and bx2 >= ax1 and by2 >= ay1 then
		return
			math.max(bx1, ax1),
			math.max(by1, ay1),
			math.min(bx2, ax2),
			math.min(by2, ay2)
	end
end

---@param text string
---@param max_w number
---@param max_h number
---@return string[], number, number @lines, width, height of the wrapped text
function util.measure_and_wrap_text(text, max_w, max_h)
  local lines = {}
  local cur_line = ""
  local max_width = 0
  for i = 1, #text do
    local ch = text:sub(i, i)

    if ch == '\n' then
      max_width = math.max(max_width, #cur_line)
      table.insert(lines, cur_line)
      cur_line = ""
    elseif (#cur_line+1) >= max_w then
      max_width = math.max(max_width, #cur_line)
      table.insert(lines, cur_line)
      cur_line = ch
    else
      cur_line = cur_line .. ch
    end
  end

  if cur_line ~= "" then
    table.insert(lines, cur_line)
  end

  return lines, max_width, #lines
end

return util
