from pathlib import Path
import re

folder = Path(__file__).resolve().parent
shared = (folder / "DodgeShared.luau").read_text(encoding="utf-8")

def method(source, name, replacement):
    pattern = r"function Service:" + re.escape(name) + r"\([^\n]*\)\n.*?(?=\nfunction Service:|\nlocal function |\Z)"
    result, count = re.subn(pattern, lambda _: replacement.rstrip() + "\n", source, count=1, flags=re.S)
    assert count == 1, name
    return result

for name, prefix, burst, start, stop, phase, attr, role in [
    ("BritishBulldogService", "BB", "dodgeBurst", "_startDodgeBurst", "_stopDodgeBurst", "Crossing", "setAttribute", 'record.role ~= "Runner" or record.arrived'),
    ("TagService", "TG", "burst", "_startBurst", "_stopBurst", "Playing", "attribute", "false"),
]:
    path = folder / "After" / (name + ".luau")
    source = path.read_text(encoding="utf-8-sig") if path.exists() else (folder / "Before" / (name + ".luau")).read_text(encoding="utf-8-sig")
    if 'function Service:_clipDodgeTravel(' in source:
        print(name + " already patched")
        continue
    replacement = shared
    for key, value in {"PREFIX":prefix,"BURST":burst,"START":start,"STOP":stop,"PHASE":phase,"ATTR":attr,"ROLESTOP":role}.items():
        replacement = replacement.replace("__" + key + "__", value)
    if prefix == "TG":
        replacement = replacement.replace("not self:_inside(self.bounds, root.Position)", "not self:_batInField(record)")
        replacement = replacement.replace('token=self.currentRound,crossing=self.crossingNumber', 'token=self.currentRound,role=record.role')
        replacement = replacement.replace('self.crossingNumber ~= burst.crossing', 'record.role ~= burst.role')
        replacement = replacement.replace('or false or time >= burst.endsAt', 'or time >= burst.endsAt')
    source = method(source, stop, "")
    source = method(source, start, replacement)
    if prefix == "BB":
        source = method(source, "_dodgeClear", "")
        old = re.search(r"local function dodgeSpeed.*?(?=\nfunction Service:|\nlocal function)", source, re.S)
        assert old
        source = source[:old.start()] + source[old.end():]
        source = source.replace('or record.humanoid.FloorMaterial == Enum.Material.Air then return { ok = false, message = "Dodge while crossing the field." } end', 'then return { ok = false, message = "Dodge while crossing the field." } end')
        source = source.replace('local params = self:_movementRayParameters()\n\tlocal duration', 'local params = self:_movementRayParameters()\n\tif not self:_dodgeGrounded(record, params) then return {ok=false,message="Dodge while on the ground."} end\n\tlocal duration')
        source = source.replace('if not self:_dodgeClear(record, travel.Unit, travel.Magnitude, params) then return { ok = false, message = "No room to dodge." } end', 'local fraction = self:_clipDodgeTravel(record, travel, params)\n\tif distance * fraction < 0.75 then return {ok=false,message="No room to dodge."} end\n\tdistance, forwardVelocity = distance * fraction, forwardVelocity * fraction')
        source = source.replace('self:_startDodgeBurst(record, direction, now, duration, distance, forwardVelocity, params)\n\trecord.dodgeReadyAt', 'if not self:_startDodgeBurst(record, direction, now, duration, distance, forwardVelocity, params) then record.pendingEscape=nil return {ok=false,message="Your character cannot dodge yet."} end\n\trecord.dodgeReadyAt')
    else:
        source = method(source, "Move", '''function Service:Move(player, action, direction)
\tlocal record = self.records[player]
\tlocal now = workspace:GetServerTimeNow()
\tif action ~= "Dodge" or typeof(direction) ~= "Vector3" or direction.X ~= direction.X or direction.Y ~= direction.Y
\t\tor direction.Z ~= direction.Z or math.abs(direction.Y) > 0.01 or direction.Magnitude < 0.99 or direction.Magnitude > 1.01 then return false, "Unknown move" end
\tif player.Parent ~= Players or not self.active or self.phase ~= "Playing" or now >= self.endsAt or not record
\t\tor not record.participating or record.isBot or not alive(record) then return false, "Not in an active Tag game" end
\tif record.frozen or record.ragdoll or not self:_batInField(record) then return false, "Wait until you can move again" end
\tif now < (record.moveCooldowns.Dodge or 0) then return false, "Dodge is recharging" end
\tlocal params = self:_rayParameters()
\tparams.CollisionGroup = "TGPlayer"
\tif not self:_dodgeGrounded(record, params) then return false, "Dodge while on the ground" end
\tdirection = Vector3.new(direction.X,0,direction.Z).Unit
\tlocal right = direction
\tlocal forward = Vector3.new(-right.Z,0,right.X).Unit
\tlocal forwardVelocity = forward * math.clamp(record.root.AssemblyLinearVelocity:Dot(forward),-record.humanoid.WalkSpeed,record.humanoid.WalkSpeed)
\tlocal duration, distance = 0.32, 8
\tlocal fraction = self:_clipDodgeTravel(record,direction*distance+forwardVelocity*duration,params)
\tif distance*fraction < 0.75 then return false, "No room to dodge" end
\tif not self:_startBurst(record,direction,now,duration,distance*fraction,forwardVelocity*fraction,params) then return false, "Your character cannot dodge yet" end
\trecord.moveCooldowns.Dodge = now + 3
\tattribute(player,"TGDodgeReadyAt",record.moveCooldowns.Dodge)
\treturn true
end''')
        source = source.replace('function(player, action) return self:Move(player, action) end', 'function(player, action, direction) return self:Move(player, action, direction) end')
        source = re.sub(r'^.*attribute\(player, "TGVaultReadyAt", 0\).*\n', '', source, flags=re.M)
    path.write_text(source, encoding="utf-8")
    print("Patched " + str(path))
