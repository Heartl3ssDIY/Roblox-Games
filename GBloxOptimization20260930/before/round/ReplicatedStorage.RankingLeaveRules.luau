local M={}
function M.CanLeave(phase,version,rankingVersion)
 return version==rankingVersion and (phase=="Intermission" or phase=="MatchComplete" or phase=="AwaitingCourse")
end
return M
