-- Shared seasonal option, registered after the main locale files.
local addon = ...
local locales = {
	enUS = { "Hide Halloween decorations", "Hide the seasonal decorations for this character until next Halloween. Available only during the event." },
	deDE = { "Halloween-Dekoration ausblenden", "Blendet die saisonale Dekoration für diesen Charakter bis zum nächsten Halloween aus. Nur während des Ereignisses verfügbar." },
	esES = { "Ocultar decoraciones de Halloween", "Oculta las decoraciones de temporada para este personaje hasta el próximo Halloween. Solo disponible durante el evento." },
	frFR = { "Masquer les décorations d’Halloween", "Masque les décorations saisonnières pour ce personnage jusqu’au prochain Halloween. Disponible uniquement pendant l’événement." },
	itIT = { "Nascondi le decorazioni di Halloween", "Nasconde le decorazioni stagionali per questo personaggio fino al prossimo Halloween. Disponibile solo durante l’evento." },
	koKR = { "할로윈 장식 숨기기", "다음 할로윈까지 이 캐릭터의 시즌 장식을 숨깁니다. 이벤트 기간에만 사용할 수 있습니다." },
	ptBR = { "Ocultar decorações de Halloween", "Oculta as decorações sazonais deste personagem até o próximo Halloween. Disponível apenas durante o evento." },
	ruRU = { "Скрыть украшения Хеллоуина", "Скрывает сезонные украшения для этого персонажа до следующего Хеллоуина. Доступно только во время события." },
	zhCN = { "隐藏万圣节装饰", "为此角色隐藏节日装饰，直到下一个万圣节。仅在活动期间可用。" },
	zhTW = { "隱藏萬聖節裝飾", "為此角色隱藏節日裝飾，直到下一個萬聖節。僅在活動期間可用。" }
}
-- Register the fallback first, independent of the active client language.
local ace = LibStub("AceLocale-3.0")
local fallback = ace:NewLocale(addon, "enUS", true, true)
fallback[locales.enUS[1]], fallback[locales.enUS[2]] = true, true
for locale, strings in pairs(locales) do
	if (locale ~= "enUS") then
		local L = ace:NewLocale(addon, locale)
		if (L) then
			L[locales.enUS[1]], L[locales.enUS[2]] = strings[1], strings[2]
		end
	end
end
