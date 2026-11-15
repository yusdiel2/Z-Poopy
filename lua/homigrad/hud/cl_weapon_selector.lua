--
hg = hg or {}
hg.WeaponSelector = hg.WeaponSelector or {}
local WS = hg.WeaponSelector

function WS.GetPrintName( self )
	local class = self:GetClass()
	local phrase = language.GetPhrase(class)
	return phrase ~= class and phrase or self:GetPrintName()
end

WS.Show = 0
WS.Transparent = 0
WS.LastSelectedSlot = 0
WS.LastSelectedSlotPos = 0

WS.SelectedSlot = 0
WS.SelectedSlotPos = 0

WS.Anim = WS.Anim or setmetatable({}, { __mode = "k" })
WS.Seen = WS.Seen or setmetatable({}, { __mode = "k" })
WS.SlotPres = {}
WS.SlotItems = {}

WS.InfoSlot = nil
WS.InfoSnap = false
WS.InfoAlpha = 0
WS.InfoRest = 0
WS.InfoX = 0
WS.InfoY = 0

function WS.DrawText(text, font, posX, posY, color, textAlign)
    draw.DrawText( text, font, posX + 2, posY + 2, ColorAlpha(color_black,WS.Transparent*255) ,textAlign )
    draw.DrawText( text, font, posX, posY, ColorAlpha(color,WS.Transparent*255) ,textAlign )
end

function WS.GetSelectedWeapon()
    if not IsValid( LocalPlayer() ) or not LocalPlayer():Alive() then return end
    local Weapons = WS.GetWeaponTable( LocalPlayer() )
    return Weapons[WS.SelectedSlot] and Weapons[WS.SelectedSlot][WS.SelectedSlotPos] or Weapons[WS.LastSelectedSlot][WS.LastSelectedSlotPos] or Weapons[0][0]
end

function WS.GetWeaponTable( ply )
    if not IsValid( ply ) or not ply:Alive() then return end
    local WeaponsGet = {}
    for _, wep in ipairs( ply:GetWeapons() ) do
        WS.Seen[wep] = WS.Seen[wep] or CurTime()
        if wep.Slot ~= nil or CurTime() - WS.Seen[wep] > 0.3 then
            WeaponsGet[#WeaponsGet + 1] = wep
        end
    end
    local FormatedTable = {
        [0] = {}, [1] = {}, [2] = {}, [3] = {}, [4] = {}, [5] = {},
    }

    table.sort(WeaponsGet, function(a, b)
        local sa, sb = a.SlotPos or 0, b.SlotPos or 0
        if sa ~= sb then return sa > sb end
        return a:EntIndex() < b:EntIndex()
    end)

    for k,wep in ipairs(WeaponsGet) do
        local tTbl = FormatedTable[wep.Slot or 0]
        local iMinPos = math.min( (wep.SlotPos and wep.SlotPos) or 1, ((#tTbl or 0) + 1)) - 1
        local iPos = tTbl[ iMinPos ] and #tTbl + 1 or iMinPos
        tTbl[ iPos ] = wep
    end
    return FormatedTable
end

local scrW, scrH = ScrW(), ScrH()

local AcsentColor = Color(155,0,0)
local gradient_u = Material("vgui/gradient-d")

local function DrawCollapsed( x, y, w, h, name, alpha )
    local old = WS.Transparent
    WS.Transparent = alpha

    render.SetScissorRect( math.floor( x ), math.floor( y ), math.ceil( x + w ), math.ceil( y + h ), true )
    draw.RoundedBox( 0, x, y, w, h, ColorAlpha(color_black, WS.Transparent * 205) )
    draw.RoundedBox( 0, x, y + h - 2, w, 2, ColorAlpha(color_black, WS.Transparent * 205) )
    WS.DrawText( name, "HomigradFontSmall", x + w / 2, y + 2.5, color_white, TEXT_ALIGN_CENTER )
    render.SetScissorRect( 0, 0, 0, 0, false )

    WS.Transparent = old
end

local function ResetState()
    WS.InfoSlot = nil
    WS.SlotPres = {}
    WS.SlotItems = {}
    WS.TrackedWep = nil
end

local function FindWeapon( Weapons, wep )
    for s = 0, 5 do
        for pos = 0, #Weapons[s] do
            if Weapons[s][pos] == wep then return s, pos end
        end
    end
end

local function FindNearest( Weapons, slot, pos )
    for d = 0, 5 do
        for _, s in ipairs( d == 0 and { slot } or { slot - d, slot + d } ) do
            local list = Weapons[s]
            if list and table.Count( list ) > 0 then
                local best, bestDist
                for p in pairs( list ) do
                    local dist = math.abs( p - pos )
                    if not bestDist or dist < bestDist then best, bestDist = p, dist end
                end
                return s, best
            end
        end
    end
end

function WS.WeaponSelectorDraw( ply )
    if not IsValid( ply ) or not ply:Alive() or GetGlobalBool("RadialInventory", false) then
        ResetState()
        return
    end
    if WS.Show < CurTime() then
        WS.SelectedSlot = WS.LastSelectedSlot
        WS.SelectedSlotPos = -1
        ResetState()

        return
    end
    local Weapons = WS.GetWeaponTable( ply )
    local SelectedWep = WS.GetSelectedWeapon()
    if not IsValid(SelectedWep) then return end

    if WS.TrackedWep and WS.TrackedWep ~= SelectedWep then
        local s, pos = FindWeapon( Weapons, WS.TrackedWep )
        if not s then
            s, pos = FindNearest( Weapons, WS.TrackedSlot or 0, WS.TrackedPos or 0 )
        end
        if s then
            WS.SelectedSlot, WS.SelectedSlotPos = s, pos
            SelectedWep = Weapons[s][pos]
        end
    end
    WS.TrackedWep = SelectedWep
    WS.TrackedSlot, WS.TrackedPos = FindWeapon( Weapons, SelectedWep )

    WS.Transparent = LerpFT( 0.2, WS.Transparent, math.min( WS.Show - CurTime(), 1 ) )
    --draw.RoundedBox(0,(scrW / 2)-10,(scrH *0.15),20,20, color_red )

    local baseTransparent = WS.Transparent

    local pres = {}
    local total = 0
    for i = 0, 5 do
        local has = table.Count(Weapons[i]) > 0 and 1 or 0
        local p = LerpFT( 0.2, WS.SlotPres[i] or has, has )
        if math.abs( p - has ) < 0.01 then p = has end
        WS.SlotPres[i] = p
        pres[i] = p
        total = total + p * (scrW * 0.1 + scrW * 0.008)
    end
    total = total - scrW * 0.008

    local cursor = scrW / 2 - total / 2
    local infoWep
    local infoCol
    local cols = {}

    for i = 0, 5 do
        local p = pres[i]
        if p <= 0 then
            WS.SlotItems[i] = nil
            continue
        end

        local slotTbl = Weapons[i]
        local live = table.Count(slotTbl) > 0

        local x = cursor
        cursor = cursor + p * (scrW * 0.1 + scrW * 0.008)

        local y = scrH * 0.055
        local restY = y

        WS.Transparent = baseTransparent * p

        WS.DrawText( i + 1, "HomigradFontMedium", x + scrW * 0.1 / 2, scrH * 0.02, color_white, TEXT_ALIGN_CENTER )

        --  draw.RoundedBox(
        --      1,
        --      x,
        --      (scrH *0.01),
        --      scrW * 0.1,
        --      (scrH *0.02),
        --      ColorAlpha(color_black,WS.Transparent*255)
        --  )
        --if slotTbl and table.Count(slotTbl) < 0 then continue end

        local items = WS.SlotItems[i] or {}

        if live then
            local current = {}
            local inCurrent = {}
            for Id = 0, #slotTbl do
                local wep = slotTbl[Id]
                if wep then
                    current[#current + 1] = wep
                    inCurrent[wep] = true
                end
            end

            local known = {}
            for _, it in ipairs( items ) do known[it.wep] = it end

            local firstFill = #items == 0

            for idx, wep in ipairs( current ) do
                if not known[wep] then
                    local pos = 1
                    local prevWep = current[idx - 1]
                    if prevWep and known[prevWep] then
                        for k, it in ipairs( items ) do
                            if it.wep == prevWep then pos = k + 1 break end
                        end
                    end
                    local it = { wep = wep, p = firstFill and 1 or 0 }
                    table.insert( items, pos, it )
                    known[wep] = it
                end
            end

            local liveSlots, ordered = {}, {}
            for k, it in ipairs( items ) do
                if inCurrent[it.wep] then liveSlots[#liveSlots + 1] = k end
            end
            for _, wep in ipairs( current ) do ordered[#ordered + 1] = known[wep] end
            for n, k in ipairs( liveSlots ) do items[k] = ordered[n] end

            for k = #items, 1, -1 do
                local it = items[k]
                if inCurrent[it.wep] then
                    it.p = LerpFT( 0.2, it.p, 1 )
                    if it.p > 0.99 then it.p = 1 end
                    it.name = WS.GetPrintName( it.wep )
                else
                    it.p = LerpFT( 0.2, it.p, 0 )
                    it.h = (it.lastH or scrH * 0.028) * it.p
                    if it.p < 0.03 then table.remove( items, k ) end
                end
            end

            WS.SlotItems[i] = items

            for _, it in ipairs( items ) do
                local wep = it.wep

                if inCurrent[wep] then
                    local expand = LerpFT( 0.2, WS.Anim[wep] or 0, SelectedWep == wep and 1 or 0 )
                    WS.Anim[wep] = expand
                    local fullH = Lerp( expand, scrH * 0.028, scrH * 0.12 )
                    it.lastH = fullH
                    local h = fullH * p * it.p

                    draw.RoundedBox( 0, x, y, scrW * 0.1, h, ColorAlpha(color_black, WS.Transparent * 205) )
                    draw.RoundedBox( 0, x, y + math.max( h - 2, 0 ), scrW * 0.1, math.min( h, 2 ), ColorAlpha(color_black, WS.Transparent * 205) )

                    if SelectedWep == wep then
                        surface.SetDrawColor( 155, 0, 0, WS.Transparent * 200 )
                        surface.SetMaterial( gradient_u )
                        surface.DrawTexturedRect( x, y, scrW * 0.1, h )

                        surface.SetDrawColor( 255, 0, 0, WS.Transparent * 155 )
                        surface.DrawOutlinedRect( x, y, scrW * 0.1, h, 2 )

                        if WS.InfoSlot ~= i then
                            WS.InfoSlot = i
                            WS.InfoAlpha = 0
                            WS.InfoSnap = true
                        end
                        WS.InfoX = x + scrW * 0.1 + scrW * 0.004
                        WS.InfoRest = restY + scrH * 0.12 * p * it.p + scrH * 0.004
                        infoWep = wep
                        infoCol = i

                        if wep.DrawWeaponSelection then
                            render.SetScissorRect( math.floor( x ), math.floor( y ), math.ceil( x + scrW * 0.1 ), math.ceil( y + h ), true )
                            wep:DrawWeaponSelection(
                                x + 5,
                                y + scrH * 0.032,
                                scrW * 0.1 - 10,
                                h - scrH * 0.028,
                                WS.Transparent * 255
                            )
                            render.SetScissorRect( 0, 0, 0, 0, false )
                        end
                    end

                    render.SetScissorRect( math.floor( x ), math.floor( y ), math.ceil( x + scrW * 0.1 ), math.ceil( y + h ), true )
                    WS.DrawText( it.name, "HomigradFontSmall", x + scrW * 0.1 / 2, y + 2.5, color_white, TEXT_ALIGN_CENTER )
                    render.SetScissorRect( 0, 0, 0, 0, false )

                    y = y + h
                    restY = restY + scrH * 0.028 * p * it.p
                else
                    local h = (it.h or scrH * 0.028) * p
                    DrawCollapsed( x, y, scrW * 0.1, h, it.name or "", baseTransparent * p )

                    y = y + h
                    restY = restY + h
                end
            end
        else
            for _, it in ipairs( items ) do
                local h = (it.lastH or scrH * 0.028) * p
                DrawCollapsed( x, y, scrW * 0.1, h, it.name or "", baseTransparent * p )
                y = y + h
                restY = restY + h
            end
        end

        cols[#cols + 1] = { idx = i, x = x, restBottom = restY }
        WS.Transparent = baseTransparent
    end

    if infoWep and infoWep.PrintWeaponInfo then
        local target = WS.InfoRest
        for _, c in ipairs( cols ) do
            if c.idx ~= infoCol then
                local overlap = math.min( c.x + scrW * 0.1, WS.InfoX + 260 ) - math.max( c.x, WS.InfoX )
                local weight = math.Clamp( overlap / (scrW * 0.02), 0, 1 )
                weight = weight * weight * (3 - 2 * weight)
                target = math.max( target, weight * (c.restBottom + scrH * 0.008) )
            end
        end

        if WS.InfoSnap then
            WS.InfoY = target
            WS.InfoSnap = false
        else
            WS.InfoY = LerpFT( 0.22, WS.InfoY, target )
        end
        WS.InfoAlpha = LerpFT( 0.2, WS.InfoAlpha, 1 )

        infoWep:PrintWeaponInfo( WS.InfoX, WS.InfoY, WS.Transparent * 255 * WS.InfoAlpha )
    end
end

-- Changer
local tAcceptKeys = {
    ["slot1"] = 1,
    ["slot2"] = 2,
    ["slot3"] = 3,
    ["slot4"] = 4,
    ["slot5"] = 5,
    ["slot6"] = 6,
}

--[[
    Table:
        [1]	=	Weapon [52][weapon_hands_sh]
        [2]	=	Weapon [117][weapon_bigconsumable]
        [3]	=	Weapon [121][weapon_handcuffs_key]
        [4]	=	Weapon [122][weapon_handcuffs]
        [5]	=	Weapon [123][weapon_traitor_poison1]
        [6]	=	Weapon [124][weapon_traitor_suit]
        [7]	=	Weapon [125][weapon_matches]

    TableFormated:
    [0]:
		[0]	=	Weapon [126][weapon_physgun]
		[1]	=	Weapon [52][weapon_hands_sh]
    [1]:
    [2]:
    [3]:
		[1]	=	Weapon [117][weapon_bigconsumable]
		[2]	=	Weapon [121][weapon_handcuffs_key]
		[3]	=	Weapon [122][weapon_handcuffs]
		[4]	=	Weapon [123][weapon_traitor_poison1]
		[5]	=	Weapon [125][weapon_matches]
    [4]:
    [5]:
		[1]	=	Weapon [124][weapon_traitor_suit]
--]]

local function GetUpper(Weapons)
    if #LocalPlayer():GetWeapons() < 1 then return end
    WS.SelectedSlot = WS.SelectedSlot < 0 and #Weapons or WS.SelectedSlot - 1
    WS.SelectedSlotPos = Weapons[WS.SelectedSlot] and #Weapons[WS.SelectedSlot] or 0

    --print(WS.SelectedSlot, WS.SelectedSlotPos)

    if Weapons[WS.SelectedSlot] == nil or Weapons[WS.SelectedSlot][WS.SelectedSlotPos] == nil then
        GetUpper(Weapons)
    end
end

local function GetDown(Weapons)
    if #LocalPlayer():GetWeapons() < 1 then return end
    WS.SelectedSlot = WS.SelectedSlot > #Weapons and 0 or WS.SelectedSlot + 1
    WS.SelectedSlotPos = 0

    --print(WS.SelectedSlot, WS.SelectedSlotPos)

    if Weapons[WS.SelectedSlot] == nil or Weapons[WS.SelectedSlot][WS.SelectedSlotPos] == nil then
        GetDown(Weapons)
    end
end

local LastSelected = 0

local function get_active_tool(ply, tool)
    local activeWep = ply:GetActiveWeapon()
    if not IsValid(activeWep) or activeWep:GetClass() ~= "gmod_tool" or activeWep.Mode ~= tool then return end
    return activeWep:GetToolObject(tool)
end

local function canUseSelector(ply)
    local wep = ply:GetActiveWeapon()
    local tool = get_active_tool(ply, "submaterial")
    if tool and IsValid(ply:GetEyeTraceNoCursor().Entity) then
        return true
    end

    return IsAiming(ply) or (IsValid(wep) and wep:GetClass() == "weapon_physgun" and ply:KeyDown(IN_ATTACK)) or (lply.organism and lply.organism.pain and lply.organism.pain > 100) or GetGlobalBool("RadialInventory", false)
end

function WS.ChangeSelectionWep( ply, key )
    if not IsValid( ply ) or not ply:Alive() or GetGlobalBool("RadialInventory", false) then return end
    if ply.organism and ply.organism.otrub then return end
    if canUseSelector( ply ) then return end
    --print(canUseSelector( ply ))
    --print("Table")
    --PrintTable( WS.GetWeaponTable( ply ) )
    local iPos = tAcceptKeys[ key ]
    if iPos or key == "invnext" or key == "invprev" or key == "lastinv" then

        local Weapons = WS.GetWeaponTable( ply )

        WS.Show = CurTime() + 4
        WS.TrackedWep = nil
        --print(key)
        surface.PlaySound("arc9_eft_shared/weapon_generic_rifle_spin"..math.random(10)..".ogg")
        if iPos then
            iPos = iPos - 1
            if LastSelected ~= iPos then
                WS.SelectedSlotPos = -1
            end
            WS.SelectedSlotPos = (Weapons[iPos] and LastSelected == iPos and WS.SelectedSlotPos + 1 > #Weapons[iPos] and 0 or math.min( WS.SelectedSlotPos + 1, #Weapons[iPos] )) or 0
            WS.SelectedSlot = iPos
            LastSelected = iPos
            --print(WS.SelectedSlotPos)
            --print(iPos)
            --print( Weapons[WS.SelectedSlot][WS.SelectedSlotPos] )
        elseif key == "invprev" then
            WS.SelectedSlotPos = WS.SelectedSlotPos - 1
            --print(WS.SelectedSlotPos)
            if Weapons[WS.SelectedSlot] and WS.SelectedSlotPos < 0  then
                GetUpper(Weapons)
            end
            --WS.SelectedSlot = Weapons[WS.SelectedSlot] and #Weapons[WS.SelectedSlot] > (WS.SelectedSlotPos + 1) and WS.SelectedSlot + 1 or WS.SelectedSlot + 1 > #Weapons - 1 and 0 or 0
        elseif key == "invnext" then
            WS.SelectedSlotPos = WS.SelectedSlotPos + 1
            --print(WS.SelectedSlotPos)
            if Weapons[WS.SelectedSlot] and WS.SelectedSlotPos > #Weapons[WS.SelectedSlot] then
                GetDown(Weapons)
            end
        elseif key == "lastinv" and IsValid(WS.LastInv) then
            WS.Show = 0
            WS.LastInv = WS.LastInv or "weapon_hands_sh"
            local oldwep = ply:GetActiveWeapon()
            input.SelectWeapon( WS.LastInv )
            WS.LastInv = oldwep
        end

    end
end

function WS.SetActuallyWeapon( ply, cmd )
    if not IsValid( ply ) or not ply:Alive() or GetGlobalBool("RadialInventory", false) then return end
    if (cmd:KeyDown( IN_ATTACK ) or cmd:KeyDown( IN_ATTACK2 )) and WS.Show > CurTime() then

        if WS.Selected and WS.Selected > CurTime() then
            cmd:RemoveKey(IN_ATTACK)
            cmd:RemoveKey(IN_ATTACK2)
        else
            cmd:RemoveKey(IN_ATTACK)
            cmd:RemoveKey(IN_ATTACK2)
            --print(WS.GetSelectedWeapon())

            if IsValid(WS.GetSelectedWeapon()) then
                WS.LastInv = WS.LastInv ~= ply:GetActiveWeapon() and WS.LastInv or ply:GetActiveWeapon()
                input.SelectWeapon( WS.GetSelectedWeapon() )
            end
            cmd:RemoveKey(IN_ATTACK)
            cmd:RemoveKey(IN_ATTACK2)

            WS.LastSelectedSlot = WS.SelectedSlot
            WS.LastSelectedSlotPos = WS.SelectedSlotPos
            WS.Selected = CurTime() + 0.2
            WS.Show = CurTime() + 0.2
            surface.PlaySound("arc9_eft_shared/weapon_generic_spin"..math.random(1,10)..".ogg")
        end
    end
end

hook.Add( "PlayerBindPress", "WeaponSelector_PlayerBindPress", WS.ChangeSelectionWep )

hook.Add( "HUDPaint", "WeaponSelector_Draw", function()
    WS.WeaponSelectorDraw( LocalPlayer() )
end)

hook.Add( "StartCommand", "WeaponSelector_StartCommand", WS.SetActuallyWeapon )

local tHideElements = {
    ["CHudWeaponSelection"] = true
}

hook.Add("HUDShouldDraw", "WeaponSelector_HUDShouldDraw", function(sElementName)
    if tHideElements[sElementName] then return false end
end)

-- Я ТАК ЗАДОЛБАЛСЯ ПРОСТО УБЕЙТЕ МЕНЯ ХАХАХАХАХАХАХАХАХАХААХАХАХАХАХАХА
-- ПОЛЧАСА Я ПЫТАЛСЯ СДЕЛАТЬ НОРМЛАЬНОЕ ПЕРЕКЛЮЧЕНИЕ ГОВНА!!!
-- ЗАТО ПОЛУЧИЛОСЬ!!!!
-- УЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭ
--[[
    /\_/\
    |_ _|
    |   |__
   /_|_____\ -- IT'S SO OVER
--]]