local _G = _G
local _, PM = ...
_G.PMWishList = PM

local wipe, tContains, tInsert, print, tostring, pairs, select, next, hooksecurefunc = _G.wipe, _G.tContains, _G.tinsert, _G.print, _G.tostring, _G.pairs, _G.select, _G.next, _G.hooksecurefunc
local Item = _G.Item
local CreateFrame = _G.CreateFrame
local CreateAtlasMarkup = _G.CreateAtlasMarkup
local CreateTextureMarkup = _G.CreateTextureMarkup
local After = _G.C_Timer.After
local GetItemInfo = _G.GetItemInfo
local GetServerTime = _G.GetServerTime
local GetTexCoordsForRole = _G.GetTexCoordsForRole
local GetActiveCovenantID = _G.C_Covenants.GetActiveCovenantID
local GetItemInventorySlotInfo = _G.GetItemInventorySlotInfo
local UnitClass = _G.UnitClass
local UnitInRaid = _G.UnitInRaid
local UnitGroupRolesAssigned = _G.UnitGroupRolesAssigned
local EJ_GetEncounterInfoByIndex = _G.EJ_GetEncounterInfoByIndex
local EJ_SelectInstance = _G.EJ_SelectInstance

local ST = LibStub("ScrollingTable")
local GUI = LibStub("AceGUI-3.0")
local SER = LibStub("AceSerializer-3.0")
local COMM = LibStub("AceComm-3.0")
local QTIP = LibStub("LibQTip-1.0")

PM.Version = 6
PM.DataVersion = 1
PM.EJButtonNumber = 10
PM.TableData = {}
PM.TableFilter = false
PM.InstanceWhitelist = {
  1188, -- De Other Side
  1185, -- Halls of Atonement
  1184, -- Mists of Tirna Scithe
  1183, -- Plaguefall
  1189, -- Sanguine Depths
  1186, -- Spires of Ascension
  1182, -- The Necrotic Wake
  1187, -- Theater of Pain
  1194, -- Tazavesh, the Veiled Market
  1190, -- Castle Nathria
  1193, -- Sanctum of Domination
  1195, -- Sepulcher of the First Ones
}
PM.Status = {
  [0] = {text = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:10:10:0:0|t"},
  [1] = {text = "|TInterface\\RaidFrame\\ReadyCheck-Ready:10:10:0:0|t"}
}
PM.Roles = {
  ["TANK"] = CreateTextureMarkup([[Interface\LFGFrame\UI-LFG-ICON-ROLES]], 256, 256, 0, 0, GetTexCoordsForRole("TANK")),
  ["HEALER"] = CreateTextureMarkup([[Interface\LFGFrame\UI-LFG-ICON-ROLES]], 256, 256, 0, 0, GetTexCoordsForRole("HEALER")),
  ["DAMAGER"] = CreateTextureMarkup([[Interface\LFGFrame\UI-LFG-ICON-ROLES]], 256, 256, 0, 0, GetTexCoordsForRole("DAMAGER"))
}
PM.Covenants = {
  [1] = CreateAtlasMarkup("covenantchoice-panel-sigil-kyrian"),
  [2] = CreateAtlasMarkup("covenantchoice-panel-sigil-venthyr"),
  [3] = CreateAtlasMarkup("covenantchoice-panel-sigil-nightfae"),
  [4] = CreateAtlasMarkup("covenantchoice-panel-sigil-necrolords")
}

_G.SLASH_PMWL1 = "/pmwl"

function PM:OnLoad(self)
	self:RegisterEvent("ADDON_LOADED")
end

function PM:OnEvent(self, event, ...)
	if event == "ADDON_LOADED" then
    if ... == "PMWishList" then
      if not _G.PMWishListData then
        _G.PMWishListData = {}
      end
      if not _G.PMWishListDB then
        _G.PMWishListDB = {["Players"] = {}, ["Lists"] = {}, ["DataVersion"] = PM.DataVersion}
      end
      if not _G.PMWishListDB["DataVersion"] or _G.PMWishListDB["DataVersion"] ~= PM.DataVersion then
        _G.PMWishListData = {}
        _G.PMWishListDB = {["Players"] = {}, ["Lists"] = {}, ["DataVersion"] = PM.DataVersion}
      end
      PM.WishList = _G.PMWishListData
      PM.WishListDB = _G.PMWishListDB
      for i, _ in pairs(PM.WishList) do
        for j, _ in pairs(PM.WishList[i]) do
          for k, v in pairs(PM.WishList[i][j]) do
            if v == 0 then
              PM.WishList[i][j][k] = nil
            end
          end
          if next(PM.WishList[i][j]) == nil then
            PM.WishList[i][j] = nil
          end
        end
        if next(PM.WishList[i]) == nil then
          PM.WishList[i] = nil
        end
      end

      _G.SlashCmdList["PMWL"] = function(_)
        wipe(PM.TableData)
        After(5, function() PM:SetupGUI(); PM:UpdateTable() end)
        local data = {["version"] = PM.Version,
                      ["command"] = "request",
                      ["instanceID"] = PM.InstanceWhitelist[#PM.InstanceWhitelist]}
        COMM:SendCommMessage("PMWishList", SER:Serialize(data), "GUILD")
      end

      COMM:RegisterComm("PMWishList", PM.OnAddonMessage)
    elseif ... == "Blizzard_EncounterJournal" then
      self:UnregisterEvent("ADDON_LOADED")

      for i=1, PM.EJButtonNumber do
        local frame = _G["EncounterJournalEncounterFrameInfoLootScrollFrameButton"..i]
        if frame then
            PM:AddButton(frame)
        end
      end

      PM.EJ = _G["EncounterJournal"]
      hooksecurefunc("EncounterJournal_SetLootButton", PM.UpdateButtons)
      _G["EncounterJournalEncounterFrameInfoLootScrollFrameScrollBar"]:HookScript("OnValueChanged", PM.UpdateButtons)
    end
  end
end

function PM:OnClick()
  PM.TableFilter = not PM.TableFilter
  if PM.TableFilter then
    PM.GUI.Button:SetText("Displaying raid members only")
  else
    PM.GUI.Button:SetText("Displaying entire guild")
  end
  PM.Table:SetFilter(PM.CustomFilter)
end

function PM:SetupGUI()
  if PM.Table then
    PM.GUI:Show()
    return
  end

  PM.GUI = GUI:Create("Window")
  PM.GUI:SetTitle("PM WishList")
  PM.GUI:EnableResize(false)
  PM.GUI.Button = GUI:Create("Button")
  PM.GUI.Button:SetText("Displaying entire guild")
  PM.GUI.Button:SetCallback("OnClick", PM.OnClick)
  PM.GUI:AddChild(PM.GUI.Button)

  EJ_SelectInstance(PM.InstanceWhitelist[#PM.InstanceWhitelist])
  local tableStructure = {
    {
      ["name"] = _G.NAME,
      ["width"] = 100,
      ["bgcolor"] = {
        ["r"] = 0.15,
        ["g"] = 0.15,
        ["b"] = 0.15,
        ["a"] = 1.0
      },
      ["align"] = "LEFT"
    }
  }
  local index = 1
  local name, _, encounterID = EJ_GetEncounterInfoByIndex(index)
  local colorToggle = false
  while encounterID do
    local column = {
      ["name"] = name,
      ["width"] = 75,
      ["align"] = "CENTER",
      ["encounterID"] = encounterID
    }
    if colorToggle then
      column["bgcolor"] = {["r"] = 0.15, ["g"] = 0.15, ["b"] = 0.15, ["a"] = 1.0}
    end
    colorToggle = not colorToggle
    tInsert(tableStructure, column)
    index = index + 1
    name, _, encounterID = EJ_GetEncounterInfoByIndex(index)
  end
  local bossIndex = index - 1
  for k, v in pairs(tableStructure) do
    v["comparesort"] = function (self, rowa, rowb, sortbycol) return PM:CustomSort(self, rowa, rowb, sortbycol, k + bossIndex + 1) end
  end

  PM.GUI:SetHeight(485)
  PM.GUI:SetWidth(bossIndex * 75 + 100 + 60)
  PM.GUI.Button:SetWidth(PM.GUI.frame:GetWidth() - 25)
  PM.Table = ST:CreateST(tableStructure, 25, nil, nil, PM.GUI.frame)
  PM.Table.bossIndex = bossIndex
  PM.Table:RegisterEvents({
    ["OnClick"] = function (_, cell, _, _, _, row, column, _, button, _)
      if row ~= nil and button == "LeftButton" and PM.Tooltip == nil and tonumber(cell.text:GetText()) ~= nil then
        local payload = PM.WishListDB.Lists[PM.InstanceWhitelist[#PM.InstanceWhitelist]][PM.Table.cols[column].encounterID][PM.Table.data[row][2 + PM.Table.bossIndex]]["Items"]
        PM.Tooltip = QTIP:Acquire("PMWishListTooltip", 3, "CENTER", "CENTER", "CENTER")
        for itemID, status in pairs(payload) do
          if status == 1 then
            local item = Item:CreateFromItemID(itemID)
            item:ContinueOnItemLoad(function()
              PM.Tooltip:AddLine("|T"..item:GetItemIcon()..":32|t", item:GetItemLink(), GetItemInventorySlotInfo(item:GetInventoryType()))
            end)
          end
        end
        PM.Tooltip:SmartAnchorTo(cell)
        PM.Tooltip:Show()
			end
    end,
    ["OnLeave"] = function (_, _, _, _, _, row, _)
			if row ~= nil and PM.Tooltip ~= nil then
				QTIP:Release(PM.Tooltip)
        PM.Tooltip = nil
			end
		end,
	})
  PM.Table.cols[1].sort = ST.SORT_DSC
  if _G.AddOnSkins then
    local f = PM.Table.frame
    _G.AddOnSkins[1]:SkinFrame(f, nil, true)
    _G.AddOnSkins[1]:StripTextures(_G[f:GetName().."ScrollTrough"], true)
    _G.AddOnSkins[1]:SkinScrollBar(_G[f:GetName().."ScrollFrameScrollBar"])
  end
  PM.Table.frame:ClearAllPoints()
  PM.Table.frame:SetPoint("CENTER", PM.GUI.frame, "CENTER", 0, -35)
end

function PM:UpdateTable()
  local row
  local instanceID = PM.InstanceWhitelist[#PM.InstanceWhitelist]
  EJ_SelectInstance(instanceID)

  for player, data in pairs(PM.WishListDB.Players) do
    row = {}
    tInsert(row, "|c".._G.RAID_CLASS_COLORS[data["class"]].colorStr..player.."|r"..PM:GetCovenantIcon(data["covenant"])..PM:GetRoleIcon(player, data["role"]))
    local index = 1
    local encounterID = select(3, EJ_GetEncounterInfoByIndex(index))
    while encounterID do
      tInsert(row, PM:GetWishList(instanceID, encounterID, player, false))
      index = index + 1
      encounterID = select(3, EJ_GetEncounterInfoByIndex(index))
    end
    tInsert(row, player)
    index = 1
    encounterID = select(3, EJ_GetEncounterInfoByIndex(index))
    while encounterID do
      tInsert(row, PM:GetWishList(instanceID, encounterID, player, true))
      index = index + 1
      encounterID = select(3, EJ_GetEncounterInfoByIndex(index))
    end
    tInsert(PM.TableData, row)
  end

  PM.Table:SetData(PM.TableData, true)
end

function PM:OnAddonMessage(msg, channel, sender)
  local status, payload = SER:Deserialize(msg)
  if status then
    if payload["command"] == "request" then
      if channel ~= "GUILD" then
        return
      end
      if payload["version"] > PM.Version then
        print("[|cFFF2E699PM WishList|r] Addon is out-of-date!")
        return
      end
      if PM.WishList[payload["instanceID"]] then
        local data = {["version"] = PM.Version,
                      ["command"] = "data",
                      ["instanceID"] = payload["instanceID"],
                      ["role"] = UnitGroupRolesAssigned("PLAYER"),
                      ["class"] = select(2, UnitClass("PLAYER")),
                      ["covenant"] = GetActiveCovenantID(),
                      ["data"] = PM.WishList[payload["instanceID"]]}
        COMM:SendCommMessage("PMWishList", SER:Serialize(data), "WHISPER", sender)
      end
    elseif payload["command"] == "data" then
      if channel ~= "WHISPER" then
        return
      end
      if payload["version"] == PM.Version then
        if not PM.CurrentEncounters then
          PM.CurrentEncounters = {}
          local index = 1
          EJ_SelectInstance(PM.InstanceWhitelist[#PM.InstanceWhitelist])
          local encounterID = select(3, EJ_GetEncounterInfoByIndex(index))
          while encounterID do
            tInsert(PM.CurrentEncounters, encounterID)
            index = index + 1
            encounterID = select(3, EJ_GetEncounterInfoByIndex(index))
          end
        end
        PM.WishListDB.Players[sender] = {["role"] = payload["role"], ["class"] = payload["class"], ["covenant"] = payload["covenant"], ["timestamp"] = GetServerTime()}
        if not PM.WishListDB.Lists[payload["instanceID"]] then
          PM.WishListDB.Lists[payload["instanceID"]] = {}
        end
        for _, i in pairs(PM.CurrentEncounters) do
          if not PM.WishListDB.Lists[payload["instanceID"]][i] then
            PM.WishListDB.Lists[payload["instanceID"]][i] = {}
          end
          PM.WishListDB.Lists[payload["instanceID"]][i][sender] = nil
          if payload["data"][i] then
            for itemID, k in pairs(payload["data"][i]) do
              if k > 0 then
                if not PM.WishListDB.Lists[payload["instanceID"]][i][sender] then
                  PM.WishListDB.Lists[payload["instanceID"]][i][sender] = {[1] = 0, ["Score"] = 0, ["Items"] = {}}
                end
                PM.WishListDB.Lists[payload["instanceID"]][i][sender][k] = PM.WishListDB.Lists[payload["instanceID"]][i][sender][k] + 1
                PM.WishListDB.Lists[payload["instanceID"]][i][sender]["Score"] = PM.WishListDB.Lists[payload["instanceID"]][i][sender]["Score"] + 1
                PM.WishListDB.Lists[payload["instanceID"]][i][sender]["Items"][itemID] = k
              end
            end
          end
        end
      end
    end
  end
end

function PM:AddButton(frame)
  if not frame.PMWLHolder then
    frame.PMWLHolder = CreateFrame("Frame", nil, frame)
    frame.PMWLHolder:SetAllPoints(frame)

    local button = GUI:Create("Button")
    frame.PMWLHolder.Button = button
    button:SetWidth(45)
    button:SetHeight(45)
    button:SetText(PM.Status[1]["text"])
    button:SetCallback("OnClick", function() PM:SetStatus(button, frame.encounterID, frame.itemID) end)
    button.frame:SetParent(frame.PMWLHolder)
    button.frame:ClearAllPoints()
    button.frame:SetPoint("CENTER", 150, 0)
    button.frame:Show()
  end
end

function PM:UpdateButtons()
  local shouldShow = tContains(PM.InstanceWhitelist, PM.EJ.instanceID)
  for i=1, PM.EJButtonNumber do
    local frame = _G["EncounterJournalEncounterFrameInfoLootScrollFrameButton"..i]
    if frame and frame.PMWLHolder then
      if shouldShow and frame.itemID then
        local itemClassID, itemSubClassID = select(12, GetItemInfo(frame.itemID))
        if not PM:CheckIfVanityItem(itemClassID, itemSubClassID) then
          PM:GetStatus(frame.PMWLHolder.Button, frame.encounterID, frame.itemID)
          frame.PMWLHolder:Show()
        else
          frame.PMWLHolder:Hide()
        end
      else
        frame.PMWLHolder:Hide()
      end
    end
  end
end

function PM:GetStatus(button, encounterID, itemID)
  local instanceID = PM.EJ.instanceID
  if not instanceID or instanceID == 0 then
    return
  end

  if not PM.WishList[instanceID] or not PM.WishList[instanceID][encounterID] or not PM.WishList[instanceID][encounterID][itemID] or PM.WishList[instanceID][encounterID][itemID] == 0 then
    button:SetText(PM.Status[0]["text"])
  else
    button:SetText(PM.Status[1]["text"])
  end
end

function PM:SetStatus(button, encounterID, itemID)
  local instanceID = PM.EJ.instanceID
  if not instanceID or instanceID == 0 then
    return
  end

  if not PM.WishList[instanceID] then
    PM.WishList[instanceID] = {}
  end
  if not PM.WishList[instanceID][encounterID] then
    PM.WishList[instanceID][encounterID] = {}
  end
  if not PM.WishList[instanceID][encounterID][itemID] then
    PM.WishList[instanceID][encounterID][itemID] = 0
  end

  if PM.WishList[instanceID][encounterID][itemID] == 0 then
    button:SetText(PM.Status[1]["text"])
    PM.WishList[instanceID][encounterID][itemID] = 1
  else
    button:SetText(PM.Status[0]["text"])
    PM.WishList[instanceID][encounterID][itemID] = 0
  end
end

function PM:GetWishList(instanceID, encounterID, player, raw)
  if PM.WishListDB.Lists[instanceID] then
    if PM.WishListDB.Lists[instanceID][encounterID] then
      if PM.WishListDB.Lists[instanceID][encounterID][player] then
        local data = PM.WishListDB.Lists[instanceID][encounterID][player]
        if raw then
          return data["Score"]
        elseif data[1] > 0 then
          return tostring(data[1])
        else
          return "-"
        end
      else
        return raw and 0 or "-"
      end
    else
      return raw and 0 or "-"
    end
  else
    return raw and 0 or "-"
  end
end

function PM:GetRoleIcon(name, role)
  if UnitInRaid(name) and role ~= "NONE" then
    return " "..PM.Roles[role]
  else
    return ""
  end
end

function PM:GetCovenantIcon(covenant)
  if covenant and covenant > 0 then
    return " "..PM.Covenants[covenant]
  else
    return ""
  end
end

function PM:CheckIfVanityItem(itemClassID, itemSubClassID)
  local vanityItem = false
	if itemClassID == 15 then -- Miscellaneous
		if itemSubClassID == 5 or itemSubClassID == 2 then -- Mount, Companion Pets
			vanityItem = true
    end
  elseif itemClassID == 12 then -- Quest
		if itemSubClassID == 0 then -- Quest
			vanityItem = true
    end
  elseif itemClassID == 1 then -- Container
		if itemSubClassID == 0 then -- Bag
			vanityItem = true
    end
	end
	return vanityItem
end

function PM:CustomFilter(rowdata)
  if PM.TableFilter then
    return UnitInRaid(rowdata[PM.Table.bossIndex + 2])
  else
    return true
  end
end

function PM:CustomSort(obj, rowa, rowb, sortbycol, fieldID)
	local column = obj.cols[sortbycol]
	local direction = column.sort or column.defaultsort or ST.SORT_ASC
  local rowA = obj.data[rowa][fieldID]
  local rowB = obj.data[rowb][fieldID]
	if rowA == rowB then
		return false
	else
		if direction == ST.SORT_ASC then
			return rowA > rowB
		else
			return rowA < rowB
		end
	end
end
