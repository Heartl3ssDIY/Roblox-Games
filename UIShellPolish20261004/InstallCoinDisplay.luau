return function(dryRun)
 assert(not game:GetService("RunService"):IsRunning(), "Apply while Studio is in Edit mode")
 local shell = game.StarterGui:WaitForChild("PlaygroundShell")
 local wallet = shell:WaitForChild("Wallet")
 assert(wallet:FindFirstChild("Coins") and wallet:FindFirstChild("Coin") and wallet.Coin:FindFirstChild("ReusableIcon"))
 if dryRun then return {target=wallet:GetFullName(),image=wallet.Coin.ReusableIcon.Image,pickupsChanged=false} end
 local backup = game.ServerStorage:FindFirstChild("UIShellPolishBackup20261004")
 if not backup then backup=Instance.new("Folder") backup.Name="UIShellPolishBackup20261004" backup.Parent=game.ServerStorage end
 if not backup:FindFirstChild("WalletBefore") then local old=wallet:Clone() old.Name="WalletBefore" old.Parent=backup end
 wallet:SetAttribute("CoinOnlyWalletVersion",1)
 wallet.AnchorPoint=Vector2.zero
 wallet.Position=UDim2.fromOffset(18,84)
 wallet.Size=UDim2.fromOffset(190,56)
 wallet.SizeLimit.MinSize=Vector2.new(190,56)
 wallet.SizeLimit.MaxSize=Vector2.new(190,56)
 for _,name in ipairs({"Wins","WinsCaption","Level","LevelCaption"})do wallet[name].Visible=false end
 wallet.CoinsCaption.Visible=true
 wallet.CoinsCaption.Position=UDim2.fromOffset(58,6)
 wallet.CoinsCaption.Size=UDim2.new(1,-68,0,13)
 wallet.CoinsCaption.TextXAlignment=Enum.TextXAlignment.Center
 wallet.Coins.Position=UDim2.fromOffset(58,21)
 wallet.Coins.Size=UDim2.new(1,-68,0,28)
 wallet.Coins.TextXAlignment=Enum.TextXAlignment.Center
 wallet.Coins.TextSizeLimit.MaxTextSize=29
 local coin=wallet.Coin
 coin.Visible=true
 coin.Position=UDim2.fromOffset(8,7)
 coin.Size=UDim2.fromOffset(42,42)
 coin.BackgroundTransparency=1
 coin.Outline.Transparency=1
 coin.Symbol.Visible=false
 local icon=coin.ReusableIcon
 icon.ZIndex=5
 local old=coin:FindFirstChild("ReusableIconFallback")
 if old then assert(old:GetAttribute("CoinIconFallbackVersion")==1) old:Destroy() end
 local ink=Color3.fromRGB(27,42,65)
 local gold=Color3.fromRGB(255,205,57)
 local fallback=Instance.new("Frame")
 fallback.Name="ReusableIconFallback"
 fallback.Size=UDim2.fromScale(1,1)
 fallback.BackgroundColor3=ink fallback.BorderSizePixel=0 fallback.ZIndex=4
 fallback:SetAttribute("BackgroundFallbackFor","ReusableIcon")
 fallback:SetAttribute("BackgroundFallbackVersion",1)
 fallback:SetAttribute("CoinIconFallbackVersion",1)
 fallback:SetAttribute("FallbackInkColor",ink)
 fallback:SetAttribute("FallbackFaceColor",gold)
 fallback.Visible=not icon.IsLoaded
 local function rounded(object)
  local corner=Instance.new("UICorner") corner.CornerRadius=UDim.new(1,0) corner.Parent=object
 end
 rounded(fallback)
 local edge=Instance.new("Frame")
 edge.Name="Edge" edge.BackgroundColor3=Color3.fromRGB(255,235,158)
 edge.Position=UDim2.fromOffset(2,2) edge.Size=UDim2.new(1,-4,1,-4)
 edge.BorderSizePixel=0 edge.ZIndex=4 rounded(edge) edge.Parent=fallback
 local face=Instance.new("Frame")
 face.Name="Face" face.BackgroundColor3=gold
 face.Position=UDim2.fromOffset(3,3) face.Size=UDim2.new(1,-6,1,-7)
 face.BorderSizePixel=0 face.ZIndex=4 rounded(face) face.Parent=edge
 local gradient=Instance.new("UIGradient")
 gradient.Color=ColorSequence.new(Color3.fromRGB(255,248,193),Color3.fromRGB(234,168,18))
 gradient.Rotation=90 gradient.Parent=face
 local symbol=Instance.new("TextLabel")
 symbol.Name="Symbol" symbol.Text="$" symbol.Font=Enum.Font.FredokaOne
 symbol.TextColor3=Color3.fromRGB(255,243,165) symbol.BackgroundTransparency=1
 symbol.Size=UDim2.fromScale(1,1) symbol.Position=UDim2.fromOffset(0,-1)
 symbol.TextScaled=true symbol.ZIndex=4
 local limit=Instance.new("UITextSizeConstraint") limit.MinTextSize=10 limit.MaxTextSize=29 limit.Parent=symbol
 local stroke=Instance.new("UIStroke")
 stroke.Name="TextOutline" stroke.Color=Color3.fromRGB(154,87,13) stroke.Thickness=2
 stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual stroke.BorderStrokePosition=Enum.BorderStrokePosition.Outer stroke.Parent=symbol
 symbol.Parent=face fallback.Parent=coin
 return {coinOnly=true,icon=icon.Image,nativeIconFallback=true,pickupsChanged=false,leaderstatsChanged=false}
end
