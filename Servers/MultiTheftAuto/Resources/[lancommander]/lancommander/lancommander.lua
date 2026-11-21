-- Creates (or updates the password of) the admin account from the admin_user/admin_password
-- settings, which the container writes from MTA_ADMIN_USER / MTA_ADMIN_PASSWORD, and puts it in
-- the Admin ACL group. Log in in-game with /login <password>, then press P for the admin panel.
addEventHandler("onResourceStart", resourceRoot,
	function()
		local user = get("admin_user")
		local password = get("admin_password")
		if type(user) ~= "string" or user == "" or type(password) ~= "string" or password == "" then
			return
		end

		local account = getAccount(user)
		if account then
			setAccountPassword(account, password)
		else
			account = addAccount(user, password)
		end
		if not account then
			return outputDebugString("lancommander: could not create the admin account '" .. user .. "'", 1)
		end

		local group = aclGetGroup("Admin")
		if not group then
			return outputDebugString("lancommander: ACL group Admin not found", 1)
		end
		if not isObjectInACLGroup("user." .. user, group) then
			aclGroupAddObject(group, "user." .. user)
			aclSave()
		end
		outputServerLog("LANCOMMANDER: admin account '" .. user .. "' is ready")
	end
)
