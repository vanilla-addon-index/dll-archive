CHARACTER_SELECT_ROTATION_START_X = nil;
CHARACTER_SELECT_INITIAL_FACING = nil;

CHARACTER_ROTATION_CONSTANT = 0.6;

MAX_CHARACTERS_DISPLAYED = 10;
MAX_CHARACTERS_PER_REALM = 10;

AUTO_DRAG_TIME = 0.5;

function CharacterSelect_OnLoad()
	this:SetSequence(0);
	this:SetCamera(0);

	this.createIndex = 0;
	this.selectedIndex = 0;
	this.selectLast = 0;
	this.currentModel = "";
	this.translationTable = {};
	this.orderChanged = nil;
	this.pressDownButton = nil;
	this.pressDownTime = 0;
	this.draggedIndex = nil;
	this.suppressNextClick = nil;
	this:RegisterEvent("ADDON_LIST_UPDATE");
	this:RegisterEvent("CHARACTER_LIST_UPDATE");
	this:RegisterEvent("UPDATE_SELECTED_CHARACTER");
	this:RegisterEvent("SELECT_LAST_CHARACTER");
	this:RegisterEvent("SELECT_FIRST_CHARACTER");
	this:RegisterEvent("SUGGEST_REALM");
	this:RegisterEvent("FORCE_RENAME_CHARACTER");

	CharacterSelect:SetModel("Interface\\Glues\\Models\\UI_Orc\\UI_Orc.mdx");

	local fogInfo = CharModelFogInfo["ORC"];
	CharacterSelect:SetFogColor(fogInfo.r, fogInfo.g, fogInfo.b);
	CharacterSelect:SetFogNear(0);
	CharacterSelect:SetFogFar(fogInfo.far);

	SetCharSelectModelFrame("CharacterSelect");
	--CharSelectModel:SetLight(1, 0, 0, -0.707, -0.707, 0.7, 1.0, 1.0, 1.0, 0.8, 1.0, 1.0, 0.8);

	-- Color edit box backdrops
	local backdropColor = DEFAULT_TOOLTIP_COLOR;
	CharacterSelectCharacterFrame:SetBackdropBorderColor(backdropColor[1], backdropColor[2], backdropColor[3]);
	CharacterSelectCharacterFrame:SetBackdropColor(backdropColor[4], backdropColor[5], backdropColor[6], 0.85);

end

function CharacterSelect_OnShow()
	CurrentGlueMusic = "Sound\\Music\\GlueScreenMusic\\wow_main_theme.mp3";

	UpdateAddonButton();

	local serverName, isPVP, isRP = GetServerName();
	local connected = IsConnectedToServer();
	local serverType = "";
	if ( serverName ) then
		if( not connected ) then
			serverName = serverName.."\n("..SERVER_DOWN..")";
		end
		if ( isPVP ) then
			if ( isRP ) then
				serverType = RPPVP_PARENTHESES;
			else
				serverType = PVP_PARENTHESES;
			end
		elseif ( isRP ) then
			serverType = RP_PARENTHESES;
		end
		CharSelectRealmName:SetText(serverName.." "..serverType);
		CharSelectRealmName:Show();
	else
		CharSelectRealmName:Hide();
	end

	if ( connected ) then
		GetCharacterListUpdate();
	else
		UpdateCharacterList();
	end

	-- Gameroom billing stuff (For Korea and China only)
	if ( SHOW_GAMEROOM_BILLING_FRAME ) then
		local paymentPlan, hasFallBackBillingMethod, isGameRoom = GetBillingPlan();
		if ( paymentPlan == 0 ) then
			-- No payment plan
			GameRoomBillingFrame:Hide();
		else
			local billingTimeLeft = GetBillingTimeRemaining();
			-- Set default text for the payment plan
			local billingText = _G["BILLING_TEXT"..paymentPlan];
			if ( paymentPlan == 1 ) then
				-- Recurring account
				billingTimeLeft = ceil(billingTimeLeft/(60 * 24));
				if ( billingTimeLeft == 1 ) then
					billingText = BILLING_TIME_LEFT_LAST_DAY;
				end
			elseif ( paymentPlan == 2 ) then
				-- Free account
				if ( billingTimeLeft < (24 * 60) ) then
					billingText = format(BILLING_FREE_TIME_EXPIRE, billingTimeLeft.." "..GetText("MINUTES_ABBR", nil, billingTimeLeft));
				end
			elseif ( paymentPlan == 3 ) then
				-- Fixed but not recurring
				if ( isGameRoom == 1 ) then
					if ( billingTimeLeft <= 30 ) then
						billingText = BILLING_GAMEROOM_EXPIRE;
					else
						billingText = format(BILLING_FIXED_IGR, MinutesToTime(billingTimeLeft, 1));
					end
				else
					-- personal fixed plan
					if ( billingTimeLeft < (24 * 60) ) then
						billingText = BILLING_FIXED_LASTDAY;
					else
						billingText = format(billingText, MinutesToTime(billingTimeLeft));
					end
				end
			elseif ( paymentPlan == 4 ) then
				-- Usage plan
				if ( isGameRoom == 1 ) then
					-- game room usage plan
					if ( billingTimeLeft <= 600 ) then
						billingText = BILLING_GAMEROOM_EXPIRE;
					else
						billingText = BILLING_IGR_USAGE;
					end
				else
					-- personal usage plan
					if ( billingTimeLeft <= 30 ) then
						billingText = BILLING_TIME_LEFT_30_MINS;
					else
						billingText = format(billingText, billingTimeLeft);
					end
				end
			end
			-- If fallback payment method add a note that says so
			if ( hasFallBackBillingMethod == 1 ) then
				billingText = billingText.."\n\n"..BILLING_HAS_FALLBACK_PAYMENT;
			end
			GameRoomBillingFrameText:SetText(billingText);
			GameRoomBillingFrame:SetHeight(GameRoomBillingFrameText:GetHeight() + 26);
			GameRoomBillingFrame:Show();
		end
	end

	-- fadein the character select ui
	GlueFrameFadeIn(CharacterSelectUI, CHARACTER_SELECT_FADE_IN)
end

function CharacterSelect_OnHide()
	CharacterDeleteDialog:Hide();
	CharacterRenameDialog:Hide();
end

function CharacterSelect_OnKeyDown()
	if ( arg1 == "ESCAPE" ) then
		CharacterSelect_Exit();
	elseif ( arg1 == "ENTER" ) then
		CharacterSelect_EnterWorld();
	elseif ( arg1 == "PRINTSCREEN" ) then
		Screenshot();
	elseif ( arg1 == "UP" or arg1 == "LEFT" ) then
		local numChars = GetNumCharacters();
		if ( numChars > 1 ) then
			if ( this.selectedIndex > 1 ) then
				CharacterSelect_SelectCharacter(this.selectedIndex - 1);
			else
				CharacterSelect_SelectCharacter(numChars);
			end
		end
	elseif ( arg1 == "DOWN" or arg1 == "RIGHT" ) then
		local numChars = GetNumCharacters();
		if ( numChars > 1 ) then
			if ( this.selectedIndex < GetNumCharacters() ) then
				CharacterSelect_SelectCharacter(this.selectedIndex + 1);
			else
				CharacterSelect_SelectCharacter(1);
			end
		end
	end
end

function CharacterSelect_OnEvent()
	if ( event == "ADDON_LIST_UPDATE" ) then
		UpdateAddonButton();
	elseif ( event == "CHARACTER_LIST_UPDATE" ) then
		CharacterSelect_RebuildTranslationTable();
		CharacterOrder_Apply();
		CharacterOrder_Save();
		if ( this.pendingSelectedCharID ) then
			this.selectedIndex = GetIndexFromCharID(this.pendingSelectedCharID);
			this.pendingSelectedCharID = nil;
		end
		UpdateCharacterList();
		CharSelectCharacterName:SetText(GetCharacterInfo(GetCharIDFromIndex(this.selectedIndex)));
	elseif ( event == "UPDATE_SELECTED_CHARACTER" ) then
		if ( arg1 == 0 ) then
			CharSelectCharacterName:SetText("");
		else
			CharSelectCharacterName:SetText(GetCharacterInfo(arg1));
			if ( table.getn(this.translationTable) == 0 ) then
				this.pendingSelectedCharID = arg1;
			else
				this.selectedIndex = GetIndexFromCharID(arg1);
			end
		end
		UpdateCharacterSelection();
	elseif ( event == "SELECT_LAST_CHARACTER" ) then
		this.selectLast = 1;
	elseif ( event == "SELECT_FIRST_CHARACTER" ) then
		CharacterSelect_SelectCharacter(1, 1);
	elseif ( event == "SUGGEST_REALM" ) then
		local name = GetRealmInfo(arg1, arg2);
		RealmWizard.suggestedRealmName = name;
		RealmWizard.suggestedCategory = arg1;
		RealmWizard.suggestedID = arg2;
		GlueDialog_Show("SUGGEST_REALM");
	elseif ( event == "FORCE_RENAME_CHARACTER" ) then
		CharacterRenameDialog:Show();
	    CharacterRenameBackground:SetHeight(16 + CharacterRenameText1:GetHeight() + CharacterRenameText2:GetHeight() + 23 + CharacterRenameEditBox:GetHeight() + 8 + CharacterRenameButton1:GetHeight() + 16);

		CharacterRenameText1:SetText(_G[arg1]);
	end
end

function CharacterSelect_UpdateModel()
	UpdateSelectionCustomizationScene();
	this:AdvanceTime();
end

function UpdateCharacterSelection()
	local draggedIndex = CharacterSelect.draggedIndex;
	local highlightIndex = draggedIndex or CharacterSelect.selectedIndex;
	for i=1, MAX_CHARACTERS_DISPLAYED, 1 do
		local btn = _G["CharSelectCharacterButton"..i];
		btn:UnlockHighlight();
		if ( draggedIndex and i ~= draggedIndex ) then
			btn:SetAlpha(0.4);
		else
			btn:SetAlpha(1);
		end
	end
	if ( (highlightIndex > 0) and (highlightIndex <= MAX_CHARACTERS_DISPLAYED) ) then
		_G["CharSelectCharacterButton"..highlightIndex]:LockHighlight();
	end
end

function UpdateCharacterList()
	local numChars = GetNumCharacters();
	local index = 1;

	for i=1, numChars, 1 do
		local name, race, class, level, zone, fileString, gender, ghost = GetCharacterInfo(GetCharIDFromIndex(i));

		local button = _G["CharSelectCharacterButton"..index];
		if ( not name ) then
			button:SetText("ERROR - Tell Jeremy");
		else
			if ( not zone ) then
				zone = "";
			end

			local classColor
			local classToken = TW_CLASS_TOKEN and TW_CLASS_TOKEN[class]
			if classToken and CLASS_COLORS[classToken] then
				classColor = CLASS_COLORS[classToken]
				class = classColor .. class .. "|r"
			end
			_G["CharSelectCharacterButton"..index.."ButtonTextName"]:SetText(name);
			if ( ghost ) then
				_G["CharSelectCharacterButton"..index.."ButtonTextInfo"]:SetText(format(CHARACTER_SELECT_INFO_GHOST, level, class));
			else
				_G["CharSelectCharacterButton"..index.."ButtonTextInfo"]:SetText(format(CHARACTER_SELECT_INFO, level, class));
			end
			_G["CharSelectCharacterButton"..index.."ButtonTextLocation"]:SetText(zone);
		end
		button:Show();

		index = index + 1;
		if ( index > MAX_CHARACTERS_DISPLAYED ) then
			break;
		end
	end

	if ( numChars == 0 ) then
		CharacterSelectDeleteButton:Disable();
		CharSelectEnterWorldButton:Disable();
	else
		CharacterSelectDeleteButton:Enable();
		CharSelectEnterWorldButton:Enable();
	end

	CharacterSelect.createIndex = 0;
	CharSelectCreateCharacterButton:Hide();

	local connected = IsConnectedToServer();
	for i=index, MAX_CHARACTERS_DISPLAYED, 1 do
		local button = _G["CharSelectCharacterButton"..index];
		if ( (CharacterSelect.createIndex == 0) and (numChars < MAX_CHARACTERS_PER_REALM) ) then
			CharacterSelect.createIndex = index;
			if ( connected ) then
				--If can create characters position and show the create button
				CharSelectCreateCharacterButton:SetID(index);
				--CharSelectCreateCharacterButton:SetPoint("TOP", button, "TOP", 0, -5);
				CharSelectCreateCharacterButton:Show();
			end
		end
		button:Hide();
		index = index + 1;
	end

	if ( numChars == 0 ) then
		CharacterSelect.selectedIndex = 0;
		return;
	end

	if ( CharacterSelect.selectLast == 1 ) then
		CharacterSelect.selectLast = 0;
		CharacterSelect_SelectCharacter(numChars, 1);
		return;
	end

	if ( (CharacterSelect.selectedIndex == 0) or (CharacterSelect.selectedIndex > numChars) ) then
		CharacterSelect.selectedIndex = 1;
	end
	CharacterSelect_SelectCharacter(CharacterSelect.selectedIndex, 1);
end

function CharacterSelect_OnChar()
end

function CharacterSelectButton_OnClick()
	if ( CharacterSelect.suppressNextClick ) then
		CharacterSelect.suppressNextClick = nil;
		return;
	end
	local id = this:GetID();
	if ( id ~= CharacterSelect.selectedIndex ) then
		CharacterSelect_SelectCharacter(id);
	end
end

function CharacterSelectButton_OnDoubleClick()
	if ( CharacterSelect.suppressNextClick ) then
		CharacterSelect.suppressNextClick = nil;
		return;
	end
	local id = this:GetID();
	if ( id ~= CharacterSelect.selectedIndex ) then
		CharacterSelect_SelectCharacter(id);
	end
	CharacterSelect_EnterWorld();
end

function CharacterSelect_TabResize()
	local buttonMiddle = _G[this:GetName().."Middle"];
	local buttonMiddleDisabled = _G[this:GetName().."MiddleDisabled"];
	local width = this:GetTextWidth() - 8;
	local leftWidth = _G[this:GetName().."Left"]:GetWidth();
	buttonMiddle:SetWidth(width);
	buttonMiddleDisabled:SetWidth(width);
	this:SetWidth(width + (2 * leftWidth));
end

function CharacterSelect_SelectCharacter(id, noCreate)
	if ( id == CharacterSelect.createIndex ) then
		if ( not noCreate ) then
			PlaySound("gsCharacterSelectionCreateNew");
			--ResetRaceSelect();
			--UpdateSelectedRace(nil);
			SetGlueScreen("charcreate");
		end
	else
		local charID = GetCharIDFromIndex(id);
		local name, race, class, level, zone, fileString = GetCharacterInfo(charID);

		if ( fileString ~= CharacterSelect.currentModel ) then
			CharacterSelect.currentModel = fileString;
			SetBackgroundModel(CharacterSelect, fileString);
		end
		SelectCharacter(charID);
	end
end

function CharacterDeleteDialog_OnShow()
	local name, race, class, level = GetCharacterInfo(GetCharIDFromIndex(CharacterSelect.selectedIndex));
	CharacterDeleteText1:SetText(format(CONFIRM_CHAR_DELETE, name, level, class));
	CharacterDeleteBackground:SetHeight(16 + CharacterDeleteText1:GetHeight() + CharacterDeleteText2:GetHeight() + 23 + CharacterDeleteEditBox:GetHeight() + 8 + CharacterDeleteButton1:GetHeight() + 16);
	CharacterDeleteButton1:Disable();
end

function CharacterSelect_EnterWorld()
	PlaySound("gsCharacterSelectionEnterWorld");
	EnterWorld();
end

function CharacterSelect_Exit()
	PlaySound("gsCharacterSelectionExit");
	DisconnectFromServer();
	SetGlueScreen("login");
end

function CharacterSelect_AccountOptions()
	PlaySound("gsCharacterSelectionAcctOptions");
end

function CharacterSelect_TechSupport()
	PlaySound("gsCharacterSelectionAcctOptions");
	LaunchURL(TECH_SUPPORT_URL);
end

function CharacterSelect_Delete()
	PlaySound("gsCharacterSelectionDelCharacter");
	if ( CharacterSelect.selectedIndex > 0 ) then
		CharacterDeleteDialog:Show();
	end
end

function CharacterSelect_ChangeRealm()
	PlaySound("gsLoginChangeRealmSelect");
	RequestRealmList(1);
end

function CharacterSelectFrame_OnMouseDown(button)
	if ( button == "LeftButton" ) then
		CHARACTER_SELECT_ROTATION_START_X = GetCursorPosition();
		CHARACTER_SELECT_INITIAL_FACING = GetCharacterSelectFacing();
	end
end

function CharacterSelectFrame_OnMouseUp(button)
	if ( button == "LeftButton" ) then
		CHARACTER_SELECT_ROTATION_START_X = nil
	end
end

function CharacterSelectFrame_OnUpdate()
	if ( CHARACTER_SELECT_ROTATION_START_X ) then
		local x = GetCursorPosition();
		local diff = (x - CHARACTER_SELECT_ROTATION_START_X) * CHARACTER_ROTATION_CONSTANT;
		CHARACTER_SELECT_ROTATION_START_X = GetCursorPosition();
		SetCharacterSelectFacing(GetCharacterSelectFacing() + diff);
	end

	-- Press-and-hold detector: a character button held past AUTO_DRAG_TIME
	-- promotes into drag mode. Released sooner, OnMouseUp clears the
	-- button and the click flows normally.
	if ( CharacterSelect.pressDownButton ) then
		CharacterSelect.pressDownTime = CharacterSelect.pressDownTime + arg1;
		if ( CharacterSelect.pressDownTime >= AUTO_DRAG_TIME ) then
			CharacterSelectButton_OnDragStart(CharacterSelect.pressDownButton);
		end
	end
end

function CharacterSelectRotateRight_OnUpdate()
	if ( this:GetButtonState() == "PUSHED" ) then
		SetCharacterSelectFacing(GetCharacterSelectFacing() + CHARACTER_FACING_INCREMENT);
	end
end

function CharacterSelectRotateLeft_OnUpdate()
	if ( this:GetButtonState() == "PUSHED" ) then
		SetCharacterSelectFacing(GetCharacterSelectFacing() - CHARACTER_FACING_INCREMENT);
	end
end

function CharacterSelect_ManageAccount()
	PlaySound("gsCharacterSelectionAcctOptions");
	LaunchURL(AUTH_NO_TIME_URL);
end


-- ---------------------------------------------------------------------------
-- Character reordering
-- ---------------------------------------------------------------------------
--
-- `CharacterSelect.translationTable[displayIndex] = charID` maps the slot
-- a button occupies on screen to the server-assigned character ID expected
-- by `GetCharacterInfo` / `SelectCharacter` / `DeleteCharacter` / etc.
-- Default identity table (1->1, 2->2, ...) gets reshuffled by MoveCharacter
-- and restored on every CHARACTER_LIST_UPDATE.

function GetCharIDFromIndex(index)
	return CharacterSelect.translationTable[index] or index;
end

function GetIndexFromCharID(charID)
	-- Fast path while the table is still identity.
	if ( not CharacterSelect.orderChanged ) then
		return charID;
	end
	for index = 1, table.getn(CharacterSelect.translationTable) do
		if ( CharacterSelect.translationTable[index] == charID ) then
			return index;
		end
	end
	return 0;
end

function CharacterSelect_RebuildTranslationTable()
	CharacterSelect.translationTable = {};
	CharacterSelect.orderChanged = nil;
	local numChars = GetNumCharacters();
	for i = 1, numChars do
		table.insert(CharacterSelect.translationTable, i);
	end
end

function MoveCharacter(originIndex, targetIndex, fromDrag)
	CharacterSelect.orderChanged = 1;
	local n = table.getn(CharacterSelect.translationTable);
	if ( n < 2 ) then return; end
	if ( targetIndex < 1 ) then
		targetIndex = n;
	elseif ( targetIndex > n ) then
		targetIndex = 1;
	end
	if ( originIndex == CharacterSelect.selectedIndex ) then
		CharacterSelect.selectedIndex = targetIndex;
	elseif ( targetIndex == CharacterSelect.selectedIndex ) then
		CharacterSelect.selectedIndex = originIndex;
	end
	local t = CharacterSelect.translationTable;
	t[originIndex], t[targetIndex] = t[targetIndex], t[originIndex];
	if ( fromDrag ) then
		CharacterSelect.draggedIndex = targetIndex;
	end
	UpdateCharacterSelection();
	UpdateCharacterList();
	CharacterOrder_Save();
end

-- ---------------------------------------------------------------------------
-- Drag handlers
-- ---------------------------------------------------------------------------
--
-- 1.12 glue widgets don't expose `RegisterForDrag`, so we synthesize drag
-- mode by watching how long a character button is held: any press past
-- AUTO_DRAG_TIME enters drag mode. The dragged button's OnUpdate then
-- watches the cursor's Y position and calls MoveCharacter when it crosses
-- into another slot. Mouse-up tears everything down.

function CharacterSelectButton_OnMouseDown()
	CharacterSelect.pressDownButton = this;
	CharacterSelect.pressDownTime = 0;
end

function CharacterSelectButton_OnMouseUp()
	if ( CharacterSelect.draggedIndex ) then
		CharacterSelectButton_OnDragStop(this);
		-- The drag concluded on a button; the engine still dispatches
		-- OnClick (and OnDoubleClick) afterwards. Suppress one.
		CharacterSelect.suppressNextClick = 1;
	end
	CharacterSelect.pressDownButton = nil;
end

function CharacterSelectButton_OnDragStart(button)
	if ( GetNumCharacters() < 2 ) then return; end
	CharacterSelect.pressDownButton = nil;
	CharacterSelect.draggedIndex = button:GetID();
	-- Cache slot geometry once per drag from the live buttons. Stride
	-- accounts for the 13px visual overlap defined in CharacterSelect.xml.
	CharacterSelect.dragListTop = CharSelectCharacterButton1:GetTop();
	CharacterSelect.dragRowStride = CharSelectCharacterButton1:GetTop() - CharSelectCharacterButton2:GetTop();
	if ( not CharacterSelect.dragRowStride or CharacterSelect.dragRowStride <= 0 ) then
		-- Fallback if button2 wasn't ready (single character, etc.) —
		-- shouldn't reach here because of the >=2 guard above, but be safe.
		CharacterSelect.dragRowStride = 57;
	end
	button:SetScript("OnUpdate", CharacterSelectButton_OnDragUpdate);
	UpdateCharacterSelection();
end

function CharacterSelectButton_OnDragUpdate()
	if ( not CharacterSelect.draggedIndex ) then
		CharacterSelectButton_OnDragStop(this);
		return;
	end
	local _, cursorY = GetCursorPosition();
	local top = CharacterSelect.dragListTop;
	local stride = CharacterSelect.dragRowStride;
	if ( cursorY <= top ) then
		local hoverIndex = math.floor((top - cursorY) / stride) + 1;
		local hover = getglobal("CharSelectCharacterButton"..hoverIndex);
		if ( hover and hover:IsShown() and hoverIndex ~= CharacterSelect.draggedIndex ) then
			if ( hoverIndex > CharacterSelect.draggedIndex ) then
				MoveCharacter(CharacterSelect.draggedIndex, CharacterSelect.draggedIndex + 1, 1);
			else
				MoveCharacter(CharacterSelect.draggedIndex, CharacterSelect.draggedIndex - 1, 1);
			end
		end
	end
end

function CharacterSelectButton_OnDragStop(button)
	CharacterSelect.pressDownButton = nil;
	CharacterSelect.draggedIndex = nil;
	if ( button ) then
		button:SetScript("OnUpdate", nil);
	end
	-- draggedIndex is now nil, so UpdateCharacterSelection restores
	-- full alpha on every slot and highlights only the selected one.
	UpdateCharacterSelection();
end

-- ---------------------------------------------------------------------------
-- Delete / Rename wrappers (selectedIndex is now a display index, so
-- engine calls expecting a charID need translation)
-- ---------------------------------------------------------------------------

function CharacterSelect_DeleteCharacter()
	DeleteCharacter(GetCharIDFromIndex(CharacterSelect.selectedIndex));
	CharacterDeleteDialog:Hide();
end

function CharacterSelect_RenameCharacter()
	if ( RenameCharacter(GetCharIDFromIndex(CharacterSelect.selectedIndex), CharacterRenameEditBox:GetText()) ) then
		CharacterRenameDialog:Hide();
	end
end

-- ---------------------------------------------------------------------------
-- Persistence — relies on ClassicAPI's glue bindings
-- (GetSavedCharacterOrder / SetSavedCharacterOrder). Both calls are
-- guarded so the drag feature is functional in-session even before the
-- DLL binding ships; persistence kicks in automatically once it does.
-- ---------------------------------------------------------------------------

function CharacterOrder_Load()
	if ( type(GetSavedCharacterOrder) ~= "function" ) then return ""; end
	local realm = GetServerName() or "";
	if ( realm == "" ) then return ""; end
	return GetSavedCharacterOrder(realm) or "";
end

function CharacterOrder_Apply()
	local saved = CharacterOrder_Load();
	if ( not saved or saved == "" ) then return; end
	local numChars = GetNumCharacters();
	if ( numChars < 2 ) then return; end

	-- Build name -> charID lookup against the server's natural order.
	-- The translation table is identity at this point (set by
	-- RebuildTranslationTable), so charID == display index here.
	local nameToID = {};
	for charID = 1, numChars do
		local name = GetCharacterInfo(charID);
		if ( name ) then nameToID[name] = charID; end
	end

	local newOrder = {};
	local claimed = {};
	for name in string.gfind(saved, "([^|]+)") do
		local charID = nameToID[name];
		if ( charID and not claimed[charID] ) then
			table.insert(newOrder, charID);
			claimed[charID] = 1;
		end
	end
	-- Append any characters that exist on the server but weren't in the
	-- saved order (newly created since last save).
	for charID = 1, numChars do
		if ( not claimed[charID] ) then
			table.insert(newOrder, charID);
		end
	end

	-- Only adopt the rebuilt order if it actually differs from identity.
	local differs = false;
	for i = 1, table.getn(newOrder) do
		if ( newOrder[i] ~= i ) then differs = true; break; end
	end
	if ( differs ) then
		CharacterSelect.translationTable = newOrder;
		CharacterSelect.orderChanged = 1;
	end
end

function CharacterOrder_Save()
	if ( type(SetSavedCharacterOrder) ~= "function" ) then return; end
	local realm = GetServerName() or "";
	if ( realm == "" ) then return; end
	local numChars = GetNumCharacters();
	-- Skip when the list is empty. CHARACTER_LIST_UPDATE can fire in a
	-- transient state (returning to glue after logout, before the server's
	-- SMSG_CHAR_ENUM populates the list) where numChars is briefly 0.
	-- Writing an empty string here would wipe the saved order before the
	-- real update arrives to Apply it.
	if ( numChars == 0 ) then return; end
	local names = {};
	for i = 1, numChars do
		local name = GetCharacterInfo(GetCharIDFromIndex(i));
		if ( name ) then table.insert(names, name); end
	end
	SetSavedCharacterOrder(realm, table.concat(names, "|"));
end
