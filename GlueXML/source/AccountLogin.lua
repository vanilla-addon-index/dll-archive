-- Autologin: account selection list backed by Windows Credential
-- Manager via ClassicAPI. Passwords live encrypted in the OS
-- credential vault and are never exposed to Lua — `LoginWithSavedAccount`
-- dispatches the login from C so plaintext never crosses the
-- C↔Lua boundary on the way out.
--
-- `GetSavedAccountName` / `SetSavedAccountName` now holds just the
-- last-used account name (no password, no character map). On
-- `Autologin_Load` we use it to pre-select the same account in the
-- list. The first save after this update overwrites whatever the
-- legacy plaintext-password format left in WTF.

Autologin_Table = {};
Autologin_SelectedIdx = nil;
Autologin_CurrentPage = 0;
Autologin_PageSize = 4;
Autologin_LimitReached = false;

-- When the typed account name matches a saved vault entry we hide the
-- password field (and slide the Login button up) since LoginWithSavedAccount
-- will use the vault credential anyway. PASSWORD_FIELD_FORCED lets the
-- "Change password" button re-reveal the field without changing the name
-- — once true, only an account re-selection or a fresh OnShow resets it.
Autologin_PasswordFieldForced = false;

local function HasSavedPassword(name)
	if ( not name or name == "" ) then return false; end
	local accounts = GetSavedAccounts();
	for i = 1, table.getn(accounts) do
		-- GetSavedAccounts now returns { {name=..., lastUsed=...}, ... }.
		if ( accounts[i].name == name ) then return true; end
	end
	return false;
end

-- Best-effort extraction of an account name from whatever's currently
-- in GetSavedAccountName(). Under the new scheme we write just the
-- bare name, but legacy installs have "NAME PASSWORD CHAR;..." — we
-- accept either by taking the first non-space token before any space
-- or semicolon. Returns nil if nothing usable.
local function ParseLastAccount(raw)
	if ( not raw or raw == "" ) then return nil; end
	local _s, _e, n = string.find(raw, "^([^;%s]+)");
	return n;
end

function Autologin_Load()
	Autologin_Table = {};

	local lastUsedName = GetSavedAccountName()
	-- GetSavedAccounts() now returns { {name=..., lastUsed=epochSeconds}, ... }
	-- where lastUsed is the Windows-tracked LastWritten timestamp on
	-- the vault entry (auto-refreshed by LoginWithSavedAccount).
	local accounts = GetSavedAccounts();
	Autologin_SelectedIdx = nil;
	for i = 1, table.getn(accounts) do
		local entry = accounts[i];
		table.insert(Autologin_Table, {
			name = entry.name,
			lastUsed = entry.lastUsed or 0,
		});
		if entry.name == lastUsedName then Autologin_SelectedIdx = i end
	end

	if ( Autologin_SelectedIdx ) then
		Autologin_CurrentPage =
			math.floor((Autologin_SelectedIdx - 1) / Autologin_PageSize);
	else
		Autologin_CurrentPage = 0;
	end
end

-- `name` is the new last-used account, or "" to forget. Always-overwrite
-- semantics mean any leftover plaintext from the legacy format is
-- replaced on the first successful login after this update ships.
function Autologin_Save(name)
	SetSavedAccountName(name or "");
end

function Autologin_SelectAccount(idx)
	local i = Autologin_CurrentPage * Autologin_PageSize + idx;
	local r = Autologin_Table[i];
	if ( not r ) then return; end
	Autologin_PasswordFieldForced = false;
	AccountLoginAccountEdit:SetText(r.name);
	-- Clear the password field — we no longer have plaintext to
	-- repopulate it with. Empty + a known account name signals
	-- "use the saved credential" in Autologin_OnLogin below.
	AccountLoginPasswordEdit:SetText("");
	-- Don't rely on SetText → OnTextChanged → Autologin_OnNameUpdate
	-- firing — call directly so the visible highlight reliably moves
	-- to the clicked row. OnNameUpdate is idempotent if the chain
	-- does fire afterward.
	Autologin_OnNameUpdate(r.name);
end

function Autologin_OnNameUpdate(name)
	Autologin_SelectedIdx = nil;
	for i = 1, table.getn(Autologin_Table) do
		if ( Autologin_Table[i].name == name ) then Autologin_SelectedIdx = i; end
	end
	if ( Autologin_SelectedIdx ) then
		Autologin_CurrentPage = math.floor((Autologin_SelectedIdx - 1) / Autologin_PageSize);
	end
	Autologin_UpdateUI();
	Autologin_UpdatePasswordVisibility();
end

-- Show the password edit only when we need it: either the typed name
-- isn't a saved vault entry, or the user clicked "Change password" to
-- force the field open. When hidden, the Login button slides up into
-- the password edit's slot so the form doesn't have a gap.
function Autologin_UpdatePasswordVisibility()
	local name = AccountLoginAccountEdit:GetText() or "";
	if ( Autologin_PasswordFieldForced or not HasSavedPassword(name) ) then
		AccountLoginPasswordEdit:Show();
		AccountLoginLoginButton:ClearAllPoints();
		AccountLoginLoginButton:SetPoint("TOP", 8, -519);
		AutologinChangePasswordButton:Hide();
	else
		AccountLoginPasswordEdit:SetText("");
		AccountLoginPasswordEdit:Hide();
		AccountLoginLoginButton:ClearAllPoints();
		AccountLoginLoginButton:SetPoint("TOP", AccountLoginPasswordEdit, "TOP", 0, 0);
		AutologinChangePasswordButton:Show();
	end
end

function Autologin_ChangePassword()
	Autologin_PasswordFieldForced = true;
	Autologin_UpdatePasswordVisibility();
	AccountLogin_FocusPassword();
end

-- Formats `epochSeconds` as a "Last used: <date>" line for the row's
-- second text slot. Falls back to "Never" for entries with no
-- timestamp (theoretically only possible for credentials saved by
-- an older build of this DLL that didn't preserve LastWritten).
local function FormatLastUsed(epochSeconds)
	if ( not epochSeconds or epochSeconds == 0 ) then
		return "Last used: never";
	end
	return "Last used: " .. date("%m/%d/%Y", epochSeconds);
end

function Autologin_UpdateUI()
	local skip = Autologin_CurrentPage * Autologin_PageSize;
	for i = 1, Autologin_PageSize do
		getglobal("AutologinAccountButton" .. i):UnlockHighlight();
		if ( skip + i > table.getn(Autologin_Table) ) then
			getglobal("AutologinAccountButton" .. i):Hide();
		else
			local r = Autologin_Table[skip + i];
			getglobal("AutologinAccountButton" .. i):Show();
			getglobal("AutologinAccountButton" .. i .. "ButtonTextName"):SetText(r.name);
			getglobal("AutologinAccountButton" .. i .. "ButtonTextPassword"):SetText(
				FormatLastUsed(r.lastUsed));
			-- Character autoselect was removed alongside the
			-- plaintext store; the row's character line is always
			-- blank now.
			getglobal("AutologinAccountButton" .. i .. "ButtonTextCharacter"):SetText("");

			if ( Autologin_SelectedIdx == skip + i ) then
				getglobal("AutologinAccountButton" .. i):LockHighlight();
			end
		end
	end

	-- AutologinSizeWarning was tied to the 128-byte SavedAccount cap
	-- for the legacy "name pw char;name pw char;..." format. With
	-- only the last-used account name persisted, the cap is
	-- effectively unreachable; keep the widget hidden.
	getglobal("AutologinSizeWarning"):Hide();
end

function Autologin_OnLogin()
	local name = AccountLoginAccountEdit:GetText();
	local password = AccountLoginPasswordEdit:GetText();

	if ( name == nil or name == "" ) then return; end

	if ( password ~= nil and password ~= "" ) then
		-- New credentials or overwrite of an existing entry.
		-- SaveAccount + LoginWithSavedAccount means the plaintext
		-- password lives in this Lua scope only briefly, and is
		-- never persisted to SavedVariables.
		SaveAccount(name, password);
		Autologin_Save(name);
		Autologin_Load();
		Autologin_UpdateUI();
		LoginWithSavedAccount(name);
	elseif ( HasSavedPassword(name) ) then
		-- Selected a saved account and didn't retype: use the
		-- vault entry directly.
		Autologin_Save(name);
		Autologin_Load();
		Autologin_UpdateUI();
		LoginWithSavedAccount(name);
	end
	-- Empty password + unknown account = no-op; the engine would
	-- have shown an error dialog, but skipping the call keeps the
	-- user on the login screen without an interrupting popup.
end

function AutologinAccountButton_OnClick()
	Autologin_SelectAccount(this:GetID());
end

function AutologinAccountButton_OnDoubleClick()
	Autologin_SelectAccount(this:GetID());
	AccountLogin_Login();
end

function Autologin_RemoveAccount()
	if ( not Autologin_SelectedIdx ) then return; end

	local removed = Autologin_Table[Autologin_SelectedIdx];
	if ( removed ) then
		DeleteAccount(removed.name);
		-- If the removed account was also the last-used, forget it
		-- so next launch doesn't try to pre-select a missing entry.
		if ( ParseLastAccount(GetSavedAccountName()) == removed.name ) then
			Autologin_Save("");
		end
	end

	-- Rebuild from the authoritative list (the vault).
	Autologin_Load();
	Autologin_PasswordFieldForced = false;
	AccountLoginAccountEdit:SetText("");
	AccountLoginPasswordEdit:SetText("");

	if ( Autologin_CurrentPage > 0 and Autologin_CurrentPage * Autologin_PageSize > table.getn(Autologin_Table) - 1 ) then
		Autologin_CurrentPage = Autologin_CurrentPage - 1;
	end

	Autologin_UpdateUI();
end

function Autologin_NextPage()
	if ( (Autologin_CurrentPage + 1) * Autologin_PageSize > table.getn(Autologin_Table) - 1 ) then return; end
	Autologin_CurrentPage = Autologin_CurrentPage + 1;
	Autologin_UpdateUI();
end

function Autologin_PrevPage()
	if ( Autologin_CurrentPage == 0 ) then return; end
	Autologin_CurrentPage = Autologin_CurrentPage - 1;
	Autologin_UpdateUI();
end


FADE_IN_TIME = 2;
DEFAULT_TOOLTIP_COLOR = {0.8, 0.8, 0.8, 0.09, 0.09, 0.09};
MAX_PIN_LENGTH = 10;

function AccountLogin_OnLoad()
	this:SetSequence(0);
	this:SetCamera(0);

	this:RegisterEvent("SHOW_SERVER_ALERT");
	this:RegisterEvent("SHOW_SURVEY_NOTIFICATION");

	local versionType, buildType, version, internalVersion, date = GetBuildInfo();
	AccountLoginVersion:SetText(format(VERSION_TEMPLATE, versionType, version, internalVersion, buildType, date));

	-- Color edit box backdrops
	local backdropColor = DEFAULT_TOOLTIP_COLOR;
	AccountLoginAccountEdit:SetBackdropBorderColor(backdropColor[1], backdropColor[2], backdropColor[3]);
	AccountLoginAccountEdit:SetBackdropColor(backdropColor[4], backdropColor[5], backdropColor[6]);
	AccountLoginPasswordEdit:SetBackdropBorderColor(backdropColor[1], backdropColor[2], backdropColor[3]);
	AccountLoginPasswordEdit:SetBackdropColor(backdropColor[4], backdropColor[5], backdropColor[6]);
	VirtualKeypadText:SetBackdropBorderColor(backdropColor[1], backdropColor[2], backdropColor[3]);
	VirtualKeypadText:SetBackdropColor(backdropColor[4], backdropColor[5], backdropColor[6]);
end

function AccountLogin_OnShow()
	CurrentGlueMusic = "Sound\\Music\\GlueScreenMusic\\wow_main_theme.mp3";
	
	AcceptTOS();
    AcceptEULA();
	local serverName = GetServerName();
	if(serverName) then
		AccountLoginRealmName:SetText(serverName);
	else
		AccountLoginRealmName:Hide()
	end

	Autologin_Load();
	Autologin_PasswordFieldForced = false;
	if ( table.getn(Autologin_Table) ~= 0 ) then
		local r = Autologin_Table[Autologin_SelectedIdx or 1];
		if ( r ) then
			AccountLoginAccountEdit:SetText(r.name);
			AccountLoginPasswordEdit:SetText("");
			Autologin_OnNameUpdate(r.name);
		end
	end
	Autologin_UpdateUI();
	Autologin_UpdatePasswordVisibility();

	if ( table.getn(Autologin_Table) == 0 ) then
		AccountLogin_FocusAccountName();
	elseif ( AccountLoginPasswordEdit:IsVisible() ) then
		AccountLogin_FocusPassword();
	end
end

function AccountLogin_FocusPassword()
	AccountLoginPasswordEdit:SetFocus();
end

function AccountLogin_FocusAccountName()
	AccountLoginAccountEdit:SetFocus();
end

function AccountLogin_OnChar()
end

function AccountLogin_OnKeyDown()
	if ( arg1 == "ESCAPE" ) then
		if ( ConnectionHelpFrame:IsVisible() ) then
			ConnectionHelpFrame:Hide();
			AccountLoginUI:Show();
		elseif ( SurveyNotificationFrame:IsVisible() ) then
			-- do nothing
		else
			AccountLogin_Exit();
		end
		
	elseif ( arg1 == "ENTER" ) then
		if ( not TOSAccepted() ) then
			return;
		elseif ( TOSFrame:IsVisible() or ConnectionHelpFrame:IsVisible() ) then
			return;
		elseif ( SurveyNotificationFrame:IsVisible() ) then
			AccountLogin_SurveyNotificationDone(1);
		end
		AccountLogin_Login();
	elseif ( arg1 == "PRINTSCREEN" ) then
		Screenshot();
	end
end

function AccountLogin_OnEvent(event)
	if ( event == "SHOW_SERVER_ALERT" ) then
		ServerAlertText:SetText(arg1);
		ServerAlertScrollFrame:UpdateScrollChildRect();
		ServerAlertFrame:Show();
	elseif ( event == "SHOW_SURVEY_NOTIFICATION" ) then
		AccountLogin_ShowSurveyNotification();
	end
end

function AccountLogin_Login()
	PlaySound("gsLogin");
	Autologin_OnLogin();
end

function AccountLogin_Turtle_Armory_Website()
	PlaySound("gsLoginNewAccount");
	LaunchURL(TURTLE_ARMORY_WEBSITE);
end

function AccountLogin_Turtle_Website()
	PlaySound("gsLoginNewAccount");
	LaunchURL(AUTH_TURTLE_WEBSITE);
end

function AccountLogin_Turtle_Knowledge_Database()
	PlaySound("gsLoginNewAccount");
	LaunchURL(TURTLE_KNOWLEDGE_DATABASE_WEBSITE);
end

function AccountLogin_Turtle_Community_Forum()
	PlaySound("gsLoginNewAccount");
	LaunchURL(TURTLE_COMMUNITY_FORUM_WEBSITE);
end

function AccountLogin_Turtle_Discord()
	PlaySound("gsLoginNewAccount");
	LaunchURL(TURTLE_DISCORD_WEBSITE);
end

function AccountLogin_Turtle_Reddit()
	PlaySound("gsLoginNewAccount");
	LaunchURL(TURTLE_REDDIT_WEBSITE);
end

function AccountLogin_Credits()
	if ( not GlueDialog:IsVisible() ) then
		PlaySound("gsTitleCredits");
		SetGlueScreen("credits");
	end
end

function AccountLogin_Cinematics()
	if ( not GlueDialog:IsVisible() ) then
		PlaySound("gsTitleIntroMovie");
		SetGlueScreen("movie");
	end
end

function AccountLogin_Options()
	PlaySound("gsTitleOptions");
end

function AccountLogin_Exit()
	PlaySound("gsTitleQuit");
	QuitGame();
end

function AccountLogin_ShowSurveyNotification()
	GlueDialog:Hide();
	AccountLoginUI:Hide();
	SurveyNotificationAccept:Enable();
	SurveyNotificationDecline:Enable();
	SurveyNotificationFrame:Show();
end

function AccountLogin_SurveyNotificationDone(accepted)
	SurveyNotificationFrame:Hide();
	SurveyNotificationAccept:Disable();
	SurveyNotificationDecline:Disable();
	SurveyNotificationDone(accepted);
	AccountLoginUI:Show();
end

-- Virtual keypad functions
local buttonText = {}
function VirtualKeypadFrame_OnEvent(event)
	if ( event == "PLAYER_ENTER_PIN" ) then
		for i=1, 10 do
			buttonText[i] = _G["arg"..i]
		end
	end
	-- Randomize location to prevent hacking (yeah right)
	local xPadding = 5;
	local yPadding = 10;
	local xPos = random(xPadding, GlueParent:GetWidth()-VirtualKeypadFrame:GetWidth()-xPadding);
	local yPos = random(yPadding, GlueParent:GetHeight()-VirtualKeypadFrame:GetHeight()-yPadding);
	--VirtualKeypadFrame:SetPoint("TOPLEFT", GlueParent, "TOPLEFT", xPos, -yPos);
	
	VirtualKeypadFrame:Show();
	VirtualKeypad_UpdateButtons();
end

function VirtualKeypadButton_OnClick()
	local text = VirtualKeypadText:GetText();
	if ( not text ) then
		text = "";
	end
	VirtualKeypadFrame.PIN = VirtualKeypadFrame.PIN..this:GetID();
	VirtualKeypadText:SetText(VirtualKeypadFrame.PIN);
	VirtualKeypad_UpdateButtons();
end

function VirtualKeypadOkayButton_OnClick()
	local PIN = VirtualKeypadText:GetText();
	local numNumbers = strlen(PIN);
	if numNumbers < 6 then return end
	local pinNumber = {};
	for i=1, MAX_PIN_LENGTH do
		if ( i <= numNumbers ) then
			pinNumber[i] = nil;
			for j=1, 10 do
				if tonumber(buttonText[j]) == tonumber(strsub(PIN,i,i)) then
					pinNumber[i] = j-1;
				end
			end
		else
			pinNumber[i] = nil;
		end
	end
	PINEntered(pinNumber[1], pinNumber[2], pinNumber[3], pinNumber[4], pinNumber[5], pinNumber[6], pinNumber[7], pinNumber[8], pinNumber[9], pinNumber[10]);
	VirtualKeypadFrame:Hide();
end

function VirtualKeypad_UpdateButtons()
end
