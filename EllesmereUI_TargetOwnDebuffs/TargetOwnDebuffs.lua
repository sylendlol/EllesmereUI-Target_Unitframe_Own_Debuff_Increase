if EUI_CLIENT_BLOCKED then return end -- pre-12.1 client failsafe (EllesmereUI_ClientGate.lua)
-------------------------------------------------------------------------------
--  EllesmereUI_TargetOwnDebuffs \ TargetOwnDebuffs.lua
--
--  Larger icons for YOUR debuffs on the EllesmereUI target frame, without
--  touching EllesmereUI files. Everything else keeps showing at the normal
--  Debuff Size.
--
--  How it works:
--   * The target's debuff AuraContainer is captured when EUI declares its
--     first group on it (post-hook on AuraKit.AddGroupToContainer, style key
--     "uf:target:HARMFUL").
--   * EUI's own setter calls on that container (max count, filter string,
--     candidate filters, layout) are recorded per group key through instance
--     post-hooks, so we always know what EUI last asked for.
--   * After every ns.UF_ReloadAuraContainers(frame, "target") pass we
--     reconcile:
--       Show All mode      : our group = HARMFUL|PLAYER (large), EUI's "all"
--                            group is narrowed to HARMFUL|!PLAYER. Every debuff
--                            matches exactly one of the two.
--       Own Only /
--       Important or Own   : EUI's "own" group (HARMFUL|PLAYER) is parked at 0
--                            and our large group takes over with the same
--                            filter and candidates.
--       other modes        : inactive, EUI untouched.
--   * Our group lays out first (layoutIndex 0, like EUI's Purgeable Buff
--     Glow). Optional: the rest starts on a new line (forceNewLine on "all").
--   * Our style is a copy of EUI's target debuff style with a larger size
--     (border, fonts, dispel ring, timer text all follow EUI's settings).
--
--  PLAYER = cast by you or your pet (the engine's filter token).
--
--  Settings: ns.UF_GetSettings("target").ownDebuffEnlarge (follows EUI
--  profiles). Keys: enabled, size, newRow, scaleText, max (0 = Debuff Max).
-------------------------------------------------------------------------------
local ADDON_NAME = ...
local EllesmereUI = _G.EllesmereUI
local ns = EllesmereUI and EllesmereUI._ModuleNS and EllesmereUI._ModuleNS["EllesmereUIUnitFrames"]
local AK = EllesmereUI and EllesmereUI.AuraKit
if not (ns and AK and AK.AddGroupToContainer) then return end

local TOD = {}
ns._TOD = TOD

local UNIT = "target"
local EUI_STYLE = "uf:target:HARMFUL"
local OWN_STYLE = "uf:target:HARMFUL:tod_own"
local OWN_KEY = "tod_own"
local SETTINGS_KEY = "ownDebuffEnlarge"

-- Which EUI group our large group replaces / splits, per Debuff Filter mode.
local HOST_FOR_MODE = { all = "all", own = "own", importantOrOwn = "own" }
TOD.HOST_FOR_MODE = HOST_FOR_MODE

local DEFAULTS = { enabled = true, size = 30, newRow = true, scaleText = true, max = 0 }
TOD.DEFAULTS = DEFAULTS

local state = {
    container = nil,  -- the target debuff AuraContainer
    declared = false, -- our group exists on it
    rec = {},         -- [groupKey] = EUI's last setter values + version counters
    applied = {},     -- [name] = fingerprint of what we last pushed
    busy = false,     -- true while WE call the setters (not recorded)
    styleFP = nil,
    ownW = nil, ownH = nil,
    active = false,
    hostKey = nil,
}
TOD._state = state

-------------------------------------------------------------------------------
--  Settings
-------------------------------------------------------------------------------
function TOD.UnitSettings()
    if ns.UF_GetSettings then return ns.UF_GetSettings(UNIT) end
    local db = ns.db
    return db and db.profile and db.profile[UNIT] or nil
end

-- Our table inside the target settings (created on first access).
function TOD.Settings()
    local s = TOD.UnitSettings()
    if not s then return nil end
    local o = s[SETTINGS_KEY]
    if type(o) ~= "table" then
        o = {}
        s[SETTINGS_KEY] = o
    end
    return o
end

function TOD.Get(key)
    local o = TOD.Settings()
    local v = o and o[key]
    if v == nil then return DEFAULTS[key] end
    return v
end

function TOD.Set(key, value)
    local o = TOD.Settings()
    if not o then return end
    o[key] = value
    TOD.Apply()
end

-- The current EUI Debuff Filter mode of the target ("all", "own", ...).
function TOD.Mode()
    local s = TOD.UnitSettings()
    if not s then return "all" end
    if ns.UF_DebuffFilterMode then return ns.UF_DebuffFilterMode(s) end
    return "all"
end

function TOD.ModeSupported()
    return HOST_FOR_MODE[TOD.Mode()] ~= nil
end

-------------------------------------------------------------------------------
--  Helpers
-------------------------------------------------------------------------------
local function Round(v) return math.floor(v + 0.5) end

local function SnapSize(size)
    local PP = EllesmereUI.PP
    local m = PP and PP.mult or 1
    if PP and m ~= 1 and PP.FromPixels and PP.ToPixels then
        size = PP.FromPixels(PP.ToPixels(size))
    end
    return size, m
end

local function CopyTable(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
end

local function FP(...)
    local n = select("#", ...)
    local t = {}
    for i = 1, n do
        local v = select(i, ...)
        if type(v) == "number" then
            t[i] = string.format("%.2f", v)
        else
            t[i] = tostring(v)
        end
    end
    return table.concat(t, "|")
end

-- Runs fn with the recorder muted. Errors are reported, never thrown, so a
-- failing engine call can never break EUI's own reload pass.
local function Guarded(fn)
    state.busy = true
    local ok, err = pcall(fn)
    state.busy = false
    if not ok then geterrorhandler()(err) end
    return ok
end

-- Group caps go through AuraKit like EUI's own (EUI 9.5+): where the client
-- supports it, a cap of 0 also switches the group off (not parsed at all) and
-- a cap above 0 switches it back on. Older AuraKit: the plain setter.
local function SetCap(c, key, n)
    if AK.SetGroupCap then
        AK.SetGroupCap(c, key, n)
    else
        c:SetAuraGroupMaxFrameCount(key, n)
    end
end

-- Pushes a setter only when its fingerprint changed (every engine setter is
-- a dirty mark that costs a re-parse/re-layout).
local function Put(name, fp, fn)
    if state.applied[name] == fp then return end
    if Guarded(fn) then state.applied[name] = fp end
end

-------------------------------------------------------------------------------
--  Recording EUI's setter calls on the container
-------------------------------------------------------------------------------
local function Rec(key)
    local r = state.rec[key]
    if not r then
        r = { maxV = 0, filterV = 0, candV = 0, layoutV = 0 }
        state.rec[key] = r
    end
    return r
end

local function HookContainer(c)
    hooksecurefunc(c, "SetAuraGroupMaxFrameCount", function(_, key, n)
        if state.busy or key == OWN_KEY then return end
        local r = Rec(key); r.max = n; r.maxV = r.maxV + 1
    end)
    if c.SetAuraGroupFilterString then
        hooksecurefunc(c, "SetAuraGroupFilterString", function(_, key, f)
            if state.busy or key == OWN_KEY then return end
            local r = Rec(key); r.filter = f; r.filterV = r.filterV + 1
        end)
    end
    hooksecurefunc(c, "SetAuraGroupCandidateFilters", function(_, key, cand)
        if state.busy or key == OWN_KEY then return end
        local r = Rec(key); r.cand = cand; r.candV = r.candV + 1
    end)
    hooksecurefunc(c, "SetAuraGroupLayout", function(_, key, layout)
        if state.busy or key == OWN_KEY then return end
        local r = Rec(key); r.layout = layout; r.layoutV = r.layoutV + 1
    end)
end

local function Attach(c)
    if state.container == c then return end
    if state.container then
        -- A second container for the same unit should never happen (EUI
        -- never swaps containers); keep the first one.
        return
    end
    state.container = c
    HookContainer(c)
end

hooksecurefunc(AK, "AddGroupToContainer", function(container, g)
    if state.busy or not container or type(g) ~= "table" then return end
    if g.style == EUI_STYLE then Attach(container) end
end)

-------------------------------------------------------------------------------
--  Style
-------------------------------------------------------------------------------
-- Rebuilds our style from EUI's current target debuff style when either side
-- changed. Returns false while EUI's style does not exist yet.
local function EnsureStyle()
    local base = AK.styles and AK.styles[EUI_STYLE]
    if not base then return false end
    local size = SnapSize(math.max(8, tonumber(TOD.Get("size")) or DEFAULTS.size))
    local scaleText = TOD.Get("scaleText") ~= false
    local fp = FP(tostring(base), size, scaleText)
    if state.styleFP == fp then return true end

    local st = CopyTable(base)
    local bw = base.width or 22
    local bh = base.height or bw
    local _, m = SnapSize(1)
    local h = size
    if bh ~= bw and bw > 0 then
        -- Cropped icons keep EUI's aspect (the copied texCoord stays valid).
        h = math.floor(size / m * (bh / bw) + 0.5) * m
    end
    st.width, st.height = size, h
    if scaleText and bw > 0 then
        local f = size / bw
        st.cdTextSize = math.max(6, Round((base.cdTextSize or 10) * f))
        st.stackSize = math.max(6, Round((base.stackSize or 14) * f))
    end
    AK.styles[OWN_STYLE] = st
    state.ownW, state.ownH = size, h
    -- Buttons created before this rebuild need a restyle; at the first build
    -- no button exists yet (the declaration's initializer reads the table).
    if state.styleFP and state.declared then AK.RestyleSoon(OWN_STYLE) end
    state.styleFP = fp
    return true
end

-------------------------------------------------------------------------------
--  Reconcile
-------------------------------------------------------------------------------
local function OwnLayout(L)
    return {
        elementWidth = state.ownW,
        elementHeight = state.ownH,
        elementSpacing = L.elementSpacing,
        lineSpacing = L.lineSpacing,
        layoutIndex = 0, -- lays out before every EUI group
    }
end

-- Gives a host group back exactly what EUI last set on it.
local function Release(key)
    local c = state.container
    local r = state.rec[key]
    local A = state.applied
    if key == "all" then
        if A["host:all:filter"] then
            A["host:all:filter"] = nil
            local f = (r and r.filter) or AK.Filter("HARMFUL")
            if c.SetAuraGroupFilterString then
                Guarded(function() c:SetAuraGroupFilterString("all", f) end)
            end
        end
        if A["host:all:layout"] then
            A["host:all:layout"] = nil
            if r and r.layout then
                Guarded(function() c:SetAuraGroupLayout("all", r.layout) end)
            end
        end
    elseif key == "own" then
        if A["host:own:max"] then
            A["host:own:max"] = nil
            local n = (r and r.max) or 0
            Guarded(function() SetCap(c, "own", n) end)
        end
    end
end

local function Declare(r)
    local c = state.container
    -- Already on the container (e.g. a declaration the client watchdog cut
    -- short after the engine registered it): a duplicate key asserts.
    if c.HasAuraGroup and c:HasAuraGroup(OWN_KEY) then
        -- Unknown state: push our group's candidates, layout and cap fresh.
        state.declared = true
        state.applied["own:cand"] = nil
        state.applied["own:layout"] = nil
        state.applied["own:max"] = nil
        return true
    end
    local ok = Guarded(function()
        AK.AddGroupToContainer(c, {
            key = OWN_KEY,
            filter = { "HARMFUL", "PLAYER" },
            maxFrameCount = 0,
            style = OWN_STYLE,
            candidateFilters = CopyTable(r.cand),
            layout = OwnLayout(r.layout),
        })
    end)
    if ok then
        state.declared = true
        state.applied["own:cand"] = tostring(r.candV)
        state.applied["own:layout"] = FP(state.ownW, state.ownH, r.layout.elementSpacing, r.layout.lineSpacing)
        -- Left unset: the first cap write also switches the group on/off
        -- through AuraKit (a declared group starts enabled).
        state.applied["own:max"] = nil
    end
    return ok
end

local function Deactivate()
    local c = state.container
    Release("all")
    Release("own")
    if state.declared then
        Put("own:max", "0", function() SetCap(c, OWN_KEY, 0) end)
    end
    state.active = false
    state.hostKey = nil
end

function TOD.Reconcile()
    local c = state.container
    if not c then return end
    if not TOD.UnitSettings() then return end

    local hostKey = HOST_FOR_MODE[TOD.Mode()]
    local r = hostKey and state.rec[hostKey]
    local active = TOD.Get("enabled") ~= false and r ~= nil and r.layout ~= nil
        and (r.max or 0) > 0
    -- Splitting Show All needs the live filter-string setter; without it the
    -- catch-all would show your debuffs a second time.
    if hostKey == "all" and not c.SetAuraGroupFilterString then active = false end
    if not active then
        Deactivate()
        return
    end
    if not EnsureStyle() then
        Deactivate()
        return
    end

    -- The host we used before (if different) gets EUI's values back.
    for _, k in ipairs({ "all", "own" }) do
        if k ~= hostKey then Release(k) end
    end

    if not state.declared and not Declare(r) then
        Deactivate()
        return
    end

    local L = r.layout
    -- Our group: same candidates (always-hidden, Exhaustion, Tracked Auras
    -- excludes) as the group it splits from.
    Put("own:cand", tostring(r.candV), function()
        c:SetAuraGroupCandidateFilters(OWN_KEY, CopyTable(r.cand))
    end)
    Put("own:layout", FP(state.ownW, state.ownH, L.elementSpacing, L.lineSpacing), function()
        c:SetAuraGroupLayout(OWN_KEY, OwnLayout(L))
    end)
    local maxOwn = tonumber(TOD.Get("max")) or 0
    if maxOwn <= 0 then maxOwn = r.max end
    Put("own:max", tostring(maxOwn), function()
        SetCap(c, OWN_KEY, maxOwn)
    end)

    if hostKey == "all" then
        -- Everyone else: the same catch-all minus your casts.
        if c.SetAuraGroupFilterString then
            Put("host:all:filter", tostring(r.filterV), function()
                c:SetAuraGroupFilterString("all", AK.Filter("HARMFUL", "!PLAYER"))
            end)
        end
        if TOD.Get("newRow") ~= false then
            Put("host:all:layout", tostring(r.layoutV), function()
                local nl = CopyTable(L)
                nl.forceNewLine = true
                c:SetAuraGroupLayout("all", nl)
            end)
        elseif state.applied["host:all:layout"] then
            state.applied["host:all:layout"] = nil
            Guarded(function() c:SetAuraGroupLayout("all", L) end)
        end
    else -- "own": our group replaces it
        Put("host:own:max", tostring(r.maxV), function()
            SetCap(c, "own", 0)
        end)
    end

    state.active = true
    state.hostKey = hostKey
end

-- Settings changed from our options: re-run, re-parse.
function TOD.Apply()
    TOD.Reconcile()
    local c = state.container
    if c and c.UpdateAllAuras then
        Guarded(function() c:UpdateAllAuras() end)
    end
end

-- After every EUI aura reload of the target (settings, profile switch,
-- Tracked Auras gate, final build stage).
hooksecurefunc(ns, "UF_ReloadAuraContainers", function(_, unit)
    if unit == UNIT then TOD.Reconcile() end
end)

-------------------------------------------------------------------------------
--  /euitod  -- status line for troubleshooting
-------------------------------------------------------------------------------
SLASH_EUITOD1 = "/euitod"
SlashCmdList.EUITOD = function()
    local p = "|cff0cd29fTarget Own Debuffs:|r "
    if not state.container then
        print(p .. "the target debuff container was not found (is the target frame enabled in EllesmereUI?).")
        return
    end
    local mode = TOD.Mode()
    print(p .. string.format("mode=%s, supported=%s, enabled=%s, active=%s, host=%s, size=%s, newRow=%s",
        tostring(mode), tostring(HOST_FOR_MODE[mode] ~= nil), tostring(TOD.Get("enabled") ~= false),
        tostring(state.active), tostring(state.hostKey), tostring(TOD.Get("size")),
        tostring(TOD.Get("newRow") ~= false)))
end
