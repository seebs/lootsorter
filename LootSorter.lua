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

function ls.printf(fmt, ...)
  print(string.format(fmt or 'nil', ...))
end

function ls.makeitem()
  local item = {}
  item.frame = UI.CreateFrame("Frame", "Item Frame", ls.window)

  item.name = UI.CreateFrame("Text", "Item Name", item.frame)
  item.name:SetPoint("TOPLEFT", item.frame, "TOPLEFT")
  item.name:SetPoint("BOTTOMRIGHT", item.frame, "BOTTOMLEFT", 200, 0)

  item.qty = UI.CreateFrame("Text", "Item Qty", item.frame)
  item.qty:SetPoint("TOPLEFT", item.frame, "TOPLEFT", 202, 0)
  item.qty:SetPoint("BOTTOMRIGHT", item.frame, "BOTTOMLEFT", 250, 0)

  item.frame:SetBackgroundColor(0.5, 0.5, 0.5, 1)
  return item
end

function ls.setgrey(frame, count)
  local grey = 0.25
  frame:SetBackgroundColor(grey, grey, grey, 0.4)
end

function ls.makewindow()
  if ls.window then
    ls.ui:SetVisible(true)
    ls.window:SetVisible(true)
    return
  end
  ls.item_lines = 22
  ls.window = UI.CreateFrame("RiftWindow", "LootSorter", ls.ui)
  ls.window:SetWidth(800)
  ls.window:SetTitle("LootSorter")

  local l, t, r, b = ls.window:GetTrimDimensions()

  ls.scrollbar = UI.CreateFrame("RiftScrollbar", "LootSorter", ls.window)
  ls.scrollbar:SetPoint("TOPRIGHT", ls.window, "TOPRIGHT", -2 + r * -1, t + 40)
  ls.scrollbar:SetPoint("BOTTOMRIGHT", ls.window, "BOTTOMRIGHT", -2 + r * -1, -2 + b * -1)
  -- only active when there is scrolletry to do
  ls.scrollbar:SetEnabled(false)
  ls.scrollbar.Event.ScrollbarChange = ls.show_items
  local w = ls.scrollbar:GetWidth()

  ls.heading = ls.makeitem()
  ls.heading.frame:SetBackgroundColor(0, 0, 0, 0)
  ls.heading.frame:SetPoint("TOPLEFT", ls.window, "TOPLEFT", l + 2, t + 12)
  ls.heading.frame:SetPoint("BOTTOMRIGHT", ls.window, "TOPRIGHT", -2 + (r * -1) - w, t + 32)
  ls.show_item(ls.heading, { name = 'Name', rarity = 'Rarity', stack = 'Stack' }, true)

  ls.items = {}
  for i = 1, ls.item_lines do
    ls.items[i] = ls.makeitem()
    ls.setgrey(ls.items[i].frame, i)
    ls.items[i].frame:SetPoint("TOPLEFT", ls.window, "TOPLEFT", l + 2, t + 20 + (20 * i))
    ls.items[i].frame:SetPoint("BOTTOMRIGHT", ls.window, "TOPRIGHT",
    	-2 + (r * -1) - w,
	t + (20 * i) + 38)
  end
end

function ls.order(a, b)
  local acmp, bcmp
  a = ls.item_list[a]
  b = ls.item_list[b]
  acmp = a and (a.name or "") or ""
  bcmp = b and (b.name or "") or ""
  if acmp < bcmp then
    return true
  else
    return false
  end
end

function ls.show_item(frame, item, heading)
  frame.name:SetText(item.name or "")
  if heading then
    frame.name:SetFontColor(1, 1, 0.8, 1)
    frame.qty:SetFontColor(1, 1, 0.8, 1)
  else
    local r, g, b = lbag.rarity_color(item.rarity)
    frame.name:SetFontColor(r, g, b, 1)
  end
  frame.qty:SetText(tostring(item.stack or ""))
  frame.frame:SetVisible(true)
end

function ls.show_items()
  ls.makewindow()

  local max
  local pos = math.floor(ls.scrollbar:GetPosition())

  for i = 1, ls.item_lines do
    local item_idx = i + pos
    local item_name = ls.item_ordered[item_idx]
    ls.setgrey(ls.items[i].frame, i + pos)
    if item_name then
      local item = ls.item_list[item_name]
      if not item then
	ls.printf("Trying to look at pos %d out of %d, got %s",
	  item_idx, ls.item_count, item_name or "nil")
      else
        ls.show_item(ls.items[i], item)
      end
    else
      ls.items[i].frame:SetVisible(false)
    end
  end
end

function ls.dump(filter)
  ls.item_list = filter:find()
  ls.item_count = 0
  ls.item_ordered = {}
  for k, v in pairs(ls.item_list) do
    ls.item_count = ls.item_count + 1
    table.insert(ls.item_ordered, k)
  end
  table.sort(ls.item_ordered, ls.order)

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
    local slotspec, charspec = lbag.slotspec_p(spec)
    if not slotspec then
      slotspec = Utility.Item.Slot.All()
    end
    if string.match(args['C'], '/') then
      charspec = args['C']
    else
      charspec = lbag.char_identifier(args['C'])
    end
    filter:slot(string.format("%s:%s", charspec, slotspec))
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
