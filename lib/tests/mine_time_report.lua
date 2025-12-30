-- Тестовый стенд расчёта времени добычи
-- Сравнивает raw время vs saturated время vs final округлённое время

local time = require "lib.utils.time"
local mine_module = require "main.mines.mine_module"

local function run_mine_time_report()
	local mines_cfg = {
		{id=1, name="TINY_MINE",     xp_per_size=0,   xp=0,   goldinmine=2,    basebet=1,    sectocoin=4.90, sleep_time=180,  betgrowth=1.35, playercommission=0.7, shild_time=86400},
		{id=2, name="SMALL_MINE",    xp_per_size=1,   xp=1,   goldinmine=10,   basebet=4,    sectocoin=4.80, sleep_time=300,  betgrowth=1.35, playercommission=0.7, shild_time=43200},
		{id=3, name="MEDIUM_MINE",   xp_per_size=3,   xp=4,   goldinmine=45,   basebet=18,   sectocoin=4.55, sleep_time=600,  betgrowth=1.35, playercommission=0.7, shild_time=21600},
		{id=4, name="LARGE_MINE",    xp_per_size=9,   xp=13,  goldinmine=129,  basebet=50,   sectocoin=4.40, sleep_time=900,  betgrowth=1.35, playercommission=0.7, shild_time=10800},
		{id=5, name="BIG_MINE",      xp_per_size=18,  xp=31,  goldinmine=434,  basebet=160,  sectocoin=4.31, sleep_time=1200, betgrowth=1.35, playercommission=0.7, shild_time=5400},
		{id=6, name="HUGE_MINE",     xp_per_size=36,  xp=67,  goldinmine=1429, basebet=500,  sectocoin=4.22, sleep_time=1800, betgrowth=1.35, playercommission=0.7, shild_time=2700},
		{id=7, name="GIGANTIC_MINE", xp_per_size=72,  xp=139, goldinmine=4500, basebet=1500, sectocoin=3.71, sleep_time=3600, betgrowth=1.35, playercommission=0.7, shild_time=1200},
		{id=8, name="LEGENDARY_MINE",xp_per_size=144, xp=283, goldinmine=11000,basebet=3500, sectocoin=3.00, sleep_time=7200, betgrowth=1.35, playercommission=0.7, shild_time=600},
	}

	local grades = {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25}

	pprint("==== ВРЕМЯ ДОБЫЧИ: ОТЧЁТ (raw vs saturated vs final-rounded) ====")
	for _, params in ipairs(mines_cfg) do
		pprint(string.format("-- %s (id=%d) sectocoin=%.2f basebet=%d growth=%.2f gold=%.0f", params.name, params.id, params.sectocoin, params.basebet, params.betgrowth, params.goldinmine))
		for _, grade in ipairs(grades) do
			local mine = { grade = grade }
			local data = mine_module.getCurrentMineData(params, mine)

			local bet = data.bet
			local gold = data.goldinmine
			local prize = data.prize

			local raw_time_s
			if grade == 0 then
				raw_time_s = params.sectocoin * prize
			else
				raw_time_s = params.sectocoin * bet
			end

			local sat_time_s = (grade > 0) and time.saturating_time_pvp(params.sectocoin, bet, 24*60*60, 1) or raw_time_s
			local final_s = data.time_extraction

			local function fmt(s)
				return time.get_human_time_symbol(s)
			end

			pprint(string.format("grade=%-3d bet=%-8.0f gold=%-8.0f prize=%-8.0f | raw=%-10s (%-6.0fs) sat=%-10s (%-6.0fs) final=%-10s (%-6.0fs)",
				grade, bet, gold, prize,
				fmt(raw_time_s), raw_time_s,
				fmt(sat_time_s), sat_time_s,
				fmt(final_s), final_s
			))
		end
	end
	pprint("==== КОНЕЦ ОТЧЁТА ====")
end

-- Экспортируем функцию для использования в других модулях
return {
	run = run_mine_time_report
}
