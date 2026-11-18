--!strict
-- Steal a Snack v2 — Effects: small, pooled-feeling visual pops.
-- One-shot bursts only (a neon flash part + a ParticleEmitter), cleaned up
-- by the Debris service so nothing leaks per frame.
--
-- PUBLIC API:
--   pop(parent, pos, rgb) -> ()   burst of sparks at a world position

local Debris = game:GetService("Debris")

local Effects = {}

function Effects.pop(parent: Instance, pos: Vector3, rgb: { number }): ()
	local flash = Instance.new("Part")
	flash.Name = "PopFlash"
	flash.Size = Vector3.new(1, 1, 1)
	flash.Shape = Enum.PartType.Ball
	flash.Color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
	flash.Material = Enum.Material.Neon
	flash.Anchored = true
	flash.CanCollide = false
	flash.Position = pos
	flash.Parent = parent

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromRGB(rgb[1], rgb[2], rgb[3]))
	emitter.Size = NumberSequence.new(0.6)
	emitter.Lifetime = NumberRange.new(0.4, 0.8)
	emitter.Rate = 60
	emitter.Speed = NumberRange.new(6, 12)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = flash
	emitter:Emit(24)

	Debris:AddItem(flash, 1.2)
end

return Effects
