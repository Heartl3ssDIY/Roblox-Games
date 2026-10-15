local viewports = {{390,844},{844,390},{640,360},{768,1024},{1024,768},{1365,768}}
local ui = game:GetService("StarterGui")
local records = {}
local fixture = Instance.new("Part")
fixture.Name = "MobileLayoutFixture20261007"
fixture.Anchored = true
fixture.CanCollide = false
fixture.CanTouch = false
fixture.CanQuery = false
fixture.Transparency = 1
fixture.Position = Vector3.new(0,-10000,0)
fixture.Parent = workspace
local ok, failure = pcall(function()
    for _, viewport in ipairs(viewports) do
        local surface = Instance.new("SurfaceGui")
        surface.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
        surface.CanvasSize = Vector2.new(viewport[1],viewport[2])
        surface.Parent = fixture
        local shop = ui.PlaygroundShell.ShopPanel:Clone()
        local emotes = ui.PlaygroundEmoteWheel.Panel:Clone()
        local toys = ui.PlaygroundToyHotbar.Bar:Clone()
        for _, object in ipairs({shop,emotes,toys}) do object.Visible=true object.Parent=surface end
        for _,card in ipairs(shop.Cards:GetChildren()) do
            if card:IsA("Frame") and card:FindFirstChild("Action") then
                card.Price.Text = "100,000 coins"
                card:FindFirstChild("Name").Text = "Sunfeather Phoenix"
            end
        end
        for index=1,8 do emotes.Wheel["Slot"..index].ItemName.Text = "Pretty Young Thing" end
        task.wait(.08)
        local checks = 0
        local minimumTouch = math.huge
        local function button(button)
            checks += 1
            minimumTouch = math.min(minimumTouch,button.AbsoluteSize.X,button.AbsoluteSize.Y)
            assert(button.AbsoluteSize.X >= 43.99 and button.AbsoluteSize.Y >= 43.99, button:GetFullName().." touch target too small at "..viewport[1].."x"..viewport[2])
        end
        for _, object in ipairs({shop.Close, shop.Pager.Previous,shop.Pager.Next,emotes.Close,emotes.StopButton,emotes.Previous,emotes.Next,emotes.ShopButton,toys.Use}) do button(object) end
        for _, category in ipairs(shop.Categories:GetChildren()) do if category:IsA("GuiButton") and category.Visible then button(category) end end
        for _, card in ipairs(shop.Cards:GetChildren()) do
            if card:IsA("Frame") and card:FindFirstChild("Action") then
                button(card.Action) button(card.Try)
                assert(card.Price.TextFits and card:FindFirstChild("Name").TextFits,"Shop text overflow")
                assert(card.AbsoluteSize.X <= shop.Cards.AbsoluteSize.X,"Card wider than scrolling area")
            end
        end
        for index=1,8 do button(emotes.Wheel["Slot"..index]) end
        local function overlaps(a,b)
            local ap,as,bp,bs = a.AbsolutePosition,a.AbsoluteSize,b.AbsolutePosition,b.AbsoluteSize
            return ap.X < bp.X+bs.X-.1 and ap.X+as.X > bp.X+.1 and ap.Y < bp.Y+bs.Y-.1 and ap.Y+as.Y > bp.Y+.1
        end
        for index=1,8 do
            local slot = emotes.Wheel["Slot"..index]
            assert(not overlaps(slot,emotes.StopButton),"Stop button overlaps emote slot")
            assert(not overlaps(slot,emotes.Hint),"Hint overlaps emote slot")
        end
        for index=1,4 do button(toys.Slots["Slot"..index]) end
        for _, panel in ipairs({shop,emotes,toys}) do
            local p,s = panel.AbsolutePosition,panel.AbsoluteSize
            assert(p.X >= -.01 and p.Y >= -.01 and p.X+s.X <= viewport[1]+.01 and p.Y+s.Y <= viewport[2]+.01,"Panel outside viewport: "..panel.Name)
        end
        local columns = 0
        local firstY = shop.Cards.Slot01.AbsolutePosition.Y
        for _, card in ipairs(shop.Cards:GetChildren()) do
            if card:IsA("Frame") and card:FindFirstChild("Action") and math.abs(card.AbsolutePosition.Y-firstY)<.1 then columns+=1 end
        end
        table.insert(records,{viewport=viewport,minimumTouch=minimumTouch,buttons=checks,shopColumns=columns,scrollCanvasY=shop.Cards.AbsoluteCanvasSize.Y,wheelSize=emotes.Wheel.AbsoluteSize.X})
        surface:Destroy()
    end
end)
fixture:Destroy()
assert(ok,failure)
return game.HttpService:JSONEncode({passed=true,viewports=records,playStarted=false})
