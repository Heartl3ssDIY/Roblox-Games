-- TimeService: in-game clock -> Lighting, day/week/month counters + change signals, current shift.
local RS=game:GetService("ReplicatedStorage"); local Lighting=game:GetService("Lighting"); local RunService=game:GetService("RunService")
local Progression=require(RS.Configs.ProgressionConfig)

local TimeService={}
TimeService.ShiftChanged=Instance.new("BindableEvent")  -- (newShift, day)
TimeService.DayChanged=Instance.new("BindableEvent")    -- (day)
TimeService.WeekChanged=Instance.new("BindableEvent")   -- (week)
TimeService.MonthChanged=Instance.new("BindableEvent")  -- (month)

local HOUR=Progression.GameHourSeconds
-- admin fast-forward: a local time offset (in-game hours) that can be advanced quickly to reach night.
local timeOffset=0
local accel=false
local ACCEL_HOUR_SECONDS=10   -- while accelerating, 1 in-game hour passes in this many real seconds
local WEEKDAYS={"Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"}
local function weekdayFor(day) return WEEKDAYS[((day-1)%7)+1] end
local function shiftFor(h)
	if h>=6 and h<14 then return "Morning" elseif h>=14 and h<22 then return "Afternoon" else return "Night" end
end

-- GLOBAL clock: in-game time is a pure function of the real UTC clock (os.time), so EVERY server
-- agrees on the day/hour/weekday AND time keeps advancing even with no players online -- so the weekly
-- investor cycle (and anything gated on the day) stays on a single global schedule. EPOCH anchors
-- in-game Day 1 to a fixed real instant; DO NOT change it after launch or everyone's calendar jumps.
local EPOCH=1782049379   -- ~2026-06-21 UTC; in-game Day 1 hour 0
local function totalHours() return (os.time()-EPOCH)/HOUR + timeOffset end
local function nowCal()
	local th=totalHours()
	local day=math.floor(th/24)+1
	return th%24, day, math.floor((day-1)/7)+1, math.floor((day-1)/30)+1
end
TimeService.getDay=function() local _,d=nowCal(); return d end   -- global day, for day-gated services

function TimeService.Start()
	local gt=RS:FindFirstChild("GameTime") or Instance.new("Configuration")
	gt.Name="GameTime"; gt.Parent=RS
	local hour,day,week,month=nowCal()
	local curShift=shiftFor(hour); local lastDay,lastWeek,lastMonth=day,week,month
	gt:SetAttribute("Hour",hour); gt:SetAttribute("Day",day); gt:SetAttribute("Week",week); gt:SetAttribute("Month",month); gt:SetAttribute("Shift",curShift); gt:SetAttribute("Weekday",weekdayFor(day))
	Lighting.ClockTime=hour
	RunService.Heartbeat:Connect(function(dt)
		if accel then timeOffset += (dt or 1/60)*(1/ACCEL_HOUR_SECONDS - 1/HOUR) end
		local h,d,w,m=nowCal()
		if accel and shiftFor(h)=="Night" then accel=false end   -- reached night: resume normal speed
		Lighting.ClockTime=h
		gt:SetAttribute("Hour",h); gt:SetAttribute("Day",d); gt:SetAttribute("Week",w); gt:SetAttribute("Month",m)
		local s=shiftFor(h)
		if s~=curShift then curShift=s; gt:SetAttribute("Shift",s); TimeService.ShiftChanged:Fire(s,d) end
		if d~=lastDay then lastDay=d; gt:SetAttribute("Weekday",weekdayFor(d)); TimeService.DayChanged:Fire(d) end
		if w~=lastWeek then lastWeek=w; TimeService.WeekChanged:Fire(w) end
		if m~=lastMonth then lastMonth=m; TimeService.MonthChanged:Fire(m) end
	end)
end
-- Admin: speed time up (1 hour = ACCEL_HOUR_SECONDS) until the Night shift, then resume normal.
function TimeService.fastForwardToNight()
	local h=nowCal()
	if shiftFor(h)=="Night" then return false, "It's already night." end
	accel=true
	return true
end
function TimeService.isAccelerating() return accel end
function TimeService.getShift() local gt=RS:FindFirstChild("GameTime"); return gt and gt:GetAttribute("Shift") or "Morning" end
function TimeService.getWeekday() local gt=RS:FindFirstChild("GameTime"); return gt and gt:GetAttribute("Weekday") or "Monday" end
function TimeService.getHour() local gt=RS:FindFirstChild("GameTime"); return gt and gt:GetAttribute("Hour") or 6 end
return TimeService

