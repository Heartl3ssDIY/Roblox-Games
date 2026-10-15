local M={}
function M.Allow(phase,status,podium)
 return not (phase=="Running" or phase=="Countdown" or phase=="MatchComplete"
  or status=="Running" or status=="Recovering" or status=="Podium" or podium==true)
end
return M

