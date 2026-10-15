-- Walk.lua: walking costs over the baked walking maps (NaowhForever_JourneysData), built when needed, let go when idle.
local ns = _G.NaowhForever

local sqrt, floor = math.sqrt, math.floor
local yield, running = coroutine.yield, coroutine.running
local debugprofilestop = debugprofilestop

local Jy = ns.Journeys
local C = Jy.C

local DATA_ADDON = "NaowhForever_JourneysData"
local TILE = 1600 / 3
local ORIGIN = 32 * TILE
local Q = 1
local EDGE_KEY = 65536
local SIDE = 8
local OCEAN = 2
local PIER_WIDTH = 30
local NUDGE = 0.5
local RAY_HOPS = 4000
local RAY_SLACK = 1e-6
local RAY_EDGE = 0.05
local BOAT = "Boat"
local FACTOR = { [0] = 1, [1] = C.SWIM, [OCEAN] = C.SEA }

local Walk = {}
Jy.Walk = Walk

local function Set()
    return { cost = {}, done = {}, heap = {}, prev = {} }
end

local function Tables(into)
    if not into then return {}, {}, {}, {} end
    return wipe(into.cost), wipe(into.done), wipe(into.heap), wipe(into.prev)
end

local segment = Set()

function Walk.Scratch()
    return { near = Set(), far = Set(), seeds = {} }
end

local loaded, store
local tiles, used = {}, {}
local graphs, places = {}, {}
local budgetEnd = 0
local lastUse, releasing = 0, false

local function Decode(s)
    local u = C_EncodingUtil
    return u.DeserializeCBOR(u.DecompressString(u.DecodeBase64(s), Enum.CompressionMethod.Deflate))
end

local function Pause()
    if running() and debugprofilestop() > budgetEnd then
        yield()
        budgetEnd = debugprofilestop() + C.WALK_BUDGET
    end
end

function Walk.StartBudget()
    budgetEnd = debugprofilestop() + C.WALK_BUDGET
end

local function Release()
    local idle = GetTime() - lastUse
    if idle < C.WALK_RELEASE then
        C_Timer.After(C.WALK_RELEASE - idle, Release)
        return
    end
    releasing = false
    wipe(tiles)
    wipe(used)
    wipe(graphs)
    wipe(places)
    segment = Set()
end

local function Used()
    lastUse = GetTime()
    if releasing then return end
    releasing = true
    C_Timer.After(C.WALK_RELEASE, Release)
end

function Walk.Ready()
    if loaded ~= nil then return loaded end
    if InCombatLockdown() then return false end
    if not C_AddOns.IsAddOnLoaded(DATA_ADDON) then C_AddOns.LoadAddOn(DATA_ADDON) end
    store = ns.JourneyData
    loaded = store ~= nil
    return loaded
end

local function Neighbours(polys)
    local owner, nbr = {}, {}
    for p = 1, #polys do
        local poly, row = polys[p], {}
        nbr[p] = row
        for k = 1, #poly do
            local a, b = poly[k], poly[k % #poly + 1]
            local key = a < b and a * EDGE_KEY + b or b * EDGE_KEY + a
            local other = owner[key]
            if other then
                local q = floor(other / SIDE)
                row[k] = q
                nbr[q][other % SIDE + 1] = p
            else
                owner[key] = p * SIDE + k - 1
            end
        end
    end
    return nbr
end

local function Build(tx, ty, data)
    local x0, y0 = ORIGIN - ty * TILE, ORIGIN - tx * TILE
    local v, vx, vy, vz = data.v, {}, {}, {}
    local qx, qy, qz = 0, 0, 0
    for i = 1, #v, 3 do
        qx, qy, qz = qx + v[i], qy + v[i + 1], qz + v[i + 2]
        local n = #vx + 1
        vx[n], vy[n], vz[n] = x0 - qx / Q, y0 - qy / Q, qz / Q
    end
    local polys, p, index, i = {}, data.p, 0, 1
    while i <= #p do
        local poly = {}
        for k = 1, p[i] do
            index = index + p[i + k]
            poly[k] = index
        end
        i = i + p[i] + 1
        polys[#polys + 1] = poly
    end
    local cx, cy, cz = {}, {}, {}
    for n = 1, #polys do
        local poly, sx, sy, sz = polys[n], 0, 0, 0
        for k = 1, #poly do sx, sy, sz = sx + vx[poly[k]], sy + vy[poly[k]], sz + vz[poly[k]] end
        cx[n], cy[n], cz[n] = sx / #poly, sy / #poly, sz / #poly
    end
    local cross = {}
    local x = data.x or {}
    for k = 1, #x, 2 do cross[#cross + 1] = { x[k], x[k + 1] } end
    local links = {}
    local l = data.l or {}
    for k = 1, #l, 5 do
        local key = l[k] * SIDE + l[k + 1] - 1
        local list = links[key] or {}
        links[key] = list
        list[#list + 1], list[#list + 2], list[#list + 3] = l[k + 2], l[k + 3], l[k + 4]
    end
    return { vx = vx, vy = vy, vz = vz, polys = polys, nbr = Neighbours(polys), cx = cx, cy = cy, cz = cz,
        area = data.a, cross = cross, links = links }
end

local function Forget()
    local oldest, oldestKey = math.huge, nil
    for key, at in pairs(used) do
        if at < oldest then oldest, oldestKey = at, key end
    end
    tiles[oldestKey], used[oldestKey] = nil, nil
end

function Walk.Tile(map, tx, ty)
    if not Walk.Ready() then return nil end
    local key = map .. ":" .. tx .. ":" .. ty
    local tile = tiles[key]
    if tile == nil then
        local all = store.tiles[map]
        local s = all and all[tx .. "_" .. ty]
        tile = s and Build(tx, ty, Decode(s)) or false
        local count = 0
        for _ in pairs(tiles) do count = count + 1 end
        if count >= C.WALK_TILES then Forget() end
        tiles[key] = tile
    end
    used[key] = GetTime()
    Used()
    return tile or nil
end

function Walk.TileOf(x, y)
    return floor((ORIGIN - y) / TILE), floor((ORIGIN - x) / TILE)
end

local function Inside(tile, poly, x, y)
    local vx, vy = tile.vx, tile.vy
    local inside = false
    local j = poly[#poly]
    for k = 1, #poly do
        local i = poly[k]
        if (vy[i] > y) ~= (vy[j] > y) and x < (vx[j] - vx[i]) * (y - vy[i]) / (vy[j] - vy[i]) + vx[i] then
            inside = not inside
        end
        j = i
    end
    return inside
end

function Walk.StandOn(tile, x, y, z, dry)
    local best, bestScore, extra = nil, math.huge, 0
    local area = dry and tile.area
    for p = 1, #tile.polys do
        local dx, dy = tile.cx[p] - x, tile.cy[p] - y
        local flat = sqrt(dx * dx + dy * dy)
        local inside = Inside(tile, tile.polys[p], x, y)
        local height = z and math.abs(tile.cz[p] - z) or 0
        local score = inside and height or flat + height * C.HEIGHT_WEIGHT
        if (inside or flat < C.WALK_REACH) and score < bestScore and not (area and area[p] == OCEAN) then
            best, bestScore, extra = p, score, inside and 0 or flat + height
        end
    end
    return best, extra
end

function Walk.Ashore(spot)
    if not Walk.Ready() then return true end
    local tile = Walk.Tile(spot.c, Walk.TileOf(spot.x, spot.y))
    local poly = tile and Walk.StandOn(tile, spot.x, spot.y, spot.z)
    return poly ~= nil and not (tile.area and tile.area[poly] == OCEAN)
end

local function Push(heap, cost, node)
    local n = #heap + 1
    heap[n] = node
    local i = n
    while i > 1 do
        local up = floor(i / 2)
        if cost[heap[up]] <= cost[heap[i]] then break end
        heap[up], heap[i] = heap[i], heap[up]
        i = up
    end
end

local function Pop(heap, cost)
    local top, n = heap[1], #heap
    heap[1] = heap[n]
    heap[n] = nil
    n = n - 1
    local i = 1
    while true do
        local l, r, m = 2 * i, 2 * i + 1, i
        if l <= n and cost[heap[l]] < cost[heap[m]] then m = l end
        if r <= n and cost[heap[r]] < cost[heap[m]] then m = r end
        if m == i then break end
        heap[m], heap[i] = heap[i], heap[m]
        i = m
    end
    return top
end

local function EdgeMid(tile, p, k)
    local poly = tile.polys[p]
    local a, b = poly[k], poly[k % #poly + 1]
    return (tile.vx[a] + tile.vx[b]) / 2, (tile.vy[a] + tile.vy[b]) / 2, (tile.vz[a] + tile.vz[b]) / 2
end

local function Rate(tile, p)
    return tile.area and FACTOR[tile.area[p]] or 1
end

local function Leg(tile, p, x, y, z)
    local dx, dy, dz = tile.cx[p] - x, tile.cy[p] - y, tile.cz[p] - z
    return sqrt(dx * dx + dy * dy + dz * dz) * Rate(tile, p)
end

function Walk.Spread(tile, from, extra, into)
    local cost, done, heap, prev = Tables(into)
    cost[from], heap[1] = extra, from
    while #heap > 0 do
        local p = Pop(heap, cost)
        if not done[p] then
            done[p] = true
            local nbr = tile.nbr[p]
            for k = 1, #tile.polys[p] do
                local q = nbr[k]
                if q and not done[q] then
                    local mx, my, mz = EdgeMid(tile, p, k)
                    local c = cost[p] + Leg(tile, p, mx, my, mz) + Leg(tile, q, mx, my, mz)
                    if c < (cost[q] or math.huge) then
                        cost[q], prev[q] = c, p
                        Push(heap, cost, q)
                    end
                end
            end
            Pause()
        end
    end
    return cost, prev
end

local function Graph(map)
    Used()
    local g = graphs[map]
    if g == nil then
        local s = store.graph[map]
        g = false
        if s then
            local data = Decode(s)
            local c, e, px, py, pz, adj = data.c, data.e, {}, {}, {}, {}
            for i = 1, #c, 3 do
                local n = #px + 1
                px[n], py[n], pz[n], adj[n] = c[i] / Q, c[i + 1] / Q, c[i + 2] / Q, {}
            end
            for i = 1, #e, 3 do
                local a, b, w = e[i], e[i + 1], e[i + 2]
                local la, lb = adj[a], adj[b]
                la[#la + 1], la[#la + 2] = b, w
                lb[#lb + 1], lb[#lb + 2] = a, w
            end
            g = { px = px, py = py, pz = pz, adj = adj }
        end
        graphs[map] = g
    end
    return g or nil
end

local function Places(map)
    Used()
    local p = places[map]
    if p == nil then
        local s = store.walks[map]
        p = false
        if s then
            local data = Decode(s)
            local index = {}
            for i, key in ipairs(data.k) do index[key] = i end
            p = { index = index, count = #data.k, d = data.d, r = data.r }
        end
        places[map] = p
    end
    return p or nil
end

local function Search(g, seeds, into)
    local cost, done, heap, prev = Tables(into)
    for c, w in pairs(seeds) do
        cost[c] = w
        Push(heap, cost, c)
    end
    while #heap > 0 do
        local a = Pop(heap, cost)
        if not done[a] then
            done[a] = true
            local list = g.adj[a]
            for i = 1, #list, 2 do
                local b = list[i]
                local w = cost[a] + list[i + 1]
                if not done[b] and w < (cost[b] or math.huge) then
                    cost[b], prev[b] = w, a
                    Push(heap, cost, b)
                end
            end
            Pause()
        end
    end
    return cost, prev
end

local function Pier(map, spot)
    local p = Places(map)
    if not p then return nil end
    for s, ship in ipairs(ns.JourneyNetwork.ships) do
        if ship[1] == BOAT then
            for i = 3, #ship do
                local dock = ship[i]
                local at = dock[1] == map and p.index["s" .. s .. "." .. i - 2]
                local r = at and p.r[at]
                local tile = r and r[1] and Walk.Tile(map, r[1], r[2])
                if tile then
                    local rx, ry = tile.cx[r[3]], tile.cy[r[3]]
                    local span = sqrt((dock[2] - rx) ^ 2 + (dock[3] - ry) ^ 2)
                    local toRoot = sqrt((spot.x - rx) ^ 2 + (spot.y - ry) ^ 2)
                    local toDock = sqrt((spot.x - dock[2]) ^ 2 + (spot.y - dock[3]) ^ 2)
                    if toDock + toRoot <= span + PIER_WIDTH then return tile, r[1], r[2], r[3], toRoot end
                end
            end
        end
    end
end

function Walk.From(spot, scratch)
    if not Walk.Ready() then return nil end
    local map = spot.c
    local tx, ty = Walk.TileOf(spot.x, spot.y)
    local tile = Walk.Tile(map, tx, ty)
    local g = Graph(map)
    if not g then return nil end
    local poly, extra
    if tile then poly, extra = Walk.StandOn(tile, spot.x, spot.y, spot.z, true) end
    if not poly then
        local x0, y0 = tx, ty
        for dx = -1, 1 do
            for dy = -1, 1 do
                local t = Walk.Tile(map, x0 + dx, y0 + dy)
                if t then
                    local p, e = Walk.StandOn(t, spot.x, spot.y, spot.z, true)
                    if p and (not poly or e < extra) then poly, extra, tile, tx, ty = p, e, t, x0 + dx, y0 + dy end
                end
            end
        end
    end
    local pier
    if not poly or extra > 0 then
        local t, x, y, p, e = Pier(map, spot)
        if t then tile, tx, ty, poly, extra, pier = t, x, y, p, e, true end
    end
    if not poly then return false end
    local x, y, off = spot.x, spot.y, nil
    local sx, sy = Walk.TileOf(spot.x, spot.y)
    if pier or sx ~= tx or sy ~= ty then x, y, off = tile.cx[poly], tile.cy[poly], { spot.x, spot.y } end
    local near, nearPrev = Walk.Spread(tile, poly, extra, scratch and scratch.near)
    local seeds = scratch and wipe(scratch.seeds) or {}
    for _, c in ipairs(tile.cross) do
        local reach = near[c[2]]
        if reach then
            local dx, dy = g.px[c[1]] - tile.cx[c[2]], g.py[c[1]] - tile.cy[c[2]]
            seeds[c[1]] = reach + sqrt(dx * dx + dy * dy)
        end
    end
    local far, farPrev = Search(g, seeds, scratch and scratch.far)
    return { map = map, tx = tx, ty = ty, poly = poly, x = x, y = y, off = off, near = near, nearPrev = nearPrev,
        far = far, farPrev = farPrev }
end

local function ToPlace(reach, p, i)
    local r = p.r[i]
    if not r or not r[1] then return nil end
    local best
    if r[1] == reach.tx and r[2] == reach.ty then best = reach.near[r[3]] end
    for k = 4, #r, 2 do
        local far = reach.far[r[k]]
        if far and (not best or far + r[k + 1] < best) then best = far + r[k + 1] end
    end
    return best
end

local function Between(a, b)
    local best = a.tx == b.tx and a.ty == b.ty and a.near[b.poly] or nil
    local via
    local tile = Walk.Tile(b.map, b.tx, b.ty)
    local g = Graph(b.map)
    for _, c in ipairs(tile.cross) do
        local far, back = a.far[c[1]], b.near[c[2]]
        if far and back then
            local dx, dy = g.px[c[1]] - tile.cx[c[2]], g.py[c[1]] - tile.cy[c[2]]
            local total = far + back + sqrt(dx * dx + dy * dy)
            if not best or total < best then best, via = total, c[1] end
        end
    end
    return best, via
end

local function Area2(ax, ay, bx, by, cx, cy)
    return (cx - ax) * (by - ay) - (bx - ax) * (cy - ay)
end

local function Portal(tile, p, q, fromX, fromY, toX, toY)
    local poly = tile.polys[p]
    for k = 1, #poly do
        if tile.nbr[p][k] == q then
            local a, b = poly[k], poly[k % #poly + 1]
            local ax, ay, bx, by = tile.vx[a], tile.vy[a], tile.vx[b], tile.vy[b]
            if Area2(fromX, fromY, toX, toY, ax, ay) > 0 then ax, ay, bx, by = bx, by, ax, ay end
            return ax, ay, bx, by
        end
    end
end

local function Funnel(lx, ly, rx, ry, out)
    local n = #lx
    local apx, apy = lx[1], ly[1]
    local flx, fly, frx, fry = lx[1], ly[1], rx[1], ry[1]
    local apex
    local left, right = 1, 1
    local i = 2
    while i <= n do
        local nlx, nly, nrx, nry = lx[i], ly[i], rx[i], ry[i]
        local restart = false
        if Area2(apx, apy, frx, fry, nrx, nry) <= 0 then
            if (apx == frx and apy == fry) or Area2(apx, apy, flx, fly, nrx, nry) > 0 then
                frx, fry, right = nrx, nry, i
            else
                out[#out + 1], out[#out + 2] = flx, fly
                apx, apy, apex = flx, fly, left
                frx, fry, right = apx, apy, apex
                i, restart = apex + 1, true
            end
        end
        if not restart and Area2(apx, apy, flx, fly, nlx, nly) >= 0 then
            if (apx == flx and apy == fly) or Area2(apx, apy, frx, fry, nlx, nly) < 0 then
                flx, fly, left = nlx, nly, i
            else
                out[#out + 1], out[#out + 2] = frx, fry
                apx, apy, apex = frx, fry, right
                flx, fly, left = apx, apy, apex
                i, restart = apex + 1, true
            end
        end
        if not restart then i = i + 1 end
    end
    out[#out + 1], out[#out + 2] = lx[n], ly[n]
end

local function Segment(tile, fromPoly, fromX, fromY, toPoly, toX, toY, out)
    local _, prev = Walk.Spread(tile, fromPoly, 0, segment)
    local chain, p = {}, toPoly
    while p and p ~= fromPoly do
        table.insert(chain, 1, p)
        p = prev[p]
    end
    if not p then return false end
    table.insert(chain, 1, fromPoly)
    local lx, ly, rx, ry = { fromX }, { fromY }, { fromX }, { fromY }
    for k = 1, #chain - 1 do
        local a, b = chain[k], chain[k + 1]
        local ax, ay, bx, by = Portal(tile, a, b, tile.cx[a], tile.cy[a], tile.cx[b], tile.cy[b])
        lx[#lx + 1], ly[#ly + 1], rx[#rx + 1], ry[#ry + 1] = ax, ay, bx, by
    end
    lx[#lx + 1], ly[#ly + 1], rx[#rx + 1], ry[#ry + 1] = toX, toY, toX, toY
    Funnel(lx, ly, rx, ry, out)
    return true
end

local SIDES = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

local function PolyFor(tile, crossing)
    for _, c in ipairs(tile.cross) do
        if c[1] == crossing then return c[2] end
    end
end

local function Ends(b, out)
    if b.off then out[#out + 1], out[#out + 2] = b.off[1], b.off[2] end
    return out
end

local function Side(tile, p, k, x, y)
    local poly = tile.polys[p]
    local i, j = poly[k], poly[k % #poly + 1]
    local ax, ay, bx, by = tile.vx[i], tile.vy[i], tile.vx[j], tile.vy[j]
    local side = Area2(ax, ay, bx, by, x, y) / sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
    if Area2(ax, ay, bx, by, tile.cx[p], tile.cy[p]) < 0 then side = -side end
    return side, ax, ay, bx, by
end

local function Within(tile, p, x, y)
    for k = 1, #tile.polys[p] do
        if Side(tile, p, k, x, y) < -RAY_EDGE then return false end
    end
    return true
end

local function Exit(tile, p, sx, sy, ex, ey, after)
    local dx, dy = ex - sx, ey - sy
    local edge, at, outside
    for k = 1, #tile.polys[p] do
        local side, ax, ay, bx, by = Side(tile, p, k, ex, ey)
        if side < -RAY_EDGE then
            outside = true
            local denom = dx * (by - ay) - dy * (bx - ax)
            if denom ~= 0 then
                local t = ((ax - sx) * (by - ay) - (ay - sy) * (bx - ax)) / denom
                if t >= after - RAY_SLACK and (not at or t < at) then edge, at = k, t end
            end
        end
    end
    return outside, edge, at
end

local function Around(tile, p, x, y)
    local best, bestHeight
    for q = 1, #tile.polys do
        if q ~= p and Within(tile, q, x, y) then
            local height = math.abs(tile.cz[q] - tile.cz[p])
            if not best or height < bestHeight then best, bestHeight = q, height end
        end
    end
    return best
end

local function Clear(map, tile, tx, ty, p, sx, sy, ex, ey, wet)
    local length = sqrt((ex - sx) ^ 2 + (ey - sy) ^ 2)
    if length == 0 then return tile, tx, ty, p end
    local ux, uy = (ex - sx) / length, (ey - sy) / length
    local after, turned = 0, false
    for _ = 1, RAY_HOPS do
        if not wet and tile.area and tile.area[p] ~= 0 then return nil end
        local outside, k, t = Exit(tile, p, sx, sy, ex, ey, after)
        if not outside then return tile, tx, ty, p end
        if not k then return nil end
        local q = tile.nbr[p][k]
        local list = not q and tile.links[p * SIDE + k - 1]
        if not q and not list and not turned and t * length < NUDGE then
            q = Around(tile, p, sx + ux * NUDGE, sy + uy * NUDGE)
            turned = true
            t = after
        end
        after = t
        if q then
            p = q
        else
            if not list then return nil end
            local x, y = sx + (ex - sx) * t, sy + (ey - sy) * t
            local found
            for i = 1, #list, 3 do
                local nextTile = Walk.Tile(map, tx + list[i], ty + list[i + 1])
                if nextTile and Within(nextTile, list[i + 2], x - list[i + 1] * NUDGE, y - list[i] * NUDGE) then
                    tile, tx, ty, p, found = nextTile, tx + list[i], ty + list[i + 1], list[i + 2], true
                    break
                end
            end
            if not found then return nil end
        end
    end
end

local function Straight(a, points, start)
    local out = {}
    for i = 1, start + 1 do out[i] = points[i] end
    local tile, tx, ty, p = Walk.Tile(a.map, a.tx, a.ty), a.tx, a.ty, a.poly
    local last = #points - 1
    local i = start
    while i < last do
        local reached, rTile, rtx, rty, rp
        for j = i + 2, last, 2 do
            local t2, tx2, ty2, p2 = Clear(a.map, tile, tx, ty, p, points[i], points[i + 1], points[j], points[j + 1],
                j == i + 2)
            Pause()
            if not t2 then break end
            reached, rTile, rtx, rty, rp = j, t2, tx2, ty2, p2
        end
        if not reached then
            for k = i + 2, #points do out[#out + 1] = points[k] end
            return out
        end
        out[#out + 1], out[#out + 2] = points[reached], points[reached + 1]
        tile, tx, ty, p, i = rTile, rtx, rty, rp, reached
    end
    return out
end

function Walk.Path(a, b)
    local _, via = Between(a, b)
    local out = a.off and { a.off[1], a.off[2], a.x, a.y } or { a.x, a.y }
    local start = #out - 1
    if not via then
        if a.tx ~= b.tx or a.ty ~= b.ty or not a.near[b.poly] then return nil end
        local tile = Walk.Tile(a.map, a.tx, a.ty)
        return Segment(tile, a.poly, a.x, a.y, b.poly, b.x, b.y, out) and Ends(b, Straight(a, out, start)) or nil
    end
    local g = Graph(a.map)
    local chain, c = {}, via
    while c do
        table.insert(chain, 1, c)
        c = a.farPrev[c]
    end
    local tx, ty = a.tx, a.ty
    local tile = Walk.Tile(a.map, tx, ty)
    local fromPoly, fromX, fromY = a.poly, a.x, a.y
    for k = 1, #chain do
        local id = chain[k]
        local toPoly = PolyFor(tile, id)
        if not toPoly or not Segment(tile, fromPoly, fromX, fromY, toPoly, g.px[id], g.py[id], out) then return nil end
        fromPoly = nil
        for _, step in ipairs(SIDES) do
            local nextTile = Walk.Tile(a.map, tx + step[1], ty + step[2])
            local poly = nextTile and PolyFor(nextTile, id)
            if poly then
                tile, fromPoly, tx, ty = nextTile, poly, tx + step[1], ty + step[2]
                break
            end
        end
        if not fromPoly then return nil end
        fromX, fromY = g.px[id], g.py[id]
    end
    if not Segment(tile, fromPoly, fromX, fromY, b.poly, b.x, b.y, out) then return nil end
    return Ends(b, Straight(a, out, start))
end

function Walk.Cost(map, a, b)
    if not Walk.Ready() then return nil end
    local p = Places(map)
    if type(a) == "string" and type(b) == "string" then
        local i, j = p and p.index[a], p and p.index[b]
        if not i or not j or not p.r[i][1] or not p.r[j][1] then return nil end
        local d = p.d[(i - 1) * p.count + j]
        return d >= 0 and d or false
    end
    if type(a) == "string" then a, b = b, a end
    if type(b) == "string" then
        local i = p and p.index[b]
        if not i or not p.r[i][1] then return nil end
        return ToPlace(a, p, i) or false
    end
    return Between(a, b) or false
end
