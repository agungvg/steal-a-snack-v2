-- Headless mock of the Roblox API surface used by the testable modules
-- (Config, CharacterFactory, Weather). Sets globals; load this first.

-- ---------------------------------------------------------------- Vec3
local Vec3 = {}
local v3mt = {}
v3mt.__index = function(t, k)
	if k == "Magnitude" then
		return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
	end
	return nil
end
v3mt.__add = function(a, b)
	return Vec3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
v3mt.__sub = function(a, b)
	return Vec3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
v3mt.__mul = function(a, b)
	if type(a) == "number" then
		return Vec3.new(a * b.X, a * b.Y, a * b.Z)
	elseif type(b) == "number" then
		return Vec3.new(a.X * b, a.Y * b, a.Z * b)
	else
		return Vec3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
	end
end
v3mt.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
function Vec3.new(x, y, z)
	local v = { X = x or 0, Y = y or 0, Z = z or 0 }
	setmetatable(v, v3mt)
	return v
end

-- ------------------------------------------------------------------ CFrm
local CFrm = {}
local cfMt = {}
cfMt.__mul = function(a, _b)
	return a
end
function CFrm.new(x, y, z)
	local pos
	if type(x) == "table" and x.X ~= nil then
		pos = x
	elseif x == nil then
		pos = Vec3.new(0, 0, 0)
	else
		pos = Vec3.new(x, y, z)
	end
	local cf = { Position = pos }
	setmetatable(cf, cfMt)
	return cf
end
function CFrm.Angles(_rx, _ry, _rz)
	local cf = { Position = Vec3.new(0, 0, 0) }
	setmetatable(cf, cfMt)
	return cf
end

-- ------------------------------------------------------------------ Col3
local Col3 = {}
function Col3.fromRGB(r, g, b)
	return { R = r / 255, G = g / 255, B = b / 255 }
end
function Col3.new(r, g, b)
	return { R = r, G = g, B = b }
end

-- ------------------------------------------------------------------- UD2
local UD2 = {}
function UD2.new(xs, xo, ys, yo)
	return {
		X = { Scale = xs or 0, Offset = xo or 0 },
		Y = { Scale = ys or 0, Offset = yo or 0 },
	}
end

-- -------------------------------------------------------------------- EnumT
local EnumT = {
	Material = {
		SmoothPlastic = "SmoothPlastic",
		Neon = "Neon",
		Metal = "Metal",
		Grass = "Grass",
		Plastic = "Plastic",
		Wood = "Wood",
	},
	PartType = { Ball = "Ball", Block = "Block", Cylinder = "Cylinder" },
	Font = { GothamBold = "GothamBold", Gotham = "Gotham" },
	TextXAlignment = { Left = "Left", Center = "Center", Right = "Right" },
}

-- ---------------------------------------------------------------- Inst
local Inst = {}
local methods = {}

function methods:FindFirstChild(name)
	for _, child in ipairs(self._children) do
		if child.Name == name then
			return child
		end
	end
	return nil
end

function methods:GetChildren()
	local out = {}
	for _, child in ipairs(self._children) do
		table.insert(out, child)
	end
	return out
end

function methods:GetDescendants()
	local out = {}
	local function walk(node)
		for _, child in ipairs(node._children) do
			table.insert(out, child)
			walk(child)
		end
	end
	walk(self)
	return out
end

function methods:Destroy()
	self._destroyed = true
	self.Parent = nil
end

function methods:PivotTo(cf)
	self._pivot = cf
	if self.PrimaryPart then
		self.PrimaryPart.CFrm = cf
	end
end

function methods:GetPivot()
	if self._pivot then
		return self._pivot
	end
	if self.PrimaryPart then
		return CFrm.new(self.PrimaryPart.Position)
	end
	return CFrm.new(0, 0, 0)
end

function methods:IsA(className)
	if className == "BasePart" then
		return self.ClassName == "Part"
	end
	return self.ClassName == className
end

function methods:SetAttribute(key, value)
	self._attrs[key] = value
end

function methods:GetAttribute(key)
	return self._attrs[key]
end

local instanceMt = {}
instanceMt.__index = function(t, k)
	if k == "Parent" then
		return rawget(t, "_parent")
	end
	local v = rawget(t, k)
	if v ~= nil then
		return v
	end
	return methods[k]
end
instanceMt.__newindex = function(t, k, v)
	if k == "Parent" then
		local old = rawget(t, "_parent")
		if old then
			for i, child in ipairs(old._children) do
				if child == t then
					table.remove(old._children, i)
					break
				end
			end
		end
		rawset(t, "_parent", v)
		if v then
			table.insert(v._children, t)
		end
	else
		rawset(t, k, v)
	end
end

function Inst.new(className, parent)
	local obj = {
		ClassName = className,
		Name = className,
		_children = {},
		_attrs = {},
		_destroyed = false,
	}
	if className == "ClickDetector" then
		obj.MouseClick = {
			Connect = function(_self, cb)
				obj._clickCb = cb
				return { Disconnect = function() end }
			end,
		}
	end
	setmetatable(obj, instanceMt)
	if parent then
		obj.Parent = parent
	end
	return obj
end

-- Publish as globals, like the real engine does
-- (bare assignment: _G is readonly in standalone Luau).
Vector3 = Vec3
CFrame = CFrm
Color3 = Col3
UDim2 = UD2
Enum = EnumT
Instance = Inst

return true
