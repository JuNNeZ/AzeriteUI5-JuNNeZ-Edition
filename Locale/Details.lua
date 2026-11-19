-- Details skin switch (/az -> Themes -> Details), registered after the main locale files.
local addon = ...
local locales = {
	enUS = {
		"Use the AzeriteUI skin on Details windows",
		"Gives every Details window the AzeriteUI Forged (Preview) skin through Details' own skin selector. Turning it off gives each window back the skin it had before.",
		"Details resets a window's appearance settings when its skin changes. Window positions and meter data are kept. Continue?",
		"Requires the Details! Damage Meter addon."
	},
	deDE = {
		"AzeriteUI-Skin für Details-Fenster verwenden",
		"Gibt jedem Details-Fenster den Skin AzeriteUI Forged (Preview) über die Skin-Auswahl von Details. Ausschalten gibt jedem Fenster seinen vorherigen Skin zurück.",
		"Details setzt die Darstellungseinstellungen eines Fensters zurück, wenn sich sein Skin ändert. Fensterpositionen und Messdaten bleiben erhalten. Fortfahren?",
		"Erfordert das Addon Details! Damage Meter."
	},
	esES = {
		"Usar la apariencia de AzeriteUI en las ventanas de Details",
		"Aplica la apariencia AzeriteUI Forged (Preview) a todas las ventanas de Details mediante el selector de apariencias de Details. Al desactivarla, cada ventana recupera la apariencia que tenía antes.",
		"Details restablece los ajustes de aspecto de una ventana cuando cambia su apariencia. Se conservan las posiciones de las ventanas y los datos del medidor. ¿Continuar?",
		"Requiere el addon Details! Damage Meter."
	},
	frFR = {
		"Utiliser le skin AzeriteUI sur les fenêtres de Details",
		"Applique le skin AzeriteUI Forged (Preview) à chaque fenêtre de Details via le sélecteur de skins de Details. Le désactiver rend à chaque fenêtre son skin précédent.",
		"Details réinitialise les réglages d’apparence d’une fenêtre quand son skin change. Les positions des fenêtres et les données du compteur sont conservées. Continuer ?",
		"Nécessite l’addon Details! Damage Meter."
	},
	itIT = {
		"Usa la skin di AzeriteUI nelle finestre di Details",
		"Applica la skin AzeriteUI Forged (Preview) a ogni finestra di Details tramite il selettore di skin di Details. Disattivandola, ogni finestra torna alla skin precedente.",
		"Details reimposta le impostazioni di aspetto di una finestra quando ne cambia la skin. Le posizioni delle finestre e i dati del misuratore restano invariati. Continuare?",
		"Richiede l’addon Details! Damage Meter."
	},
	koKR = {
		"Details 창에 AzeriteUI 스킨 사용",
		"Details의 스킨 선택기를 통해 모든 Details 창에 AzeriteUI Forged (Preview) 스킨을 적용합니다. 끄면 각 창이 이전 스킨으로 돌아갑니다.",
		"Details는 창의 스킨이 바뀌면 해당 창의 외형 설정을 초기화합니다. 창 위치와 미터 데이터는 유지됩니다. 계속하시겠습니까?",
		"Details! Damage Meter 애드온이 필요합니다."
	},
	ptBR = {
		"Usar a skin do AzeriteUI nas janelas do Details",
		"Aplica a skin AzeriteUI Forged (Preview) a todas as janelas do Details pelo seletor de skins do próprio Details. Ao desativar, cada janela volta à skin que tinha antes.",
		"O Details redefine as configurações de aparência de uma janela quando a skin muda. As posições das janelas e os dados do medidor são mantidos. Continuar?",
		"Requer o addon Details! Damage Meter."
	},
	ruRU = {
		"Использовать скин AzeriteUI для окон Details",
		"Применяет скин AzeriteUI Forged (Preview) ко всем окнам Details через собственный выбор скинов Details. При отключении каждому окну возвращается прежний скин.",
		"Details сбрасывает настройки внешнего вида окна при смене скина. Положение окон и данные измерителя сохраняются. Продолжить?",
		"Требуется аддон Details! Damage Meter."
	},
	zhCN = {
		"在 Details 窗口使用 AzeriteUI 皮肤",
		"通过 Details 自带的皮肤选择器，为每个 Details 窗口应用 AzeriteUI Forged (Preview) 皮肤。关闭后，每个窗口恢复之前的皮肤。",
		"更换皮肤时，Details 会重置该窗口的外观设置。窗口位置和统计数据会保留。是否继续？",
		"需要 Details! Damage Meter 插件。"
	},
	zhTW = {
		"在 Details 視窗使用 AzeriteUI 外觀",
		"透過 Details 內建的外觀選擇器，為每個 Details 視窗套用 AzeriteUI Forged (Preview) 外觀。關閉後，每個視窗恢復先前的外觀。",
		"更換外觀時，Details 會重設該視窗的外觀設定。視窗位置和統計資料會保留。是否繼續？",
		"需要 Details! Damage Meter 插件。"
	}
}
-- Register the fallback first, independent of the active client language.
local ace = LibStub("AceLocale-3.0")
local fallback = ace:NewLocale(addon, "enUS", true, true)
for _, key in ipairs(locales.enUS) do fallback[key] = true end
for locale, strings in pairs(locales) do
	if (locale ~= "enUS") then
		local L = ace:NewLocale(addon, locale)
		if (L) then
			for index, key in ipairs(locales.enUS) do L[key] = strings[index] end
		end
	end
end
