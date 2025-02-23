local gui_container = require("gui_container")
local fs = require("filesystem")

if gui_container.linksAdded then
	error("you cannot run this file a second time", 2)
end

---------------------------- modify

local modify = {}
modify.newCreate = { --структура {name, exp, allowCheck(), create(path)}
	{
		"system-dump",
		"afpx",
		function (path)
			return not fs.isReadOnly(path)
		end,
		function (path)
			return require("archiver").pack("/mnt/root", path)
		end
	}
}

modify.filesExps = { --дополнительные действия к файлам

}

modify.openVia = {
	["afpx"] = "unpackArchive",
	["tar"] = "unpackArchive",
	["reg"] = "applyReg",
	["xpkg"] = "xpkgInstall",
	["box"] = "boxInstall",
	["vbox"] = "boxInstall",
	["sbox"] = "boxInstall",
	["ebox"] = "boxInstall"
}

modify.typecolors = {
	["app"] = gui_container.colors.red,
	["afpx"] = gui_container.colors.orange,
	["tar"] = gui_container.colors.orange,
	["lua"] = gui_container.colors.lime
}

modify.typenames = {
	["t1p"] = "image",
	["t2p"] = "image",
	["t3p"] = "image",
	["txt"] = "text",
	["afpx"] = "archive",
	["tar"] = "archive",
	["scrsv"] = "screensaver"
}

modify.knownExps = { --данные файлы не будет предложинно открыть в текстовом редакторе(если поставить editable то будет предложенно)
	["scrsv"] = true,   
	["lua"] = true,
	["app"] = true,
	["t1p"] = true,
	["t2p"] = true,
	["t3p"] = true,
	["plt"] = true,
	["dat"] = true,
	["cfg"] = true,
	["log"] = true,
	["afpx"] = true,
	["tar"] = true,
	["txt"] = true, --текстовому документу не нужно отдельная кнопка, он по умалчанию открываеться через редактор
	["reg"] = true,
	["xpkg"] = true,
	["box"] = true,
	["vbox"] = true,
	["ebox"] = true,
	["sbox"] = true
}

modify.editable = { --вместо "open is text editor" будет писаться "edit"
	["lua"] = true,
	["scrsv"] = true,
	["plt"] = true,
	["reg"] = true
}

----------------------------

for listname, list in pairs(modify) do
	for k, v in pairs(list) do
		gui_container[listname][k] = v
	end
end

gui_container.linksAdded = true
gui_container.refresh()