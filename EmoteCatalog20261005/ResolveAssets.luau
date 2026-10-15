return function(catalogIds)
	assert(not game:GetService("RunService"):IsRunning(), "Edit mode required")
	local marketplace = game:GetService("MarketplaceService")
	local insert = game:GetService("InsertService")
	local results, nextIndex, remaining = {}, 1, #catalogIds
	local function resolve(index, id)
		local result = { catalogId = id, url = "https://www.roblox.com/catalog/" .. tostring(id),
			metadataStatus = "pending", resolveStatus = "pending", loadStatus = "not_checked", playable = false }
		results[index] = result
		local ok, metadata = pcall(marketplace.GetProductInfoAsync, marketplace, id, Enum.InfoType.Asset)
		if not ok then
			result.metadataStatus, result.resolveStatus, result.metadataError = "failed", "unresolved", tostring(metadata)
			return
		end
		result.name, result.assetTypeId, result.metadataStatus = metadata.Name, metadata.AssetTypeId, "verified"
		result.creator = metadata.Creator
		result.isForSale = metadata.IsForSale
		result.catalogPriceInRobux = metadata.PriceInRobux
		if metadata.AssetTypeId ~= 61 and metadata.AssetTypeId ~= 24 then
			result.resolveStatus = "unsupported_asset_type"
			return
		end
		if metadata.AssetTypeId == 24 then
			result.animationId, result.resolveStatus = id, "animation_asset"
			return
		end
		local loaded, model = pcall(insert.LoadAsset, insert, id)
		if not loaded then
			result.resolveStatus, result.resolveError = "load_asset_failed", tostring(model)
			return
		end
		local found, seen = {}, {}
		local scanOk, scanError = pcall(function()
			for _, instance in ipairs(model:GetDescendants()) do
				if instance:IsA("Animation") then
					local value = instance.AnimationId
					local animationId = tonumber(value:match("rbxassetid://(%d+)") or value:match("[?&]id=(%d+)"))
					if animationId and not seen[animationId] then
						seen[animationId] = true
						table.insert(found, { animationId = animationId, name = instance.Name, content = value })
					end
				end
			end
		end)
		model:Destroy()
		if not scanOk then result.resolveStatus, result.resolveError = "inspection_failed", tostring(scanError) return end
		result.animations = found
		if #found == 1 then result.animationId, result.resolveStatus = found[1].animationId, "resolved"
		elseif #found == 0 then result.resolveStatus = "no_animation_found"
		else result.resolveStatus = "multiple_animations" end
	end
	for _ = 1, math.min(4, #catalogIds) do
		task.spawn(function()
			while nextIndex <= #catalogIds do
				local index = nextIndex
				nextIndex += 1
				local ok, failure = pcall(resolve, index, catalogIds[index])
				if not ok then results[index] = { catalogId = catalogIds[index], metadataStatus = "error", resolveStatus = "error", error = tostring(failure), playable = false } end
				remaining -= 1
			end
		end)
	end
	while remaining > 0 do task.wait(0.05) end
	return results
end
