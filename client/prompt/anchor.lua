--[[
    Core.Prompt, part 1: where a prompt sits (0.15.0).

    An anchor is a place in the world, or an entity with an optional bone. The point is worked out
    again every time it is asked for: the bone's own position right now, moved by an offset along the
    ENTITY's axes (x right, y forward, z up), so it stays right on a slope, on a lift and on a rolled car.

    All the entity maths goes through two natives that cannot be mixed up:
      GetOffsetFromEntityGivenWorldCoords   world point -> entity offset
      GetOffsetFromEntityInWorldCoords      entity offset -> world point

    Every answer names its source:
      'coords'    a fixed place
      'entity'    the entity's own origin (no bone asked)
      'bone'      the bone, read this frame
      'kept'      the bone reads the entity origin (a wheel that broke off): its last good offset
      'fallback'  the bone does not exist: the caller's fallback offset
      'box'       the bone does not exist and no fallback was given: a point on the model's box

    No drawing and no state of its own besides what it keeps on the anchor table it is given.
    The wheel names, the wheel list order, the tyre numbers, the origin rule and the face of a steered
    wheel come from the in-game spikes: [docs]/reports/prompt-spikes-2026-11-21.md (S3 to S6).
]]

PromptAnchor = {}
local A = PromptAnchor

-- a bone this close to the entity origin, after it once read somewhere else, is a part that came off
A.BROKEN_M = 0.05
-- sideways distance from the centre line below which a wheel has no side (bikes)
A.CENTRE_M = 0.05
-- half a tyre's width when the game gives none
A.HALF_TYRE_M = 0.12
-- bounds of that half (the native reads the rim radius, see halfWidth)
A.HALF_MIN_M, A.HALF_MAX_M = 0.06, 0.18
-- added to that half. Measured in the game (phase 4 facecal, tyre edge by pixel): the real outer face sits
-- 9.7 cm out on the sultan (half rim 11.8), 11.8 on gsticona1 (15.0), about 15.3 on the mule (14.9) and
-- 17.8 on the pounder (17.7). No one shift fits all; this one errs inward (a point a little inside the
-- tyre still reads as on it; one in the air does not)
A.FACE_OUT_M = -0.015
-- no wheel steers further than this; a larger turn is a misread rotation and counts as 0
A.STEER_MAX_DEG = 50.0
-- the car's wheel list x offset and the bone's x agree to 0.2 mm on a parked car (S3), but a hanging wheel's
-- bone moves 2 cm inward (S5, phase 4 facecal): beyond this they are not the same wheel
A.XOFF_M = 0.05
-- wheels whose forward offsets differ by less than this share an axle
A.AXLE_M = 0.30
-- where a wheel sits along the box when its bone is missing (share of the half length)
A.BOX_WHEEL_Y = 0.62

-- every wheel bone name a vehicle may have (S3). Bikes and bicycles use wheel_lf and wheel_lr;
-- wheel_f and wheel_r exist on no stock model. wheel_lm2 to wheel_rm3 were on none of the test models.
A.WHEEL_BONES = {
    'wheel_lf', 'wheel_rf', 'wheel_lm1', 'wheel_rm1', 'wheel_lm2', 'wheel_rm2',
    'wheel_lm3', 'wheel_rm3', 'wheel_lr', 'wheel_rr',
}

-- the order of the car's own wheel list (the FiveM wheel natives), found by breaking each wheel off
-- (S4): these names in this order, the missing ones left out. A two-wheeler's list is rear, then front.
local ORDER = {
    'wheel_lf', 'wheel_rf', 'wheel_lr', 'wheel_rr', 'wheel_lm1', 'wheel_rm1',
    'wheel_lm2', 'wheel_rm2', 'wheel_lm3', 'wheel_rm3',
}
local ORDER_TWO = { 'wheel_lr', 'wheel_lf' }

-- short wheel names a caller may use, each with the bones tried in order
A.WHEEL_ALIAS = {
    lf = { 'wheel_lf' },              rf = { 'wheel_rf' },
    lr = { 'wheel_lr' },              rr = { 'wheel_rr' },
    lm = { 'wheel_lm1' },             rm = { 'wheel_rm1' },
    lm1 = { 'wheel_lm1' },            rm1 = { 'wheel_rm1' },
    lm2 = { 'wheel_lm2' },            rm2 = { 'wheel_rm2' },
    lm3 = { 'wheel_lm3' },            rm3 = { 'wheel_rm3' },
    f = { 'wheel_f', 'wheel_lf' },    r = { 'wheel_r', 'wheel_lr' },
}

-- tyre numbers of the tyre natives (IsVehicleTyreBurst ...), by bone: 0 to 5 found by bursting each
-- (S4); lm2 and rm2 are from the native docs, not measured (no test model has them)
local TYRE = {
    wheel_lf = 0, wheel_rf = 1, wheel_lm1 = 2, wheel_rm1 = 3, wheel_lr = 4, wheel_rr = 5,
    wheel_lm2 = 45, wheel_rm2 = 47,
}

local function isWheel(name) return type(name) == 'string' and name:sub(1, 6) == 'wheel_' end

local function xyz(v)
    if v == nil then return nil end
    return v.x + 0.0, v.y + 0.0, v.z + 0.0
end

--- A table { x, y, z } from a vector, a table with x y z, or an array of three numbers. nil when it is none.
function A.Triple(v)
    if v == nil then return nil end
    local ok, x, y, z = pcall(function()
        if v.x ~= nil then return v.x, v.y, v.z end
        return v[1], v[2], v[3]
    end)
    if not ok or type(x) ~= 'number' or type(y) ~= 'number' or type(z) ~= 'number' then return nil end
    return { x + 0.0, y + 0.0, z + 0.0 }
end

--- The list of bone names for a spec: `wheel` ('lf', or a bone name) wins over `bone` (a name or a list).
function A.BoneList(bone, wheel)
    if wheel ~= nil then
        local alias = A.WHEEL_ALIAS[tostring(wheel):lower()]
        if alias then return { table.unpack(alias) } end
        return { tostring(wheel) }
    end
    if type(bone) == 'string' then return { bone } end
    if type(bone) == 'table' then
        local out = {}
        for _, name in ipairs(bone) do
            if type(name) == 'string' then out[#out + 1] = name end
        end
        if #out > 0 then return out end
    end
    return nil
end

--- A new anchor from a spec { coords | entity, bone?, wheel?, face?, offset?, fallback? }.
--- -> the anchor, or nil and 'bad_anchor'.
function A.New(spec)
    local a = { off = A.Triple(spec.offset) or { 0.0, 0.0, 0.0 } }
    local at = A.Triple(spec.coords)
    if at then
        a.coords = at
        return a
    end
    if type(spec.entity) ~= 'number' or spec.entity == 0 then return nil, 'bad_anchor' end
    a.entity = spec.entity
    a.bones = A.BoneList(spec.bone, spec.wheel)
    a.face = spec.face == 'out'
    a.fallback = A.Triple(spec.fallback)
    return a
end

-- finds the anchor's bone on its entity; called again when the model behind the handle changed
local function lookup(a, model)
    a.model, a.index, a.name, a.kept, a.half = model, -1, nil, nil, nil
    if not a.bones then return end
    for _, name in ipairs(a.bones) do
        local i = GetEntityBoneIndexByName(a.entity, name)
        if i ~= nil and i ~= -1 then
            a.index, a.name = i, name
            return
        end
    end
    a.name = a.bones[1]
end

-- the point on the model's box that stands in for a bone that is not there
local function boxPoint(a)
    local mn, mx = GetModelDimensions(a.model)
    local name = a.name or ''
    local side = name:match('^wheel_([lr])') or name:match('^door_([dp])side') or name:match('^handle_([dp])side')
    local x = 0.0
    if side == 'l' or side == 'd' then x = mn.x elseif side == 'r' or side == 'p' then x = mx.x end
    if isWheel(name) then
        local tail = name:sub(-1)
        local y = 0.0
        if tail == 'f' then y = mx.y * A.BOX_WHEEL_Y elseif tail == 'r' then y = mn.y * A.BOX_WHEEL_Y end
        return x, y, mn.z + (mx.z - mn.z) * 0.25
    end
    if name == 'bonnet' or name == 'engine' or name:sub(1, 9) == 'headlight' then return x, mx.y, 0.0 end
    if name == 'boot' or name:sub(1, 7) == 'exhaust' or name:sub(1, 9) == 'taillight' then return x, mn.y, 0.0 end
    return x, 0.0, 0.0
end

-- how far the outer tyre face sits from the wheel bone, asked once per anchor. The game has no tyre
-- width for stock wheels: GetVehicleWheelTireColliderWidth really reads the rim radius (S3, S5). It is
-- the closest number there is, so half of it, bounded, plus the measured outward shift of the tyre.
local function halfWidth(a)
    if a.half then return a.half end
    local half = A.HALF_TYRE_M
    if a.index ~= -1 and GetVehicleWheelTireColliderWidth then
        for _, w in ipairs(A.Wheels(a.entity)) do
            if w.bone == a.name and w.wheelIndex then
                local ok, width = pcall(GetVehicleWheelTireColliderWidth, a.entity, w.wheelIndex)
                if ok and type(width) == 'number' and width > 0.02 and width < 1.5 then
                    half = math.min(math.max(width / 2, A.HALF_MIN_M), A.HALF_MAX_M)
                end
                break
            end
        end
    end
    a.half = half + A.FACE_OUT_M
    return a.half
end

-- A steered wheel's turn against the car, in degrees, counterclockwise from above (left is +). The wheel
-- bone's rotation, composed z, then x, then y, has the axle as its own x axis; that axis stays put while
-- the wheel spins and turns with the steering (found in the game in phase 4: 150 rolling frames, spread
-- 0.0 degrees; the steering native reads 1.43 times this). Subtracting the car's yaw from the bone's, the
-- spike's way, reads about 10 degrees on straight parked wheels and anything at all on a rolling one.
-- (wx, wy, wz) is the bone in the world, (lx, ly) in the car's axes.
local function steer(ent, index, wx, wy, wz, lx, ly)
    local r = GetEntityBoneRotation(ent, index)
    local x, y, z = math.rad(r.x), math.rad(r.y), math.rad(r.z)
    local cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
    local o = GetOffsetFromEntityGivenWorldCoords(ent, wx + cz * cy - sz * sx * sy, wy + sz * cy + cz * sx * sy, wz - cx * sy)
    local dr, df = o.x - lx, o.y - ly
    if dr < 0 then dr, df = -dr, -df end          -- right-side wheel bones are mirrored: their axle points left
    if dr * dr + df * df < 0.25 then return 0.0 end
    local yaw = math.deg(math.atan(df, dr))
    if yaw > A.STEER_MAX_DEG or yaw < -A.STEER_MAX_DEG then return 0.0 end
    return yaw
end

--- The anchor's world point right now. -> x, y, z, source   or   nil, 'gone'
function A.Resolve(a)
    local off = a.off
    if a.coords then
        return a.coords[1] + off[1], a.coords[2] + off[2], a.coords[3] + off[3], 'coords'
    end
    local ent = a.entity
    if not DoesEntityExist(ent) then return nil, 'gone' end
    local model = GetEntityModel(ent)
    if a.model ~= model then lookup(a, model) end

    local lx, ly, lz, source = 0.0, 0.0, 0.0, 'entity'
    local wx, wy, wz
    if a.bones then
        if a.index ~= -1 then
            wx, wy, wz = xyz(GetWorldPositionOfEntityBone(ent, a.index))
            lx, ly, lz = xyz(GetOffsetFromEntityGivenWorldCoords(ent, wx, wy, wz))
            source = 'bone'
            local atOrigin = lx * lx + ly * ly + lz * lz < A.BROKEN_M * A.BROKEN_M
            if atOrigin then
                -- a bone at the entity origin is not there (S6): a wheel or a door that came off, or an
                -- addon bone the modeller left at the origin
                if a.kept then
                    lx, ly, lz, source = a.kept[1], a.kept[2], a.kept[3], 'kept'
                elseif a.fallback then
                    lx, ly, lz, source = a.fallback[1], a.fallback[2], a.fallback[3], 'fallback'
                else
                    lx, ly, lz = boxPoint(a)
                    source = 'box'
                end
            elseif not atOrigin then
                local k = a.kept
                if k then k[1], k[2], k[3] = lx, ly, lz else a.kept = { lx, ly, lz } end
            end
        elseif a.fallback then
            lx, ly, lz, source = a.fallback[1], a.fallback[2], a.fallback[3], 'fallback'
        else
            lx, ly, lz = boxPoint(a)
            source = 'box'
        end
        -- the outer face of a tyre: from the hub centre outward along the wheel's own axle, on its side.
        -- The axle turns with the steering; a kept offset has no live bone, so no turn.
        if a.face and isWheel(a.name) and (source == 'bone' or source == 'kept') then
            local side = lx > A.CENTRE_M and 1 or lx < -A.CENTRE_M and -1 or 0
            if side ~= 0 then
                local r = source == 'bone' and math.rad(steer(ent, a.index, wx, wy, wz, lx, ly)) or 0.0
                local half = halfWidth(a)
                lx, ly = lx + side * half * math.cos(r), ly + side * half * math.sin(r)
            end
        end
    end
    local px, py, pz = xyz(GetOffsetFromEntityInWorldCoords(ent, lx + off[1], ly + off[2], lz + off[3]))
    return px, py, pz, source
end

--- Every wheel of a vehicle, read from its bones: front axle first, left before right.
--- Each: { name = 'lf', bone = 'wheel_lf', side = 'left'|'right'|'centre', axle = 1.., tyre, wheelIndex,
---         offset = { x, y, z } } (offset in the vehicle's axes). {} when the entity is gone or has none.
function A.Wheels(ent)
    local out = {}
    if type(ent) ~= 'number' or not DoesEntityExist(ent) then return out end
    for _, bone in ipairs(A.WHEEL_BONES) do
        local i = GetEntityBoneIndexByName(ent, bone)
        if i ~= nil and i ~= -1 then
            local wx, wy, wz = xyz(GetWorldPositionOfEntityBone(ent, i))
            local lx, ly, lz = xyz(GetOffsetFromEntityGivenWorldCoords(ent, wx, wy, wz))
            local side = lx > A.CENTRE_M and 'right' or lx < -A.CENTRE_M and 'left' or 'centre'
            out[#out + 1] = {
                name = bone:sub(7), bone = bone, side = side, tyre = TYRE[bone],
                offset = { lx, ly, lz }, broken = lx * lx + ly * ly + lz * lz < A.BROKEN_M * A.BROKEN_M,
            }
        end
    end
    local list = out
    local order = { left = 1, centre = 2, right = 3 }
    table.sort(list, function(p, q)
        if math.abs(p.offset[2] - q.offset[2]) >= A.AXLE_M then return p.offset[2] > q.offset[2] end
        if order[p.side] ~= order[q.side] then return order[p.side] < order[q.side] end
        return p.bone < q.bone
    end)
    local axle, lastY = 0, nil
    for _, w in ipairs(list) do
        if lastY == nil or lastY - w.offset[2] >= A.AXLE_M then
            axle = axle + 1
            lastY = w.offset[2]
        end
        w.axle = axle
    end
    -- The car's own wheel list (the FiveM wheel natives), in the fixed name order of S4. Kept only when
    -- the list is as long as the wheels found and each wheel's x offset in it equals its bone's x (a
    -- broken-off wheel's bone reads the origin, so it is not compared); otherwise wheelIndex stays nil.
    local count = GetVehicleNumberOfWheels and GetVehicleNumberOfWheels(ent) or 0
    if count == #list and count > 0 then
        local byBone, two = {}, true
        for _, w in ipairs(list) do
            byBone[w.bone] = w
            if w.side ~= 'centre' and not w.broken then two = false end
        end
        local seq = {}
        for _, bone in ipairs(two and ORDER_TWO or ORDER) do
            if byBone[bone] then seq[#seq + 1] = byBone[bone] end
        end
        local agree = #seq == count
        if agree and GetVehicleWheelXOffset then
            for i, w in ipairs(seq) do
                local ok, x = pcall(GetVehicleWheelXOffset, ent, i - 1)
                if not ok or type(x) ~= 'number' then agree = false; break end
                if not w.broken and math.abs(x - w.offset[1]) >= A.XOFF_M then agree = false; break end
            end
        end
        if agree then for i, w in ipairs(seq) do w.wheelIndex = i - 1 end end
    end
    return list
end

return A
