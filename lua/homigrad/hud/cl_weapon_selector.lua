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
WS.SlotVis = {}
WS.SlotNames = {}

WS.InfoSlot = nil
WS.InfoWep = nil
WS.InfoGlide = 0
WS.InfoFloor = 0
WS.InfoAlpha = 0
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
    WS.InfoFloor = 0
    WS.LastSet = nil
    WS.SlotPres = {}
    WS.SlotVis = {}
    WS.SlotNames = {}
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
        local removed = not s
        if removed then
            s, pos = FindNearest( Weapons, WS.TrackedSlot or 0, WS.TrackedPos or 0 )
        end
        if s then
            WS.SelectedSlot, WS.SelectedSlotPos = s, pos
            SelectedWep = Weapons[s][pos]
            if removed and IsValid( SelectedWep ) then WS.Anim[SelectedWep] = 1 end
        end
    end
    WS.TrackedWep = SelectedWep
    WS.TrackedSlot, WS.TrackedPos = FindWeapon( Weapons, SelectedWep )

    local nowSet = {}
    for slot = 0, 5 do
        for _, w in pairs( Weapons[slot] ) do
            nowSet[w] = true
            if WS.LastSet and not WS.LastSet[w] then
                WS.Anim[w] = SelectedWep == w and 1 or 0
            end
        end
    end
    WS.LastSet = nowSet

    WS.Transparent = LerpFT( 0.2, WS.Transparent, math.min( WS.Show - CurTime(), 1 ) )
    local baseTransparent = WS.Transparent
    --draw.RoundedBox(0,(scrW / 2)-10,(scrH *0.15),20,20, color_red )

    local pres = {}
    local vis = {}
    local total = 0
    for i = 0, 5 do
        local has = table.Count(Weapons[i]) > 0 and 1 or 0
        local space = WS.SlotPres[i] or has
        local show = WS.SlotVis[i] or has

        local spaceTarget = has == 1 and 1 or (show <= 0.35 and 0 or space)
        space = LerpFT( 0.2, space, spaceTarget )
        if math.abs( space - spaceTarget ) < 0.01 then space = spaceTarget end

        local showTarget = (has == 1 and space >= 1) and 1 or 0
        show = LerpFT( 0.2, show, showTarget )
        if math.abs( show - showTarget ) < 0.01 then show = showTarget end

        WS.SlotPres[i] = space
        WS.SlotVis[i] = show
        pres[i] = space
        vis[i] = show
        total = total + space * (scrW * 0.1 + scrW * 0.008)
    end
    total = total - scrW * 0.008

    local cursor = scrW / 2 - total / 2
    local infoWep
    local infoCol
    local cols = {}

    for i = 0, 5 do
        local p = pres[i]
        local v = vis[i]
        if p <= 0 then
            WS.SlotNames[i] = nil
            continue
        end

        local slotTbl = Weapons[i]
        local x = cursor
        cursor = cursor + p * (scrW * 0.1 + scrW * 0.008)

        if v <= 0 then continue end

        local y = scrH * 0.055
        local restY = y

        WS.Transparent = baseTransparent * v

        WS.DrawText( i + 1, "HomigradFontMedium", x + scrW * 0.1 / 2, scrH * 0.02, color_white, TEXT_ALIGN_CENTER )

        --  draw.RoundedBox(
        --      1,
        --      position,
        --      (scrH *0.01),
        --      sizeX,
        --      (scrH *0.02), 
        --      ColorAlpha(color_black,WS.Transparent*255) 
        --  )
        --if slotTbl and table.Count(slotTbl) < 0 then continue end

        if table.Count(slotTbl) > 0 then
            local kept = {}
            local list = {}
            local yy = y
            local finalYY = y
            for Id = 0, #slotTbl do
                local wep = slotTbl[Id]
                if not wep then continue end
                --print(wepId,wep)

                local expand = LerpFT( 0.2, WS.Anim[wep] or 0, SelectedWep == wep and 1 or 0 )
                WS.Anim[wep] = expand
                local fullH = Lerp( expand, scrH * 0.028, scrH * 0.12 )
                local h = fullH
                local ty = math.Round( yy )
                finalYY = finalYY + (SelectedWep == wep and scrH * 0.12 or scrH * 0.028)
                list[#list + 1] = {
                    wep = wep,
                    name = WS.GetPrintName( wep ),
                    ty = ty,
                    hh = math.Round( yy + h ) - ty,
                    bot = yy + h,
                    finalBot = finalYY,
                    restAbove = restY,
                }
                kept[#kept + 1] = { name = list[#list].name, h = fullH }
                yy = yy + h
                restY = restY + scrH * 0.028
            end
            WS.SlotNames[i] = kept

            for k, it in ipairs( list ) do
                local wep = it.wep
                local dy, hh = it.ty, it.hh
                local sx, sy, sx2, sy2 = math.floor( x ), math.floor( dy ), math.ceil( x + scrW * 0.1 ), math.ceil( dy + hh )

                render.SetScissorRect( sx, sy, sx2, sy2, true )
                draw.RoundedBox( 0, x, dy, scrW * 0.1, hh, ColorAlpha(color_black, WS.Transparent * 205) )
                draw.RoundedBox( 0, x, dy + math.max( hh - 2, 0 ), scrW * 0.1, math.min( hh, 2 ), ColorAlpha(color_black, WS.Transparent * 205) )

                if SelectedWep == wep then
                    surface.SetDrawColor( 155, 0, 0, WS.Transparent * 200 )
                    surface.SetMaterial( gradient_u )
                    surface.DrawTexturedRect( x, dy, scrW * 0.1, hh )

                    surface.SetDrawColor( 255, 0, 0, WS.Transparent * 155 )
                    surface.DrawOutlinedRect( x, dy, scrW * 0.1, hh, 2 )

                    local cornerY = it.finalBot + scrH * 0.004
                    if WS.InfoSlot ~= i then
                        WS.InfoSlot = i
                        WS.InfoAlpha = 0
                        WS.InfoWep = wep
                        WS.InfoGlide = 0
                        WS.InfoDodgeSnap = true
                    elseif WS.InfoWep ~= wep then
                        WS.InfoGlide = WS.InfoY - cornerY
                        WS.InfoWep = wep
                    end
                    WS.InfoGlide = LerpFT( 0.2, WS.InfoGlide, 0 )
                    WS.InfoX = x + scrW * 0.1 + scrW * 0.004
                    WS.InfoY = cornerY + WS.InfoGlide
                    WS.InfoAlpha = LerpFT( 0.2, WS.InfoAlpha, 1 )
                    infoWep = wep
                    infoCol = i

                    if wep.DrawWeaponSelection then
                        wep:DrawWeaponSelection(
                            x + 5,
                            dy + scrH * 0.032,
                            scrW * 0.1 - 10,
                            hh - scrH * 0.028,
                            WS.Transparent * 255
                        )
                    end
                end

                WS.DrawText( it.name, "HomigradFontSmall", x + scrW * 0.1 / 2, dy + 2.5, color_white, TEXT_ALIGN_CENTER )
                render.SetScissorRect( 0, 0, 0, 0, false )
            end
        else
            for _, it in ipairs( WS.SlotNames[i] or {} ) do
                local h = it.h
                local ty = math.Round( y )
                DrawCollapsed( x, ty, scrW * 0.1, math.Round( y + h ) - ty, it.name, baseTransparent * v )
                y = y + h
                restY = restY + h
            end
        end

        cols[#cols + 1] = { idx = i, x = x, restBottom = restY }
        WS.Transparent = baseTransparent
    end

    if infoWep and infoWep.PrintWeaponInfo then
        local blurbW = 260
        local top = WS.InfoY
        local floorTarget = 0
        for _, c in ipairs( cols ) do
            if c.idx ~= infoCol then
                local overlapX = math.min( c.x + scrW * 0.1, WS.InfoX + blurbW ) - math.max( c.x, WS.InfoX )
                local weight = math.Clamp( overlapX / (scrW * 0.02), 0, 1 )
                weight = weight * weight * (3 - 2 * weight)
                floorTarget = math.max( floorTarget, weight * (c.restBottom + scrH * 0.008) )
            end
        end

        if WS.InfoDodgeSnap then
            WS.InfoFloor = floorTarget
            WS.InfoDodgeSnap = false
        end
        WS.InfoFloor = math.max( LerpFT( 0.2, WS.InfoFloor, floorTarget ), top )

        WS.InfoY = WS.InfoFloor
        infoWep:PrintWeaponInfo( WS.InfoX, WS.InfoY, WS.Transparent * 255 * WS.InfoAlpha )
        WS.InfoY = top
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