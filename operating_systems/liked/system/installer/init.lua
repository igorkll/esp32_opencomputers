local internet = component.proxy(component.list("internet")() or "")

if not internet then
	error("an internet card is required for the installer", 0)
end

local function get(url)
	local handle, err = internet.request(url)
	if handle then
		local data = {}
		while true do
			local result, reason = handle.read(math.huge) 
			if result then
				table.insert(data, result)
			else
				handle.close()
				
				if reason then
					return nil, reason
				else
					return table.concat(data)
				end
			end
		end
	end
	return nil, tostring(err or "unknown")
end

assert(load(assert(get("https://raw.githubusercontent.com/igorkll/liked/main/installer/webInstaller.lua"))))()
computer.shutdown()