if EUI_CLIENT_BLOCKED then return end -- pre-12.1 client failsafe (EllesmereUI_ClientGate.lua)
-------------------------------------------------------------------------------
--  EllesmereUI_TargetOwnDebuffs \ TargetOwnDebuffs_Options.lua
--
--  Unit Frames > Main Frames > Target > OWN DEBUFFS, without touching
--  EllesmereUI files: ns.UFO_BuildBuffsDebuffsSection (defined by the LOD
--  EllesmereUIOptions add-on, looked up at call time by the Main Frames page)
--  is wrapped; on the Target tab our section is appended right after
--  BUFFS AND DEBUFFS (before ABSORBS AND HEALS).
-------------------------------------------------------------------------------
local EllesmereUI = _G.EllesmereUI
local ns = EllesmereUI and EllesmereUI._ModuleNS and EllesmereUI._ModuleNS["EllesmereUIUnitFrames"]
local TOD = ns and ns._TOD
if not TOD then return end

local UNSUPPORTED_TIP = "Works with the Target Debuff Filter set to Show All, Own Only or Important or Own"

local function Pack(...) return { n = select("#", ...), ... } end

local function BuildSection(parent, y, W)
    local _, h
    _, h = W:SectionHeader(parent, "OWN DEBUFFS", y); y = y - h

    local function Off()
        return TOD.Get("enabled") == false or not TOD.ModeSupported()
    end
    local function OffTip()
        if not TOD.ModeSupported() then return UNSUPPORTED_TIP end
        return "Enlarge Own Debuffs"
    end

    -- Enlarge Own Debuffs | Own Debuff Size
    _, h = W:DualRow(parent, y,
        { type = "toggle", text = "Enlarge Own Debuffs",
          tooltip = "Debuffs cast by you (or your pet) on your target use a larger icon. Every other debuff - other players', NPCs', zone effects - still shows at the normal Debuff Size.",
          disabled = function() return not TOD.ModeSupported() end,
          disabledTooltip = UNSUPPORTED_TIP,
          getValue = function() return TOD.Get("enabled") ~= false end,
          setValue = function(v) TOD.Set("enabled", v and true or false); EllesmereUI:RefreshPage() end },
        { type = "slider", text = "Own Debuff Size", min = 12, max = 64, step = 1,
          disabled = Off, disabledTooltip = OffTip,
          getValue = function() return TOD.Get("size") end,
          setValue = function(v) TOD.Set("size", v) end }
    ); y = y - h

    -- Own Debuffs On Separate Row | Scale Text With Size
    _, h = W:DualRow(parent, y,
        { type = "toggle", text = "Own Debuffs On Separate Row",
          tooltip = "Your debuffs fill their own row(s) first (nearest the frame); the other debuffs start on a new row. Only applies with the Show All filter.",
          disabled = function() return Off() or TOD.Mode() ~= "all" end,
          disabledTooltip = function()
              if Off() then return OffTip() end
              return "Only applies with the Target Debuff Filter set to Show All"
          end,
          getValue = function() return TOD.Get("newRow") ~= false end,
          setValue = function(v) TOD.Set("newRow", v and true or false) end },
        { type = "toggle", text = "Scale Text With Size",
          tooltip = "The timer and stack text on your debuffs grow in proportion to the larger icon.",
          disabled = Off, disabledTooltip = OffTip,
          getValue = function() return TOD.Get("scaleText") ~= false end,
          setValue = function(v) TOD.Set("scaleText", v and true or false) end }
    ); y = y - h

    -- Own Debuff Max | (blank)
    local blank = EllesmereUI.BlankRowCfg and EllesmereUI.BlankRowCfg() or { type = "label", text = "" }
    _, h = W:DualRow(parent, y,
        { type = "slider", text = "Own Debuff Max", min = 0, max = 20, step = 1,
          tooltip = "How many of your debuffs show at most. 0 = the same as Debuff Max. Your debuffs and the others are counted separately.",
          disabled = Off, disabledTooltip = OffTip,
          getValue = function() return TOD.Get("max") end,
          setValue = function(v) TOD.Set("max", v) end },
        blank
    ); y = y - h

    _, h = W:Spacer(parent, y, 20); y = y - h
    return y
end

local function Install()
    if TOD.optionsHooked then return true end
    local orig = ns.UFO_BuildBuffsDebuffsSection
    if type(orig) ~= "function" then return false end
    TOD.optionsHooked = true

    ns.UFO_BuildBuffsDebuffsSection = function(parent, y, ctx, ...)
        local res = Pack(orig(parent, y, ctx, ...))
        local env = ns._UFO_OptEnv
        local optState = env and env.optState
        local W = ctx and ctx.W
        if optState and optState.selectedUnit == "target" and type(W) == "table"
            and type(res[1]) == "number" then
            local ok, ny = pcall(BuildSection, parent, res[1], W)
            if ok and type(ny) == "number" then
                res[1] = ny
            elseif not ok then
                geterrorhandler()(ny)
            end
        end
        return unpack(res, 1, res.n)
    end
    return true
end

local IsLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
if not (IsLoaded and IsLoaded("EllesmereUIOptions") and Install()) then
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(self, _, name)
        if name == "EllesmereUIOptions" then
            Install()
            self:UnregisterAllEvents()
        end
    end)
end
