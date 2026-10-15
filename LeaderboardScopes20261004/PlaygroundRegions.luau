--!strict
-- Geographic grouping: https://unstats.un.org/unsd/methodology/m49/overview/
-- Roblox country codes: https://create.roblox.com/docs/reference/engine/classes/LocalizationService

export type Region = { id: string, name: string }

local regions: { [string]: Region } = {
	Europe = table.freeze({ id = "Europe", name = "Europe" }),
	NorthAmerica = table.freeze({ id = "NorthAmerica", name = "North America" }),
	SouthAmerica = table.freeze({ id = "SouthAmerica", name = "South America" }),
	Africa = table.freeze({ id = "Africa", name = "Africa" }),
	Asia = table.freeze({ id = "Asia", name = "Asia" }),
	Oceania = table.freeze({ id = "Oceania", name = "Oceania" }),
}
table.freeze(regions)

local countries = {
	Europe = "AD AL AT AX BA BE BG BY CH CZ DE DK EE ES FI FO FR GB GG GI GR HR HU IE IM IS IT JE LI LT LU LV MC MD ME MK MT NL NO PL PT RO RS RU SE SI SJ SK SM UA VA",
	NorthAmerica = "AG AI AN AW BB BL BM BQ BS BZ CA CR CU CW DM DO GD GL GP GT HN HT JM KN KY LC MF MQ MS MX NI PA PM PR SV SX TC TT US VC VG VI",
	SouthAmerica = "AR BO BR BV CL CO EC FK GF GS GY PE PY SR UY VE",
	Africa = "AO BF BI BJ BW CD CF CG CI CM CV DJ DZ EG EH ER ET GA GH GM GN GQ GW IO KE KM LR LS LY MA MG ML MR MU MW MZ NA NE NG RE RW SC SD SH SL SN SO SS ST SZ TD TF TG TN TZ UG YT ZA ZM ZW",
	Asia = "AE AF AM AZ BD BH BN BT CN CY GE HK ID IL IN IQ IR JO JP KG KH KP KR KW KZ LA LB LK MM MN MO MV MY NP OM PH PK PS QA SA SG SY TH TJ TL TM TR TW UZ VN YE",
	Oceania = "AS AU CC CK CX FJ FM GU HM KI MH MP NC NF NR NU NZ PF PG PN PW SB TK TO TV UM VU WF WS",
}
local byCountry: { [string]: Region } = {}
for id, codes in countries do
	for code in string.gmatch(codes, "%u%u") do
		byCountry[code] = regions[id]
	end
end
-- AN remains a documented Roblox return code; TW belongs to geographic Asia.
-- AQ has no requested region; XX is Roblox's unknown-country response.
table.freeze(byCountry)

local PlaygroundRegions = {}

function PlaygroundRegions.Resolve(countryCode: unknown): Region?
	if type(countryCode) ~= "string" or #countryCode ~= 2 then
		return nil
	end
	if not string.match(countryCode, "^[A-Za-z][A-Za-z]$") then
		return nil
	end
	return byCountry[string.upper(countryCode)]
end

return table.freeze(PlaygroundRegions)
