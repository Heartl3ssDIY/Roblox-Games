local R={}
R.Codes={RELEASE={Cash=10000,Trophies=30}}
function R.Normalize(input)
 if type(input)~="string" or #input>64 then return nil end
 local code=input:match("^%s*(.-)%s*$"):upper()
 if code=="" or not code:match("^[A-Z0-9_%-]+$") then return nil end
 return code
end
function R.Sanitize(raw)
 local clean={}
 if type(raw)=="table" then
  for code,stamp in raw do
   if type(code)=="string" and #code<=64 and (stamp==true or type(stamp)=="number" and stamp==stamp and stamp>0 and stamp<math.huge) then
    clean[code]=stamp
   end
  end
 end
 return clean
end
function R.Apply(profile,input,now)
 local code=R.Normalize(input)
 local reward=code and R.Codes[code]
 if not reward then return false,"That code is not valid.",false end
 profile.RedeemedCodes=R.Sanitize(profile.RedeemedCodes)
 if profile.RedeemedCodes[code] then return false,"You have already redeemed this code.",false end
 profile.RedeemedCodes[code]=now
 profile.Cash+=reward.Cash
 profile.TotalCashEarned+=reward.Cash
 profile.Trophies+=reward.Trophies
 return true,"RELEASE redeemed! +10,000 cash and +30 trophies.",true
end
return R

