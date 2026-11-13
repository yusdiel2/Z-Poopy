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
WS.SlotPres = {}
WS.SlotItems = {}

WS.InfoSlot = nil
WS.InfoWep = nil
WS.InfoGlide = 0
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
    local WeaponsGet = ply:GetWeapons()
    local FormatedTable = {
        [0] = {}, [1] = {}, [2] = {}, [3] = {}, [4] = {}, [5] = {},
    }

    table.sort(WeaponsGet, function(a, b) return (a.SlotPos or 0) > (b.SlotPos or 0) end)

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

function WS.WeaponSelectorDraw( ply )
    if not IsValid( ply ) or not ply:Alive() or GetGlobalBool("RadialInventory", false) then return end
    if WS.Show < CurTime() then
        WS.SelectedSlot = WS.LastSelectedSlot
        WS.SelectedSlotPos = -1
        WS.InfoSlot = nil
        WS.SlotPres = {}
        WS.SlotItems = {}

        return
    end
    local Weapons = WS.GetWeaponTable( ply )
    local SelectedWep = WS.GetSelectedWeapon()
    if not IsValid(SelectedWep) then return end

    if IsValid( WS.TrackedWep ) and WS.TrackedWep ~= SelectedWep then
        for s = 0, 5 do
            for pos = 0, #Weapons[s] do
                if Weapons[s][pos] == WS.TrackedWep then
                    WS.SelectedSlot, WS.SelectedSlotPos = s, pos
                    SelectedWep = WS.TrackedWep
                end
            end
        end
    end
    WS.TrackedWep = SelectedWep

    WS.Transparent = LerpFT( 0.2, WS.Transparent, math.min( WS.Show - CurTime(), 1 ) )

    local baseTransparent = WS.Transparent

    local pres = {}
    local total = 0
    for i = 0, 5 do
        local has = table.Count(Weapons[i]) > 0 and 1 or 0
        local raw = math.Approach( WS.SlotPres[i] or has, has, FrameTime() / 0.25 )
        WS.SlotPres[i] = raw
        local p = raw * raw * (3 - 2 * raw)
        pres[i] = p
        total = total + p * (scrW * 0.1 + scrW * 0.008)
    end
    total = total - scrW * 0.008

    local cursor = scrW / 2 - total / 2
    local infoWep

    for i = 0, 5 do
        local p = pres[i]
        if p <= 0 then continue end

        local slotTbl = Weapons[i]
        local live = table.Count(slotTbl) > 0

        local x = cursor
        cursor = cursor + p * (scrW * 0.1 + scrW * 0.008)

        local y = scrH * 0.055

        WS.Transparent = baseTransparent * p

        WS.DrawText( i + 1, "HomigradFontMedium", x + scrW * 0.1 / 2, scrH * 0.02, color_white, TEXT_ALIGN_CENTER )

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

            for idx, wep in ipairs( current ) do
                if not known[wep] then
                    local pos = 1
                    local prevWep = current[idx - 1]
                    if prevWep and known[prevWep] then
                        for k, it in ipairs( items ) do
                            if it.wep == prevWep then pos = k + 1 break end
                        end
                    end
                    local it = { wep = wep, p = 1 }
                    table.insert( items, pos, it )
                    known[wep] = it
                end
            end

            for k = #items, 1, -1 do
                local it = items[k]
                if inCurrent[it.wep] then
                    it.p = 1
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
                    local h = Lerp( expand, scrH * 0.028, scrH * 0.12 )
                    it.lastH = h

                    draw.RoundedBox( 0, x, y, scrW * 0.1, h, ColorAlpha(color_black, WS.Transparent * 205) )
                    draw.RoundedBox( 0, x, y + h - 2, scrW * 0.1, 2, ColorAlpha(color_black, WS.Transparent * 205) )

                    if SelectedWep == wep then
                        surface.SetDrawColor( 155, 0, 0, WS.Transparent * 200 )
                        surface.SetMaterial( gradient_u )
                        surface.DrawTexturedRect( x, y, scrW * 0.1, h )

                        surface.SetDrawColor( 255, 0, 0, WS.Transparent * 155 )
                        surface.DrawOutlinedRect( x, y, scrW * 0.1, h, 2 )

                        local cornerY = y + h + scrH * 0.004
                        if WS.InfoSlot ~= i then
                            WS.InfoSlot = i
                            WS.InfoAlpha = 0
                            WS.InfoWep = wep
                            WS.InfoGlide = 0
                        elseif WS.InfoWep ~= wep then
                            WS.InfoGlide = WS.InfoY - cornerY
                            WS.InfoWep = wep
                        end
                        WS.InfoGlide = LerpFT( 0.2, WS.InfoGlide, 0 )
                        WS.InfoX = x + scrW * 0.1 + scrW * 0.004
                        WS.InfoY = cornerY + WS.InfoGlide
                        WS.InfoAlpha = LerpFT( 0.2, WS.InfoAlpha, 1 )
                        infoWep = wep

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

                    WS.DrawText( it.name, "HomigradFontSmall", x + scrW * 0.1 / 2, y + 2.5, color_white, TEXT_ALIGN_CENTER )

                    y = y + h
                else
                    local h = it.h or scrH * 0.028
                    DrawCollapsed( x, y, scrW * 0.1, h, it.name or "", baseTransparent * p )

                    y = y + h
                end
            end
        else
            for _, it in ipairs( items ) do
                local h = it.lastH or scrH * 0.028
                DrawCollapsed( x, y, scrW * 0.1, h, it.name or "", baseTransparent * p )
                y = y + h
            end
        end

        WS.Transparent = baseTransparent
    end

    if infoWep and infoWep.PrintWeaponInfo then
        infoWep:PrintWeaponInfo( WS.InfoX, WS.InfoY, WS.Transparent * 255 * WS.InfoAlpha )
    end
end

local tAcceptKeys = {
    ["slot1"] = 1,
    ["slot2"] = 2,
    ["slot3"] = 3,
    ["slot4"] = 4,
    ["slot5"] = 5,
    ["slot6"] = 6,
}

local function GetUpper(Weapons)
    if #LocalPlayer():GetWeapons() < 1 then return end
    WS.SelectedSlot = WS.SelectedSlot < 0 and #Weapons or WS.SelectedSlot - 1
    WS.SelectedSlotPos = Weapons[WS.SelectedSlot] and #Weapons[WS.SelectedSlot] or 0

    if Weapons[WS.SelectedSlot] == nil or Weapons[WS.SelectedSlot][WS.SelectedSlotPos] == nil then
        GetUpper(Weapons)
    end
end

local function GetDown(Weapons)
    if #LocalPlayer():GetWeapons() < 1 then return end
    WS.SelectedSlot = WS.SelectedSlot > #Weapons and 0 or WS.SelectedSlot + 1
    WS.SelectedSlotPos = 0

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
    local iPos = tAcceptKeys[ key ]
    if iPos or key == "invnext" or key == "invprev" or key == "lastinv" then

        local Weapons = WS.GetWeaponTable( ply )

        WS.Show = CurTime() + 4
        WS.TrackedWep = nil
        surface.PlaySound("arc9_eft_shared/weapon_generic_rifle_spin"..math.random(10)..".ogg")
        if iPos then
            iPos = iPos - 1
            if LastSelected ~= iPos then
                WS.SelectedSlotPos = -1
            end
            WS.SelectedSlotPos = (Weapons[iPos] and LastSelected == iPos and WS.SelectedSlotPos + 1 > #Weapons[iPos] and 0 or math.min( WS.SelectedSlotPos + 1, #Weapons[iPos] )) or 0
            WS.SelectedSlot = iPos
            LastSelected = iPos
        elseif key == "invprev" then
            WS.SelectedSlotPos = WS.SelectedSlotPos - 1
            if Weapons[WS.SelectedSlot] and WS.SelectedSlotPos < 0  then
                GetUpper(Weapons)
            end
        elseif key == "invnext" then
            WS.SelectedSlotPos = WS.SelectedSlotPos + 1
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