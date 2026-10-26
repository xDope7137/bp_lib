# bp_lib — Function Reference

`bp_lib` is a compatibility layer that wraps a long list of frameworks, inventories, target systems, fuels, etc. behind a single `Core` table. Every consumer accesses the library via:

```lua
local Core = exports['bp_lib']:Core()
```

The `Core` table is assembled in `client/main.lua` and `server/main.lua` by loading the implementation file selected in `shared/config.lua`. Function signatures listed here are the contract every implementation must satisfy.

> **Convention used in this doc:** each entry is grouped by `Core.<module>`. Each function shows side (client/server), source file, signature, and a short usage snippet. "Used by" lists at least one consumer in this monorepo when the function is referenced from another resource — confirmed via grep on `resources/[bp]/`.

---

## Table of contents

- [Bootstrap & exports](#bootstrap--exports)
- [Core.Framework (client)](#coreframework-client)
- [Core.Framework (server)](#coreframework-server)
- [Core.Inventory (client)](#coreinventory-client)
- [Core.Inventory (server)](#coreinventory-server)
- [Core.Notify](#corenotify)
- [Core.Target](#coretarget)
- [Core.TextUI](#coretextui)
- [Core.ProgressBar](#coreprogressbar)
- [Core.Menu](#coremenu)
- [Core.Input](#coreinput)
- [Core.Poly](#corepoly)
- [Core.Fuel](#corefuel)
- [Core.VehicleKeys](#corevehiclekeys)
- [Core.VehicleProperties](#corevehicleproperties)
- [Core.Clothing](#coreclothing)
- [Core.Dispatch](#coredispatch)
- [Core.Weather (client)](#coreweather-client)
- [Core.Weather (server)](#coreweather-server)
- [Core.Database (server)](#coredatabase-server)
- [Core.Logs (server)](#corelogs-server)
- [Core.EntitySync (client)](#coreentitysync-client)
- [Core.EntitySync (server)](#coreentitysync-server)
- [Core.Groups (server)](#coregroups-server)
- [Core.Groups (client)](#coregroups-client)
- [Core.Math (client)](#coremath-client)
- [Core.Utils (shared)](#coreutils-shared)
- [Locale helpers (shared)](#locale-helpers-shared)
- [CarryItems exports (client)](#carryitems-exports-client)
- [Skill menu export (client)](#skill-menu-export-client)
- [EntitySync exports (server)](#entitysync-exports-server)
- [Built-in callbacks](#built-in-callbacks)
- [Events](#events)
- [Configuration reference](#configuration-reference)

---

## Bootstrap & exports

| Export | Side | Returns | Source |
|---|---|---|---|
| `exports['bp_lib']:Core()` | client | The `Core` table | `client/main.lua:53` |
| `exports['bp_lib']:Core()` | server | The `Core` table | `server/main.lua:121` |

Standard usage:

```lua
local Core = exports['bp_lib']:Core()
```

`Used by:` `bp_apartments`, `bp_cookies`, `bp_redzones`, `bp_spikes`, `bp_truckheist`, `bp_mystery`.

---

## Core.Framework (client)

Source: `client/framework/{esx,ox,qb,qbx,tmc}.lua` — implementation chosen by `Config.Framework`.

### `Core.Framework.PlayerLoaded`
- **Type:** `boolean` (state field, not a function)
- **Set to true** when the framework fires its on-loaded event; the lib also fires `bp_lib:PlayerLoaded` at that moment.

```lua
while not Core.Framework.PlayerLoaded do Wait(100) end
```

### `Core.Framework.Framework`
- **Type:** `string` — one of `"qb"`, `"qbx"`, `"esx"`, `"ox"`, `"tmc"`. Useful for branching on framework specifics.

### `Core.Framework.Callbacks.Trigger(name, ...)`
Synchronously triggers a server callback. Internally awaits a promise.
- **Returns:** whatever the callback returns.

```lua
local data = Core.Framework.Callbacks.Trigger('bp_lib:GetSkillData')
```

### `Core.Framework.Callbacks.TriggerAsync(name, cb, ...)`
Same as above, but resolves into the supplied callback. Returns nothing.

```lua
Core.Framework.Callbacks.TriggerAsync('my:cb', function(result)
    print(result)
end, arg1, arg2)
```

### `Core.Framework.SpawnVehicle(model, pos, cb, networked)`
- **model:** `string|hash`
- **pos:** `vector3`/`vector4`
- **cb:** `function(vehicle)` — receives the spawned entity (already converted from netId where applicable).
- **networked:** `boolean` (qb only — qbx/ox always networked).

```lua
Core.Framework.SpawnVehicle('adder', GetEntityCoords(PlayerPedId()), function(veh)
    SetPedIntoVehicle(PlayerPedId(), veh, -1)
end, true)
```

### `Core.Framework.GetVehicleProperties(vehicle)`
Returns the framework's vehicle properties table (qb's `GetVehicleProperties`, ox's `lib.getVehicleProperties`, etc.).

### `Core.Framework.SetVehicleProperties(vehicle, data)`
Applies a properties table previously produced by `GetVehicleProperties`.

### `Core.Framework.GetPlayerJob()`
Returns the player's job table — shape depends on the framework (qb-style `{name, label, grade=…}`).

---

## Core.Framework (server)

Source: `server/framework/{esx,ox,qb,qbx,tmc}.lua`.

### `Core.Framework.RegisterCallback(name, cb)`
Registers a server callback in a framework-agnostic way. Callback signature: `function(source, cb, ...)`.

On **ox** and **qbx**, this wraps `lib.callback.register`: your handler must call `cb(result)` **before it returns** (same tick). Thrown errors are caught and logged; missing `cb()` returns `nil` to the client.

```lua
Core.Framework.RegisterCallback('myresource:fetch', function(source, cb, id)
    cb({ id = id, name = 'foo' })
end)
```

### `Core.Framework.GetIdentifier(player)`
- **player:** server source id.
- **Returns:** the framework citizen identifier (`citizenid` for qb/qbx, identifier for esx, charId for ox).

### `Core.Framework.GetIdentifierID(identifier)`
Inverse of the above — `identifier → source` (or `false` if offline).

### `Core.Framework.GetCharName(player)`
- **Returns:** `{ first = string, last = string, full = "First Last" }` or `nil`.

### `Core.Framework.GetJobPlayerCount(jobs)`
- **jobs:** array of job names (e.g. `{'police','sheriff'}`).
- **Returns:** number of currently on-duty players across those jobs.

### `Core.Framework.GetPlayers()`
Returns the framework's array of online player ids.

### `Core.Framework.HasGroup(player, group)`
- **Returns:** `boolean` — wraps the framework permission/ace check.

### `Core.Framework.Money.Give(player, amount, account)`
- **account:** `"cash"`, `"bank"`, or `"black_money"` (the latter is wired to the inventory item on qbx).

### `Core.Framework.Money.Get(player, account)`
Returns the current balance for that account, or `0` for missing items / `nil` for missing players.

### `Core.Framework.Money.Remove(player, amount, account)`
Same account values as `Give`. Returns whatever the underlying framework returns.

### `Core.Framework.Job.Set(player, job, grade)`
Sets the player's job/grade.

### `Core.Framework.Job.Get(player)`
Returns the current job *name*.

### `Core.Framework.Job.GetLabel(player)`
Returns the current job *label*.

### `Core.Framework.Job.GetGrade(player)`
Returns the current grade *level* (number).

### `Core.Framework.Job.GetGradeLabel(player)`
Returns the current grade *name* (string).

---

## Core.Inventory (client)

Source: `client/inventory/<system>.lua` (selected by `Config.Inventory`).

### `Core.Inventory.GetItemLabel(item)`
- **Returns:** the item's friendly label string, or `"NO_LABEL"` if unknown.

### `Core.Inventory.AddCarriableItem(itemName, options)`
Registers an item as a "carry item" — the lib will then play an animation / attach a prop / apply clothing while the player has it. Options table:

```lua
Core.Inventory.AddCarriableItem('cardboard_box', {
    anim       = 'idle',                          -- optional
    animDict   = 'anim@heists@box_carry@',        -- required if anim
    prop       = 'prop_cs_cardbox_01',            -- prop model
    boneIndex  = 60309,                           -- ped bone index
    offsets    = {0.025, 0.08, 0.255, -145.0, 290.0, 0.0},
    clothing   = {                                -- optional swap
        male   = { id = 5, drawable = 45, texture = 0 },
        female = { id = 5, drawable = 44, texture = 0 },
    },
    disableSprint = true,                         -- optional
    disableJump   = true,                         -- optional
    disableFight  = true,                         -- optional
})
```

### `Core.Inventory.RemoveCarriableItem(itemName)`
Unregisters a carry item and clears the player's pose if it was active.

### `Core.Inventory.OpenStash(stashName, maxWeight, slots)`
Registers (server-side, via callback) and immediately opens a stash. Only meaningful with `ox_inventory`.

```lua
Core.Inventory.OpenStash('mystash_'..plate, 100000, 50)
```

---

## Core.Inventory (server)

Source: `server/inventory/<system>.lua`.

### `Core.Inventory.AddItem(source, item, amount, metadata)`
- **Returns:** `boolean` — `false` when the inventory cannot carry the item, otherwise the result of the underlying call.
- `metadata` is a free-form table on inventories that support it (`ox_inventory`, etc.).

```lua
local ok = Core.Inventory.AddItem(src, 'phone', 1, { number = '555-0100' })
```

### `Core.Inventory.RemoveItem(source, item, amount, metadata)`
Removes by quantity, optionally matched against metadata.

### `Core.Inventory.GetSlots(identifier)`
- **Returns:** `slotsUsed, slotsFree` (numbers). Implemented for `qb-inventory`; on `ox_inventory` it is omitted (use `CanCarryItem` instead).

### `Core.Inventory.GetTotalWeight(items)`
- **items:** array as returned by `GetItems`.
- **Returns:** `number` (weight). qb-only helper.

### `Core.Inventory.CanCarryItem(source, item, amount)`
- **Returns:** `boolean[, reason]` — second value is `'weight'` or `'slots'` on failure (qb).

### `Core.Inventory.GetItem(source, item, metadata)`
- **Returns:** `{ item = name, count = number, metadata = table } | nil`.

### `Core.Inventory.GetItems(source)`
- **Returns:** array of `{ item, count, metadata }` records.

### `Core.Inventory.HasPlayerItem(source, item, count)`
Convenience around `GetItem`. With `count` omitted, returns `true` if any quantity exists.

### `Core.Inventory.RegisterUsableItem(item, callback)`
Registers a usable item across frameworks (`QBCore.Functions.CreateUseableItem`, `ESX.RegisterUsableItem`, or the qbx export).

```lua
Core.Inventory.RegisterUsableItem('lockpick', function(source, item)
    -- consume / trigger client event
end)
```

---

## Core.Notify

`Core.Notify` is itself a function (the notifications module returns a callable), not a table.

Source: `client/notifications/<system>.lua`.

### `Core.Notify(title, desc, type)`
- **title:** main message.
- **desc:** subtitle / body (optional on most backends).
- **type:** one of `"info"`, `"success"`, `"error"`, `"warning"`. ox_lib remaps `"info"` to `"inform"` automatically.

```lua
Core.Notify('Inventory', 'Item added', 'success')
```

A net event mirror is registered in `client/main.lua:49`:

```lua
TriggerClientEvent('bp_lib:notify', src, 'Title', 'Body', 'success')
```

`Used by:` `bp_apartments`, `bp_cookies`, `bp_redzones`, `bp_spikes`.

---

## Core.Target

Source: `client/target/<system>.lua` (`ox_target`, `qb-target`, `qtarget`).

The `options` argument to every Add* function is an array of:

```lua
{
    name        = 'unique_action_id',
    icon        = 'fas fa-key',
    label       = 'Use Key',
    item        = 'key',                 -- optional: requires inventory item
    canInteract = function(entity) ... end,
    onSelect    = function(entity) ... end,
    jobs        = { 'police' },          -- optional job/group gate
}
```

### `Core.Target.AddEntity(entities, options, distance)`
Registers options on one or more local entities (entity handles or netIds).

### `Core.Target.AddNetworkedEntity(netId, options, distance)`
Same but addressed by network id (ox_target only).

### `Core.Target.AddBone(bones, options, distance)`
Adds an interaction tied to a vehicle bone set.

### `Core.Target.AddModel(models, options, distance)`
Adds an interaction to every entity matching a model hash / name.

### `Core.Target.AddBoxZone(boxData, options, distance)`
- **boxData:** `{ name, coords = vector3, size = vector3, heading = number, debug = boolean }`.
- **Returns:** `id` — pass to `RemoveZone`.

### `Core.Target.AddPlayer(options, distance)`
Adds player-targeted interactions.

### `Core.Target.AddVehicle(options, distance)`
Adds global vehicle interactions.

### `Core.Target.AddGlobalVehicle(options)`
Lower-level passthrough for ox_target's `addGlobalVehicle`.

### `Core.Target.RemoveZone(id)`
Removes a zone created via `AddBoxZone`.

### `Core.Target.RemoveEntityZone(entities, names)`
Removes a per-entity option (or list of options) by name.

### `Core.Target.RemoveBone(bones, names)` / `Core.Target.RemovePlayer(names)` / `Core.Target.RemoveVehicle(names)`
Companion removers for the matching `Add*` calls.

`Used by:` `bp_apartments` (entity & box zones), `bp_cookies`.

---

## Core.TextUI

Source: `client/textui/<system>.lua`. The notifications backend determines the renderer.

### `Core.TextUI.Draw(text, pos)`
Shows persistent text. Re-invoking with the same string is a no-op (avoids flicker).

### `Core.TextUI.Stop()`
Hides the active TextUI.

```lua
Core.TextUI.Draw('[E] Open door')
-- ... later
Core.TextUI.Stop()
```

`Used by:` `bp_apartments`, `bp_redzones`.

---

## Core.ProgressBar

`Core.ProgressBar` is a function (not a table).

Source: `client/progressbar/<system>.lua`.

### `Core.ProgressBar(label, time, options)`
- **time:** duration in ms.
- **options:** `{ useWhileDead, canCancel, disableCarMovement, disableMovement, disableMouse, disableCombat, animation = { animDict, anim, flags } }`.
- **Returns:** `boolean` — `true` when completed, `false` when cancelled.

```lua
local ok = Core.ProgressBar('Picking lock', 5000, {
    canCancel = true,
    disableMovement = true,
    animation = { animDict = 'mp_common', anim = 'givetake1_a', flags = 49 }
})
if not ok then return end
```

`Used by:` `bp_apartments`, `bp_cookies`.

---

## Core.Menu

`Core.Menu` is a function.

Source: `client/menu/<system>.lua`.

### `Core.Menu(title, options)`
Opens a context menu. Each option:

```lua
{
    title       = 'Open',
    description = 'Open the door',
    icon        = 'fas fa-door-open',  -- or false
    metadata    = { 'Owner: John' },   -- optional
    disabled    = false,
    isServer    = false,               -- true ⇒ event is treated as serverEvent
    event       = 'my:event',
    args        = { foo = 1 },
    onSelect    = function() ... end,  -- runs in addition to event
}
```

`Used by:` the bundled skill menu (`client/menu/skillMenu.lua:19`), and external resources such as `bp_apartments`.

---

## Core.Input

`Core.Input` is a function.

Source: `client/input/<system>.lua`.

### `Core.Input(title, options)`
Each option:

```lua
{
    type    = 'input' | 'number' | 'checkbox' | 'select',
    label   = 'Display label',
    name    = 'fieldName',         -- key in returned table
    default = ...,                 -- optional
    options = { { value, text } }, -- only for type = 'select'
}
```

- **Returns:** `table` keyed by `name` — or `nil` if the user cancels.

```lua
local res = Core.Input('Set price', {
    { type = 'number', label = 'Price', name = 'price', default = 100 },
})
if res then print(res.price) end
```

---

## Core.Poly

Source: `client/poly/<system>.lua` (`ox_lib`, `polyzone`).

Each callback receives `(entering, zone)`.

### `Core.Poly.AddBoxZone(pos, height, width, heading, cb)`
- **pos:** `vector3`. **Returns:** `id` (string).

### `Core.Poly.AddCircularZone(pos, radius, cb)`
**Returns:** `id`.

### `Core.Poly.AddPolyZone(points, cb)`
- **points:** array of `vector3`. **Returns:** `id`.

### `Core.Poly.RemoveZone(id)`
The lib also auto-removes all zones created by a resource when that resource stops.

```lua
local zoneId = Core.Poly.AddBoxZone(vector3(100,200,30), 5.0, 3.0, 90.0, function(entering)
    if entering then Core.TextUI.Draw('[E] Interact') else Core.TextUI.Stop() end
end)
```

`Used by:` `bp_redzones`.

---

## Core.Fuel

Source: `client/fuel/<system>.lua`.

### `Core.Fuel.GetFuel(vehicle, plate)`
- **Returns:** `number` (0–100), or `0` when arguments are missing.

### `Core.Fuel.SetFuel(vehicle, plate, level)`
Sets the fuel level. `plate` is required for some backends (e.g. `ox_fuel`'s state-bag based flow).

---

## Core.VehicleKeys

`Core.VehicleKeys` is whatever the selected `client/vehiclekeys/<system>.lua` returns. The shared API across backends is:

### `Core.VehicleKeys.Give(vehicle, plate)`
Grants ownership/keys to the local player using the configured vehicle-key system.

Some legacy systems also listen for the event `bp_lib:RemoveVehKeys`:

```lua
TriggerEvent('bp_lib:RemoveVehKeys', vehicle, plate)
```

---

## Core.VehicleProperties

Source: `client/vehicleproperties/<system>.lua`.

### `Core.VehicleProperties.Get(vehicle)`
Returns the vehicle's properties table (mods, paint, etc.) — backend-specific shape.

### `Core.VehicleProperties.Set(vehicle, properties)`
Applies a previously captured properties table.

---

## Core.Clothing

Source: `client/clothing/<system>.lua`.

### `Core.Clothing.Set(outfit)`
- **outfit:** flat table with the standard slot keys:

```lua
Core.Clothing.Set({
    tshirt_1 = 1, tshirt_2 = 0,
    arms     = 0,
    torso_1  = 0, torso_2 = 0,
    pants_1  = 0, pants_2 = 0,
    shoes_1  = 0, shoes_2 = 0,
    chain_1  = 0, chain_2 = 0,
    glasses_1 = 0, glasses_2 = 0,
    ears_1   = 0, ears_2 = 0,
    decals_1 = 0, decals_2 = 0,
})
```

### `Core.Clothing.Reset()`
Restores the player's saved skin (e.g. `qb-clothes:loadPlayerSkin`).

---

## Core.Dispatch

`Core.Dispatch` is a function on both sides.

Source: `client/dispatch/<system>.lua` and `server/dispatch/<system>.lua` (selected by `Config.Dispatch`).

### Server: `Core.Dispatch(data)`
The default backend simply broadcasts to all clients via `bp_lib:SendDispatchAlert`. Other backends translate `data` into their own dispatch payloads.

```lua
Core.Dispatch({
    pos          = vector3(x, y, z),
    message      = 'Shots fired',
    dispatch_code = '10-71',
    time         = 60,        -- seconds blip stays
    sprite       = 161,
    color        = 1,
    scale        = 1.0,
    police_jobs  = { 'police', 'sheriff' },
})
```

### Client: `Core.Dispatch(data)`
Same payload shape; the default implementation plays a sound, posts a notification ticker, and pulses a temporary blip at `data.pos`.

---

## Core.Weather (client)

Source: `client/weathersync/<system>.lua`. Most backends expose only `Enable`/`Disable`; `tmc.lua` adds the rest.

### `Core.Weather.Enable()` / `Core.Weather.Disable()`
Re-enable or pause weather sync for the local client.

### `Core.Weather.ForceWeather(weather)`  *(tmc only)*
Forces a weather string locally.

### `Core.Weather.ForceTime(hour, minute)`  *(tmc only)*

### `Core.Weather.SetInsideShell(isInside)`  *(tmc only)*
Tells the weather sync the player is inside an interior shell.

### `Core.Weather.CreateSnowball()`  *(tmc only)*

### `Core.Weather.GetCurrentWeather()` / `GetCurrentTime()` / `IsBlackout()` / `IsFrozen()`  *(tmc only)*

---

## Core.Weather (server)

### `Core.Weather.Blackout(state)`
Toggles the city blackout via the configured weather sync (`qb-weathersync` is the reference implementation; some backends print an unsupported warning).

---

## Core.Database (server)

Source: `server/database/<system>.lua` (`oxmysql`, `mysql-async`, `ghmattimysql`).

### `Core.Database.FetchSync(query, params)`
Synchronous SELECT. Returns the rows array.

### `Core.Database.ExecuteSync(query, params)`
Synchronous INSERT/UPDATE/DELETE. Returns the driver's execute result.

### `Core.Database.Insert(query, params, cb)`
Async insert. `cb(insertId)`.

### `Core.Database.Execute(query, params, cb)`
Async execute. `cb(affectedRows | result)`.

```lua
local rows = Core.Database.FetchSync('SELECT * FROM users WHERE id = ?', { 1 })
Core.Database.Insert('INSERT INTO logs (msg) VALUES (?)', { 'hi' }, function(id)
    print('row id', id)
end)
```

---

## Core.Logs (server)

Source: `server/logger/<system>.lua` (`discord`, `ox_lib`).

### `Core.Logs.GetPlayerData(playerId, isTarget)`
Builds a markdown block (`**SOURCE**` or `**TARGET**`) including nickname, ids, steam/license/discord/HWID. Used internally by `Send`.

### `Core.Logs.GetPlayerIdentifier(playerId, identifier)`
Returns the value of the requested identifier (`'steam'`, `'license'`, `'discord'`, …) or `'?'`.

### `Core.Logs.Send(type, title, description, playerId, targetId, important)`
- **type:** key into the global `Logs` table from `shared/discordLogs.lua`. Falls back to `Logs.others`.
- **important:** when `true`, also posts an `@here` ping (discord backend).

```lua
Core.Logs.Send('inventory', 'Item Removed', 'phone x1', src, nil, false)
```

---

## Core.EntitySync (client)

Source: `client/entitySync/class.lua`. Exposed as `Core.EntitySync`.

These functions are sugar over server callbacks (`peuren_lib:CreateEntity`, `:CreatePed`, `:CreateVehicle`).

### `Core.EntitySync.CreateEntity(model, pos, args)`
- **pos:** `vector4` (`pos.w` = heading).
- **args:** `{ freeze = boolean }`.
- **Returns:** `{ entity = number, netId = number }` or `false`.

### `Core.EntitySync.CreateVehicle(model, pos, args)`
Same as above, server-side it uses `CreateVehicle` and joaat-hashes `model`.

### `Core.EntitySync.CreatePed(model, pos, args)`
Same, server-side via `CreatePed`.

### `Core.EntitySync.RequestEntityControl(netId)`
Migrates the entity to the local client and waits up to ~500 ms for control. **Returns:** `boolean`.

### `Core.EntitySync.AttachEntities(parentNetId, childNetId, offset, rot)`
Acquires control of both, then `AttachEntityToEntity`. `offset`/`rot` are `vector3`-ish.

`Used by:` `bp_truckheist` (vehicle/object spawning + attaching).

---

## Core.EntitySync (server)

Source: `server/entitySync/class.lua` (functions) and `server/entitySync/main.lua` (callbacks). The server-side `Core.EntitySync.CreateEntity/CreatePed/CreateVehicle` are also directly callable for native server-spawning, returning `{ entity, netId }`.

The module also registers these callbacks for the client wrappers above:

- `peuren_lib:CreateEntity`
- `peuren_lib:CreatePed`
- `peuren_lib:CreateVehicle`

---

## Core.Groups (server)

Source: `server/groups/class.lua`. The class is namespaced **per invoking resource** — calling `Core.Groups.Set` from `bp_truckheist` and from `bp_cookies` produces independent group registries.

### `Core.Groups.Set(source, args, maxPlayers)`
Creates a group owned by `source`.
- **args:** free-form table; `args.groupId` and `args.started=false` are filled in for you.
- **maxPlayers:** optional override of `Config.Groups.MemberLimit`.
- **Returns:** the new group record (`{ resource, groupId, pass, maxPlayers, owner, args, started, pCount, players }`).

### `Core.Groups.Get(source, groupId, resource)`
Looks up by either ownership (omit `groupId`) or `groupId`. **Returns:** the group record or `nil`.

### `Core.Groups.Update(source, groupId, data)`
Replaces the stored record and fires `<resource>:group:Updated` to all members.

### `Core.Groups.GetMember(source, groupId)`
Returns the member sub-record for `source` in the given group.

### `Core.Groups.GetJobGroups()`
Returns all groups for the invoking resource where `started == false`.

### `Core.Groups.Remove(source, groupId)`
Deletes the group; broadcasts `<resource>:group:Deleted` first. **Returns:** `true`.

### `Core.Groups.AddMember(source, groupId, password)`
- **Returns:**
  - the group record on success,
  - `'wrong_pass'` if the password fails,
  - `'full'` if at capacity,
  - `nil` if `source` is already in the group.

Also fires `<resource>:group:MemberAdded` to the new member.

### `Core.Groups.RemoveMember(source, groupId)`
Removes the member, fires `<resource>:group:MemberRemoved` and `:group:Updated`.

### `Core.Groups.SendEvent(source, groupId, event, args, resource)`
Triggers `event` on every member's client with `(args, isOwner)`. Sleeps 100 ms between recipients.

### `Core.Groups.SendGlobalJobEvent(event, args)`
Same as `SendEvent` but iterates every group across every resource.

### `Core.Groups.IsPlayerInGroup(source)`
Checks all *other* resources for membership; if found, sends a `peuren_lib:notify` warning and returns `true`.

### `Core.Groups.MemberDisconnected(source)`
Wired to `playerDropped`. Starts the `Config.Groups.Timeout` countdown; after expiry the leader is migrated or the group is destroyed.

### `Core.Groups.CreatePassword()`
Returns a random `Config.Groups.password.length`-char password (numeric or alphanumeric per `password.type`).

### `Core.Groups.CreateGroupId()`
Returns a unique 6-char alphanumeric id.

---

## Core.Groups (client)

Source: `client/groups/class.lua` and `main.lua`. Loaded via the `Groups` global.

### `Core.Groups.DoesBlipExist(name)`
Returns the blip name if a blip is tracked under that key, else `nil`.

### `Core.Groups.RemoveBlip(name)`
Removes the blip and clears its route.

The lib also handles two net events for you — they create / remove tracked blips:

- `bp_lib:Groups:CreateBlip(name, data)`
- `bp_lib:Groups:RemoveBlip(name)`

---

## Core.Math (client)

Source: `client/math/math.lua`.

### `Core.Math.RandomStr(length)`
Random alphabetic string. *(Note: the implementation recurses through `Core.Math.RandomStr`, so it must be invoked through the `Core.` table rather than a local alias.)*

### `Core.Math.RandomInt(length)`
Random numeric string of the given length.

### `Core.Math.SplitStr(str, delimiter)`
Returns an array of segments (Lua-pattern `delimiter`).

### `Core.Math.Trim(value)`
Strips leading/trailing whitespace. Returns `nil` for `nil` input.

### `Core.Math.FirstToUpper(value)`
Capitalizes the first letter.

### `Core.Math.Round(value, numDecimalPlaces)`
Rounds to N decimals (or to integer if omitted).

### `Core.Math.GetPlate(vehicle)`
Returns the trimmed `GetVehicleNumberPlateText` for the vehicle (`nil` for `0`).

```lua
local plate = Core.Math.GetPlate(GetVehiclePedIsIn(PlayerPedId(), false))
```

---

## Core.Utils (shared)

Source: `utils/utils.lua` (loaded on both sides). Also exposed as `Core.Print` (alias for `Utils.Print`).

### `Core.Utils.CompareTables(first, second)`
Recursive deep equality (one-direction — checks every key in `first` exists and matches in `second`). Returns `boolean`.

### `Core.Utils.Print(...)`
Prints only when `Config.Debug == true`. Same as `Core.Print(...)`.

### `Core.Utils.GetClosestVehicle(coords, radius)`  *(client only)*
Returns the first vehicle within `radius` and inside a ~45° forward cone from the local ped: `vehicle, distance` (or `nil, radius`).

---

## Locale helpers (shared)

Source: `utils/locale.lua`. Loaded into `Core` as `Core.LoadLocales`, `Core.GetLocales`, and `Core.Locale`.

### `Core.Locale(key, ...)`
Looks up `key` in the invoking resource's locale dictionary, falling back to `peuren_lib`'s. Optional varargs are forwarded to `string.format`.

```lua
Core.Notify(Core.Locale('item_added', 'phone'), nil, 'success')
```

### `Core.LoadLocales()`
Loads `locales/<Config.Language>.json` for the invoking resource (with English fallback). Called once for `bp_lib` itself in `client/main.lua:47` and `server/main.lua:64`. **Consumer resources should call this from their own startup if they ship locales.**

### `Core.GetLocales()`
Returns the full nested `dict` table — `{ resourceName = { key = value, ... } }`. Used by the bundled skill menu to pluck strings without going through `Core.Locale`.

---

## CarryItems exports (client)

Standalone exports (not on `Core`). Backed by `client/inventory/carryItems.lua`.

### `exports['bp_lib']:GetCarryItem()`
Returns the item name currently being carried, or `nil`.

### `exports['bp_lib']:AddCarryItem(item)`
Forces the lib to treat `item` as present in inventory and update animation/prop. Useful for short-lived "carry" effects that aren't tied to an actual inventory slot.

### `exports['bp_lib']:RemoveCarryItem(item)`
Force-clears the carry state for `item`.

The carry system also emits these client events:

- `bp_lib:AddedItem(itemName)`
- `bp_lib:RemovedItem(itemName)`

---

## Skill menu export (client)

Source: `client/menu/skillMenu.lua`.

### `exports['bp_lib']:OpenSkillMenu()`
Triggers the `bp_lib:GetSkillData` callback and opens a `Core.Menu` listing every skill.

The command exposed by `Config.SkillMenu.Command` (default `skills`) calls the same function.

---

## EntitySync exports (server)

Source: `server/entitySync/main.lua`. Both currently are passthrough stubs — they return whatever string you pass, but exist so consumers can branch on `if exports['bp_lib']:ValidateResourceAccess(...) then`.

### `exports['bp_lib']:GetResourceSessionToken(resourceName)`
### `exports['bp_lib']:ValidateResourceAccess(resourceName)`

---

## Built-in callbacks

Triggered with `Core.Framework.Callbacks.Trigger(name, ...)` from a client.

### `bp_lib:GetSkillData`
Server source: `server/main.lua:79`.

Returns an array of `{ locale, xp, level }` for any `peuren_*` skill resource currently started:

```lua
{
  { locale = 'peuren_fishing',              xp = 100, level = 5 },
  { locale = 'peuren_burglary_hacking',     xp = 50,  level = 3 },
  { locale = 'peuren_burglary_lockpicking', xp = 75,  level = 4 },
  { locale = 'peuren_burglary_looting',     xp = 25,  level = 2 },
}
```

### `bp_lib:GetPlayerInventory`
Source: `server/inventory/<system>.lua`.

Returns the player's items in the lib's normalized shape (`{ item, count, metadata }[]`).

### `bp_lib:inventory:RegisterStash`
Source: `server/inventory/ox_inventory.lua`.

Payload: `{ stashName, slots, weight }`. Registers a stash and returns `true`. Used internally by `Core.Inventory.OpenStash`.

### `bp_lib:SpawnVehicle`
Source: `server/framework/qbx.lua` (and the qb framework file).

Args (qbx): `(model, pos)`. Returns `netId`. The qb client wrapper calls it with `(model, pos, 90)` for spawn heading.

```lua
local netId = Core.Framework.Callbacks.Trigger('bp_lib:SpawnVehicle', 'adder', GetEntityCoords(PlayerPedId()))
local vehicle = NetToVeh(netId)
```

### `peuren_lib:CreateEntity` / `:CreatePed` / `:CreateVehicle`
Server callbacks backing `Core.EntitySync.Create*`. Not generally invoked directly — call the wrappers instead.

---

## Events

### Client

| Event | Direction | Payload | Notes |
|---|---|---|---|
| `bp_lib:PlayerLoaded` | local | – | Mirrored from each framework's player-loaded event |
| `bp_lib:notify` | server → client | `(title, desc, type)` | Calls `Core.Notify` |
| `bp_lib:SendDispatchAlert` | server → client | `data` table | Default dispatch backend only |
| `bp_lib:Groups:CreateBlip` | server → client | `(name, data)` | Creates and tracks a blip |
| `bp_lib:Groups:RemoveBlip` | server → client | `name` | Removes a tracked blip |
| `bp_lib:AddedItem` | local | `itemName` | Fired when CarryItems registers presence |
| `bp_lib:RemovedItem` | local | `itemName` | Fired when CarryItems clears presence |
| `<resource>:group:MemberAdded` / `:MemberRemoved` / `:Updated` / `:Deleted` | server → client | `(data, isOwner)` | Resource-namespaced group lifecycle |

### Server

| Event | Direction | Payload | Notes |
|---|---|---|---|
| `bp_lib:RemoveVehKeys` | local | `(vehicle, plate)` | Optional companion to `Core.VehicleKeys.Give` for backends that support removal |
| `bp_lib:group:OwnerChanged` | local | – | Fired by some group backends when ownership migrates |

---

## Configuration reference

`shared/config.lua` selects which implementation is loaded for every module. Keys ↔ modules:

| Config key | Loads `client/<dir>` and `server/<dir>` |
|---|---|
| `Config.Framework` | `framework/` |
| `Config.SQLConnector` | `database/` (server only) |
| `Config.Inventory` (and `InventoryResource`) | `inventory/` |
| `Config.Target` (and `TargetResource`) | `target/` (client only) |
| `Config.ProgessBar` *(sic)* | `progressbar/` (client only) |
| `Config.Menu` | `menu/` (client only) |
| `Config.Input` | `input/` (client only) |
| `Config.TextUI` | `textui/` (client only) |
| `Config.Poly` | `poly/` (client only) |
| `Config.Notifications` | `notifications/` (client only) |
| `Config.WeatherSync` (and `WeatherSyncResource`) | `weathersync/` |
| `Config.Dispatch` | `dispatch/` |
| `Config.Fuel` (and `FuelResource`) | `fuel/` (client only) |
| `Config.VehicleKeys` | `vehiclekeys/` (client only) |
| `Config.Clothing` | `clothing/` (client only) |
| `Config.VehicleProperties` | `vehicleproperties/` (client only) |
| `Config.Logger` | `logger/` (server only) |

Other knobs:

```lua
Config.Debug              = false        -- gates Utils.Print and zone debug rendering
Config.Language           = 'en'         -- locale file picked from locales/<lang>.json
Config.CarryItemsEnabled  = true         -- master switch for the CarryItems subsystem
Config.SkillMenu = {
    Enabled = true,
    Command = 'skills',                  -- false to disable the command
}
Config.Groups = {
    MemberLimit = 4,
    Timeout     = { min = 0, sec = 10 }, -- delay before owner migration after disconnect
    password    = { type = 'number', length = 6 }, -- 'number' | 'char'
}
```

---

## Quick recipes

### Bootstrap (client)

```lua
local Core = exports['bp_lib']:Core()
while not Core.Framework.PlayerLoaded do Wait(100) end

Core.Notify('Welcome', 'You have joined the server', 'success')
```

### Bootstrap (server)

```lua
local Core = exports['bp_lib']:Core()

Core.Framework.RegisterCallback('myresource:fetch', function(src, cb, id)
    cb(Core.Database.FetchSync('SELECT * FROM things WHERE id=?', { id }))
end)
```

### Inventory item with metadata

```lua
local ok = Core.Inventory.AddItem(src, 'phone', 1, { number = '555-0100' })
if not ok then Core.Notify(src, 'Inventory full', '', 'error') end
```

### Group lifecycle

```lua
local g = Core.Groups.Set(src, { name = 'Heist crew' })
local res = Core.Groups.AddMember(otherSrc, g.groupId, g.pass)
if res == 'wrong_pass' then ...
elseif res == 'full' then ...
else ... end
```

### Zone with TextUI prompt

```lua
local zoneId = Core.Poly.AddBoxZone(vector3(100,200,30), 5.0, 3.0, 90.0, function(entering)
    if entering then Core.TextUI.Draw('[E] Open') else Core.TextUI.Stop() end
end)
```
