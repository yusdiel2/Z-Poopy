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
WS.SlotNames = {}

WS.InfoSlot = nil
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

function WS.WeaponSelectorDraw( ply )
    if not IsValid( ply ) or not ply:Alive() or GetGlobalBool("RadialInventory", false) then return end
    if WS.Show < CurTime() then
        WS.SelectedSlot = WS.LastSelectedSlot
        WS.SelectedSlotPos = -1
        WS.InfoSlot = nil
        WS.SlotPres = {}
        WS.SlotNames = {}

        return
    end
    local Weapons = WS.GetWeaponTable( ply )
    local SelectedWep = WS.GetSelectedWeapon()
    if not IsValid(SelectedWep) then return end
    WS.Transparent = LerpFT( 0.2, WS.Transparent, math.min( WS.Show - CurTime(), 1 ) )

    local w = scrW * 0.1
    local gap = scrW * 0.008
    local baseTransparent = WS.Transparent

    local pres = {}
    local total = 0
    for i = 0, 5 do
        local has = table.Count(Weapons[i]) > 0 and 1 or 0
        local p = LerpFT( 0.2, WS.SlotPres[i] or has, has )
        if has == 0 and p < 0.01 then p = 0 end
        WS.SlotPres[i] = p
        pres[i] = p
        total = total + p * (w + gap)
    end
    total = total - gap

    local cursor = scrW / 2 - total / 2
    local infoWep

    for i = 0, 5 do
        local p = pres[i]
        if p <= 0 then continue end

        local slotTbl = Weapons[i]
        local live = table.Count(slotTbl) > 0

        local x = cursor
        cursor = cursor + p * (w + gap)

        local y = scrH * 0.055
        local colTop = y
        local above = 0

        WS.Transparent = baseTransparent * p

        WS.DrawText( i + 1, "HomigradFontMedium", x + w / 2, scrH * 0.02, color_white, TEXT_ALIGN_CENTER )

        if live then
            local names = {}

            for Id = 0, #slotTbl do
                local wep = slotTbl[Id]
                if not wep then continue end

                local expand = LerpFT( 0.2, WS.Anim[wep] or 0, SelectedWep == wep and 1 or 0 )
                WS.Anim[wep] = expand
                local h = Lerp( expand, scrH * 0.028, scrH * 0.12 )
                local name = WS.GetPrintName(wep)
                names[#names + 1] = name

                draw.RoundedBox( 0, x, y, w, h, ColorAlpha(color_black, WS.Transparent * 205) )
                draw.RoundedBox( 0, x, y + h - 2, w, 2, ColorAlpha(color_black, WS.Transparent * 205) )

                if SelectedWep == wep then
                    surface.SetDrawColor( 155, 0, 0, WS.Transparent * 200 )
                    surface.SetMaterial( gradient_u )
                    surface.DrawTexturedRect( x, y, w, h )

                    surface.SetDrawColor( 255, 0, 0, WS.Transparent * 155 )
                    surface.DrawOutlinedRect( x, y, w, h, 2 )

                    local targetX = x + w + scrW * 0.004
                    local targetY = colTop + above * scrH * 0.028 + scrH * 0.12 + scrH * 0.004
                    if WS.InfoSlot ~= i then
                        WS.InfoSlot = i
                        WS.InfoAlpha = 0
                        WS.InfoX, WS.InfoY = targetX, targetY
                    else
                        WS.InfoX = targetX
                        WS.InfoY = LerpFT( 0.2, WS.InfoY, targetY )
                    end
                    WS.InfoAlpha = LerpFT( 0.2, WS.InfoAlpha, 1 )
                    infoWep = wep

                    if wep.DrawWeaponSelection then
                        render.SetScissorRect( math.floor( x ), math.floor( y ), math.ceil( x + w ), math.ceil( y + h ), true )
                        wep:DrawWeaponSelection(
                            x + 5,
                            y + scrH * 0.032,
                            w - 10,
                            h - scrH * 0.028,
                            WS.Transparent * 255
                        )
                        render.SetScissorRect( 0, 0, 0, 0, false )
                    end
                end

                WS.DrawText( name, "HomigradFontSmall", x + w / 2, y + 2.5, color_white, TEXT_ALIGN_CENTER )

                y = y + h
                above = above + 1
            end

            WS.SlotNames[i] = names
        else
            for _, name in ipairs( WS.SlotNames[i] or {} ) do
                local h = scrH * 0.028

                draw.RoundedBox( 0, x, y, w, h, ColorAlpha(color_black, WS.Transparent * 205) )
                draw.RoundedBox( 0, x, y + h - 2, w, 2, ColorAlpha(color_black, WS.Transparent * 205) )
                WS.DrawText( name, "HomigradFontSmall", x + w / 2, y + 2.5, color_white, TEXT_ALIGN_CENTER )

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