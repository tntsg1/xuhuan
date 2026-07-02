extends RefCounted
class_name Localization


static func text(en: String, zh: String, mode: String = "both") -> String:
	if mode == "en":
		return en
	if mode == "zh":
		return zh
	return en + "\n" + zh


static func from_dict(data: Dictionary, base: String, mode: String = "both") -> String:
	var en := str(data.get(base + "_en", data.get(base, "")))
	var zh := str(data.get(base + "_zh", en))
	return text(en, zh, mode)
