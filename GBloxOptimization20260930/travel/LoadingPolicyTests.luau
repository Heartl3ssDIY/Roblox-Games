local checks = 0
local function check(value, message) checks += 1 assert(value, message) end
local function menuCase(optionalAssets, assets, loaded)
 local loading={LoadingText={},Retry={Visible=false}}
 local gui={SetAttribute=function() end}
 local warn=function() end
 local loadingInProgress=true
 local code = [====[	local failed, requiredFailed = {}, {}
	for _, id in assets do
		if not loaded[id] then
   table.insert(failed, id)
   if not optionalAssets[id] then table.insert(requiredFailed, id) end
  end
	end
	gui:SetAttribute("FailedAssets", table.concat(failed, ", "))
 if #failed > 0 then warn("[G-Blox menu] Asset fetch incomplete: "..table.concat(failed, ", ")) end
	if #requiredFailed > 0 then
		loading.LoadingText.Text = "Loading menu images"
		loading.Retry.Visible = true
		loadingInProgress = false
		return
	end
]====]
 local run=assert(loadstring("return function(loading,gui,warn,loadingInProgress,optionalAssets,assets,loaded) "..code.." end"))()
 run(loading,gui,warn,loadingInProgress,optionalAssets,assets,loaded)
 return loading.Retry.Visible
end
check(not menuCase({sound=true,decor=true},{"play","sound","decor"},{play=true}),"sound/decor outage must not block menu")
check(menuCase({sound=true},{"play","sound"},{sound=true}),"image-only Play button must remain required")
check(not menuCase({sound=true},{"play","sound"},{play=true,sound=true}),"all ready passes")
local function courseCase(assets, loaded)
 local blocked=false
 local gui={SetAttribute=function() end}
 local warn=function() end
 local showRetry=function() blocked=true end
 local code = [====[	local failed, requiredFailed = {}, {}
	for _, asset in assets do
		if not loaded[asset.key] then
   table.insert(failed, asset.id)
   if asset.required then table.insert(requiredFailed, asset.id) end
  end
	end
	gui:SetAttribute("FailedAssets", table.concat(failed, ", "))
 if #failed > 0 then warn("[Course loading] Asset fetch incomplete: "..table.concat(failed, ", ")) end
	if #requiredFailed > 0 then
		showRetry("Loading course geometry")
		loadingInProgress = false
		return
	end
]====]
 local run=assert(loadstring("return function(gui,warn,showRetry,assets,loaded) local loadingInProgress=true "..code.." end"))()
 run(gui,warn,showRetry,assets,loaded)
 return blocked
end
local assets={{key="mesh",id="mesh",required=true},{key="sound",id="sound",required=false},{key="animation",id="animation",required=false}}
check(not courseCase(assets,{mesh=true}),"cosmetic outages must not block course")
check(courseCase(assets,{sound=true,animation=true}),"missing course mesh must block entry")
check(not courseCase(assets,{mesh=true,sound=true,animation=true}),"all course assets ready")
local pending={{required=false},{required=true},{required=false},{required=true}}
table.sort(pending,function(a,b) return a.required and not b.required end)
check(pending[1].required and pending[2].required and not pending[3].required,"required course assets first")
local optional={sound=true,decor=true}
local ids={"sound","play","decor","title"}
table.sort(ids,function(a,b) return not optional[a] and optional[b]==true end)
check(not optional[ids[1]] and not optional[ids[2]] and optional[ids[3]],"required menu assets first")
local function canTimeout(now, completed, pending, optionalDeadline)
 if completed>=pending then optionalDeadline=optionalDeadline or now+4 if now>=optionalDeadline then return true,optionalDeadline end end
 return false,optionalDeadline
end
local done,deadline=canTimeout(0,0,2,nil)
check(not done and deadline==nil,"never timeout optional tail while meshes pending")
done,deadline=canTimeout(10,2,2,deadline)
check(not done and deadline==14,"optional tail starts after mesh attempts")
done,deadline=canTimeout(14,2,2,deadline)
check(done,"optional tail is bounded")
print(string.format("Loading policy: %d checks passed",checks))

