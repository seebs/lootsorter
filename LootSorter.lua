--[[ LootSorter
     /ls

     What are the four lowercase letters that are not legal flag arguments
     to the Berkeley UNIX version of `ls'?

     (Answer:  Actually, there's five, ejvyz.)

]]--

local ls = {}
ls.version = "VERSION"
local lbag = Library.LibBaggotry
LootSorter = ls

ls.item_list = {}
ls.item_count = 0
ls.item_ordered = {}
ls.order_asc = true
ls.selected = nil

function ls.printf(fmt, ...)
  print(string.format(fmt or 'nil', ...))
end

ls.columns = {
  { name = 'Name', key = 'name', width = 200 },
  { name = 'Qty', key = 'qty', width = 35 },
  { name = 'Rarity', key = 'rarity', width = 75 },
  { name = 'Location', key = 'loc', width = 100 },
  { name = 'Owner', key = 'owner', width = 150 },
}

function ls.makecolumns(item)
  local xoff = 0
  for i, v in ipairs(ls.columns) do
    local f = item.subframes[i]
    f:SetPoint("TOPLEFT", item.frame, "TOPLEFT", xoff, 0)
    f:SetPoint("BOTTOMRIGHT", item.frame, "BOTTOMLEFT", xoff + v.width, 0)
    f:SetMouseMasking("limited")
    f.Event.LeftClick = function(...) ls.leftclick(item.index, v.key, ...) end
    xoff = xoff + v.width + 5
  end
end

function ls.makeitem(idx)
  local item = {}
  item.index = idx
  item.frame = UI.CreateFrame("Frame", "Item Frame", ls.window)
  item.frame.Event.LeftClick = function(...) ls.leftclick(idx, nil, ...) end
  item.subframes = {}
  for i, v in ipairs(ls.columns) do
    item.subframes[i] = UI.CreateFrame("Text", "Column", item.frame)
  end
  return item
end

function ls.setgrey(frame, count)
  local grey = 0.25
  frame:SetBackgroundColor(grey, grey, grey, 0.4)
end

function ls.leftclick(idx, field, ...)
  -- try to prevent confusions
  ls.leftup(...)
  if idx == 0 then
    local func = ls.order_funcs[field]
    if func then
      if ls.order == func then
        ls.order_asc = not ls.order_asc
      else
        ls.order_asc = true
	ls.order = func
      end
      ls.reorder()
      ls.show_items()
    end
  elseif idx then
    local pos = math.floor(ls.scrollbar:GetPosition())
    ls.selected = idx + pos
    ls.show_items()
  end
end

-- handle dragging
function ls.leftdown(...)
  ls.dragging = true
  ls.window_x = ls.window:GetLeft()
  ls.window_y = ls.window:GetTop()
end

function ls.mousemove(...)
  if not ls.dragging then
    return
  end
  local event, x, y = ...
  if not ls.event_x then
    ls.event_x = x
    ls.event_y = y
  else
    local newx = ls.window_x + x - ls.event_x
    local newy = ls.window_y + y - ls.event_y
    ls.window:SetPoint("TOPLEFT", UIParent, "TOPLEFT", newx, newy)
  end
end

function ls.leftup(...)
  ls.dragging = false
  ls.event_x = nil
  ls.event_y = nil
end

function ls.makewindow()
  if ls.window then
    ls.ui:SetVisible(true)
    ls.window:SetVisible(true)
    return
  end
  ls.item_lines = 20
  ls.window = UI.CreateFrame("RiftWindow", "LootSorter", ls.ui)
  ls.window:SetWidth(800)
  ls.window:SetTitle("LootSorter")

  local l, t, r, b = ls.window:GetTrimDimensions()

  ls.scrollbar = UI.CreateFrame("RiftScrollbar", "LootSorter", ls.window)
  ls.scrollbar:SetPoint("TOPRIGHT", ls.window, "TOPRIGHT", -2 + r * -1, t + 80)
  ls.scrollbar:SetPoint("BOTTOMRIGHT", ls.window, "BOTTOMRIGHT", -2 + r * -1, -2 + b * -1)
  -- only active when there is scrolletry to do
  ls.scrollbar:SetEnabled(false)
  ls.scrollbar.Event.ScrollbarChange = ls.show_items
  ls.window.Event.WheelBack = function() ls.scrollbar:Nudge(3) end
  ls.window.Event.WheelForward = function() ls.scrollbar:Nudge(-3) end
  local w = ls.scrollbar:GetWidth()

  ls.window:GetContent():SetMouseMasking("full")
  ls.window:GetBorder().Event.LeftDown = ls.leftdown
  ls.window:GetBorder().Event.MouseMove = ls.mousemove
  ls.window:GetBorder().Event.LeftUp = ls.leftup

  ls.heading = ls.makeitem(0)
  ls.heading.index = 0
  ls.heading.frame:SetBackgroundColor(0, 0, 0, 0)
  ls.heading.frame:SetPoint("TOPLEFT", ls.window, "TOPLEFT", l + 2, t + 60)
  ls.heading.frame:SetPoint("BOTTOMRIGHT", ls.window, "TOPRIGHT", -2 + (r * -1) - w, t + 78)
  ls.makecolumns(ls.heading)
  ls.show_item(ls.heading, {}, true)

  ls.items = {}
  for i = 1, ls.item_lines do
    ls.items[i] = ls.makeitem(i)
    ls.setgrey(ls.items[i].frame, i)
    ls.items[i].frame:SetPoint("TOPLEFT", ls.window, "TOPLEFT", l + 2, t + 60 + (20 * i))
    ls.items[i].frame:SetPoint("BOTTOMRIGHT", ls.window, "TOPRIGHT",
    	-2 + (r * -1) - w,
	t + (20 * i) + 78)
    ls.makecolumns(ls.items[i])
  end
end

function ls.display_loc(frame, item)
  local loc
  if item._slotspec then
    local s = lbag.slotspec_p(item._slotspec)
    if s then
      local type, p1, p2 = Utility.Item.Slot.Parse(item._slotspec)
      loc = type
    else
      loc = "???"
    end
  else
    loc = "??"
  end
  frame:SetText(loc)
  frame:SetFontColor(0.98, 0.98, 0.98)
end

function ls.display_name(frame, item)
  frame:SetText(item.name or "NO NAME")
  local r, g, b = lbag.rarity_color(item.rarity)
  frame:SetFontColor(r, g, b)
end

function ls.display_owner(frame, item)
  local owner = string.match(item._charspec or "--", '.*/(.*)') or "--"
  frame:SetText(owner)
  if owner == '--' then
    frame:SetFontColor(0.5, 0.5, 0.5)
  else
    frame:SetFontColor(0.98, 0.98, 0.98)
  end
end

function ls.display_rarity(frame, item)
  frame:SetText(item.rarity or "common")
  local r, g, b = lbag.rarity_color(item.rarity)
  frame:SetFontColor(r, g, b)
end

function ls.display_qty(frame, item)
  local x
  if item.stack then
    x = string.format("%d", item.stack)
  else
    x = ""
  end
  frame:SetText(x)
  frame:SetFontColor(0.98, 0.98, 0.98)
end

ls.display_funcs = {
  loc = ls.display_loc,
  qty = ls.display_qty,
  name = ls.display_name,
  owner = ls.display_owner,
  rarity = ls.display_rarity,
}

function ls.order_qty(a, b)
  local acmp, bcmp
  a = ls.item_list[a]
  b = ls.item_list[b]
  acmp = a and (a.stack or 1) or 0
  bcmp = b and (b.stack or 1) or 0
  if acmp == bcmp then
    return false
  end
  if acmp > bcmp then
    return ls.order_asc
  else
    return not ls.order_asc
  end
end

function ls.order_owner(a, b)
  local acmp, bcmp
  a = ls.item_list[a]
  b = ls.item_list[b]
  acmp = a and (a._charspec or "") or ""
  bcmp = b and (b._charspec or "") or ""
  if acmp == bcmp then
    return false
  end
  if acmp < bcmp then
    return ls.order_asc
  else
    return not ls.order_asc
  end
end

function ls.order_name(a, b)
  local acmp, bcmp
  a = ls.item_list[a]
  b = ls.item_list[b]
  acmp = a and (a.name or "") or ""
  bcmp = b and (b.name or "") or ""
  if acmp == bcmp then
    return false
  end
  if acmp < bcmp then
    return ls.order_asc
  else
    return not ls.order_asc
  end
end

function ls.order_rarity(a, b)
  local acmp, bcmp
  a = ls.item_list[a]
  b = ls.item_list[b]
  acmp = a and (lbag.rarity_p(a.rarity)) or 0
  bcmp = b and (lbag.rarity_p(b.rarity)) or 0
  if acmp == bcmp then
    return false
  end
  if acmp > bcmp then
    return ls.order_asc
  else
    return not ls.order_asc
  end
end

function ls.order_loc(a, b)
  local acmp, bcmp
  a = ls.item_list[a]
  b = ls.item_list[b]
  acmp = a and (a._slotspec) or ""
  bcmp = b and (b._slotspec) or ""
  if acmp == bcmp then
    return false
  end
  if acmp < bcmp then
    return ls.order_asc
  else
    return not ls.order_asc
  end
end

ls.order_funcs = {
  loc = ls.order_loc,
  qty = ls.order_qty,
  name = ls.order_name,
  owner = ls.order_owner,
  rarity = ls.order_rarity,
}

ls.order = ls.order_name

function ls.show_item(frame, item, heading)
  for i, v in ipairs(ls.columns) do
    local sub = frame.subframes[i]
    if not sub then
      ls.printf("Error:  Missing subframe %d", i)
      break
    end
    if heading then
      sub:SetText(v.name)
      sub:SetFontColor(1, 1, 0.8)
    else
      local func = ls.display_funcs[v.key]
      if func then
        func(sub, item)
      else
        sub:SetText(v.name)
	sub:SetFontColor(1, 0.3, 0.3)
      end
    end
  end
  frame.frame:SetVisible(true)
end

function ls.show_items()
  ls.makewindow()

  local max
  local pos = math.floor(ls.scrollbar:GetPosition())

  for i = 1, ls.item_lines do
    local item_idx = i + pos
    local item_name = ls.item_ordered[item_idx]
    if item_name then
      local item = ls.item_list[item_name]
      if not item then
	ls.printf("Trying to look at pos %d out of %d, got %s",
	  item_idx, ls.item_count, item_name or "nil")
      else
        ls.show_item(ls.items[i], item)
      end
      if item_idx == ls.selected then
        ls.items[i].frame:SetBackgroundColor(0.4, 0.4, 0.2, 0.4)
      else
        ls.setgrey(ls.items[i].frame, item_idx)
      end
    else
      ls.items[i].frame:SetVisible(false)
    end
  end
end

function ls.reorder()
  table.sort(ls.item_ordered, ls.order)
end

function ls.dump(filter)
  ls.item_list = filter:find()
  ls.item_count = 0
  ls.item_ordered = {}
  for k, v in pairs(ls.item_list) do
    ls.item_count = ls.item_count + 1
    table.insert(ls.item_ordered, k)
  end
  ls.reorder()

  -- ensure window is available
  ls.makewindow()

  if ls.item_count > ls.item_lines then
    ls.scrollbar:SetEnabled(true)
  else
    ls.scrollbar:SetEnabled(false)
  end
  if ls.item_count > ls.item_lines then
    ls.scrollbar:SetRange(0, ls.item_count - ls.item_lines)
    ls.scrollbar:SetThickness(ls.item_lines)
  else
    ls.scrollbar:SetRange(0, 1)
    ls.scrollbar:SetThickness(1)
  end
  ls.scrollbar:SetPosition(1)
  ls.show_items()
end

function ls.slashcommand(args)
  local stack = false
  local filter = lbag.filter()
  local stack_size = nil
  if not args then
    return
  end
  if args['v'] then
    bag.printf("version %s", bag.version)
    return
  end

  if args['x'] then
    filtery = function(...) filter:exclude(...) end
  else
    if args['r'] then
      filtery = function(...) filter:require(...) end
    else
      filtery = function(...) filter:include(...) end
    end
  end

  if args['c'] then
    filtery('category', args['c'])
  end
  if args['C'] then
    local spec = filter:slot()
    local newspec = {}
    if string.match(args['C'], '/') then
      charspec = args['C']
    else
      charspec = lbag.char_identifier(args['C'])
    end
    for i, v in ipairs(spec) do
      local slotspec, _ = lbag.slotspec_p(v)
      if not slotspec then
        table.insert(newspec, string.format("%s:%s", charspec, Utility.Item.Slot.Inventory()))
        table.insert(newspec, string.format("%s:%s", charspec, Utility.Item.Slot.Bank()))
      else
        table.insert(newspec, string.format("%s:%s", charspec, slotspec))
      end
    end
    filter:slot(unpack(newspec))
  end
  if args['q'] then
    if lbag.rarity_p(args['q']) then
      filtery('>=', 'rarity', args['q'])
    else
      bag.printf("Error: '%s' is not a valid rarity.", args['q'])
    end
  end
  for _, word in pairs(args['leftover_args']) do
    if string.match(word, ':') then
      filtery(bag.strsplit(word, ':'))
    else
      filtery('name', word)
    end
  end

  if args['D'] then
    filter:dump()
    return
  end
  if args['s'] then
    local total, count

    total, count = lbag.iterate(filter, valuation)

    local silver = total % 100
    local gold = math.floor(total / 100)
    local plat = math.floor(gold / 100)
    gold = gold % 100
    if plat > 0 then
      bag.printf("%d item(s), total value: %dp%dg%ds.", count, plat, gold, silver)
    elseif gold > 0 then
      bag.printf("%d item(s), total value: %dg%ds.", count, gold, silver)
    elseif silver > 0 then
      bag.printf("%d item(s), total value: %ds.", count, silver)
    else
      bag.printf("Total value: none.")
    end
    return
  end
  ls.dump(filter)
end

ls.ui = UI.CreateContext("LootSorter")
ls.ui:SetVisible(false)

Library.LibGetOpt.makeslash("c:C:Dq:rsvx", "LootSorter", "ls", ls.slashcommand)
