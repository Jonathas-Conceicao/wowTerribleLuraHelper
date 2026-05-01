local addonName, ns = ...

-- Config.lua — Options > AddOns > TerribleLuraHelper panel via the modern
-- Settings.* API. Phase 3 ships four sections in vertical-layout order:
--   1. Chat channels — six listen-channel checkboxes (CFG-02, CFG-03)
--   2. Window        — scale slider, opacity slider, auto-hide checkbox,
--                      Lock/Unlock button (CFG-04, CFG-05, CFG-07, CFG-10,
--                      WIN-08, WIN-10)
--   3. Macros        — target-channel dropdown, recreate/update button
--                      (CFG-06, CFG-11)
--   4. Slash commands — eight help entries; canonical with ns:PrintHelp via
--                       the shared ns.SLASH_HELP table (CFG-08, CMD-05).
--
-- All Settings.* calls are deferred inside EventUtil.ContinueOnAddOnLoaded
-- (D-02 / SETTINGS_API.md footgun §5). Setting bindings use
-- Settings.RegisterAddOnSetting (NOT proxy) so the framework auto-writes
-- TerribleLuraHelperDB on every change — change callbacks here only call
-- Window.lua/Macros.lua exports to apply the new value live, never write
-- the DB themselves (D-04 / threat T-03-02).
--
-- See .planning/research/SETTINGS_API.md for verified code patterns and
-- .planning/phases/03-config-panel-integration/03-UI-SPEC.md for verbatim
-- copy contract (every label, tooltip, button text, notice string).

-- ============================================================
-- Channel toggle table (UI-SPEC §2.2)
-- DB key names match the existing schema: SAY / RAID / RAID_LEADER /
-- RAID_WARNING / INSTANCE_CHAT / INSTANCE_CHAT_LEADER (CONTEXT.md D-10/D-33).
-- ============================================================
local CHANNELS = {
	{ key = "SAY", label = "Listen on /say", tooltip = "Watch /say messages for raid markers." },
	{ key = "RAID", label = "Listen on /raid", tooltip = "Watch /raid messages for raid markers." },
	{
		key = "RAID_LEADER",
		label = "Listen on /raid (leader)",
		tooltip = "Watch raid-leader messages for raid markers.",
	},
	{ key = "RAID_WARNING", label = "Listen on /rw", tooltip = "Watch /rw raid-warning messages for raid markers." },
	{ key = "INSTANCE_CHAT", label = "Listen on /instance", tooltip = "Watch /instance messages for raid markers." },
	{
		key = "INSTANCE_CHAT_LEADER",
		label = "Listen on /instance (leader)",
		tooltip = "Watch instance-leader messages for raid markers.",
	},
}

-- ============================================================
-- Slash help block (UI-SPEC §5.2 — canonical for both this panel section
-- and ns:PrintHelp in Core.lua per CONTEXT.md D-28). Single source of
-- truth: changing one of the 8 entries here changes the chat-printed
-- help block too. Exposed on ns below.
-- ============================================================
local SLASH_HELP = {
	{ "/lura", "Toggles the helper window between shown and hidden." },
	{ "/lura show", "Shows the helper window and starts watching chat." },
	{ "/lura hide", "Hides the helper window, clears the runes, and stops watching chat." },
	{ "/lura lock", "Locks the helper window so it can't be dragged." },
	{ "/lura unlock", "Unlocks the helper window so you can drag it to a new position." },
	{ "/lura config", "Opens this settings panel." },
	{ "/lura help", "Prints the slash command list to chat." },
	{ "/tlh", "Alias for /lura — accepts every subcommand above." },
}
ns.SLASH_HELP = SLASH_HELP

-- ============================================================
-- 1. Chat channels — 6 listen-channel checkboxes
-- ============================================================
local function RegisterChannelToggles(category, layout, db)
	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Chat channels"))
	db.listenChannels = db.listenChannels or {}
	for _, ch in ipairs(CHANNELS) do
		local variable = "TLH_CHANNEL_" .. ch.key
		local setting = Settings.RegisterAddOnSetting(
			category,
			variable,
			ch.key,
			db.listenChannels,
			Settings.VarType.Boolean,
			ch.label,
			true
		)
		-- Per D-12: channel-toggle change is a no-op for chat-event registration.
		-- Filtering happens at message time in Window.lua via
		-- db.listenChannels[event:sub(10)] — the framework writes the new
		-- boolean and the next incoming message reads it. No reload required.
		Settings.CreateCheckbox(category, setting, ch.tooltip)
	end
end

-- ============================================================
-- 2. Window — scale slider + opacity slider + auto-hide checkbox + Lock/Unlock button
-- Per D-39, the Lock/Unlock button lives here (moved up from the retired
-- "Actions" section).
-- ============================================================
local function RegisterWindowControls(category, layout, db)
	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Window"))

	-- (2a) Scale slider — UI-SPEC §3.2
	do
		local setting = Settings.RegisterAddOnSetting(
			category,
			"TLH_WINDOW_SCALE",
			"scale",
			db.window,
			Settings.VarType.Number,
			"Window scale",
			1.00
		)
		setting:SetValueChangedCallback(function(_, value)
			ns:SetWindowScale(value)
		end)
		local options = Settings.CreateSliderOptions(0.50, 2.00, 0.05)
		options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, FormatPercentage)
		Settings.CreateSlider(category, setting, options, "Resizes the helper window. Drag to preview live.")
	end

	-- (2b) Opacity slider — UI-SPEC §3.3
	do
		local setting = Settings.RegisterAddOnSetting(
			category,
			"TLH_WINDOW_ALPHA",
			"alpha",
			db.window,
			Settings.VarType.Number,
			"Window opacity",
			1.00
		)
		setting:SetValueChangedCallback(function(_, value)
			ns:SetWindowAlpha(value)
		end)
		local options = Settings.CreateSliderOptions(0.20, 1.00, 0.05)
		options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, FormatPercentage)
		Settings.CreateSlider(
			category,
			setting,
			options,
			"Adjusts the helper window's transparency. Has no effect while auto-hide has hidden the window."
		)
	end

	-- (2c) Auto-hide checkbox — UI-SPEC §3.4
	do
		local setting = Settings.RegisterAddOnSetting(
			category,
			"TLH_AUTO_HIDE",
			"autoHide",
			db.window,
			Settings.VarType.Boolean,
			"Auto-hide when empty",
			false
		)
		setting:SetValueChangedCallback(function(_, value)
			ns:OnAutoHideChanged(value)
		end)
		Settings.CreateCheckbox(
			category,
			setting,
			"When enabled, the helper window stays visible but invisible while no runes are showing. The next message reveals it."
		)
	end

	-- (2d) Lock/Unlock button — UI-SPEC §4.3, moved here per D-39.
	-- buttonText is a function so the label re-evaluates each time the
	-- panel reopens (matches current db.window.locked state). The label
	-- on an already-open panel is intentionally stale; reopening refreshes.
	do
		local function OnClick()
			ns:ToggleLocked()
		end
		local function buttonText()
			if ns.db.window.locked then
				return "Unlock window"
			else
				return "Lock window"
			end
		end
		local initializer = CreateSettingsButtonInitializer(
			"Window",
			buttonText,
			OnClick,
			"Toggles whether the helper window can be dragged.",
			true
		)
		layout:AddInitializer(initializer)
	end

	-- (2e) Show/Hide window button. Mirrors the /lura no-arg toggle.
	-- Same EvaluateName Init-only caveat as the Lock button (label
	-- refreshes when the panel reopens, not on click). Left-side label
	-- omitted — keeps it visually paired with the Lock button above.
	do
		local function OnClick()
			if ns:IsWindowShown() then
				ns:HideWindow()
			else
				ns:ShowWindow()
			end
		end
		local function buttonText()
			if ns:IsWindowShown() then
				return "Hide window"
			else
				return "Show window"
			end
		end
		local initializer = CreateSettingsButtonInitializer(
			"",
			buttonText,
			OnClick,
			"Toggles the helper window between shown and hidden — same as typing /lura.",
			true
		)
		layout:AddInitializer(initializer)
	end
end

-- ============================================================
-- 3. Macros — target-channel dropdown + recreate/update button
-- ============================================================
local function RegisterMacroSection(category, layout, db)
	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Macros"))

	-- (3a) Macro target dropdown — UI-SPEC §4.5.2
	do
		local setting = Settings.RegisterAddOnSetting(
			category,
			"TLH_MACRO_CHANNEL",
			"macroChannel",
			db,
			Settings.VarType.String,
			"Macro target",
			"RAID"
		)
		setting:SetValueChangedCallback(function(_, value)
			ns:OnMacroChannelChanged(value)
		end)
		local function GenerateMacroChannelOptions()
			local container = Settings.CreateControlTextContainer()
			container:Add("RAID", "/raid")
			container:Add("RAID_WARNING", "/rw")
			container:Add("INSTANCE_CHAT", "/i")
			container:Add("SAY", "/s")
			return container:GetData()
		end
		Settings.CreateDropdown(
			category,
			setting,
			GenerateMacroChannelOptions,
			"The chat channel each TLH_* macro sends raid markers to. /raid is the default and works during raid encounters; /rw requires raid leader/assist; /i sends to instance/dungeon chat; /s works anywhere (good for solo testing)."
		)
	end

	-- (3b) Recreate / update macros button — UI-SPEC §4.2 / §4.5.3.
	-- Always print success regardless of the macrosPrintedThisSession flag —
	-- explicit user action should always confirm (UI-SPEC §4.2 rationale).
	do
		local function OnClick()
			if InCombatLockdown() then
				print(
					"|cffaa44ffTLH|r: Can't recreate macros during combat. They will be retried on PLAYER_REGEN_ENABLED, or click again after combat."
				)
				return
			end
			ns:RegisterMacros()
			print("|cffaa44ffTLH|r: Macros recreated.")
		end
		local initializer = CreateSettingsButtonInitializer(
			"Macros",
			"Recreate",
			OnClick,
			"Recreates or updates the five TLH_* player macros if you've deleted or edited them. The macro target dropdown above already updates them on change — this button is only needed if a macro went missing. Disabled during combat — the addon retries automatically when combat ends.",
			true
		)
		layout:AddInitializer(initializer)
	end

	-- (3c) Delete macros button. Removes all five TLH_* macros. The
	-- addon recreates them automatically on next login while it's
	-- enabled, so this is mainly useful before disabling/uninstalling
	-- or to free macro slots temporarily.
	do
		local function OnClick()
			if InCombatLockdown() then
				print("|cffaa44ffTLH|r: Can't delete macros during combat. Click again after combat ends.")
				return
			end
			local deleted = ns:DeleteMacros()
			if deleted and deleted > 0 then
				print(string.format("|cffaa44ffTLH|r: Deleted %d TLH_* macro(s).", deleted))
			else
				print("|cffaa44ffTLH|r: No TLH_* macros to delete.")
			end
		end
		local initializer = CreateSettingsButtonInitializer(
			"",
			"Delete",
			OnClick,
			"Removes the five TLH_* player macros. They'll be recreated automatically on your next login while the addon is enabled.",
			true
		)
		layout:AddInitializer(initializer)
	end
end

-- ============================================================
-- 4. Slash commands — 8 help entries (single-source-of-truth via
--    SLASH_HELP; ns:PrintHelp in Core.lua iterates the same table).
-- ============================================================
local function RegisterCommandHelp(category, layout)
	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Slash commands"))
	for _, c in ipairs(SLASH_HELP) do
		layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(c[1], c[2]))
	end
end

-- ============================================================
-- Top-level registration — deferred via EventUtil.ContinueOnAddOnLoaded
-- per D-02. Phase 1's Core.lua dispatcher already calls this from
-- ADDON_LOADED; the EventUtil gate is cheap insurance against future
-- call-order regressions and matches the documented Blizzard pattern.
-- Caches ns.settingsCategoryID for /lura config (must be a number per
-- footgun §6 — never pass the category name).
-- ============================================================
function ns:InitConfig()
	EventUtil.ContinueOnAddOnLoaded(addonName, function()
		local db = ns.db
		if not db then
			return -- defensive: should never trigger because ADDON_LOADED ran first
		end

		local category, layout = Settings.RegisterVerticalLayoutCategory("TerribleLuraHelper")
		ns.settingsCategoryID = category:GetID()

		RegisterChannelToggles(category, layout, db)
		RegisterWindowControls(category, layout, db)
		RegisterMacroSection(category, layout, db)
		RegisterCommandHelp(category, layout)

		Settings.RegisterAddOnCategory(category)
	end)
end
