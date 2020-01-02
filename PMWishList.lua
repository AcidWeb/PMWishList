local _G = _G
local _, PM = ...
_G.PMWishList = PM

local wipe, date, tContains = _G.wipe, _G.date, _G.tContains
local CreateFrame = _G.CreateFrame
local CreateTextureMarkup = _G.CreateTextureMarkup
local NewTimer = _G.C_Timer.NewTimer
local GameTooltip_Hide = _G.GameTooltip_Hide
local GetItemInfo = _G.GetItemInfo
local GetInstanceInfo = _G.GetInstanceInfo
local GetTexCoordsForRole = _G.GetTexCoordsForRole
local UnitInRaid = _G.UnitInRaid
local UnitClass = _G.UnitClass
local UnitGroupRolesAssigned = _G.UnitGroupRolesAssigned
local EJ_GetEncounterInfoByIndex = _G.EJ_GetEncounterInfoByIndex
local EJ_GetInstanceInfo = _G.EJ_GetInstanceInfo
local EJ_InstanceIsRaid = _G.EJ_InstanceIsRaid
local hooksecurefunc = _G.hooksecurefunc

local GUI = LibStub("AceGUI-3.0")
local SER = LibStub("AceSerializer-3.0")
local COMM = LibStub("AceComm-3.0")
local DUMP = LibStub("LibTextDump-1.0")

PM.Version = 1
PM.EJButtonNumber = 10
PM.WishListData = {}
PM.PlayerData = {}
PM.InstanceWhitelist = {
  1179 -- The Eternal Palace
}
PM.Status = {
  [0] = {id = 1, text = "N"},
  [1] = {id = 2, text = "G"},
  [2] = {id = 3, text = "U"},
  [3] = {id = 4, text = "T"},
  [4] = {id = 0, text = "-"}
}
PM.StatusScore = {
  [1] = 1000,
  [2] = 100,
  [3] = 10,
  [4] = 1
}
PM.Roles = {
  ["TANK"] = CreateTextureMarkup([[Interface\LFGFrame\UI-LFG-ICON-ROLES]], 256, 256, 0, 0, GetTexCoordsForRole("TANK")),
  ["HEALER"] = CreateTextureMarkup([[Interface\LFGFrame\UI-LFG-ICON-ROLES]], 256, 256, 0, 0, GetTexCoordsForRole("HEALER")),
  ["DAMAGER"] = CreateTextureMarkup([[Interface\LFGFrame\UI-LFG-ICON-ROLES]], 256, 256, 0, 0, GetTexCoordsForRole("DAMAGER"))
}

SLASH_PMWL1 = "/pmwl"

function PM:OnLoad(self)
	self:RegisterEvent("ADDON_LOADED")
end

function PM:OnEvent(self, event, ...)
	if event == "ADDON_LOADED" then
    if ... == "PMWishList" then
      if not _G.PMWishListData then
        _G.PMWishListData = {}
      end
      PM.WishList = _G.PMWishListData
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

      _G.SlashCmdList["PMWL"] = function()
        local target = "GUILD"
        if UnitInRaid("PLAYER") then
          target = "RAID"
        end
        local _, type, _, _, _, _, _, instanceID = GetInstanceInfo()
        if not type == "raid" or not tContains(PM.InstanceWhitelist, instanceID) then
          instanceID = PM.InstanceWhitelist[#PM.InstanceWhitelist]
        end
        local data = {["version"] = PM.Version,
                      ["command"] = "request",
                      ["instanceID"] = instanceID}
        wipe(PM.WishListData)
        wipe(PM.PlayerData)
        COMM:SendCommMessage("PMWishList", SER:Serialize(data), target)
      end

      PM.DumpFrame = DUMP:New("|cFFF2E699PM|r WishList")
      if _G.AddOnSkins then
        local f = DUMP.frames[PM.DumpFrame]:GetName()
        _G.AddOnSkins[1]:SkinFrame(_G[f])
        _G.AddOnSkins[1]:CreateBackdrop(_G[f].scrollArea)
        _G.AddOnSkins[1]:SetOutside(_G[f].scrollArea.Backdrop, _G[f].scrollArea, 4, 4)
        _G.AddOnSkins[1]:SkinCloseButton(_G[f.."Close"])
        _G.AddOnSkins[1]:SkinScrollBar(_G[f].scrollArea.ScrollBar)
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

function PM:OnAddonMessage(msg, channel, sender)
  local status, payload = SER:Deserialize(msg)
  if status then
    if payload["command"] == "request" then
      if channel ~= "RAID" and channel ~= "GUILD" then
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
                      ["data"] = PM.WishList[payload["instanceID"]]}
        COMM:SendCommMessage("PMWishList", SER:Serialize(data), "WHISPER", sender)
      end
    elseif payload["command"] == "data" then
      if channel ~= "WHISPER" then
        return
      end
      if payload["version"] == PM.Version then
        PM.PlayerData[sender] = {["role"] = payload["role"], ["class"] = payload["class"]}
        if not PM.WishListData[payload["instanceID"]] then
          PM.WishListData[payload["instanceID"]] = {}
        end
        for i, _ in pairs(payload["data"]) do
          if not PM.WishListData[payload["instanceID"]][i] then
            PM.WishListData[payload["instanceID"]][i] = {}
          end
          for _, k in pairs(payload["data"][i]) do
            if k > 0 then
              if not PM.WishListData[payload["instanceID"]][i][sender] then
                PM.WishListData[payload["instanceID"]][i][sender] = {[1] = 0, [2] = 0, [3] = 0, [4] = 0, ["Score"] = 0}
              end
              PM.WishListData[payload["instanceID"]][i][sender][k] = PM.WishListData[payload["instanceID"]][i][sender][k] + 1
              PM.WishListData[payload["instanceID"]][i][sender]["Score"] = PM.WishListData[payload["instanceID"]][i][sender]["Score"] + PM.StatusScore[k]
            end
          end
        end
        if PM.Timer then
          PM.Timer:Cancel()
        end
        PM.Timer = NewTimer(1, PM.UpdateFrame)
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
    button:SetText(PM.Status[4]["text"])
    button:SetCallback("OnClick", function() PM:SetStatus(button, frame.encounterID, frame.itemID) end)
    button:SetCallback("OnEnter", function()
                                            _G.GameTooltip:SetOwner(button.frame, "ANCHOR_RIGHT")
                                            _G.GameTooltip:AddLine("N - Need")
                                            _G.GameTooltip:AddLine("I need this item for my main spec.", 1, 1, 1, false, 20)
                                            _G.GameTooltip:AddLine("G - Greed")
                                            _G.GameTooltip:AddLine("I need this item for my off spec.", 1, 1, 1, false, 20)
                                            _G.GameTooltip:AddLine("U - Upgrade")
                                            _G.GameTooltip:AddLine("I already have this item but want another version.", 1, 1, 1, false, 20)
                                            _G.GameTooltip:AddLine("T - Transmog")
                                            _G.GameTooltip:AddLine("I only need this item for transmog.", 1, 1, 1, false, 20)
                                            _G.GameTooltip:Show()
                                  end)
    button:SetCallback("OnLeave", function() GameTooltip_Hide() end)
    button.frame:SetParent(frame.PMWLHolder)
    button.frame:SetPoint("CENTER", 75, 0)
    button.frame:Show()
  end
end

function PM:UpdateButtons()
  local shouldShow = EJ_InstanceIsRaid() and tContains(PM.InstanceWhitelist, PM.EJ.instanceID)
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
    button:SetText(PM.Status[4]["text"])
  else
    button:SetText(PM.Status[PM.WishList[instanceID][encounterID][itemID] - 1]["text"])
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

  local status = PM.Status[PM.WishList[instanceID][encounterID][itemID]]
  button:SetText(status["text"])
  PM.WishList[instanceID][encounterID][itemID] = status["id"]
end

function PM:UpdateFrame()
  PM.DumpFrame:Clear()

  local _, type, _, _, _, _, _, instanceID = GetInstanceInfo()
  if not type == "raid" or not tContains(PM.InstanceWhitelist, instanceID) then
    instanceID = PM.InstanceWhitelist[#PM.InstanceWhitelist]
  end
  local instanceName = EJ_GetInstanceInfo(instanceID)
  PM.DumpFrame:AddLine("|cFFF2E699~~ "..instanceName.." || "..date("%m/%d/%y %H:%M:%S").." ~~|r")
  PM.DumpFrame:AddLine(" ")

  if PM.WishListData[instanceID] then
    local index = 1
    local name, _, encounterID = EJ_GetEncounterInfoByIndex(index, instanceID)
    while encounterID do
      PM.DumpFrame:AddLine("|cFFFF0000- "..name.." -|r")
      if PM.WishListData[instanceID][encounterID] then
        table.sort(PM.WishListData[instanceID][encounterID], PM.ScoreSort)
        for player, data in pairs(PM.WishListData[instanceID][encounterID]) do
          local wishList = PM:GetWishList(data)
          if wishList then
            PM.DumpFrame:AddLine("|c"..RAID_CLASS_COLORS[PM.PlayerData[player]["class"]].colorStr..player.."|r ||"..PM:GetRoleIcon(PM.PlayerData[player]["role"])..wishList)
          end
        end
      end
      PM.DumpFrame:AddLine(" ")

      index = index + 1
      name, _, encounterID = EJ_GetEncounterInfoByIndex(index, instanceID)
    end
  end

  PM.DumpFrame:Display()
end

function PM:GetWishList(data)
  if data["Score"] > 0 then
    return tostring(data[1]).."/"..tostring(data[2]).."/"..tostring(data[3]).."/"..tostring(data[4])
  end
end

function PM:GetRoleIcon(role)
  if role ~= "NONE" then
    return PM.Roles[role].."|| "
  else
    return " "
  end
end

function PM:CheckIfVanityItem(itemClassID, itemSubClassID)
	local vanityItem = false
	if itemClassID == 15 then -- Miscellaneous
		if itemSubClassID == 5 or itemSubClassID == 2 then -- Mount, Companion Pets
			vanityItem = true
		end
	elseif itemClassID == 0 then -- Consumable
		if itemSubClassID == 8 then -- Other
			vanityItem = true
		end
	end
	return vanityItem
end

function PM:ScoreSort(a, b)
  return a["Score"] < b["Score"]
end
