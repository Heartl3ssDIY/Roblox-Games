local board = game.StarterGui.ArenaSelectGui.Board
local backup = Instance.new("Folder")
backup.Name = "BeforeArenaProgressCurveFix20260925"
backup.Parent = game.ServerStorage
board.Progress:Clone().Parent = backup
board.Progress.Corner.CornerRadius = UDim.new(.5, 0)
for _, spec in ipairs({{"FillClip", 230}, {"LossClip", 273}}) do
    local image = board.Progress[spec[1]].Image
    image.ScaleType = Enum.ScaleType.Slice
    image.SliceCenter = Rect.new(25, 0, spec[2] - 1, 50)
    image.SliceScale = board.Progress.Size.Y.Offset / 50
end
return "Rounded ends retain their original proportions; bar layout preserved"
