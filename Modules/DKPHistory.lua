local _, core = ...;
local _G = _G;
local CommDKP = core.CommDKP;
local L = core.L;

local players;
local reason;
local dkp;
local formdate = date;
local date;
local year;
local month;
local day;
local timeofday;
local ostime = time;
local player_table = {};
local classSearch;
local playerString = "";
local filter;
local c;
local maxDisplayed = 10
local currentLength = 10;
local currentRow = 0;
local btnText = 10;
local curDate;
local history = {};
local menuFrame = CreateFrame("Frame", "CommDKPDeleteDKPMenuFrame", UIParent, "UIDropDownMenuTemplate")

function CommDKP:SortDKPHistoryTable()             -- sorts the DKP History Table by date/time
  table.sort(CommDKP:GetTable(CommDKP_DKPHistory, true), function(a, b)
    return a["date"] > b["date"]
  end)
end

local function GetSortOptions()
	local PlayerList = {}
	for i=1, #CommDKP:GetTable(CommDKP_DKPTable, true) do
		local playerSearch = CommDKP:Table_Search(PlayerList, CommDKP:GetTable(CommDKP_DKPTable, true)[i].player)
		if not playerSearch then
			tinsert(PlayerList, CommDKP:GetTable(CommDKP_DKPTable, true)[i].player)
		end
	end
	table.sort(PlayerList, function(a, b)
		return a < b
	end)
	return PlayerList;
end

function CommDKP:DKPHistory_Reset()
	if not CommDKP.ConfigTab6 then return end
	currentRow = 0
	currentLength = maxDisplayed;
	curDate = nil;
	btnText = maxDisplayed;
	if CommDKP.ConfigTab6.loadMoreBtn then
		CommDKP.ConfigTab6.loadMoreBtn:SetText(L["LOAD"].." "..btnText.." "..L["MORE"].."...")
	end

	if CommDKP.ConfigTab6.history then
		for i=1, #CommDKP.ConfigTab6.history do
			if CommDKP.ConfigTab6.history[i] then
				CommDKP.ConfigTab6.history[i].h:SetText("")
				CommDKP.ConfigTab6.history[i].h:Hide()
				CommDKP.ConfigTab6.history[i].d:SetText("")
				CommDKP.ConfigTab6.history[i].d:Hide()
				CommDKP.ConfigTab6.history[i].s:SetText("")
				CommDKP.ConfigTab6.history[i].s:Hide()
				CommDKP.ConfigTab6.history[i]:SetHeight(10)
				CommDKP.ConfigTab6.history[i]:Hide()
			end
		end
	end
end

function CommDKP:DKPHistoryFilterBox_Create()
	local PlayerList = GetSortOptions();
	local curSelected = 0;

	-- Create the dropdown, and configure its appearance
	if not filterDropdown then
		filterDropdown = CreateFrame("FRAME", "CommDKPDKPHistoryFilterNameDropDown", CommDKP.ConfigTab6, "CommunityDKPUIDropDownMenuTemplate")
	end

	-- Create and bind the initialization function to the dropdown menu
	UIDropDownMenu_Initialize(filterDropdown, function(self, level, menuList)
		local filterName = UIDropDownMenu_CreateInfo()
		local ranges = {1}
		while ranges[#ranges] < #PlayerList do
			table.insert(ranges, ranges[#ranges]+20)
		end

		if (level or 1) == 1 then
			local numSubs = ceil(#PlayerList/20)
			filterName.func = self.FilterSetValue
			filterName.text, filterName.arg1, filterName.arg2, filterName.checked, filterName.isNotRadio = L["NOFILTER"], L["NOFILTER"], L["NOFILTER"], L["NOFILTER"] == curfilterName, true
			UIDropDownMenu_AddButton(filterName)
			filterName.text, filterName.arg1, filterName.arg2, filterName.checked, filterName.isNotRadio = L["DELETEDENTRY"], L["DELETEDENTRY"], L["DELETEDENTRY"], L["DELETEDENTRY"] == curfilterName, true
			UIDropDownMenu_AddButton(filterName)
		
			for i=1, numSubs do
				local max = i*20;
				if max > #PlayerList then max = #PlayerList end
				filterName.text, filterName.checked, filterName.menuList, filterName.hasArrow = strsub(PlayerList[((i*20)-19)], 1, 1).."-"..strsub(PlayerList[max], 1, 1), curSelected >= (i*20)-19 and curSelected <= i*20, i, true
				UIDropDownMenu_AddButton(filterName)
			end
			
		else
			filterName.func = self.FilterSetValue
			for i=ranges[menuList], ranges[menuList]+19 do
				if PlayerList[i] then
					local classSearch = CommDKP:Table_Search(CommDKP:GetTable(CommDKP_DKPTable, true), PlayerList[i])
				    local c;

				    if classSearch then
				     	c = CommDKP:GetCColors(CommDKP:GetTable(CommDKP_DKPTable, true)[classSearch[1][1]].class)
				    else
				     	c = { hex="ff444444" }
				    end
					filterName.text, filterName.arg1, filterName.arg2, filterName.checked, filterName.isNotRadio = "|c"..c.hex..PlayerList[i].."|r", PlayerList[i], "|c"..c.hex..PlayerList[i].."|r", PlayerList[i] == curfilterName, true
					UIDropDownMenu_AddButton(filterName, level)
				end
			end
		end
	end)

	filterDropdown:SetPoint("TOPRIGHT", CommDKP.ConfigTab6, "TOPRIGHT", -13, -11)

	UIDropDownMenu_SetWidth(filterDropdown, 150)
	UIDropDownMenu_SetText(filterDropdown, curfilterName or L["NOFILTER"])
	
  -- Dropdown Menu Function
  function filterDropdown:FilterSetValue(newValue, arg2)
    if curfilterName ~= newValue then curfilterName = newValue else curfilterName = nil end
    UIDropDownMenu_SetText(filterDropdown, arg2)
    
    if newValue == L["NOFILTER"] then
    	filter = nil;
    	maxDisplayed = 10; 				
    	curSelected = 0
    elseif newValue == L["DELETEDENTRY"] then
    	filter = newValue;
    	maxDisplayed = 10; 				
    	curSelected = 0
    else
	    filter = newValue;
	    maxDisplayed = 30;
	    local search = CommDKP:Table_Search(PlayerList, newValue)
	    curSelected = search[1]
    end

    CommDKP:DKPHistory_Update(true)
    CloseDropDownMenus()
  end
end

local function CommDKPDeleteDKPEntry(index, timestamp, item)  -- index = entry index (Vapok-1), item = # of the entry on DKP History tab; may be different than the key of DKPHistory if hidden fields exist
	-- pop confirmation. If yes, cycles through CommDKP:GetTable(CommDKP_DKPHistory, true).players and every name it finds, it refunds them (or strips them of) dkp.
	-- if deleted is the weekly decay,     curdkp * (100 / (100 - decayvalue))
	local reason_header = CommDKP.ConfigTab6.history[item].d:GetText();
	if strfind(reason_header, L["OTHER"].."- ") then reason_header = reason_header:gsub(L["OTHER"].." -- ", "") end
	if strfind(reason_header, "%%") then
		reason_header = gsub(reason_header, "%%", "%%%%")
	end
	local confirm_string = L["CONFIRMDELETEENTRY1"]..":\n\n"..reason_header.."\n\n|CFFFF0000"..L["WARNING"].."|r: "..L["DELETEENTRYREFUNDCONF"];

	StaticPopupDialogs["CONFIRM_DELETE"] = {

		text = confirm_string,
		button1 = L["YES"],
		button2 = L["NO"],
		OnAccept = function()

		-- add new entry and add "delted_by" field to entry being "deleted". make new entry exact opposite of "deleted" entry
		-- new entry gets "deletes", old entry gets "deleted_by", deletes = deleted_by index. and vice versa
			local search = CommDKP:Table_Search(CommDKP:GetTable(CommDKP_DKPHistory, true), index, "index")

			if search then
				local players = {strsplit(",", strsub(CommDKP:GetTable(CommDKP_DKPHistory, true)[search[1][1]].players, 1, -2))} 	-- cuts off last "," from string to avoid creating an empty value
				local dkp, mod;
				local dkpString = "";
				local curOfficer = UnitName("player")
				local curTime = time()
				local newIndex = curOfficer.."-"..curTime

				if strfind(CommDKP:GetTable(CommDKP_DKPHistory, true)[search[1][1]].dkp, "%-%d*%.?%d+%%") then 		-- determines if it's a mass decay
					dkp = {strsplit(",", CommDKP:GetTable(CommDKP_DKPHistory, true)[search[1][1]].dkp)}
					mod = "perc";
				else
					dkp = CommDKP:GetTable(CommDKP_DKPHistory, true)[search[1][1]].dkp
					mod = "whole"
				end

				for i=1, #players do
					if mod == "perc" then
						local search = CommDKP:Table_Search(CommDKP:GetTable(CommDKP_DKPTable, true), players[i])

						if search then
							local inverted = tonumber(dkp[i]) * -1
							CommDKP:GetTable(CommDKP_DKPTable, true)[search[1][1]].dkp = CommDKP:GetTable(CommDKP_DKPTable, true)[search[1][1]].dkp + inverted
							dkpString = dkpString..inverted..",";

							if i == #players then
								dkpString = dkpString..dkp[#dkp]
							end
						end
					else
						local search = CommDKP:Table_Search(CommDKP:GetTable(CommDKP_DKPTable, true), players[i])

						if search then
							local inverted = tonumber(dkp) * -1

							CommDKP:GetTable(CommDKP_DKPTable, true)[search[1][1]].dkp = CommDKP:GetTable(CommDKP_DKPTable, true)[search[1][1]].dkp + inverted

							if tonumber(dkp) > 0 then
								CommDKP:GetTable(CommDKP_DKPTable, true)[search[1][1]].lifetime_gained = CommDKP:GetTable(CommDKP_DKPTable, true)[search[1][1]].lifetime_gained + inverted
							end
							
							dkpString = inverted;
						end
					end
				end
				
				CommDKP:GetTable(CommDKP_DKPHistory, true)[search[1][1]].deletedby = newIndex
				table.insert(CommDKP:GetTable(CommDKP_DKPHistory, true), 1, { players=CommDKP:GetTable(CommDKP_DKPHistory, true)[search[1][1]].players, dkp=dkpString, date=curTime, reason="Delete Entry", index=newIndex, deletes=index })
				CommDKP.Sync:SendData("CommDKPDelSync", CommDKP:GetTable(CommDKP_DKPHistory, true)[1])

				if CommDKP.ConfigTab6.history and CommDKP.ConfigTab6:IsShown() then
					CommDKP:DKPHistory_Update(true)
				end

				CommDKP:StatusVerify_Update()
				CommDKP:DKPTable_Update()
			end
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}
	StaticPopup_Show ("CONFIRM_DELETE")
end


local function CreateDKPEditWindow()
	local f = CreateFrame("Frame", "CommDKP_DKPEditWindow", core.MonDKPUI);

	f:SetPoint("TOPLEFT", core.CommDKPUI, "TOPLEFT", 300, -200);
	f:SetSize(500, 250);
	f:SetClampedToScreen(true)
	f:SetBackdrop( {
		bgFile = "Textures\\white.blp", tile = true,                -- White backdrop allows for black background with 1.0 alpha on low alpha containers
		edgeFile = "Interface\\AddOns\\CommunityDKP\\Media\\Textures\\edgefile.tga", tile = true, tileSize = 1, edgeSize = 3,  
		insets = { left = 0, right = 0, top = 0, bottom = 0 }
	});
	f:SetBackdropColor(0,0,0,1);
	f:SetBackdropBorderColor(1,1,1,1)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(99)
	f:SetMovable(true);
	f:EnableMouse(true);
	f:RegisterForDrag("LeftButton");
	f:SetScript("OnDragStart", f.StartMoving);
	f:SetScript("OnDragStop", f.StopMovingOrSizing);
	tinsert(UISpecialFrames, f:GetName()); -- Sets frame to close on "Escape"
	
	
	local clearFocus = function(self) self:HighlightText(0,0); self:ClearFocus() end

	  -- Close Button
	f.closeContainer = CreateFrame("Frame", "CommDKPEditWindowCloseButtonContainer", f)
	f.closeContainer:SetPoint("CENTER", f, "TOPRIGHT", -4, 0)
	f.closeContainer:SetBackdrop({
		bgFile   = "Textures\\white.blp", tile = true,
		edgeFile = "Interface\\AddOns\\CommunityDKP\\Media\\Textures\\edgefile.tga", tile = true, tileSize = 1, edgeSize = 2, 
	});
	f.closeContainer:SetBackdropColor(0,0,0,0.9)
	f.closeContainer:SetBackdropBorderColor(1,1,1,0.2)
	f.closeContainer:SetSize(14, 14)

	f.closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	f.closeBtn:SetPoint("CENTER", f.closeContainer, "TOPRIGHT", -14, -14)
	
	-- date
	f.date = CreateFrame("EditBox", nil, f)
	f.date:SetFontObject("CommDKPSmallLeft");
	f.date:SetAutoFocus(false)
	f.date:SetMultiLine(false)
	f.date:SetTextInsets(10, 15, 5, 5)
	f.date:SetBackdrop({
    	bgFile   = "Textures\\white.blp", tile = true,
		edgeFile = "Interface\\AddOns\\CommunityDKP\\Media\\Textures\\edgefile", tile = true, tileSize = 32, edgeSize = 2, 
	});
	f.date:SetBackdropColor(0,0,0,0.6)
	f.date:SetBackdropBorderColor(1,1,1,0.6)
	f.date:SetPoint("LEFT", f, "TOPLEFT", 75, -20);
	f.date:SetSize(180, 28)
	f.date:SetScript("OnEscapePressed", clearFocus)
	f.date:SetScript("OnEnterPressed", clearFocus)
	f.date:SetScript("OnTabPressed", clearFocus)
	
	f.dateHeader = f:CreateFontString(nil, "OVERLAY")
	f.dateHeader:SetFontObject("CommDKPSmallRight");
	f.dateHeader:SetScale(0.7)
	f.dateHeader:SetPoint("RIGHT", f.date, "LEFT", -10, 0);
	f.dateHeader:SetText("Date:")
	
	-- dkp
	f.dkp = CreateFrame("EditBox", nil, f)
	f.dkp:SetFontObject("CommDKPSmallLeft");
	f.dkp:SetAutoFocus(false)
	f.dkp:SetMultiLine(false)
	f.dkp:SetTextInsets(10, 15, 5, 5)
	f.dkp:SetBackdrop({
    	bgFile   = "Textures\\white.blp", tile = true,
		edgeFile = "Interface\\AddOns\\CommunityDKP\\Media\\Textures\\edgefile", tile = true, tileSize = 32, edgeSize = 2, 
	});
	f.dkp:SetBackdropColor(0,0,0,0.6)
	f.dkp:SetBackdropBorderColor(1,1,1,0.6)
	f.dkp:SetPoint("TOPLEFT", f.date, "BOTTOMLEFT", 0, -10);
	f.dkp:SetSize(100, 28)
	f.dkp:SetScript("OnEscapePressed", clearFocus)
	f.dkp:SetScript("OnEnterPressed", clearFocus)
	f.dkp:SetScript("OnTabPressed", clearFocus)
	
	f.dkpHeader = f:CreateFontString(nil, "OVERLAY")
	f.dkpHeader:SetFontObject("CommDKPSmallRight");
	f.dkpHeader:SetScale(0.7)
	f.dkpHeader:SetPoint("RIGHT", f.dkp, "LEFT", -10, 0);
	f.dkpHeader:SetText("dkp:")
	
	-- reason
	f.reason = CreateFrame("EditBox", nil, f)
	f.reason:SetFontObject("CommDKPSmallLeft");
	f.reason:SetAutoFocus(false)
	f.reason:SetMultiLine(false)
	f.reason:SetTextInsets(10, 15, 5, 5)
	f.reason:SetBackdrop({
    	bgFile   = "Textures\\white.blp", tile = true,
		edgeFile = "Interface\\AddOns\\CommunityDKP\\Media\\Textures\\edgefile", tile = true, tileSize = 32, edgeSize = 2, 
	});
	f.reason:SetBackdropColor(0,0,0,0.6)
	f.reason:SetBackdropBorderColor(1,1,1,0.6)
	f.reason:SetPoint("TOPLEFT", f.dkp, "BOTTOMLEFT", 0, -10);
	f.reason:SetSize(200, 28)
	f.reason:SetScript("OnEscapePressed", clearFocus)
	f.reason:SetScript("OnEnterPressed", clearFocus)
	f.reason:SetScript("OnTabPressed", clearFocus)
	
	f.reasonHeader = f:CreateFontString(nil, "OVERLAY")
	f.reasonHeader:SetFontObject("CommDKPSmallRight");
	f.reasonHeader:SetScale(0.7)
	f.reasonHeader:SetPoint("RIGHT", f.reason, "LEFT", -10, 0);
	f.reasonHeader:SetText("reason:")
	
	-- players
	f.players = CreateFrame("EditBox", nil, f)
	f.players:SetFontObject("CommDKPSmallLeft");
	f.players:SetAutoFocus(false)
	f.players:SetMultiLine(true)
	f.players:SetTextInsets(10, 15, 5, 5)
	f.players:SetBackdrop({
    	bgFile   = "Textures\\white.blp", tile = true,
		edgeFile = "Interface\\AddOns\\CommunityDKP\\Media\\Textures\\edgefile", tile = true, tileSize = 32, edgeSize = 2, 
	});
	f.players:SetBackdropColor(0,0,0,0.6)
	f.players:SetBackdropBorderColor(1,1,1,0.6)
	f.players:SetPoint("TOPLEFT", f.reason, "BOTTOMLEFT", 0, -10);
	f.players:SetSize(400, 140)
	f.players:SetScript("OnEscapePressed", clearFocus)
	f.players:SetScript("OnEnterPressed", clearFocus)
	f.players:SetScript("OnTabPressed", clearFocus)
	
	f.playersHeader = f:CreateFontString(nil, "OVERLAY")
	f.playersHeader:SetFontObject("CommDKPSmallRight");
	f.playersHeader:SetScale(0.7)
	f.playersHeader:SetPoint("RIGHT", f.players, "LEFT", -10, 0);
	f.playersHeader:SetText("players:")
	
	-- update button
	f.update = CommDKP:CreateButton("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 20, "Update");
	f.update:SetSize(110,25)
	
	return f
end

local function CommDKPEditDKPEntry(index, timestamp, item)
	local function ParseDateString(datestr)
		local day, month, year, hour, min, sec = datestr:match("(%d+)/(%d+)/(%d+) (%d+):(%d+):(%d+)")
		return ostime({day=day,month=month,year=year,hour=hour,min=min,sec=sec})
	end
	
	local function GenerateChangesConfirmText(historyItem, newDate, newDkp, newReason, newPlayers)	
		local function ListWithout(a, b)
			local table_b = {}
			local table_result = {}
			
			for _, v in pairs(b) do
				table_b[v] = true
			end
			
			for _, v in pairs(a) do
				if table_b[v] == nil then
					table_result[#table_result + 1] = v
				end
			end
			
			return table_result
		end
		local changes = "Do you really want to perform the following changes?\n"
		
		if newDate ~= historyItem.date then
			changes = changes.."\n"
			changes = changes.."Old Date: "..formdate("%d/%m/%Y %H:%M:%S", historyItem.date).."\n"
			changes = changes.."New Date: "..formdate("%d/%m/%Y %H:%M:%S", newDate).."\n"
		end
		
		if tostring(newDkp) ~= tostring(historyItem.dkp) then
			changes = changes.."\n"
			changes = changes.."Old DKP: "..historyItem["dkp"].."\n"
			changes = changes.."New DKP: "..newDkp.."\n"
		end
		
		if newReason ~= historyItem.reason then
			changes = changes.."\n"
			changes = changes.."Old Reason: "..historyItem["reason"].."\n"
			changes = changes.."New Reason: "..newReason.."\n"
		end
		
		
		local playerArray = {strsplit(",", historyItem.players)}
		local newPlayerArray = {strsplit(",", newPlayers)}
		
		local addedPlayers = ListWithout(newPlayerArray, playerArray)
		local removedPlayers = ListWithout(playerArray, newPlayerArray)
		
		
		if #addedPlayers > 0 then
			changes = changes.."\n"
			changes = changes.."The following players have been added: "
			for i, player in pairs(addedPlayers) do
				classSearch = CommDKP:Table_Search(CommDKP:GetTable(CommDKP_DKPTable, true), player)
				c = CommDKP:GetCColors(CommDKP:GetTable(CommDKP_DKPTable, true)[classSearch[1][1]].class)
				if i < #addedPlayers then
					changes = changes.."|c"..c.hex..player.."|r, "
				else
					changes = changes.."|c"..c.hex..player.."|r\n"
				end
			end
		end
		
		if #removedPlayers > 0 then
			changes = changes.."\n"
			changes = changes.."The following players have been removed: "
			for i, player in pairs(removedPlayers) do
				classSearch = CommDKP:Table_Search(CommDKP:GetTable(CommDKP_DKPTable, true), player)
				c = CommDKP:GetCColors(CommDKP:GetTable(CommDKP_DKPTable, true)[classSearch[1][1]].class)
				if i < #removedPlayers then
					changes = changes.."|c"..c.hex..player.."|r, "
				else
					changes = changes.."|c"..c.hex..player.."|r\n"
				end
			end
		end
		
		return changes
	end

	local item_table_index = CommDKP:Table_Search(CommDKP:GetTable(CommDKP_DKPHistory, true), index, "index")[1][1]
	local historyItem = CommDKP:GetTable(CommDKP_DKPHistory, true)[item_table_index]
	local f = CreateDKPEditWindow()
	f.date:SetText(formdate("%d/%m/%Y %H:%M:%S", timestamp))
	f.dkp:SetText(historyItem.dkp)
	f.reason:SetText(historyItem.reason)
	f.players:SetText(historyItem.players)
	
	
	f.update:SetScript("OnClick", function()
		local newDate = ParseDateString(f.date:GetText())
		local newDkp = f.dkp:GetText()
		local newReason = f.reason:GetText()
		local newPlayers = f.players:GetText()
		
		if not strfind(newDkp, "%%") then
			newDkp = tonumber(newDkp)
		end
		
		StaticPopupDialogs["CONFIRM_DKPEDIT"] = {
			text = GenerateChangesConfirmText(historyItem, newDate, newDkp, newReason, newPlayers),
			button1 = L["YES"],
			button2 = L["NO"],
			OnAccept = function()
				local oldPlayersArray = {strsplit(",", strsub(historyItem.players, 1, -2))} 	-- cuts off last "," from string to avoid creating an empty value
				local oldDkp, oldMod;
				local oldDkpString;
				if strfind(historyItem.dkp, "%-%d*%.?%d+%%") then 		-- determines if it's a mass decay
					oldDkp = {strsplit(",", historyItem.dkp)}
					oldMod = "perc";
				else
					oldDkp = historyItem.dkp
					oldMod = "whole"
				end
				
				local newPlayersArray = {strsplit(",", strsub(newPlayers, 1, -2))} 	-- cuts off last "," from string to avoid creating an empty value
				local newMod;
				local newDkpString;
				if strfind(newDkp, "%-%d*%.?%d+%%") then 		-- determines if it's a mass decay
					newDkp = {strsplit(",", newDkp)}
					newMod = "perc";
				else
					newMod = "whole"
				end

				local curOfficer = UnitName("player")
				local curTime = time()
				local newIndex = curOfficer.."-"..curTime
				local deletesIndex = curOfficer.."-"..(curTime - 1)
		
				for i=1, #oldPlayersArray do
					if mod == "perc" then
						local search = CommDKP:Table_Search(CommDKP:GetTable(CommDKP_DKPTable, true), oldPlayersArray[i])

						if search then
							local inverted = tonumber(oldDkp[i]) * -1
							CommDKP:GetTable(CommDKP_DKPTable, true)[search[1][1]].dkp = CommDKP:GetTable(CommDKP_DKPTable, true)[search[1][1]].dkp + inverted
							oldDkpString = oldDkpString..inverted..",";

							if i == #newPlayersArray then
								oldDkpString = oldDkpString..oldDkp[#oldDkp]
							end
						end
					else
						local search = CommDKP:Table_Search(CommDKP:GetTable(CommDKP_DKPTable, true), oldPlayersArray[i])

						if search then
							local inverted = tonumber(oldDkp) * -1
							CommDKP:GetTable(CommDKP_DKPTable, true)[search[1][1]].dkp = CommDKP:GetTable(CommDKP_DKPTable, true)[search[1][1]].dkp + inverted
							
							if (inverted < 0) then
								CommDKP:GetTable(CommDKP_DKPTable, true)[search[1][1]].lifetime_gained = CommDKP:GetTable(CommDKP_DKPTable, true)[search[1][1]].lifetime_gained + inverted
							end

							oldDkpString = inverted;
						end
					end
				end
				
				for i=1, #newPlayersArray do
					if mod == "perc" then
						local search = CommDKP:Table_Search(CommDKP:GetTable(CommDKP_DKPTable, true), newPlayersArray[i])

						if search then
							local inverted = tonumber(newDkp[i])
							CommDKP:GetTable(CommDKP_DKPTable, true)[search[1][1]].dkp = CommDKP:GetTable(CommDKP_DKPTable, true)[search[1][1]].dkp + inverted
							newDkpString = newDkpString..inverted..",";

							if i == #newPlayersArray then
								newDkpString = newDkpString..newDkp[#newDkp]
							end
						end
					else
						local search = CommDKP:Table_Search(CommDKP:GetTable(CommDKP_DKPTable, true), newPlayersArray[i])

						if search then
							local inverted = tonumber(newDkp)

							CommDKP:GetTable(CommDKP_DKPTable, true)[search[1][1]].dkp = CommDKP:GetTable(CommDKP_DKPTable, true)[search[1][1]].dkp + inverted
							
							if (inverted > 0) then
								CommDKP:GetTable(CommDKP_DKPTable, true)[search[1][1]].lifetime_gained = CommDKP:GetTable(CommDKP_DKPTable, true)[search[1][1]].lifetime_gained + inverted
							end
							
							newDkpString = inverted;
						end
					end
				end
				
				historyItem.deletedby = deletesIndex
				table.insert(CommDKP:GetTable(CommDKP_DKPHistory, true), 1, { players=historyItem.players, dkp=oldDkpString, date=curTime, reason="Delete Entry", index=deletesIndex, deletes=index })
				table.insert(CommDKP:GetTable(CommDKP_DKPHistory, true), 1, { players=newPlayers, dkp=newDkpString, date=newDate, reason=newReason, index=newIndex })
				CommDKP.Sync:SendData("CommDKPDelSync", CommDKP:GetTable(CommDKP_DKPHistory, true)[1])

				if CommDKP.ConfigTab6.history and CommDKP.ConfigTab6:IsShown() then
					CommDKP:DKPHistory_Update(true)
				end

				CommDKP:StatusVerify_Update()
				CommDKP:DKPTable_Update()
				f:SetShown(false)
			end,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3,
		}
		StaticPopup_Show ("CONFIRM_DKPEDIT")
	end)
	
	f:SetShown(true)
end

local function RightClickDKPMenu(self, index, timestamp, item)
	local header
	local search = CommDKP:Table_Search(CommDKP:GetTable(CommDKP_DKPHistory, true), index, "index")

	if search then
		menu = {
		{ text = CommDKP.ConfigTab6.history[item].d:GetText():gsub(L["OTHER"].." -- ", ""), isTitle = true},
		{ text = L["DELETEDKPENTRY"], func = function()
			CommDKPDeleteDKPEntry(index, timestamp, item)
		end },
		{ text = L["EDITDKPENTRY"], func = function()
			CommDKPEditDKPEntry(index, timestamp, item)
		end },
		}
		EasyMenu(menu, menuFrame, "cursor", 0 , 0, "MENU", 2);
	end
end

function CommDKP:DKPHistory_Update(reset)
	local DKPHistory = {}
	CommDKP:SortDKPHistoryTable()

	if not CommDKP.UIConfig:IsShown() then 			-- prevents history update from firing if the DKP window is not opened (eliminate lag). Update run when opened
		return;
	end

	if reset then
		CommDKP:DKPHistory_Reset()
	end

	if filter and filter ~= L["DELETEDENTRY"] then
		for i=1, #CommDKP:GetTable(CommDKP_DKPHistory, true) do
			if not CommDKP:GetTable(CommDKP_DKPHistory, true)[i].deletes and not CommDKP:GetTable(CommDKP_DKPHistory, true)[i].deletedby and CommDKP:GetTable(CommDKP_DKPHistory, true)[i].reason ~= "Migration Correction" and (strfind(CommDKP:GetTable(CommDKP_DKPHistory, true)[i].players, ","..filter..",") or strfind(CommDKP:GetTable(CommDKP_DKPHistory, true)[i].players, filter..",") == 1) then
				table.insert(DKPHistory, CommDKP:GetTable(CommDKP_DKPHistory, true)[i])
			end
		end
	elseif filter and filter == L["DELETEDENTRY"] then
		for i=1, #CommDKP:GetTable(CommDKP_DKPHistory, true) do
			if CommDKP:GetTable(CommDKP_DKPHistory, true)[i].deletes then
				table.insert(DKPHistory, CommDKP:GetTable(CommDKP_DKPHistory, true)[i])
			end
		end
	elseif not filter then
		for i=1, #CommDKP:GetTable(CommDKP_DKPHistory, true) do
			if not CommDKP:GetTable(CommDKP_DKPHistory, true)[i].deletes and not CommDKP:GetTable(CommDKP_DKPHistory, true)[i].hidden and not CommDKP:GetTable(CommDKP_DKPHistory, true)[i].deletedby then
				table.insert(DKPHistory, CommDKP:GetTable(CommDKP_DKPHistory, true)[i])
			end
		end
	end
	
	CommDKP.ConfigTab6.history = history;

	if currentLength > #DKPHistory then currentLength = #DKPHistory end

	local j=currentRow+1
	local HistTimer = 0
	local processing = false
	local DKPHistTimer = DKPHistTimer or CreateFrame("StatusBar", nil, UIParent)
	DKPHistTimer:SetScript("OnUpdate", function(self, elapsed)
		HistTimer = HistTimer + elapsed
		if HistTimer > 0.001 and j <= currentLength and not processing then
			local i = j
			processing = true

			if CommDKP.ConfigTab6.loadMoreBtn then
				CommDKP.ConfigTab6.loadMoreBtn:Hide()
			end

			local curOfficer, curIndex

			if DKPHistory[i].index then
				curOfficer, curIndex = strsplit("-", DKPHistory[i].index)
			else
				curOfficer = "Unknown"
			end

			if not CommDKP.ConfigTab6.history[i] then
				if i==1 then
					CommDKP.ConfigTab6.history[i] = CreateFrame("Frame", "CommDKP:GetTable(CommDKP_DKPHistory, true)Tab", CommDKP.ConfigTab6);
					CommDKP.ConfigTab6.history[i]:SetPoint("TOPLEFT", CommDKP.ConfigTab6, "TOPLEFT", 0, -45)
					CommDKP.ConfigTab6.history[i]:SetWidth(400)
				else
					CommDKP.ConfigTab6.history[i] = CreateFrame("Frame", "CommDKP:GetTable(CommDKP_DKPHistory, true)Tab", CommDKP.ConfigTab6);
					CommDKP.ConfigTab6.history[i]:SetPoint("TOPLEFT", CommDKP.ConfigTab6.history[i-1], "BOTTOMLEFT", 0, 0)
					CommDKP.ConfigTab6.history[i]:SetWidth(400)
				end

				CommDKP.ConfigTab6.history[i].h = CommDKP.ConfigTab6:CreateFontString(nil, "OVERLAY") 		-- entry header
				CommDKP.ConfigTab6.history[i].h:SetFontObject("CommDKPNormalLeft");
				CommDKP.ConfigTab6.history[i].h:SetPoint("TOPLEFT", CommDKP.ConfigTab6.history[i], "TOPLEFT", 15, 0);
				CommDKP.ConfigTab6.history[i].h:SetWidth(400)

				CommDKP.ConfigTab6.history[i].d = CommDKP.ConfigTab6:CreateFontString(nil, "OVERLAY") 		-- entry description
				CommDKP.ConfigTab6.history[i].d:SetFontObject("CommDKPSmallLeft");
				CommDKP.ConfigTab6.history[i].d:SetPoint("TOPLEFT", CommDKP.ConfigTab6.history[i].h, "BOTTOMLEFT", 5, -2);
				CommDKP.ConfigTab6.history[i].d:SetWidth(400)

				CommDKP.ConfigTab6.history[i].s = CommDKP.ConfigTab6:CreateFontString(nil, "OVERLAY")			-- entry player string
				CommDKP.ConfigTab6.history[i].s:SetFontObject("CommDKPTinyLeft");
				CommDKP.ConfigTab6.history[i].s:SetPoint("TOPLEFT", CommDKP.ConfigTab6.history[i].d, "BOTTOMLEFT", 15, -4);
				CommDKP.ConfigTab6.history[i].s:SetWidth(400)

				CommDKP.ConfigTab6.history[i]:SetScript("OnMouseDown", function(self, button)
			    	if button == "RightButton" then
		   				if core.IsOfficer == true then
		   					RightClickDKPMenu(self, DKPHistory[i].index, DKPHistory[i].date, i)
		   				end
		   			end
			    end)
			end

			local delete_on_date, delete_day, delete_timeofday, delete_year, delete_month, delete_day, delOfficer;

			if filter == L["DELETEDENTRY"] then
				local search = CommDKP:Table_Search(CommDKP:GetTable(CommDKP_DKPHistory, true), DKPHistory[i].deletes, "index")

				if search then
					delOfficer,_ = strsplit("-", CommDKP:GetTable(CommDKP_DKPHistory, true)[search[1][1]].deletedby)
					players = CommDKP:GetTable(CommDKP_DKPHistory, true)[search[1][1]].players;
					if strfind(CommDKP:GetTable(CommDKP_DKPHistory, true)[search[1][1]].reason, L["OTHER"].." - ") == 1 then
						reason = CommDKP:GetTable(CommDKP_DKPHistory, true)[search[1][1]].reason:gsub(L["OTHER"].." -- ", "");
					else
						reason = CommDKP:GetTable(CommDKP_DKPHistory, true)[search[1][1]].reason
					end
					dkp = CommDKP:GetTable(CommDKP_DKPHistory, true)[search[1][1]].dkp;
					date = CommDKP:FormatTime(CommDKP:GetTable(CommDKP_DKPHistory, true)[search[1][1]].date);
					delete_on_date = CommDKP:FormatTime(DKPHistory[i].date)
					delete_day = strsub(delete_on_date, 1, 8)
					delete_timeofday = strsub(delete_on_date, 10)
					delete_year, delete_month, delete_day = strsplit("/", delete_day)
				end
			else
				players = DKPHistory[i].players;
				if strfind(DKPHistory[i].reason, L["OTHER"].." - ") == 1 then
					reason = DKPHistory[i].reason:gsub(L["OTHER"].." -- ", "");
				else
					reason = DKPHistory[i].reason
				end
				dkp = DKPHistory[i].dkp;
				date = CommDKP:FormatTime(DKPHistory[i].date);

				if CommDKP.ConfigTab6.history[i].b then
					CommDKP.ConfigTab6.history[i].b:Hide()
				end
			end
			
			
			player_table = { strsplit(",", players) } or players
			if player_table[1] ~= nil and #player_table > 1 then	-- removes last entry in table which ends up being nil, which creates an additional comma at the end of the string
				tremove(player_table, #player_table)
			end

			for k=1, #player_table do
				classSearch = CommDKP:Table_Search(CommDKP:GetTable(CommDKP_DKPTable, true), player_table[k])

				if classSearch then
					c = CommDKP:GetCColors(CommDKP:GetTable(CommDKP_DKPTable, true)[classSearch[1][1]].class)
					if k < #player_table then
						playerString = playerString.."|c"..c.hex..player_table[k].."|r, "
					elseif k == #player_table then
						playerString = playerString.."|c"..c.hex..player_table[k].."|r"
					end
				end
			end

			CommDKP.ConfigTab6.history[i]:SetScript("OnMouseDown", function(self, button)
		    	if button == "RightButton" and filter ~= L["DELETEDENTRY"] then
	   				if core.IsOfficer == true then
	   					RightClickDKPMenu(self, DKPHistory[i].index, DKPHistory[i].date, i)
	   				end
	   			end
		    end)
		    CommDKP.ConfigTab6.inst:Show();

			day = strsub(date, 1, 8)
			timeofday = strsub(date, 10)
			year, month, day = strsplit("/", day)

			if day ~= curDate then
				if i~=1 then
					CommDKP.ConfigTab6.history[i]:SetPoint("TOPLEFT", CommDKP.ConfigTab6.history[i-1], "BOTTOMLEFT", 0, -20)
				end
				CommDKP.ConfigTab6.history[i].h:SetText(month.."/"..day.."/"..year);
				CommDKP.ConfigTab6.history[i].h:Show()
				curDate = day;
			else
				if i~=1 then
					CommDKP.ConfigTab6.history[i]:SetPoint("TOPLEFT", CommDKP.ConfigTab6.history[i-1], "BOTTOMLEFT", 0, 0)
				end
				CommDKP.ConfigTab6.history[i].h:Hide()
			end

			local officer_search = CommDKP:Table_Search(CommDKP:GetTable(CommDKP_DKPTable, true), curOfficer, "player")
	    	if officer_search then
		     	c = CommDKP:GetCColors(CommDKP:GetTable(CommDKP_DKPTable, true)[officer_search[1][1]].class)
		    else
		     	c = { hex="ff444444" }
		    end
			
			if not strfind(dkp, "-") then
				CommDKP.ConfigTab6.history[i].d:SetText("|cff00ff00"..dkp.." "..L["DKP"].."|r - |cff616ccf"..reason.."|r |cff555555("..timeofday..")|r by |c"..c.hex..curOfficer.."|r");
			else
				if filter and filter ~= L["DELETEDENTRY"] and strfind(reason, L["WEEKLYDECAY"]) then
					local decay = {strsplit(",", dkp)}
					-- get substring till player name and split to get correct player index for decay list
					local playerIndex = {strsplit(",", string.sub(players, 1, strfind(players, filter..",")))};
					-- Print decay value using playerIndex instead of percentage
					CommDKP.ConfigTab6.history[i].d:SetText("|cffff0000"..decay[#playerIndex].." "..L["DKP"].."|r - |cff616ccf"..reason.."|r |cff555555("..timeofday..")|r by |c"..c.hex..curOfficer.."|r");
				elseif strfind(reason, L["WEEKLYDECAY"]) or strfind(reason, "Migration Correction") then
					local decay = {strsplit(",", dkp)}
					CommDKP.ConfigTab6.history[i].d:SetText("|cffff0000"..decay[#decay].." "..L["DKP"].."|r - |cff616ccf"..reason.."|r |cff555555("..timeofday..")|r by |c"..c.hex..curOfficer.."|r"..decay[#decay].." "..L["DKP"].."|r - |cff616ccf"..reason.."|r |cff555555("..timeofday..")|r by |c"..c.hex..curOfficer.."|r");
				else
					CommDKP.ConfigTab6.history[i].d:SetText("|cffff0000"..dkp.." "..L["DKP"].."|r - |cff616ccf"..reason.."|r |cff555555("..timeofday..")|r by |c"..c.hex..curOfficer.."|r");
				end
			end

			CommDKP.ConfigTab6.history[i].d:Show()

			if not filter or (filter and filter == L["DELETEDENTRY"]) then
				CommDKP.ConfigTab6.history[i].s:SetText(playerString);
				CommDKP.ConfigTab6.history[i].s:Show()
			else
				CommDKP.ConfigTab6.history[i].s:Hide()
			end

			if filter and filter ~= L["DELETEDENTRY"] then
				CommDKP.ConfigTab6.history[i]:SetHeight(CommDKP.ConfigTab6.history[i].s:GetHeight() + CommDKP.ConfigTab6.history[i].h:GetHeight() + CommDKP.ConfigTab6.history[i].d:GetHeight())
			else
				CommDKP.ConfigTab6.history[i]:SetHeight(CommDKP.ConfigTab6.history[i].s:GetHeight() + CommDKP.ConfigTab6.history[i].h:GetHeight() + CommDKP.ConfigTab6.history[i].d:GetHeight() + 10)
				if filter == L["DELETEDENTRY"] then
					if not CommDKP.ConfigTab6.history[i].b then
						CommDKP.ConfigTab6.history[i].b = CreateFrame("Button", "RightClickButtonDKPHistory"..i, CommDKP.ConfigTab6.history[i]);
					end
					CommDKP.ConfigTab6.history[i].b:Show()
					CommDKP.ConfigTab6.history[i].b:SetPoint("TOPLEFT", CommDKP.ConfigTab6.history[i], "TOPLEFT", 0, 0)
					CommDKP.ConfigTab6.history[i].b:SetPoint("BOTTOMRIGHT", CommDKP.ConfigTab6.history[i], "BOTTOMRIGHT", 0, 0)
					CommDKP.ConfigTab6.history[i].b:SetScript("OnEnter", function(self)
				    	local col
				    	local s = CommDKP:Table_Search(CommDKP:GetTable(CommDKP_DKPTable, true), delOfficer, "player")
				    	if s then
				    		col = CommDKP:GetCColors(CommDKP:GetTable(CommDKP_DKPTable, true)[s[1][1]].class)
				    	else
				    		col = { hex="ff444444"}
				    	end
						GameTooltip:SetOwner(self, "ANCHOR_TOP", 0, 0);
						GameTooltip:SetText(L["DELETEDBY"], 0.25, 0.75, 0.90, 1, true);
						GameTooltip:AddDoubleLine("|c"..col.hex..delOfficer.."|r", delete_month.."/"..delete_day.."/"..delete_year.." @ "..delete_timeofday, 1,0,0,1,1,1)
						GameTooltip:Show()
					end);
					CommDKP.ConfigTab6.history[i].b:SetScript("OnLeave", function(self)
						GameTooltip:Hide();
					end)
				end
			end

			playerString = ""
			table.wipe(player_table)

			CommDKP.ConfigTab6.history[i]:Show()

			currentRow = currentRow + 1;
			processing = false
		    j=i+1
		    HistTimer = 0
		elseif j > currentLength then
			DKPHistTimer:SetScript("OnUpdate", nil)
			HistTimer = 0

			if not CommDKP.ConfigTab6.loadMoreBtn then
				CommDKP.ConfigTab6.loadMoreBtn = CreateFrame("Button", nil, CommDKP.ConfigTab6, "CommunityDKPButtonTemplate")
				CommDKP.ConfigTab6.loadMoreBtn:SetSize(100, 30);
				CommDKP.ConfigTab6.loadMoreBtn:SetText(string.format(L["LOAD50MORE"], btnText).."...");
				CommDKP.ConfigTab6.loadMoreBtn:GetFontString():SetTextColor(1, 1, 1, 1)
				CommDKP.ConfigTab6.loadMoreBtn:SetNormalFontObject("CommDKPSmallCenter");
				CommDKP.ConfigTab6.loadMoreBtn:SetHighlightFontObject("CommDKPSmallCenter");
				CommDKP.ConfigTab6.loadMoreBtn:SetPoint("TOP", CommDKP.ConfigTab6.history[currentRow], "BOTTOM", 0, -10);
				CommDKP.ConfigTab6.loadMoreBtn:SetScript("OnClick", function(self)
					currentLength = currentLength + maxDisplayed;
					CommDKP:DKPHistory_Update()
					CommDKP.ConfigTab6.loadMoreBtn:SetText(L["LOAD"].." "..btnText.." "..L["MORE"].."...")
					CommDKP.ConfigTab6.loadMoreBtn:SetPoint("TOP", CommDKP.ConfigTab6.history[currentRow], "BOTTOM", 0, -10)
				end)
			end

			if CommDKP.ConfigTab6.loadMoreBtn and currentRow == #DKPHistory then 
				CommDKP.ConfigTab6.loadMoreBtn:Hide();
			elseif CommDKP.ConfigTab6.loadMoreBtn and currentRow < #DKPHistory then
				if (#DKPHistory - currentRow) < btnText then btnText = (#DKPHistory - currentRow) end
				CommDKP.ConfigTab6.loadMoreBtn:SetText(string.format(L["LOAD50MORE"], btnText).."...")
				CommDKP.ConfigTab6.loadMoreBtn:SetPoint("TOP", CommDKP.ConfigTab6.history[currentRow], "BOTTOM", 0, -10);
				CommDKP.ConfigTab6.loadMoreBtn:Show()
			end
		end
	end)
end
