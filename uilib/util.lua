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

return util
