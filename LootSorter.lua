--[[ LootSorter
     /ls

     What are the four lowercase letters that are not legal flag arguments
     to the Berkeley UNIX version of `ls'?

     (Answer:  Actually, there's five, ejvyz.)

     ls.windows = {
       { window =,
	 filter =,
	 selected =,
	 order =,
	 order_asc =,
       }
       [...]
     }
     ls.spare_windows = {
       window,
       ...
     }

]]--

local ls = {}
ls.version = "VERSION"
local lbag = Library.LibBaggotry
local filt = Library.LibEnfiltrate
LootSorter = ls

ls.item_lines = 22
ls.windows = {}
ls.spare_windows = {}

function ls.printf(fmt, ...)
  print(string.format(fmt or 'nil', ...))
end

function ls.variables_loaded(name)
  if name == 'LootSorter' then
    LootSorterAccount = LootSorterAccount or { window_x = 150, window_y = 150 }
    ls.account_vars = LootSorterAccount
  end
end

ls.columns = {
  { name = 'Icn', key = 'icon', width = 18, type = "Texture" },
  { name = 'Name', key = 'name', width = 200 },
  { name = 'Qty', key = 'qty', width = 70 },
  { name = 'Level', key = 'level', width = 70 },
  { name = 'Rarity', key = 'rarity', width = 75 },
  { name = 'Location', key = 'loc', width = 100 },
  { name = 'Owner', key = 'owner', width = 150 },
}

function ls.makecolumns(window, item)
  local xoff = 0
  for i, v in ipairs(ls.columns) do
    local f = item.subframes[i]
    f:SetPoint("TOPLEFT", item.frame, "TOPLEFT", xoff, 0)
    f:SetPoint("BOTTOMRIGHT", item.frame, "BOTTOMLEFT", xoff + v.width, 0)
    f:SetMouseMasking("limited")
    f.Event.LeftClick = function(...) ls.leftclick(window, item.index, v.key, ...) end
    f.Event.MouseIn = function(...) ls.mousein(window, item.index, v.key, ...) end
    f.Event.MouseOut = function(...) ls.mouseout(window, item.index, v.key, ...) end
    xoff = xoff + v.width + 5
  end
end

function ls.mousein(window, idx, subframe, ...)
  -- ls.printf("mousein %d %s", idx or -1, subframe and tostring(subframe) or 'nil')
  if idx then
    local pos = math.floor(window.scrollbar:GetPosition())
    local item_idx = idx + pos
    local item_name = window.item_ordered[item_idx]
    if window.item_list[item_name] and window.item_list[item_name].type then
      -- sometimes Command.Tooltip throws spurious errors
      local foo = function() Command.Tooltip(window.item_list[item_name].type) end
      pcall(foo)
    end
  end
end

function ls.mouseout(window, idx, ...)
  Command.Tooltip(nil)
end

function ls.makeitem(window, idx)
  local item = {}
  item.index = idx
  item.frame = UI.CreateFrame("Frame", "Item Frame", window.window)
  item.frame.Event.LeftClick = function(...) ls.leftclick(window, idx, nil, ...) end
  item.subframes = {}
  item.frame.Event.MouseIn = function(...) ls.mousein(window, idx, 'outer', ...) end
  item.frame.Event.MouseOut = function(...) ls.mouseout(window, idx, 'outer', ...) end
  for i, v in ipairs(ls.columns) do
    if idx == 0 then
      item.subframes[i] = UI.CreateFrame("Text", "Column", item.frame)
    else
      item.subframes[i] = UI.CreateFrame(v.type or "Text", "Column", item.frame)
    end
  end
  return item
end

function ls.setgrey(frame, count)
  local grey = 0.25
  frame:SetBackgroundColor(grey, grey, grey, 0.4)
end

function ls.leftclick(window, idx, field, ...)
  if idx == 0 then
    local func = ls.order_funcs[field]
    -- if there's no order function, we don't care
    if func then
      if window.order == func then
        window.order_asc = not window.order_asc
      else
        window.order_asc = true
	window.order = func
      end
      ls.reorder(window)
      ls.show_items(window)
    end
  elseif idx then
    local pos = math.floor(window.scrollbar:GetPosition())
    window.selected = idx + pos
    ls.show_items(window)
  end
end

-- handle dragging

function ls.mousemove(window, x, y)
  ls.account_vars.window_x = x
  ls.account_vars.window_y = y
end

local window_template = {}

function window_template:close()
  remove_me = nil
  for idx, window in ipairs(ls.windows) do
    if window == self then
      remove_me = idx
    end
  end
  if remove_me then
    table.remove(ls.windows, remove_me)
  end
  -- don't keep an old selection around
  self.selected = nil
  table.insert(ls.spare_windows, self)
  self.window:SetVisible(false)
end

function window_template:get()
  if ls.spare_windows[1] then
    local win = ls.spare_windows[1]
    table.remove(ls.spare_windows, 1)
    return win
  else
    return window_template:new()
  end
end

function window_template:new()
  local o = {
    order = ls.order_name,
    order_asc = true
  }
  setmetatable(o, self)
  self.__index = self

  o.window = UI.CreateFrame("RiftWindow", "LootSorter", ls.ui)
  o.window:SetWidth(800)
  o.window:SetTitle("LootSorter")
  o.window:SetPoint("TOPLEFT", UIParent, "TOPLEFT", ls.account_vars and ls.account_vars.window_x or 150, ls.account_vars and ls.account_vars.window_y or 150)

  local l, t, r, b = o.window:GetTrimDimensions()

  o.closebutton = UI.CreateFrame("RiftButton", "LootSorter", o.window)
  o.closebutton:SetSkin("close")
  o.closebutton:SetPoint("TOPRIGHT", o.window, "TOPRIGHT", r * -1 + 3, b + 2)
  o.closebutton.Event.LeftPress = function() o:close() end

  o.scrollbar = UI.CreateFrame("RiftScrollbar", "LootSorter", o.window)
  o.scrollbar:SetPoint("TOPRIGHT", o.window, "TOPRIGHT", -2 + r * -1, t + 40)
  o.scrollbar:SetPoint("BOTTOMRIGHT", o.window, "BOTTOMRIGHT", -2 + r * -1, -2 + b * -1)
  -- only active when there is scrolletry to do
  o.scrollbar:SetEnabled(false)
  o.scrollbar:SetRange(0, 1)
  o.scrollbar:SetPosition(0)
  o.scrollbar.Event.ScrollbarChange = function() ls.show_items(o) end
  o.window.Event.WheelBack = function() o.scrollbar:Nudge(3) end
  o.window.Event.WheelForward = function() o.scrollbar:Nudge(-3) end
  local w = o.scrollbar:GetWidth()

  o.window:GetContent():SetMouseMasking("full")
  Library.LibDraggable.draggify(o.window, o.mousemove)

  o.heading = ls.makeitem(o, 0)
  o.heading.index = 0
  o.heading.frame:SetBackgroundColor(0, 0, 0, 0)
  o.heading.frame:SetPoint("TOPLEFT", o.window, "TOPLEFT", l + 2, t + 20)
  o.heading.frame:SetPoint("BOTTOMRIGHT", o.window, "TOPRIGHT", -2 + (r * -1) - w, t + 38)
  ls.makecolumns(o, o.heading)
  ls.show_item(o.heading, {}, true)

  o.items = {}
  for i = 1, ls.item_lines do
    o.items[i] = ls.makeitem(o, i)
    ls.setgrey(o.items[i].frame, i)
    o.items[i].frame:SetPoint("TOPLEFT", o.window, "TOPLEFT", l + 2, t + 20 + (20 * i))
    o.items[i].frame:SetPoint("BOTTOMRIGHT", o.window, "TOPRIGHT",
    	-2 + (r * -1) - w,
	t + (20 * i) + 38)
    ls.makecolumns(o, o.items[i])
  end

  return o
end

function ls.display_loc(frame, item)
  local loc
  if item._slotspec then
    local s = lbag.slotspec_p(item._slotspec)
    if s then
      local type, p1, p2 = Utility.Item.Slot.Parse(item._slotspec)
      loc = type
    else
      loc = item._slotspec
    end
  else
    loc = "<Unknown>"
  end
  frame:SetText(loc)
  frame:SetFontColor(0.98, 0.98, 0.98)
end

function ls.display_icon(frame, item)
  if not item then
    return
  end
  if item.icon then
    frame:SetTexture("Rift", item.icon)
    frame:SetVisible(true)
  else
    frame:SetVisible(false)
  end
end

function ls.display_name(frame, item)
  frame:SetText(item.name or "NO NAME")
  local r, g, b = lbag.rarity_color(item.rarity)
  frame:SetFontColor(r, g, b)
end

function ls.display_owner(frame, item)
  local owner, suffix
  owner = item._character or "--"
  owner = string.upper(string.sub(owner, 1, 1)) .. string.sub(owner, 2)
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

function ls.display_level(frame, item)
  local x
  local me = Inspect.Unit.Detail('player')
  if item.requiredLevel then
    x = tostring(item.requiredLevel)
    if me and me.level and (me.level < item.requiredLevel) then
      frame:SetFontColor(0.9, 0, 0)
    else
      frame:SetFontColor(0.98, 0.98, 0.98)
    end
  else
    x = "--"
    frame:SetFontColor(0.5, 0.5, 0.5)
  end
  frame:SetText(x)
end

function ls.display_qty(frame, item)
  local x
  if item.stackMax or (item.stack and item.stack > 1) then
    x = string.format("%d/%d", item.stack, item.stackMax or 1)
  else
    x = ""
  end
  frame:SetText(x)
  frame:SetFontColor(0.98, 0.98, 0.98)
end

ls.display_funcs = {
  icon = ls.display_icon,
  level = ls.display_level,
  loc = ls.display_loc,
  qty = ls.display_qty,
  name = ls.display_name,
  owner = ls.display_owner,
  rarity = ls.display_rarity,
}

function ls.order_generic(window, acmp, bcmp, invert)
  if acmp == bcmp then
    return false
  end
  local c = acmp < bcmp
  if invert then
    c = not c
  end
  if c then
    return window.order_asc
  else
    return not window.order_asc
  end
end

function ls.order_qty_calc(item)
  if not item then
    return 0
  end
  if item.stackMax then
    return item.stack or 1
  else
    return 0
  end
end

function ls.order_level_calc(item)
  if not item then
    return -1
  end
  return item.requiredLevel or -1
end

function ls.order_level(window, a, b)
  local acmp, bcmp
  a = window.item_list[a]
  b = window.item_list[b]
  acmp = ls.order_level_calc(a)
  bcmp = ls.order_level_calc(b)
  return ls.order_generic(window, acmp, bcmp, true)
end


function ls.order_qty(window, a, b)
  local acmp, bcmp
  local ai = window.item_list[a]
  local bi = window.item_list[b]
  acmp = ls.order_qty_calc(ai)
  bcmp = ls.order_qty_calc(bi)
  return ls.order_generic(window, acmp, bcmp, true)
end

function ls.order_owner(window, a, b)
  local acmp, bcmp
  a = window.item_list[a]
  b = window.item_list[b]
  acmp = a and (a._character or "") or ""
  bcmp = b and (b._character or "") or ""
  return ls.order_generic(window, acmp, bcmp)
end

function ls.order_name(window, a, b)
  local acmp, bcmp
  a = window.item_list[a]
  b = window.item_list[b]
  acmp = a and (a.name or "") or ""
  bcmp = b and (b.name or "") or ""
  return ls.order_generic(window, acmp, bcmp)
end

function ls.order_rarity(window, a, b)
  local acmp, bcmp
  a = window.item_list[a]
  b = window.item_list[b]
  acmp = a and (lbag.rarity_p(a.rarity)) or 0
  bcmp = b and (lbag.rarity_p(b.rarity)) or 0
  return ls.order_generic(window, acmp, bcmp, true)
end

function ls.order_loc(window, a, b)
  local acmp, bcmp
  a = window.item_list[a]
  b = window.item_list[b]
  acmp = a and (a._slotspec) or ""
  bcmp = b and (b._slotspec) or ""
  return ls.order_generic(window, acmp, bcmp)
end

ls.order_funcs = {
  loc = ls.order_loc,
  qty = ls.order_qty,
  name = ls.order_name,
  level = ls.order_level,
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

function ls.show_items(window)
  local max
  local pos = math.floor(window.scrollbar:GetPosition())

  for i = 1, ls.item_lines do
    local item_idx = i + pos
    local item_name = window.item_ordered[item_idx]
    if item_name then
      local item = window.item_list[item_name]
      if not item then
	ls.printf("Trying to look at pos %d out of %d, got %s",
	  item_idx, window.item_count, item_name or "nil")
      else
        ls.show_item(window.items[i], item)
      end
      if item_idx == window.selected then
        window.items[i].frame:SetBackgroundColor(0.4, 0.4, 0.2, 0.4)
      else
        ls.setgrey(window.items[i].frame, item_idx)
      end
    else
      window.items[i].frame:SetVisible(false)
    end
  end
  window.window:SetVisible(true)
end

function ls.reorder(window)
  local func = nil
  if window.order then
    func = function(...) return window.order(window, ...) end
  end
  table.sort(window.item_ordered, func)
end

function ls.refresh()
  for _, window in ipairs(ls.windows) do
    if window.window:GetVisible() then
      ls.dump(window)
    end
  end
end

function ls.dump(window, newfilter)
  if not window then
    for _, win in pairs(ls.windows) do
      if win.filter == newfilter then
        window = win
      end
    end
    if not window then
      window = window_template:get()
      table.insert(ls.windows, window)
    end
    if window and newfilter then
      window.filter = newfilter
    end
  elseif newfilter then
    window.filter = newfilter
  end
  if not window.filter then
    ls.printf("ls.dump(%s, %s): no window.filter",
      tostring(window), tostring(filter))
    return
  end
  window.item_list = lbag.expand(window.filter)

  window.item_count = 0
  window.item_ordered = {}
  for k, v in pairs(window.item_list) do
    window.item_count = window.item_count + 1
    table.insert(window.item_ordered, k)
  end
  ls.reorder(window)

  local max = window.item_count - ls.item_lines
  local _, sbmax = window.scrollbar:GetRange()
  local relative = window.scrollbar:GetPosition() / sbmax
  -- ls.printf("relative position: %d/%d => %f", window.scrollbar:GetPosition(), sbmax, relative)
  if relative > 1 then
    relative = 1
  end
  if max > 0 then
    window.scrollbar:SetEnabled(true)
    window.scrollbar:SetRange(0, max)
    window.scrollbar:SetThickness(ls.item_lines)
  else
    max = 0
    window.scrollbar:SetEnabled(false)
    window.scrollbar:SetRange(0, 1)
    window.scrollbar:SetThickness(1)
  end
  window.scrollbar:SetPosition(math.floor((relative * max) + 0.5))
  ls.show_items(window)
end

function ls.slashcommand(args)
  local dump = false
  local temporary = false
  local created = false
  if not args then
    return
  end

  if args.v then
    ls.printf("version %s", ls.version)
    return
  end

  if args.f then
    local filter = filt.Filter:load(args.f, 'LootSorter')
    if not filter then
      filter = filt.Filter:new(args.f, 'item', 'LootSorter')
      created = true
    end
    args.f = nil
  else
    filter = filt.Filter:new(nil, 'item', 'LootSorter')
    temporary = true
  end

  local changed = false
  if lbag.apply_args(filter, args) then changed = true end
  if filter:apply_args(args, true) then changed = true end
  if changed then
    if not temporary then
      filter:save()
    end
  else
    if created then
      ls.printf("Found no filter named '%s'.", filter.name)
      return
    end
  end

  ls.dump(nil, filter)
end

ls.ui = UI.CreateContext("LootSorter")

table.insert(Event.Item.Slot, { ls.refresh, "LootSorter", "LootSorter refresh" })
table.insert(Event.Item.Update, { ls.refresh, "LootSorter", "LootSorter refresh" })
table.insert(Event.Addon.SavedVariables.Load.End, { ls.variables_loaded, "LootSorter", "variable loaded hook" })

Library.LibGetOpt.makeslash(filt.Filter:argstring() .. lbag.argstring() .. "f:v", "LootSorter", "ls", ls.slashcommand)
