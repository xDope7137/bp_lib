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
- [Core.Prompt](#coreprompt)
- [Core.ProgressBar](#coreprogressbar)
- [Core.Anim](#coreanim)
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
- [Core.Vehicles (server)](#corevehicles-server)
- [Core.Groups (server)](#coregroups-server)
- [Core.Groups (client)](#coregroups-client)
- [Core.Math (client)](#coremath-client)
- [Core.Utils (shared)](#coreutils-shared)
- [Shared helpers (0.10.0+)](#shared-helpers-0100)
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

**Testing whether a helper exists.** `Core` reaches another resource through exports, so its
functions arrive as callable tables: `type(Core.Inventory.GiveWithMeta) == 'function'` is false
even when the helper is there. Never test the type of a member. Test one of:

- the version: `GetResourceMetadata('bp_lib', 'version', 0)` compared with the version the helper
  came in (each helper below says it, for example `(0.11.0)`);
- the member itself, by value: `if Core.Inventory and Core.Inventory.ItemKnown then ... end`;
- a capability answer where bp_lib gives one: `Core.ItemMetaSupport()` (the inventory name, or
  false plus why).

To call a member that may be missing, use `pcall(Core.X, ...)`; never `type(Core.X) == 'function'`.

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

### `Core.Framework.Name`
The framework found: `'qb'`, `'qbx'`, `'esx'`, `'ox'` or `'tmc'`. The server has no `Framework` field (that is the client's).
When no framework was found, `Core.Framework` itself is nil on the server.

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

### `Core.Framework.Money.Give(player, amount, account, reason?)`
- **account:** `"cash"`, `"bank"`, or `"black_money"` (the latter is wired to the inventory item on qbx).
- **reason** (0.11.0, optional): why the money moved, for example `"Paycheck"`. Qbox and QBCore write
  it in their money log and pass it to their money events; ESX (1.16.3) has no money log and only
  passes it to its events. Left out, they say `unknown`.

### `Core.Framework.Money.Get(player, account)`
Returns the current balance for that account, or `0` for missing items / `nil` for missing players.

### `Core.Framework.Money.Remove(player, amount, account, reason?)`
Same account values and `reason` as `Give`. Returns whatever the underlying framework returns.
On Qbox this does not check the balance first, and Qbox lets bank money go below zero. When the
money must really be there, use `TryRemove`.

### `Core.Framework.Money.TryRemove(player, amount, account, reason?)` (0.11.0)
Takes the money only when all of it is there. Returns `true` only when the money really left the
account: the framework reported this exact remove, or the balance read after is exactly `amount`
lower than the one read before. A `false` means your money was not taken (one exception below).
Otherwise `false` and why:

| Why | Meaning |
|---|---|
| `bad_amount` | `amount` fails `Core.Amount` (not a whole number of at least 1) |
| `no_player` | the player is not online (a citizen id of someone offline also gives this) |
| `bad_account` | the framework does not know that account |
| `insufficient` | the balance is lower than `amount`; nothing was taken |
| `busy` | a `TryRemove` for the same player and account is still running; nothing was taken, try again |
| `refused` | the framework or another script's hook said no, or the framework reported no remove; nothing was taken |
| `error` | the framework call failed before it took anything |
| `mismatch` | only on a framework without money events: the balance changed by some other amount; printed in the console. Most likely nothing was taken, but check the player's money |

What holds, and what cannot:

- Two `TryRemove` calls for the same player and account never overlap: the second answers `busy`.
  On Qbox, a money hook of another resource that waits makes the call wait too; the busy rule is
  what keeps two takes from both reading the old balance.
- When the balance read after the take is below zero (another script removed money while a hook
  waited), the money is put back and the answer is `insufficient`. If it cannot be put back, the
  answer is `true` (the money did leave) and the console says the player is below zero.
- A remove that throws after it subtracted (a logger inside the framework failing) still answers
  `true`: the balance is read again.
- Nothing here can stop another script's plain `RemoveMoney` on the same player from running at the
  same moment; on Qbox that can still take bank money below zero, as it could before.

```lua
local ok, why = Core.Framework.Money.TryRemove(src, 500, 'bank', 'Car repair')
if not ok then return Core.NotifyKey(src, why == 'insufficient' and 'not_enough_money' or 'try_again', 'error') end
```

### `Core.Framework.Money.TryGive(player, amount, account, reason?)` (0.11.0)
Gives `amount` and tells you whether it arrived. `true` when the framework reported this exact add
(the call's own money event) or `Give` answered `true`. It never decides from the balance: another
script that takes money inside the money event (a loan repayment, a tax on every credit) makes the
balance rise by less than `amount` although the money arrived. Otherwise `false` and why:

| Why | Meaning |
|---|---|
| `bad_amount` | `amount` fails `Core.Amount` |
| `no_player` | the player is not online |
| `bad_account` | the framework does not know that account |
| `refused` | the framework or a hook said no; the balance did not move |
| `error` | the framework call failed before anything moved |
| `unknown` | the balance moved but nothing says this add happened; printed in the console. Never pay it again and never refund the sender: leave it for a person |

On a framework without money events, a rise of exactly `amount` counts as given.

```lua
local ok, why = Core.Framework.Money.TryGive(src, 500, 'bank', 'Transfer received')
if not ok and why == 'unknown' then -- keep the record for staff, move nothing else
end
```

### `Core.Framework.OnMoneyChange(cb)` (0.11.0)
Calls `cb(change)` after every money change the framework reports, from any script. Returns an id
for `OffMoneyChange`, or `false, 'unsupported'` on a framework without money events. Listeners are
dropped when the script that added them stops. `change` has the same shape on every framework:

| Field | Value |
|---|---|
| `source` | the player's server id |
| `citizenid` | the character id (`Core.Identifier`) |
| `account` | `'cash'`, `'bank'`, or another account name. ESX's `money` account is reported as `'cash'` |
| `action` | `'add'`, `'remove'` or `'set'` |
| `amount` | how much was added or removed. `nil` for `'set'` |
| `delta` | the signed change: `+amount` for add, `-amount` for remove. `nil` for `'set'` |
| `balance` | the balance right after the change, read from the framework when the event fired. For `'set'` it is the new total the framework reported |
| `reason` | the reason given to the framework, or `nil` when none was given (the frameworks' own `unknown`) |
| `by` | the script that made the change through bp_lib's `Money.Give`, `Remove` or `TryRemove`; `nil` when another script changed the money directly. One bp_lib call names one event: the one with the same player, account, direction and amount. A change some other code makes while the call runs (a hook, a handler of the money event) is not named. Two identical changes at the same moment may swap names; the count stays right |
| `framework` | `'qbx'`, `'qb'` or `'esx'` |
| `sync` | `true` on the ESX with ox_inventory `set` described below, else `nil` |
| `inferred` | `nil`, or how a missing reason was worked out: `'job_payment'` on Qbox (below) |

What each framework reports:

- **Qbox paychecks have no reason.** qbx_core's default `sendPaycheck` (`config/server.lua`) calls
  `AddMoney('bank', payment)` without one. A bank credit with no reason, not made through bp_lib,
  whose amount is exactly the character's job payment (the grade's payment, else `job.payment`, as
  qbx_core's own `pay()` reads it) is reported with `reason = 'paycheck'` and `inferred = 'job_payment'`.
  Another credit of the same amount with no reason would be named a paycheck too; the `inferred`
  field lets a script ignore the guess. Owners who want a real reason add `'Paycheck'` as the third
  argument in `sendPaycheck`. QBCore and ESX pass a reason themselves.
- **Qbox and QBCore** fire `QBCore:Server:OnMoneyChange` for players who are online. A change made to
  an offline character (an `AddMoney` by citizen id) fires nothing, so `cb` never hears of it. For a
  `set` they report only the new total, so the size of the change is not known.
- **ESX** fires `esx:addAccountMoney`, `esx:removeAccountMoney` and `esx:setAccountMoney` (checked on
  es_extended 1.16.3; older ESX builds may not fire them). ESX has no offline characters to change.
- **ESX with ox_inventory** keeps cash as the `money` item. A cash change through
  `addAccountMoney`/`removeAccountMoney` (bp_lib's `Give`/`Remove` too) arrives twice: first a `set`
  with the new total, reason "Sync account with item", marked `sync = true`, then the `add` or
  `remove`. A script that changes the `money` item directly produces only the `sync` set. To count a
  cash change once: on a `sync` set, take the change as the new total minus the last total you knew
  and remember the new total; then skip an `add` or `remove` whose `balance` equals the total you
  already have. Bank money is not an item and arrives once.

The callback runs inside the framework's money call: keep it short and never wait in it (queue the
work and write it from your own thread). Use `by` to skip your own changes.

```lua
Core.Framework.OnMoneyChange(function(change)
    if change.by == GetCurrentResourceName() or change.account ~= 'bank' then return end
    queue[#queue + 1] = change   -- written to the database every few seconds
end)
```

### `Core.Framework.OffMoneyChange(id)` (0.11.0)
Stops a listener. `true` when there was one.

### `Core.Framework.OnCharacter(cb)` (0.11.0)
Calls `cb(ev)` when a character finished loading and when it left. Returns an id for `OffCharacter`,
or `false, 'unsupported'` on a framework module without character events (ox, tmc), or
`false, 'bad_callback'`. Listeners are dropped when the script that added them stops; a listener
that throws is reported in the console and never stops the others. `ev` has the same shape on
every framework:

| Field | Value |
|---|---|
| `event` | `'loaded'` or `'left'` |
| `source` | the player's server id |
| `citizenid` | the character id (`Core.Identifier`); on `'left'` the character that left, even when the framework has already forgotten the player |
| `reason` | on `'left'`: `'logout'` (logout or back to the character menu), `'drop'` (disconnect), `'switch'` (a new character loaded on the same player id with no left before it). `nil` on `'loaded'` |
| `framework` | `'qbx'`, `'qb'` or `'esx'` |

Every `'loaded'` is followed by exactly one `'left'` for that character; the same character announced
twice is one `'loaded'`.

What each framework fires (read from their source: qbx_core 1.22.4, qb-core main, es_extended main):

- **Qbox**: `QBCore:Server:PlayerLoaded(player)` at the end of `CreatePlayer` (login, and a character
  switch from the menu); `QBCore:Server:OnPlayerUnload(source)` in `Logout`, while the player still
  exists. A **disconnect fires no event**: qbx_core's `playerDropped` saves and forgets the player.
  bp_lib answers the disconnect from its own `playerDropped` handler with the character it kept, so
  the framework can no longer give its money at that moment.
- **QBCore**: the same `QBCore:Server:PlayerLoaded(player)`; `QBCore:Server:OnPlayerUnload(source)` in
  `Logout`; on a disconnect `QBCore:Server:PlayerDropped(source)` then `OnPlayerUnload(source)`, after
  its save and before it forgets the player (one `'left'`, reason `'drop'`).
- **ESX**: `esx:playerLoaded(playerId, xPlayer, isNew)`; `esx:playerDropped(playerId, reason)` on a
  disconnect and on a logout (`esx:playerLogout`, reason `esx_player_logout` = `'logout'`), before
  its final save, while the xPlayer still exists.

**A restart sends nothing.** When your script (re)starts with players already in, no `'loaded'`
comes for them. Catch up once after registering:

```lua
local function load(src, cid) --[[ read what you keep for an online character ]] end
Core.Framework.OnCharacter(function(ev)
    if ev.event == 'loaded' then CreateThread(function() load(ev.source, ev.citizenid) end)
    else forget(ev.source, ev.citizenid) end
end)
for _, c in ipairs(Core.Framework.OnlineCharacters() or {}) do load(c.source, c.citizenid) end
```

A restart of bp_lib itself keeps track: it reads the characters already in when it starts, so their
`'left'` still arrives. (Restarting bp_lib also stops every script that depends on it.)

The callback runs inside the framework's event: never wait in it, start a thread for database work.

### `Core.Framework.OffCharacter(id)` (0.11.0)
Stops a listener. `true` when there was one.

### `Core.Framework.OnlineCharacters()` (0.11.0)
Every character in right now, `{ { source, citizenid }, ... }` sorted by player id. Players still in
the character menu are left out. `false, 'unsupported'` where `OnCharacter` is unsupported.

### `Core.Framework.Condition(src)` (0.11.0)
Server side: is this player dead, in last stand, or restrained right now?

```lua
local c = Core.Framework.Condition(src)
-- { dead = false, lastStand = false, cuffed = true, from = { cuffed = 'state:cuffed' } }
if not c or c.dead or c.lastStand or c.cuffed then return end
```

`nil, 'no_player'` for an id with no ped. `from` names where each true answer was read. Read in this order:

| Source | Qbox | QBCore | ESX |
|---|---|---|---|
| Framework fields | metadata `isdead`, `inlaststand`, `ishandcuffed` (qbx_core defaults; medical and police scripts set them with `SetMetaData`) | the same metadata (qb-ambulancejob, qb-policejob) | none: esx_ambulancejob writes `users.is_dead`, esx_policejob keeps cuffs on the client |
| Player state bag (`Player(src).state`) and ped state bag (`Entity(ped).state`) | dead `isDead`, `dead`; last stand `inLastStand`, `isInLastStand`, `laststand`, `inlaststand`; cuffed `cuffed`, `isCuffed`, `handcuffed`, `isHandcuffed` | the same | the same |
| Ped health | below 100 is dead (GTA counts 100 as zero health) | the same | the same |

What it cannot know: a state a script keeps only on the client (esx_policejob and qb-policejob keep
"cuffed" in a client variable unless the framework metadata is set), or a state bag under another
key. Add such keys to `CONDITION_KEYS` in `server/extras.lua`. A player in last stand who was
revived by a script that sets none of these reads as fine.

### `Core.Framework.SavePlayer(src)` (0.11.0)
Asks the framework to write the player's row to the database now, for example right after money
moved between two players. Qbox: `exports.qbx_core:Save`. QBCore: `Player.Functions.Save()`. ESX: the
`SavePlayer` export of es_extended. The framework finishes the write a moment later in its own
thread. Returns `true` when asked, `false` when the player is not loaded or the framework cannot.

### `Core.Framework.SaveMoney(src)` (0.11.0)
Writes the player's money to the framework's own row now and waits for the write. It uses the same
column and encoding as the framework's own save: `players.money` by citizenid on Qbox and QBCore,
`users.accounts` by identifier on ESX. Use it when your script's own write must not land on disk
before the player's money does. It does not replace `SavePlayer`: call that too for the rest of the
row.

The first call checks that the table and both columns exist, and that a stored value has the shape
it would write. If that check fails, or the connector is not oxmysql, it only asks the framework to
save, as `SavePlayer` does. Returns `true, 'direct'` (on disk), `true, 'asked'` (the framework was
asked, not waited for), or `false` (the player is not loaded).

### `Core.Framework.MoneySaveMode()` (0.11.0)
Returns which way `SaveMoney` works on this server: `'direct'`, or `'asked'` plus the reason.
Print it in your doctor or start-up line.

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

### `Core.Framework.JobOf(src)` (0.12.0)
The player's active job from the framework's memory (no query): `{ name, label, grade, gradeLabel,
boss, bankAuth, onDuty }` or `nil`. `grade` is the grade number; `boss` is the framework's boss grade
(QBCore and Qbox `isboss`, ESX the grade named `boss`); `bankAuth` is QBCore and Qbox `bankAuth` (a boss
always has it); `onDuty` is nil where the framework keeps no duty (base ESX). Only the active job: Qbox's
other job slots give nothing until made active. Read it on every call where access depends on it.

### `Core.Framework.GangOf(src)` (0.12.0)
The same shape for the player's gang (QBCore and Qbox; always `nil` on ESX). `Core.Framework.HasGangs()`
says whether the framework has gangs.

### `Core.Framework.OnJob(cb)` / `OffJob(id)` (0.12.0)
`cb({ source, citizenid, kind = 'job' | 'gang', name, grade })` after a job or gang change (QBCore and
Qbox `OnJobUpdate` / `OnGangUpdate`, Qbox `qbx_core:server:onGroupUpdate`, ESX `esx:setJob`). Use it
for lists and page pushes only, never for access: read `JobOf` again. Returns an id, or false plus
`'unsupported'` / `'bad_callback'`.

### `Core.Framework.JobList(kind)` (0.12.0)
Every job (`'job'`) or gang (`'gang'`) the framework knows: `{ [name] = { label, grades = { [level] =
{ label, boss, bankAuth } } } }`, or `nil`. Memory only.

### `Core.Framework.PaycheckSociety()` (0.12.0)
`true` when paychecks come out of the job's society account (QBCore `Config.Money.PayCheckSociety`,
Qbox `money.paycheckSociety`), `false` when not, `nil` when unknown (ESX).

### `Core.Framework.CharactersWithJob(cids, name, kind?)` (0.12.0)
Which of these characters (at most 10 citizen ids) hold the job (or gang) `name` in any slot, online or
not: a list of citizen ids, one query (Qbox `player_groups`, QBCore the `players` JSON, ESX `users.job`).
False plus `'unsupported'` / `'invalid'` / `'failed'`. For paced staff checks, not for every request.

### `Core.Framework.Vehicles.SetPlate(identifier, oldPlate, newPlate)`
Qbox, QBCore, ESX. Moves an owned vehicle's plate in the framework's vehicles table (`player_vehicles` /
`owned_vehicles`, the plate column and the plate inside the mods / props JSON). Returns the affected rows.
Since 0.15.0 a change that touched a row (affected rows > 0) fires the server event
`bp_lib:plateChanged` once, after the write returned (see [Events](#events)). A failed or empty change
fires nothing. Only this framework table is written: every other table keyed by plate belongs to its
script, which moves its own rows when it hears the event.

```lua
-- in your script: move your own rows when a plate changes
AddEventHandler('bp_lib:plateChanged', function(oldPlate, newPlate, identifier)
    MySQL.update.await('UPDATE my_table SET plate = ? WHERE plate = ?', { newPlate, oldPlate })
end)
```

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

### `Core.Inventory.ItemKnown(item)` (0.11.0)
Whether the inventory defines `item`, read only: `true` or `false`, or `nil` plus `'bad_item'`,
`'unsupported_inventory'` (no adapter for this inventory: nothing can be known) or `'failed'`.
Asks ox_inventory `Items(item)`, qs-inventory `GetItemList()`, qb-inventory `QBCore.Shared.Items`.

```lua
if Core.Inventory.ItemKnown('bank_card') == false then print('add bank_card to your inventory items') end
```

### `Core.Inventory.GiveWithMeta(source, item, metadata, reason?)` (0.11.0)
Gives one `item` that carries `metadata` (for example a card: `{ card = 12, last4 = '4821' }`).
Works on ox_inventory, qb-inventory and qs-inventory. Returns `true`, or `false` and why:
`cannot_carry`, `not_unique` (qb-inventory: the item must be `unique = true` in your items list,
otherwise qb-inventory stacks it with an item of the same name and drops its metadata),
`unknown_item`, `bad_metadata`, `no_player`, `unsupported_inventory`, `failed`.

### `Core.Inventory.FindWithMeta(source, item, match?)` (0.11.0)
Every slot of `item` whose metadata has each key and value of `match` (every slot of that item
when `match` is empty): `{ { slot, count, metadata }, ... }`, by slot. `nil` and why when it cannot
look.

### `Core.Inventory.RemoveWithMeta(source, item, match, count?)` (0.11.0)
Removes `count` (1) from the first slot whose metadata matches. `match` may not be empty, so
another item of the same name is never taken by mistake. Returns `true`, or `false` and why:
`not_found`, `not_enough`, `bad_match`, `bad_count`, `unsupported_inventory`, `failed`.

```lua
local ok, why = Core.Inventory.GiveWithMeta(src, 'bank_card', { card = card.id, last4 = card.last4 })
local held = Core.Inventory.FindWithMeta(src, 'bank_card', { card = card.id })
Core.Inventory.RemoveWithMeta(src, 'bank_card', { card = card.id })
```

### `Core.Inventory.OnUseWithMeta(item, fn)` (0.13.0)
Calls `fn(source, metadata, slot)` when a player uses one `item`, with that item's own metadata:
`item.metadata` on ox_inventory, `item.info` on qb-inventory, qb-inventory-new and qs-inventory.
`metadata` is always a table (empty when the item has none). `fn` runs in `pcall`, so an error in
it is printed and never breaks the inventory. It registers through `RegisterUsableItem` below.
Returns `true`, or `false` and why: `bad_item`, `unsupported_inventory` (any other inventory),
`failed`. There is no Off (frameworks cannot unregister a usable item): register once, at start.

```lua
Core.Inventory.OnUseWithMeta('bank_statement', function(src, meta, slot)
    if type(meta.statement) == 'string' then TriggerClientEvent('my_script:paper', src, meta.statement) end
end)
```

### `Core.ItemMetaSupport()` (0.11.0, server)
The inventory's name when the three functions above work on this server. Otherwise `false` and
`'no_inventory'` (no inventory found, `Core.Inventory` is `nil`) or `'unsupported_inventory'`.

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

`Core.Target` is client only. On the server, `Core.TargetScript()` (0.14.0) says which of the three
runs, so a script can refuse a "target only" setting on a server that has none:

```lua
local name, folder = Core.TargetScript()   -- 'ox_target', 'ox_target'  or nil
if not name then print('no target script is running') end
```

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

### `Core.Target.RemoveModel(models, names)` (0.11.0)
Takes the caller's own options off these models (a model name, a hash, or a list). `names`: one
option name, a list of names, or `nil` for every option the caller added to them. Returns how many
came off, and a list of labels left on (below). An option added without a `name` is named after its
label. bp_lib registers every model option with the target resource under its own name, so it keeps
track of which script added which option.

- **ox_target:** bp_lib sends each name as `<resource>:<name>`, so two scripts can use the same
  option name on the same model without one replacing or removing the other. These options also
  come off by themselves when the script that added them stops. A `canInteract(entity, distance,
  coords, name)` sees the prefixed name.
- **qb-target and qtarget:** they key a model's options by label and remove by label. The same
  label on the same model from two scripts already replaces the first when the second is added
  (the target resource does that). There is no automatic removal, and `RemoveModel` leaves a label
  another script still has on that model (it is in the second return value). Call `RemoveModel`
  from your own `onResourceStop`.

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

## Core.Prompt

Source: `client/prompt/` (`anchor.lua`, `draw.lua`, `main.lua`). Client only. Since 0.15.0.

A "press E" prompt that sits on a bone of a vehicle (a wheel, the petrol cap, the engine) or at a place. bp_lib finds the exact point every frame, picks the one prompt that is live, draws it, reads the key and calls your script once.

Older bp_lib: test with `if Core.Prompt ~= nil then`, or `(Core.HelpersVersion or 0) >= 3` on the client.

### The look and the server settings

The server owner sets these in `shared/config.lua`:

| Key | Default | Meaning |
|---|---|---|
| `Config.Prompt` | `'3d'` | `'3d'`: the key and the label are drawn in the world, on the point itself. `'textui'`: the server's own text box (`Config.TextUI`) shows `[E] label`, and a small mark is drawn at the point. With no text box loaded, `'textui'` falls back to `'3d'`. |
| `Config.PromptMark` | `true` | A small mark at each prompt that is in sight but not live (both looks). `false` turns the marks off. |
| `Config.PromptKeys` | `{ 'E', 'G' }` | The default keys of the two prompt keys. Players can rebind both in the game's key settings (FiveM section). |
| `Config.PromptStyle` | see the file | The `3d` look: `scale` (0.34), `font` (4), and the colours `key`, `keyBack`, `text`, `back`, `mark`, `fill` as `{ r, g, b }`, plus `backAlpha` (170) and `markSize` (0.0045, a share of the screen width). |

The text box is shared with other scripts. A text another script shows through bp_lib's `Core.TextUI.Draw` is never covered or hidden by a prompt. While it is on the box, the live prompt is drawn in 3D instead, and it moves back to the box when the box is free. A box another script opens directly through its text box resource (for example `lib.showTextUI` of ox_lib, or the export of ps-ui, okokTextUI, jg-textui or qb-core) cannot be seen by bp_lib. A live `textui` prompt may replace that text, and when the prompt goes it hides the box. Scripts that show their own text next to prompts should draw it with `Core.TextUI.Draw`, or the server should use the `3d` look.

The 3D look keeps one size on screen at any distance. At most 24 prompts are in play at once (the nearest), because the game allows 32 drawn points per frame for the whole client.

### `Core.Prompt.Add(options)` (0.15.0)

Returns the prompt's id, or `nil` and a reason: `bad_anchor` (options not a table, or a `netId` that is not a number), `no_entity` (no `coords`, and `entity` does not exist), `no_bone` (`strict` only).

```lua
local id = Core.Prompt.Add({
    entity = vehicle,
    wheel = 'lf',
    face = 'out',
    label = 'Remove wheel',
    onPress = function(id, info)
        -- info.entity, info.bone, info.source, info.coords
    end,
})
```

Where it sits (give `coords`, or `entity`, or `netId`):

| Field | Meaning |
|---|---|
| `coords` | A fixed place: a vector3, `{ x =, y =, z = }` or `{ x, y, z }`. |
| `entity` | An entity handle. The prompt is removed when the entity is gone. |
| `netId` | A network id instead of a handle. The prompt waits while the entity is not streamed in and comes back with it. |
| `bone` | A bone name, or a list tried in order: `{ 'petrolcap', 'petroltank' }`. |
| `wheel` | A wheel by short name: `lf`, `rf`, `lr`, `rr`, `lm1`, `rm1`, `lm2`, `rm2`, `lm3`, `rm3` (`lm` and `rm` are `lm1` and `rm1`), `f`, `r`. Bikes and bicycles have `lf` (front) and `lr` (rear); `f` and `r` find the same two. A trailer has no front wheels. Any other text is used as a bone name. `wheel` wins over `bone`. |
| `face` | `'out'` puts a wheel prompt on the outer face of the tyre instead of the hub centre. It turns with the steering. A wheel on the centre line (bikes) stays at the hub. |
| `offset` | Metres from the point, along the entity's own axes: x right, y forward, z up. It turns with the car. |
| `fallback` | An entity offset used when the bone does not exist or reads the car's origin. |
| `strict` | `true`: return `nil, 'no_bone'` when no bone of the list exists, instead of the fallback or the box point. Checked once, in `Add`. |

When a bone is missing and there is no `fallback`, the prompt sits at a point on the model's box: the corner where that wheel would be, the front end for `bonnet`, `engine` and headlights, the rear end for `boot`, exhausts and taillights. A bone that reads the car's own origin counts as missing. A wheel or a door that broke off keeps the prompt where it was. An addon car whose modeller left a bone at the origin gets the fallback or the box point.

How exact it is:

- The point is the bone's position read in the frame it is drawn in, plus `offset` in the car's own axes. On a car this client drives, or one that stands still, the prompt sits on the bone in every frame: measured parked, on a slope, on its side and up to 120 km/h.
- A car driven by another player was not measured.
- `face = 'out'`: the game gives no tyre width, so bp_lib works the face out from the rim size. It was within about 1 cm of the real tyre face on a stock car, and about 3 cm too far out on an addon car with wide tyres.
- An addon car whose modeller put a bone in the wrong place shows the prompt at that wrong place. `setr bp_prompt_debug 2` shows every point (see `Debug`).

What it says and when:

| Field | Default | Meaning |
|---|---|---|
| `label` | `''` | The words after the key. |
| `key` | `'E'` | `'E'` for the first prompt key, `'G'` for the second. Players can rebind both, and the prompt shows their real key. |
| `hold` | `0` | Milliseconds the key must be held. 0 is a tap. While held, the key cap fills up. Letting go early cancels. |
| `showDistance` | `6.0` | The small mark appears within this many metres. Never less than `useDistance`. |
| `useDistance` | `1.5` | The key works within this many metres, player to point. |
| `onFoot` | `true` | Hidden while the player sits in a vehicle. A prompt with `onFoot = false` that is live in a vehicle keeps E from sounding the horn. |
| `sight` | `false` | `true`: hidden when something blocks the view from the camera to the point. The prompt's own entity does not count. Checked about 4 times a second. |
| `enabled` | `true` | `false` hides it without removing it. |
| `priority` | `0` | The higher one wins when two prompts are in reach. |
| `mode` | server setting | `'3d'` or `'textui'` to force a look for this prompt. |

Callbacks. None of them is called per frame. Each runs in its own thread, so it may wait. An error in one is caught (printed when `Config.Debug` is on):

| Field | Called |
|---|---|
| `onPress(id, info)` | Once per press. `info` holds `entity`, `bone`, `source` and `coords`. Before it fires, bp_lib checks again that the prompt is enabled and the player is within `useDistance`. A second press within 300 ms does nothing. |
| `onShow(id)` | When this prompt becomes the live one. |
| `onHide(id, why)` | When it stops being live. `why`: `far`, `sight`, `vehicle`, `gone`, `disabled`, `removed`, `busy` (pause menu or a focused NUI), `other` (another prompt took over). |

There is no `canInteract` callback. Flip `enabled` with `Update` when your own state changes.

Only one prompt is live on the whole client, across every script. Within `useDistance` the highest `priority` wins, then the nearest. The live prompt keeps its place until another is clearly nearer for a moment, so it does not flicker between two wheels. A press does nothing while the pause menu is open or a NUI has focus.

The keys: two key mappings, `+bp_prompt` (default E) and `+bp_prompt_alt` (default G). They are registered when the first prompt is added, so a server whose scripts add none gets no new entries in the key settings. The label is the player's bound key, also after a rebind (F1 to F12 included). On a controller the pickup and detonate controls stand in. A rebind and a controller were not tested in the game.

### `Core.Prompt.Update(id, fields)` (0.15.0)

Changes any `Add` field except the callbacks, `netId` and `strict`. Giving `coords` or `entity` drops the `netId`. Returns `true`, or `false` and a reason (`no_prompt`, `not_owner`, `bad_anchor`, `no_entity`). Only the script that added a prompt can change it.

```lua
Core.Prompt.Update(id, { label = 'Fit wheel' })
Core.Prompt.Update(id, { enabled = false })
```

### `Core.Prompt.Remove(id)` / `Core.Prompt.RemoveAll()` (0.15.0)

`Remove` takes one prompt of the calling script off and returns `true`, or `false` and `no_prompt` / `not_owner`. `RemoveAll` takes all of the calling script's prompts off and returns how many. A live prompt that is removed gets `onHide(id, 'removed')`. When a script stops, bp_lib removes its prompts by itself and calls nothing of it again.

### `Core.Prompt.Wheels(vehicle)` (0.15.0)

The wheels of a vehicle, read from its bones, front axle first and left before right. Works for cars, 6-wheel trucks, trailers and bikes. An empty list when the vehicle does not exist.

```lua
for _, w in ipairs(Core.Prompt.Wheels(vehicle)) do
    -- w.name ('lf'), w.bone ('wheel_lf'), w.side ('left', 'right', 'centre'), w.axle (1 = front),
    -- w.tyre (the number the tyre natives use), w.wheelIndex (the number the wheel natives use, or nil),
    -- w.offset ({ x, y, z } in the vehicle's axes), w.broken (true when the wheel came off)
    Core.Prompt.Add({ entity = vehicle, wheel = w.name, face = 'out', label = 'Check tyre' })
end
```

`wheelIndex` is nil when the car's own wheel list does not match its wheel bones. `tyre` is nil for `lm3` and `rm3`; for `lm2` and `rm2` it comes from the native docs, since no tested model has those wheels.

### `Core.Prompt.Point(spec)` (0.15.0)

The world point of an anchor right now, with no prompt. Takes the same "where it sits" fields as `Add`, `netId` included. Returns a vector3 and the source (`bone`, `kept`, `fallback`, `box`, `entity`, `coords`), or `nil` and a reason (`bad_anchor`, `no_entity`, `gone`). Use it to walk a ped to a wheel or to place a prop there.

### `Core.Prompt.Debug()` (0.15.0)

For tests. Returns `nil` unless the server has `setr bp_prompt_debug 1`. With it, a list with one row per prompt: `id`, `owner`, `label`, `key`, `mode`, `look` (what the live prompt is drawn as right now), `entity`, `bone`, `source`, `x`, `y`, `z`, `frame` (the game frame the point was worked out in), `dist`, `shown`, `cand`, `why` (only while hidden), `ms` (see `Cost`). `setr bp_prompt_debug 2` also draws a magenta dot on every point, so a server owner can see where each prompt sits on an addon car.

### `Core.Prompt.Cost()` (0.15.0)

For tests. Returns `nil` unless `bp_prompt_debug` is 1 or more. With it: `{ ms, frames, clock, prompts }`, the module's own time per game frame averaged over the last frames (up to 300), and the timer it used. The FiveM client Lua has no clock finer than a frame, so in the game `clock` is `'none'` and `ms` is `nil`. Use `resmon` to see the cost by eye. Nothing is timed while the convar is 0.

`Used by:` none yet.

---

## Core.ProgressBar

`Core.ProgressBar` is a function. `Core.Progress` (0.15.0) holds it as `Run` plus `Cancel` and `Active`.

Source: `client/progress/main.lua`; the bar itself: `client/progressbar/<system>.lua`.

The bar is drawn by `Config.ProgessBar`: bp_lib's own (`'bp'`, what `'auto'` picks since 0.15.0) or your
server's (`ox_lib`, `qb`, `progressbar`, `mythic_progbar`, `esx`, `lation_ui`, `tgiann`, `tmc`). Whatever
draws the bar, bp_lib does the rest itself (0.15.0): it plays the animation and props through
[Core.Anim](#coreanim), blocks the controls, ends the bar when the player dies, ragdolls, falls, swims or
is cuffed, and cleans the animation and props up after. The other script never gets the animation.

### `Core.ProgressBar(label, time, options)`
- **time:** duration in ms.
- **options:**
  - `canCancel`, `useWhileDead`, `allowRagdoll`, `allowFalling`, `allowSwimming`, `allowCuffed` (booleans)
  - `disable = { move, car, combat, mouse, sprint }` (0.15.0), or the older `disableMovement`,
    `disableCarMovement`, `disableMouse`, `disableCombat`
  - `anim` (0.15.0): a [Core.Anim](#coreanim) spec (`dict` + `clip`, or `scenario`), or the older
    `animation = { animDict, anim, flags }`
  - `scenario` (0.15.0): a scenario name, the same as `anim = { scenario = ... }`
  - `props` / `prop` (0.15.0): props in the hands while the bar runs (see Core.Anim)
- **Returns:** `true` when it ran to the end, `false` when cancelled, interrupted, or another bar was
  already running. Blocks the calling thread.

```lua
local ok = Core.ProgressBar('Picking lock', 5000, {
    canCancel = true,
    disable = { move = true, combat = true },
    anim = { dict = 'mp_common', clip = 'givetake1_a', flag = 49 },
})
if not ok then return end
```

### `Core.Progress.Cancel()` / `Core.Progress.Active()` (0.15.0)
`Cancel` ends the running bar as cancelled (its call returns `false`) -> `true` when one ran.
`Active` -> `true` while a bar runs.

bp_lib's own bar: look in `Config.ProgressStyle`, cancel key `Config.ProgressCancelKey` (default `X`,
players can rebind it in the FiveM key settings as "Cancel action (progress bar)").

`Used by:` `bp_apartments`, `bp_cookies`, `bp_mechanic`.

---

## Core.Anim

(0.15.0) Animations, scenarios and props in the hands, started and cleaned up by bp_lib.

Source: `client/anim/main.lua`.

### `Core.Anim.Play(spec)` -> `id` or `nil, reason`
Never waits: the dictionary and the prop models load in a bp_lib thread, and a handle stopped before
that is never played. Reasons: `bad_anim`, `no_ped`, `no_dict`, `no_model`.

| Field | Default | Meaning |
|---|---|---|
| `dict`, `clip` | | animation dictionary and clip (`animDict`, `anim` are read too) |
| `flag` | `49` | TaskPlayAnim flag (`flags` is read too) |
| `blendIn`, `blendOut`, `duration`, `rate` | `3.0`, `1.0`, `-1`, `0.0` | TaskPlayAnim values |
| `lockX`, `lockY`, `lockZ` | `false` | |
| `scenario` | | a scenario instead of `dict` (`enter = false` skips its enter animation) |
| `props` / `prop` | | `{ model, bone = 60309, pos = vec3, rot = vec3, rotOrder = 2 }`, one or a list |
| `ped` | the player | |
| `keep` | `false` | play it again when something else cleared it (not while ragdolled, falling or in a vehicle) |
| `time` | | ms, then it ends by itself |
| `network` | `true` | props networked (others see them) |

One animation task per ped: a newer `Play` on the same ped takes it over, and stopping the older
handle then only removes the older props. A handle ends by itself when its ped dies or is gone, and
when the script that made it stops (everything is cleaned: task, props, dictionary).

### `Core.Anim.Stop(id, now)` -> `true` or `false, 'no_anim' / 'not_owner'`
Ends the task (blending out; `now = true` snaps) and deletes the props. Only the script that made it.

### `Core.Anim.StopAll(now)` -> count
Every handle of the calling script.

### `Core.Anim.Active(id)`, `Core.Anim.Playing(id)`, `Core.Anim.Props(id)`
Handle alive / its animation on the ped right now / its prop entities.

```lua
local id = Core.Anim.Play({ dict = 'anim@heists@box_carry@', clip = 'idle', flag = 49,
    props = { { model = 'prop_car_battery_01', bone = 28422, pos = vec3(0.0, -0.1, -0.25) } } })
-- ...
Core.Anim.Stop(id)
```

`Used by:` `bp_mechanic`.

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
With `ox_fuel` and `tmc` it sets the game's fuel level and the replicated `fuel` state bag, as
ox_fuel does itself (0 to 100). The bag replicates only from the client that owns the vehicle, so
call it after you spawned the vehicle or took network control of it. Test: `tests/fuel.py`.

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

### `Core.Database.Transaction(queries)` (0.11.0)
Runs every query in one database transaction: all of them happen, or none. Waits for the answer,
so call it from a thread. Each query is `{ query = 'SQL', params = { ... }, expect = n }` (or
`{ 'SQL', { ... } }`). With `expect`, the query must touch exactly `n` rows (rows it matched for
an `UPDATE`), or the whole transaction is rolled back. That makes a guarded balance change safe:

```lua
local ok = Core.Database.Transaction({
    { query = 'UPDATE accounts SET balance = balance - ? WHERE id = ? AND balance >= ?', params = { 50, from, 50 }, expect = 1 },
    { query = 'UPDATE accounts SET balance = balance + ? WHERE id = ?', params = { 50, to }, expect = 1 },
    { query = 'INSERT INTO history (account, amount) VALUES (?, ?), (?, ?)', params = { from, -50, to, 50 } },
})
```

Returns `true` when committed, else `false` and `'failed'` (rolled back; oxmysql prints the reason
in the console), `'invalid'` or `'unsupported'`. Needs oxmysql. A transaction with `expect` holds at
most 99 statements, counting one extra check statement per `expect`. Parameters follow the usual
oxmysql rules (no `nil` in the middle of a parameter list).

### `Core.Database.BatchInsert(table, columns, rows, options?)` (0.11.0)
Writes many rows with one `INSERT` statement and returns the number of affected rows, or `false`
and `'invalid'` / `'too_many'` / `'failed'`. Waits for the answer.

- `rows`: a list of rows, each a list in column order or a table keyed by column name. A missing
  value is written as `NULL`.
- `options.ignore = true`: `INSERT IGNORE`.
- `options.update = { column = 'add' | 'set' | 'max' }`: adds `ON DUPLICATE KEY UPDATE`; `add` adds
  the new value to the stored one, `set` replaces it, `max` keeps the larger. On MySQL 8.0.19 and
  later the statement uses the row alias (`AS new ... new.column`), elsewhere `VALUES(column)`
  (MariaDB has no row alias; MySQL warns that `VALUES()` is deprecated). The server version is read
  once, on the first upsert.
- Table and column names may only hold letters, digits and `_`. Values must be numbers, strings or
  booleans. At most 65,535 values per call.

```lua
Core.Database.BatchInsert('daily_totals', { 'account_id', 'day', 'money_in', 'n' },
    { { 7, 20410, 500, 1 }, { 9, 20410, 75, 3 } },
    { update = { money_in = 'add', n = 'add' } })
```

---

## Core.Logs (server)

Source: `server/logger/<system>.lua` (`discord`, `ox_lib`).

`Config.Logger = 'auto'` (0.14.0): a log type with a Discord webhook filled in `shared/discordLogs.lua`
(its own line, or `others`) is sent to Discord; every other type goes to ox_lib's logger when ox_lib
runs. Before 0.14.0 `'auto'` always took ox_lib's logger when ox_lib ran and the webhooks were ignored.
The sample line (`'your_log_webhook_url'`) is not a webhook. `Config.Logger = 'discord'` or `'ox_lib'`
set by hand is used as written.

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

These functions are sugar over server callbacks (`bp_lib:CreateEntity`, `:CreatePed`, `:CreateVehicle`).

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

- `bp_lib:CreateEntity`
- `bp_lib:CreatePed`
- `bp_lib:CreateVehicle`

---

## Core.Vehicles (server)

Source: `server/vehicleIndex/main.lua`. An index of every vehicle on the server, kept up to date by `entityCreated` / `entityRemoved`. Use it instead of looping over `GetAllVehicles()` and reading every car. Test: `tests/vehicle_index.py`. Measure on a live server: `bp_vehicles` (what it costs now) and `bp_vehicles bench` (against a loop).

What it costs to keep running:
- Nothing until a script asks its first question: the index is built then, and thrown away again after 15 minutes without a question.
- A background sweeper re-reads a slice of the list every 250 ms (a full pass takes about 8 s). A slice is never more than 150 cars, so the cost has a ceiling; past 4800 cars the pass gets longer instead. It sleeps after two minutes without a question.
- 0.3 to 0.8 KB of memory per vehicle (0.74 KB measured on the dev server; `bp_vehicles` shows the live figure).
- FXServer does not announce a car made with `CreateVehicleServerSetter`, so the index calls `GetAllVehicles()` to catch those: once per sweeper pass and at most once a second on a miss or a spot check (always for `maxAge = 0` and `Unread`). Nothing is read per car there. If your script spawns on the server, call `Core.Vehicles.Add(entity)` so the car is known at once; without it, a spot check can miss it for up to a second.

What it saves: a plate that is out is one lookup. A plate that is missing is cheap when you pass the car's model (only the cars of that model are re-read, even with `maxAge = 0`). Without a model, a miss re-reads the cars with no plate yet and the cars younger than 30 s, and `maxAge = 0` re-reads every plate.

Measured on the dev server with 316 vehicles (250 plated cars from `player_vehicles` spawned around a player, plus traffic), against a `GetAllVehicles()` loop: car is out 99% less time, car is gone with the model 98% less (82% less with `maxAge = 0`), car is gone without a model 78% less (20% less with `maxAge = 0`), spot check 70% less.

Plates compare trimmed and in upper case. Entity handles are valid in every resource.

### `Core.Vehicles.Find(plate, maxAge, model)`
Array of entities carrying the plate (empty when none). A hit is re-read before it is returned. A miss re-reads cars with no plate yet, cars younger than 30 s, and cars not read for `maxAge` ms (default `10000`); `0` re-reads on every miss, for answers money depends on. `model` (spawn name or hash, optional) is the model of the car you are looking for: a miss then re-reads only the cars of that model. Pass it whenever you know it. If the model you pass is not the model the car has in the world, a plate changed in the last few seconds can be missed until the sweeper reads it.

### `Core.Vehicles.Unread(model)`
`true` when a vehicle of this model has a plate that still reads empty. Reads only the cars of that model.

### `Core.Vehicles.UnreadModels()`
Array of model hashes of vehicles whose plate still reads empty (no client has owned them yet). Any of them could be the car a plate search missed.

### `Core.Vehicles.FirstFree(points, radius)`
Index of the first point (anything with `x`, `y`, `z`) with no vehicle within `radius`, or `nil` when all are taken. Reads only the cars around each point, the cars that were moving and the cars players sit in.

### `Core.Vehicles.Near(point, radius)`
`true` when a vehicle stands within `radius` of the point.

### `Core.Vehicles.Add(entity)`
Registers a vehicle you just made on the server, so it is known before the next catch-up.

### `Core.Vehicles.All()`
Array of every vehicle entity. For a one-time pass at script start, not for lookups.

### `Core.Vehicles.Stats()` / `Core.Vehicles.Resync()`
`Stats()` returns counts plus the running cost (`loaded`, `memoryKB`, `sweeperUsPerSecond`, `lookups`, `lookupUs`) without loading the index. `Resync()` rebuilds it from the game. Console: `bp_vehicles` (counts and cost), `bp_vehicles resync`, `bp_vehicles find <plate>`, `bp_vehicles bench` (times it against a loop; reads only), `bp_vehicles check` (compares the index with a full scan of the game).

```lua
local Core = exports.bp_lib:Core()
local car = Core.Vehicles.Find('ABC 123')[1]
local i = Core.Vehicles.FirstFree(spawnPoints, 2.5)
```

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
Checks all *other* resources for membership; if found, sends a `bp_lib:notify` warning and returns `true`.

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

## Shared helpers (0.10.0+)

Helpers BP scripts used to copy into every resource. Source: `shared/helpers.lua`,
`server/helpers.lua`, `client/helpers.lua`; copied onto `Core` in both `main.lua` files.
Anything that prints or keeps state uses the calling script's name (`GetInvokingResource()`),
so scripts never share a tag, cache or rate limit. Tests: `tests/helpers.py` (lupa).

Check for them with `Core.HelpersVersion` (1 in 0.10.0, 2 in 0.11.0; on the server 3 in 0.12.0 and 4 in 0.14.0; on the client 3 in 0.15.0, `Core.Prompt`). The two sides count apart. Stop with a clear message on
older bp_lib:

```lua
if not lib.HelpersVersion then
    print('^1[my_script] Needs bp_lib 0.10.0 or newer. Update bp_lib, then start my_script again. Stopping.^0')
    CreateThread(function() StopResource(GetCurrentResourceName()) end)
end
```

A script that uses the 0.11.0 additions checks `(lib.HelpersVersion or 0) >= 2` the same way.

| Function | Side | What it does |
|---|---|---|
| `Core.Say(msg, colour?)` | both | Console line `[script] msg`. No colour: cyan tag. With a colour (`'^1'`) the whole line takes it. |
| `Core.Debug(enabled, ...)` | both | `[script:debug] a b c`, only when `enabled` is truthy. |
| `Core.Trim(value)` | both | Trimmed string; nil stays nil. |
| `Core.Clamp(n, lo, hi, default)` | both | `tonumber(n)` held in range; not a number or NaN gives `default`. |
| `Core.Round(n, decimals?)` | both | Half up; 0 decimals returns an integer. |
| `Core.Amount(n, min?, max?)` | both | 0.11.0. The strict money rule: `n` as an integer when it is a number, finite, whole, at least `min` (1) and at most `max` (2^53 - 1, the largest whole number every part of the game holds exactly). Anything else gives `nil` and why: `not_number`, `not_finite`, `not_whole`, `too_small`, `too_large`. Never rounds or converts: `"100"`, `1.5`, `0`, `-1`, NaN and infinity are refused. |
| `Core.Plate.Normalize(plate)` | both | Trimmed upper case plate, nil when empty. Use before comparing or storing. |
| `Core.Plate.World(plate)` | both | Normalized and cut to the game's 8 characters. |
| `Core.Plate.Spellings(plate)` | both | Raw, normalized and every 8-char padding, for SQL lookups. |
| `Core.Plate.Of(entity)` | both | Normalized plate of a vehicle, nil for no entity. |
| `Core.IsAdmin(src, { ace, groups, console })` | server | ACE first, then any framework group. Console (src 0) only with `console = true`. |
| `Core.Identifier(src)` | server | Character id as a string, nil when not loaded. Never throws. |
| `Core.DisplayName(src, max?)` | server | Character name, else FiveM name, else `player <id>`; cut to `max` (64). `'console'` for src 0. |
| `Core.RateLimit(src, key, ms)` | server | true when allowed (and counted), false when the same key came within `ms`. |
| `Core.Bucket(src, key, max, windowMs)` | server | true while fewer than `max` calls in the last `windowMs`. |
| `Core.NotifyKey(src, key, kind?, ...)` | server | Notify with a locale key of the calling script. kind defaults to `'info'`. |
| `Core.Alert(src, title, body?, kind?, { app?, data? }?)` | server | 0.11.0. The notification bridge, for notes that matter. With BP Laptop running and an app of your script this player can see there, the note goes into the laptop (stored, bell list, unread badge, toast; `data` comes back to your app when the player opens it; `app` picks one of your apps, default your first). Otherwise, or when the laptop refuses (rate limit, app switched off, laptop restarting), the normal `Core.Notify` with `kind`. Never both. Returns `'laptop'` or `'notify'`, `false` for no player. No laptop needed: on a server without it this is just a notify. |
| `Core.Webhook(url, embed, username?)` | server | Posts one Discord embed. `embed.footer` may be a string. false without a url. |
| `Core.Lock(keys, fn, ttl?)` | server | 0.11.0. Runs `fn()` while holding every key in `keys` (one key or a list), kept per script. Keys are sorted and taken all at once, whatever order you gave them in; if any is held, `fn` does not run and you get `false, 'busy'`. Otherwise `true` and what `fn` returned. Released when `fn` returns and when it throws (the error is raised again). A lock older than `ttl` ms (30000) counts as free. Not re-entrant. |
| `Core.IsLocked(keys)` | server | 0.11.0. true when any of the keys is held by your script. |
| `Core.IsNear(src, coords, radius)` | server | 0.11.0. true when the player's ped is within `radius` metres of `coords` (vector3, vector4 or `{ x, y, z }`), measured from the server's copy of the ped's position. That stops a page, an event or a callback that only claims a place; it does not stop a teleport or a position cheat, because under OneSync the server's copy comes from that client's own sync data. Also returns the distance. false for no player or no ped. |
| `Core.Role(src, staff)` | server | 0.11.0. The highest staff role a player holds, from ACE rights and framework groups (each role is checked like `Core.IsAdmin`). See below. |
| `Core.TargetScript()` | server | 0.14.0. Which target script the server runs right now: `'ox_target'`, `'qb-target'` or `'qtarget'` and the resource's folder name, or `nil` when none is running. Read at call time (a target script started after bp_lib counts). A `Config.Target` set by hand is the only one that counts; with `'auto'` the first one running wins. `Core.Target` itself stays client only. |
| `Core.NotifyKey(key, kind?, ...)` | client | Same as the server one, for the local player. |
| `Core.UILocale(prefixes?)` | client | Every key in the script's `locales/en.json`, translated, for its NUI. Optional prefix filter like `{ 'ui_', 'err_' }`. Cached. |
| `Core.RequestModel(model, timeout?)` | client | Hash once loaded, nil when missing or timed out (5000 ms). Needs a thread. |
| `Core.RequestAnimDict(dict, timeout?)` | client | true once loaded, false when missing or timed out (5000 ms). Needs a thread. |

`Core.Role` takes one table:

```lua
local Staff = {
    owner = { ace = 'my_script.owner' },                              -- optional, always the top
    roles = {
        admin = { ace = 'my_script.admin', groups = { 'admin', 'god' } },
        mod   = { ace = 'my_script.mod',   groups = { 'mod' } },
        trial = { ace = 'my_script.trial', groups = { 'support' } },
    },
    order = { 'admin', 'mod', 'trial' },                             -- highest first
    console = true,                                                  -- the server console counts as owner
}
local role, place = Core.Role(src, Staff)   -- 'mod', 2  (owner is place 0), or nil
```

Without `order`, roles are ranked by a `rank` number on each role (higher first), then by name.
On Qbox and QBCore a group is an ACE group (`add_principal identifier.fivem:1 group.admin`); on ESX
it is the player's ESX group.

---

## Locale helpers (shared)

Source: `utils/locale.lua`. Loaded into `Core` as `Core.LoadLocales`, `Core.GetLocales`, and `Core.Locale`.

### `Core.Locale(key, ...)`
Looks up `key` in the invoking resource's locale dictionary, falling back to `bp_lib`'s. Optional varargs are forwarded to `string.format`.

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

The command exposed by `Config.SkillMenu.Command` (default `bp_skills`) calls the same function.

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

### `bp_lib:CreateEntity` / `:CreatePed` / `:CreateVehicle`
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
| `bp_lib:plateChanged` | local (0.15.0) | `(oldPlate, newPlate, identifier)` | Fired once by `Core.Framework.Vehicles.SetPlate` (Qbox, QBCore, ESX) after a write that changed a row; never on failure. Plates and the owner's character id exactly as passed to `SetPlate`. Server only, never a net event: listen with `AddEventHandler`, never `RegisterNetEvent`. Move your own rows from the old plate to the new one, comparing plates the way your tables store them |

---

## BP Development notices (0.13.0+)

bp_lib checks `https://tebex.bhavikp.in/announcements.json` and prints short BP Development
notices (new script launches, discount codes) in the **server console**. Nothing is shown in game
or to players, and nothing about your server is sent. Notices for scripts you already run are skipped.

```cfg
set bp_announce 0          # turn the notices off
set bp_announce_hours 6    # re-check interval in hours, 0 = only at start
```

`bp_announcements` in the server console prints the current notices again.

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
| `Config.Logger` | `logger/` (server only). `'auto'` with a webhook in `shared/discordLogs.lua` loads `logger/auto.lua` (0.14.0) |

Other knobs:

```lua
Config.Debug              = false        -- gates Utils.Print and zone debug rendering
Config.Language           = 'en'         -- locale file picked from locales/<lang>.json
Config.CarryItemsEnabled  = true         -- master switch for the CarryItems subsystem
Config.SkillMenu = {
    Enabled = true,
    Command = 'bp_skills',               -- false to disable the command
}
Config.Prompt      = '3d'         -- 0.15.0, Core.Prompt look: '3d' or 'textui'
Config.PromptMark  = true         -- the small mark at prompts not yet in reach
Config.PromptKeys  = { 'E', 'G' } -- default keys of the two prompt key mappings
Config.PromptStyle = { ... }      -- size, font and colours of the '3d' look (see Core.Prompt)
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
