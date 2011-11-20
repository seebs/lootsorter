This is... well, basically, I wanted to be able to type /ls.

It's also a sort of test addon for working on, designing, and debugging
LibBaggotry.  Especially the "other characters' inventories" features.

For now:
	/ls -C *
will show you everyone's inventory and bank.  Some filtering is available;
e.g.,
	/ls -c material -C *
will show all things tagged as "materials".

Options:
	[-beiw]
		Show items from {bank, equipment, inventory, wardrobe}
		Default is bank, inventory
	-C char|*
		Show items from named character, or all characters;
		default is self only.
	-c category
		Show only items in category
	-h
		hide (closes window)
	-q quality
		Show items of quality; default relation is >= rather
		than ==.
	-r
		Qualifiers are requirements; all must be met
	-x
		Qualifiers are exclusions; anything matching them
		is rejected.

Words that aren't attached to options:
	If there's no colons, it's treated as a name match; note
	that these are case-insensitive substrings.  (If you want
	an anchored match, use ^ or $, and you can use other Lua
	pattern features.)

	If there's colons, treated as args to the filter-making
	stuff in LibBaggotry.  That means either:
		attribute:value
	or
		attribute:relop:value
	where relop is something like ">" or "==".  If you don't
	specify one, the default is ==.
