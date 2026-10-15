local Rules={}
Rules.GroupId=168026080 -- Deus Invictus Studios, the community owning G-Blox.
Rules.VisitRadius=11
Rules.CloseRadius=16
Rules.LikeRewardEnabled=true -- Owner-approved, one-time thank-you on trust; NOT proof of a Roblox vote.
function Rules.Sanitize(value)
 value=typeof(value)=="table" and value or {}
 return {Community=value.Community==true,Like=value.Like==true}
end
function Rules.ApplyCommunity(profile,verifiedMember)
 local claims=Rules.Sanitize(profile.CommunityRewards)
 profile.CommunityRewards=claims
 if claims.Community then return false,"Already claimed." end
 if verifiedMember~=true then return false,"Join the community first." end
 -- Permanent receipt and both balances change without yielding; saved together.
 claims.Community=true
 profile.Cash+=75000
 profile.TotalCashEarned+=75000
 profile.Trophies+=70
 return true,"Community reward: +75,000 cash and +70 trophies!"
end
function Rules.ApplyLike(profile)
 local claims=Rules.Sanitize(profile.CommunityRewards)
 profile.CommunityRewards=claims
 if claims.Like then return false,"Your thank-you gift was already claimed." end
 if not Rules.LikeRewardEnabled then return false,"This reward is not available." end
 claims.Like=true
 profile.Cash+=25000
 profile.TotalCashEarned+=25000
 profile.Trophies+=30
 return true,"Thank you! +25,000 cash and +30 trophies. Please like G-Blox on its Roblox page."
end
function Rules.Near(position,target,radius)
 local d=position-target
 return Vector2.new(d.X,d.Z).Magnitude<=radius and math.abs(d.Y)<=9
end
return Rules

