--[[
    Core.Prompt, part 2: the looks (0.15.0).

    PromptDraw   the '3d' look and the small mark, drawn with natives under SetDrawOrigin. The game
                 projects a draw origin when it renders the frame, so what is drawn stays on the point.
                 Sizes are shares of the screen, so the prompt keeps one size at any distance.
    PromptBox    the 'textui' look: the server's own text box through Core.TextUI. It shows on a change
                 only, it never covers a text another script put on the box with Core.TextUI.Draw (the
                 prompt draws in 3D until the box is free), and it hides the box only when the text on
                 it is still its own. A box another script opened directly with its text box resource
                 (lib.showTextUI and the like) is invisible to bp_lib: the prompt may cover it and hide it.

    A frame has 32 draw origins for the whole client, shared with every other resource; a draw past the
    32nd lands in the screen's top-left corner (spike S8). main.lua never asks for more than PromptDraw.MAX.
]]

PromptDraw = { MAX = 24 }
PromptBox = {}

local D, B = PromptDraw, PromptBox

local function style()
    local s = Config.PromptStyle or {}
    return {
        font = s.font or 4,
        scale = s.scale or 0.34,
        key = s.key or { 255, 255, 255 },
        keyBack = s.keyBack or { 20, 22, 26 },
        text = s.text or { 255, 255, 255 },
        back = s.back or { 20, 22, 26 },
        backAlpha = s.backAlpha or 170,
        mark = s.mark or { 255, 255, 255 },
        markSize = s.markSize or 0.0045,
        fill = s.fill or { 76, 175, 80 },
    }
end

local S            -- the style, read once per frame
local aspect = 1.78
local widths = {}  -- [font|scale|text] = width as a share of the screen

--- Call once at the start of a frame that draws.
function D.Begin()
    S = style()
    aspect = GetAspectRatio(false)
    if not aspect or aspect <= 0 then aspect = 1.78 end
end

local function textWidth(text)
    local id = S.font .. '|' .. S.scale .. '|' .. text
    local w = widths[id]
    if w then return w end
    BeginTextCommandGetWidth('STRING')
    AddTextComponentSubstringPlayerName(text)
    SetTextFont(S.font)
    SetTextScale(0.0, S.scale)
    w = EndTextCommandGetWidth(true)
    widths[id] = w
    return w
end

local function text(str, x, y, colour, alpha, centre)
    SetTextFont(S.font)
    SetTextScale(0.0, S.scale)
    SetTextColour(colour[1], colour[2], colour[3], alpha)
    SetTextCentre(centre)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(str)
    EndTextCommandDisplayText(x, y)
end

--- The small mark at a point. alpha 0..255.
function D.Mark(x, y, z, alpha)
    local w = S.markSize
    local h = w * aspect
    SetDrawOrigin(x, y, z, 0)
    DrawRect(0.0, 0.0, w * 1.6, h * 1.6, 0, 0, 0, math.floor(alpha * 0.6))
    DrawRect(0.0, 0.0, w, h, S.mark[1], S.mark[2], S.mark[3], alpha)
    ClearDrawOrigin()
end

--- The full prompt: the key cap sits exactly on the point, the label to its right.
--- hold: nil, or 0..1 for how far a hold has come. glyph: key is a GTA ~INPUT_~ token (a key with no
--- text name): the game draws the bound key's own icon in the cap.
function D.Full(x, y, z, key, label, alpha, hold, glyph)
    local lineH = GetRenderedCharacterHeight(S.scale, S.font)
    local capH = lineH * 1.5
    local capW = glyph and capH / aspect or math.max(capH / aspect, textWidth(key) + 0.006)
    local gap = 0.004
    local labelW = (label and label ~= '') and textWidth(label) or 0
    SetDrawOrigin(x, y, z, 0)
    if labelW > 0 then
        local plateW = labelW + gap * 2
        DrawRect(capW / 2 + plateW / 2, 0.0, plateW, capH, S.back[1], S.back[2], S.back[3],
            math.floor(S.backAlpha * alpha / 255))
        text(label, capW / 2 + gap, -lineH * 0.62, S.text, alpha, false)
    end
    DrawRect(0.0, 0.0, capW, capH, S.keyBack[1], S.keyBack[2], S.keyBack[3], alpha)
    if hold and hold > 0 then
        local w = capW * math.min(hold, 1.0)
        DrawRect(-capW / 2 + w / 2, 0.0, w, capH, S.fill[1], S.fill[2], S.fill[3], alpha)
    end
    text(key, 0.0, -lineH * 0.62, S.key, alpha, true)
    ClearDrawOrigin()
end

--- Test aid (setr bp_prompt_debug 2): a 3 pixel pure magenta dot exactly on the point.
function D.Dot(x, y, z)
    local sw, sh = GetActiveScreenResolution()
    if not sw or sw <= 0 or not sh or sh <= 0 then return end
    SetDrawOrigin(x, y, z, 0)
    DrawRect(0.0, 0.0, 3 / sw, 3 / sh, 255, 0, 255, 255)
    ClearDrawOrigin()
end

-- ------------------------------------------------------------------ the text box --

local shown = nil   -- the text this module put on the box

--- true when the server has a text box this module can use
function B.Usable()
    return Core ~= nil and Core.TextUI ~= nil and Core.TextUI.Draw ~= nil and Core.TextUI.Stop ~= nil
end

--- Shows the text on the server's text box. Does nothing when it already shows it. -> false when it
--- cannot: no text box, or another script's text is on it (that text is never covered).
function B.Show(str)
    if not B.Usable() then return false end
    local now = Core.TextUI.Text
    if shown == str and now == str then return true end
    if now ~= nil and now ~= '' and now ~= shown then
        shown = nil              -- another script drew over ours, or was there first: the box is theirs
        return false
    end
    local ok = pcall(Core.TextUI.Draw, str)
    shown = ok and str or nil
    return ok
end

--- Takes this module's text off the box. Another script's text is left alone.
function B.Hide()
    if not shown then return end
    local mine = shown
    shown = nil
    if not B.Usable() then return end
    if Core.TextUI.Text == nil or Core.TextUI.Text == mine then pcall(Core.TextUI.Stop) end
end

function B.Shown() return shown end

return D
