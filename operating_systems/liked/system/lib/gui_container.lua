local gui_container = {}
gui_container.criticalChargeLevel = 20

gui_container.colors = {}
gui_container.indexsColors = {}

--------------------------------------------

local fs = require("filesystem")
local unicode = require("unicode")
local paths = require("paths")

--------------------------------------------

gui_container.defaultUserRoot = "/data/userdata/"

gui_container.userRoot = {} --{screen = path, ...}
gui_container.viewFileExps = {} --если адрес экрана сдесь равен true то разширения имен файлов не будут скрыты
gui_container.devModeStates = {} --легаси, и почти негде не используеться, dev-mode был удален из системы
gui_container.unlockedDisks = {}
gui_container.hiddenFiles = {}

gui_container.chars = {
	threeDots = "…",
	splitLine = "⎯",
	wideSplitLine = "⠶",
	dot = "●"
}

gui_container.archiveFormats = {
	"tar",
	"afpx"
}

gui_container.screenSaverPath = "/data/screenSaver.scrsv"

---------------------------- необходимо сканфигурировать это все, в своей програме для поддержки свого формата

gui_container.newCreate = { --структура {name, exp, allowCheck(), create(path)}
}

gui_container.filesExps = { --дополнительные действия к файлам
}

gui_container.openVia = {
}

gui_container.typecolors = {
}

gui_container.typenames = {
}

gui_container.knownExps = { --данные файлы не будет предложинно открыть в текстовом редакторе(если поставить editable то будет предложенно)
}

gui_container.editable = { --вместо "open is text editor" будет писаться "edit"
}

----------------------------

function gui_container.getUserRoot(screen)
	local path = gui_container.userRoot[screen] or gui_container.defaultUserRoot
	fs.makeDirectory(path)
	if path:sub(#path, #path) ~= "/" then
		return path .. "/"
	end
	return path
end

function gui_container.short(str, max, endcheck)
	local len = unicode.len(str)
	if len > max then
		if endcheck then
			return unicode.sub(str, 1, max - 1) .. gui_container.chars.threeDots
		else
			return gui_container.chars.threeDots .. unicode.sub(str, (len - max) + 2, len)
		end
	end
	return str
end

function gui_container.toUserPath(screen, path) --конвертирует рутовый путь в путь пользователя
	return paths.canonical(unicode.sub(path, unicode.len(gui_container.getUserRoot(screen)), unicode.len(path)))
end

function gui_container.checkPath(screen, path) --проверяет не вышел ли пользователь из своей папки
	local userPath = gui_container.getUserRoot(screen)
	if unicode.sub(path, 1, unicode.len(userPath)) ~= userPath then
		return userPath
	end
	return path
end

function gui_container.refresh()
	local registry = require("registry")
	for str, tbl in pairs(registry.gui_container or {}) do
		for key, value in pairs(tbl) do
			gui_container[str][key] = value
		end
	end

	local cache = require("cache")
	cache.cache.findIcon = nil
	cache.cache.getIcon = nil
end

return gui_container