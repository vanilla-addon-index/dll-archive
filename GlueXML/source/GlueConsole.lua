GLUE_CONSOLE_MAX_LINES = 200;

function GlueConsole_OnLoad()
	GlueConsoleOutput:SetFading(false);
	GlueConsoleOutput:SetMaxLines(GLUE_CONSOLE_MAX_LINES);
	GlueConsoleOutput:SetJustifyH("LEFT");

	-- ChatFrameBackground is a white pixel; tint to dark + faint border.
	GlueConsoleInput:SetBackdropColor(0, 0, 0, 0.7);
	GlueConsoleInput:SetBackdropBorderColor(0.4, 0.4, 0.4, 1);

	-- Route print() output into the console so RunScript("print(...)") is visible.
	local original_print = print;
	print = function(...)
		local parts = {};
		for i = 1, arg.n do
			parts[i] = tostring(arg[i]);
		end
		GlueConsole_Print(table.concat(parts, "  "));
		if ( original_print ) then
			original_print(unpack(arg));
		end
	end
end

function GlueConsole_Print(msg)
	if ( msg == nil ) then msg = "nil"; end
	GlueConsoleOutput:AddMessage(tostring(msg));
end

function GlueConsole_Toggle()
	if ( GlueConsoleFrame:IsVisible() ) then
		GlueConsoleInput:ClearFocus();
		GlueConsoleFrame:Hide();
	else
		GlueConsoleFrame:Show();
		GlueConsoleFrame:Raise();
		GlueConsoleInput:SetFocus();
	end
end

-- Returns true if a backtick was found in the EditBox text. Strips it and toggles the console.
-- Used as an OnTextChanged interceptor so backtick still toggles the console while an EditBox has focus
-- (the parent frame's OnKeyDown doesn't fire when an EditBox has consumed the keystroke).
function GlueConsole_StripBacktickAndToggle(editBox)
	local text = editBox:GetText();
	if ( text == nil ) then return false; end
	if ( string.find(text, "`", 1, true) == nil ) then return false; end
	editBox:SetText((string.gsub(text, "`", "")));
	GlueConsole_Toggle();
	return true;
end

function GlueConsole_Submit()
	local text = GlueConsoleInput:GetText();
	GlueConsoleInput:SetText("");
	if ( text == nil or text == "" ) then return; end

	GlueConsole_Print("> " .. text);
	if ( RunScript ) then
		RunScript(text);
	else
		GlueConsole_Print("|cffff4444RunScript is not available in this context|r");
	end
end
