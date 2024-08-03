local s = minetest.get_mod_storage()
local F = minetest.formspec_escape
local delay = {}
local selected = {}
local msglist = {}
local http = minetest.request_http_api()
local dcmsg
if not http then
	minetest.log("warning",
		"Discord relay of StaffMail is disabled. Please add `staffmail` to secure.http_mods to enable it.")
else
	local url = minetest.settings:get("staffmail.dcwh_url")
	if url then
		dcmsg = function(data)
			local json = minetest.write_json({content = data})
			http.fetch({
				url = url,
				method = "POST",
				extra_headers = {"Content-Type: application/json"},
				data = json
			},function() end)
		end
	else
		minetest.log("warning",
			"Discord relay of StaffMail is disabled because Discord webhook URL is not set.")

	end
end

minetest.register_privilege("staffmail",{
	give_to_singleplayer = false,
	give_to_admin = false
})

local staff_fs = function(name, text)
	local list = {}
	for title,content in pairs(s:to_table().fields) do
		if title and title ~= "" then
			table.insert(list,title)
		end
	end
	msglist[name] = list
	minetest.show_formspec(name,"staffmail_staff","size[16,10]" ..
		"label[0.2,0.1;List of messages]" ..
		"box[5.5,0.2;10,9.6;#000]" ..
		"textlist[0.2,0.5;5.2,8.5;messages;"..table.concat(list,",").."]" ..
		(list[selected[name]] and text and
		"textarea[5.8,0.2;10.2,11.2;;"..list[selected[name]]..";"..text.."]" or "") ..
		"button[0.2,9;1.5,1;open;Open]" ..
		"button[1.7,9;1.5,1;delete;Delete]" ..
		"button[4.1,9;1.5,1;sendnew;Send new]")
end

local player_fs = function(name)
	minetest.show_formspec(name,"staffmail","size[10,10]" ..
		"field[0.6,0.6;9.5,1;title;Title;]" ..
		"field_close_on_enter[title;false]" ..
		"textarea[0.6,1.4;9.5,9;text;Text;]" ..
		"button[0.3,9.1;9.5,1;send;Send]")
end

local function setdelay(name)
	if not minetest.check_player_privs(name,{staffmail=true}) then
		delay[name] = true
		minetest.after(600, function()
			delay[name] = nil
		end)
	end
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	local name = player and player:get_player_name()
	if not name then return end
	if formname == "staffmail" then
		if fields.send then
			if delay[name] then
				minetest.chat_send_player(name,"You have to wait 10 minutes before sending another message to the staff")
				return
			end
			if not fields.title or fields.title == "" then
				minetest.chat_send_player(name,"Please fill the title")
				return
			end
			if not fields.text or not fields.text:match("%S+") then
				minetest.chat_send_player(name,"Please type the text of the message")
				return
			end
			s:set_string(name.." - '"..F(fields.title).."' ("..os.date("%d.%m.%Y %H:%M:%S")..")",F(fields.text))
			if dcmsg then
				dcmsg(name.." sent '"..fields.title.."':```\n"..fields.text.."\n```")
			end
			setdelay(name)
			minetest.close_formspec(name,"staffmail")
			minetest.chat_send_player(name,"'"..fields.title.."' sent successfully")
		end
	end
	if formname == "staffmail_staff" then
		local list = msglist[name]
		local text = selected[name] and list[selected[name]] and s:get_string(list[selected[name]]) or ""
		if fields.messages then
			local evnt = minetest.explode_textlist_event(fields.messages)
			selected[name] = evnt.index
			text = list[evnt.index] and s:get_string(list[evnt.index]) or ""
			if evnt.type == "DCL" then
				staff_fs(name,text)
			end
		end
		if fields.open then
			staff_fs(name,text)
		end
		if fields.delete and list[selected[name]] then
			s:set_string(list[selected[name]],"")
			selected[name] = nil
			staff_fs(name)
		end
		if fields.sendnew then
			player_fs(name)
		end
		if fields.quit then
			selected[name] = nil
			msglist[name] = nil
		end
	end
end)

minetest.register_chatcommand("smail",{
	description = "Send the message to the staff. Use without params to open GUI",
	params = "[title] [text]",
	privs = {interact=true},
	func = function(name, param)
		if param and param ~= "" then
			local params = param:split(" ", false, 1)
			if params and #params == 2 then
				if delay[name] then
					return fale, "You have to wait 10 minutes before sending another message to the staff"
				end
				s:set_string(name.." - '"..F(params[1]).."' ("..os.date("%d.%m.%Y %H:%M:%S")..")",F(params[2]))
				if dcmsg then
					dcmsg(name.." send '"..params[1].."':```\n"..params[2].."\n```")
				end
				setdelay(name)
				return true, "'"..params[1].."' sent successfully."
			else
				return false, "Invalid params"
			end
		end
		if minetest.get_player_by_name(name) then
			if minetest.check_player_privs(name, {staffmail=true}) then
				staff_fs(name)
			else
				player_fs(name)
			end
		else
			return false, "This command can be executed ingame only"
		end
end})
minetest.register_chatcommand("purge-smail",{
	description = "Purge all messages in the staffmail",
	privs = {staffmail=true},
	func = function(name)
		local count = 0
		for title,content in pairs(s:to_table().fields) do
			if type(title) == "string" then
				s:set_string(title,"")
				count = count + 1
			end
		end
		return true, "Deleted "..tostring(count).." entries"
end})
