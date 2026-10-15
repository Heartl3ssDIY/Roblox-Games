from pathlib import Path

root = Path(__file__).resolve().parent

def patch(name, changes):
    source = (root / 'Before' / name).read_text(encoding='utf-8')
    for old, new in changes:
        assert source.count(old) == 1, (name, old[:100], source.count(old))
        source = source.replace(old, new)
    (root / 'After' / name).write_text(source, encoding='utf-8', newline='\n')

patch('PlaygroundCoordinator.luau', [
    ('then minimum=id=="StuckInTheMud" and 4 or 2 end', 'then minimum=2 end'),
    ('self.votingEndsAt = now + 20', '''local intermission = self.lobby:GetAttribute("IntermissionSeconds")
			if typeof(intermission) ~= "number" or intermission ~= intermission or math.abs(intermission) == math.huge then intermission = 35 end
			self.votingEndsAt = now + math.max(1, intermission)'''),
])
patch('TagSprintService.luau', [
    ('local sprinting=canMove and entry.held and not entry.locked and moving', 'local sprinting=canMove and entry.held and entry.remaining>0 and moving\n   local sprintFraction=sprinting and math.min(1,entry.remaining/math.max(delta,0.00001)) or 0'),
    ('    if entry.remaining<=0 then entry.locked=true sprinting=false end\n', ''),
    ('    if entry.locked and entry.remaining>=maximum-0.00001 then entry.locked=false end\n   end', '   end\n   entry.locked=entry.remaining<=0'),
    ('base*(sprinting and self:_setting("SprintMultiplier",2.5,1) or 1)', 'base*(1+(self:_setting("SprintMultiplier",2.5,1)-1)*sprintFraction)'),
])
patch('TagHUD.SprintController.luau', [
    ('return Enum.ContextActionResult.Sink', 'return Enum.ContextActionResult.Pass'),
    ('player:GetAttribute("TGSprintExhausted") and "RECHARGING" or player:GetAttribute("TGSprinting") and "SPRINTING"', 'player:GetAttribute("TGSprinting") and "SPRINTING" or player:GetAttribute("TGSprintExhausted") and "RECHARGING"'),
])
patch('PlaygroundPodium.Controller.luau', [
    ('model:ScaleTo(model:GetScale() * 5.5 / height)', '''local avatarHeight = script.Parent:GetAttribute("AvatarHeight")
	if not finite(avatarHeight) or avatarHeight <= 0 then avatarHeight = 27.5 end
	model:ScaleTo(model:GetScale() * avatarHeight / height)'''),
])
patch('TagService.luau', [
    ('function Service:Move(player, action, direction)\n', 'function Service:Move(player, action, direction)\n\tif action == "Dodge" then return false, "Dodge is temporarily disabled" end\n'),
])
patch('TagHUD.Controller.luau', [
    ('button.Active = cooldown == 0 and not busy and player:GetAttribute("TGRagdolled") ~= true', 'button.Active = false\n\tbutton.Interactable = false\n\tbutton.Visible = false'),
    ('if not alive or busy or player:GetAttribute("TGParticipating")~=true', 'if controls.Dodge.Interactable == false then return end\n\tif not alive or busy or player:GetAttribute("TGParticipating")~=true'),
])
print('Prepared 6 root scripts')
