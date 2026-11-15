--!strict
-- Greybox stand-ins for houses and properties (GDD §4.1 visual briefs, Appendix E "readable in
-- silhouette"). Every house level and property type has a distinct shape and colour so the
-- street can tell a Trailer from a Studio at a glance. Replaced by real models in the art pass;
-- callers only need build(...) to return a Model pivoted at the anchor.

local Greybox = {}

type Block = { size: Vector3, offset: Vector3, color: Color3, material: Enum.Material?, shape: string? }

local function make(name: string, blocks: { Block }, at: CFrame): Model
	local model = Instance.new("Model")
	model.Name = name
	for i, b in blocks do
		local p: BasePart
		if b.shape == "wedge" then
			p = Instance.new("WedgePart")
		elseif b.shape == "cylinder" or b.shape == "disc" then
			local part = Instance.new("Part")
			part.Shape = Enum.PartType.Cylinder
			p = part
		elseif b.shape == "ball" then
			local part = Instance.new("Part")
			part.Shape = Enum.PartType.Ball
			p = part
		else
			p = Instance.new("Part")
		end
		p.Name = if i == 1 then "Body" else `Part{i}`
		p.Anchored = true
		p.CanCollide = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Material = b.material or Enum.Material.SmoothPlastic
		p.Color = b.color
		p.Size = b.size
		p.CFrame = at * CFrame.new(b.offset)
		-- Roblox cylinders run along X: "cylinder" stands upright, "disc" faces the road (Z).
		if b.shape == "cylinder" then
			p.CFrame = p.CFrame * CFrame.Angles(0, 0, math.rad(90))
		elseif b.shape == "disc" then
			p.CFrame = p.CFrame * CFrame.Angles(0, math.rad(90), 0)
		end
		p.Parent = model
		if i == 1 then
			model.PrimaryPart = p
		end
	end
	return model
end

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- Ten houses, footprint grows with level. Offsets are relative to the HouseAnchor (ground level).
-- Keep every block behind z = -9 (front edge of the first property row) and within x = +-22.
local HOUSES: { { Block } } = {
	{ -- 1 Cardboard Box
		{
			size = Vector3.new(5, 4, 5),
			offset = Vector3.new(0, 2, 0),
			color = rgb(176, 136, 90),
			material = Enum.Material.Cardboard,
		},
		{ size = Vector3.new(2, 1.5, 2), offset = Vector3.new(4, 0.75, -2), color = rgb(70, 120, 200) }, -- milk crate
	},
	{ -- 2 Tent
		{
			size = Vector3.new(8, 6, 5),
			offset = Vector3.new(0, 3, -1.25),
			color = rgb(60, 140, 80),
			shape = "wedge",
			material = Enum.Material.Fabric,
		},
		{
			size = Vector3.new(8, 6, 5),
			offset = Vector3.new(0, 3, 1.25),
			color = rgb(60, 140, 80),
			shape = "wedge",
			material = Enum.Material.Fabric,
		},
	},
	{ -- 3 Trailer: long and low
		{
			size = Vector3.new(16, 7, 7),
			offset = Vector3.new(0, 4, 0),
			color = rgb(205, 205, 195),
			material = Enum.Material.Metal,
		},
		{ size = Vector3.new(16, 1, 7.4), offset = Vector3.new(0, 4, 0), color = rgb(40, 120, 170) },
	},
	{ -- 4 Studio: one-room cube with a window box
		{
			size = Vector3.new(12, 10, 10),
			offset = Vector3.new(0, 5, 0),
			color = rgb(225, 200, 160),
			material = Enum.Material.Brick,
		},
		{ size = Vector3.new(4, 1, 1.5), offset = Vector3.new(0, 4, -5.5), color = rgb(90, 160, 70) },
	},
	{ -- 5 Row House: tall and narrow with a stoop
		{
			size = Vector3.new(10, 18, 12),
			offset = Vector3.new(0, 9, 0),
			color = rgb(150, 75, 60),
			material = Enum.Material.Brick,
		},
		{
			size = Vector3.new(4, 2, 3),
			offset = Vector3.new(0, 1, -7.5),
			color = rgb(160, 160, 160),
			material = Enum.Material.Concrete,
		},
	},
	{ -- 6 Townhouse: wider, balcony
		{
			size = Vector3.new(16, 20, 12),
			offset = Vector3.new(0, 10, 0),
			color = rgb(170, 85, 65),
			material = Enum.Material.Brick,
		},
		{
			size = Vector3.new(10, 1, 3),
			offset = Vector3.new(0, 12, -7.5),
			color = rgb(40, 40, 40),
			material = Enum.Material.Metal,
		},
	},
	{ -- 7 Villa: wide, white, fountain
		{
			size = Vector3.new(24, 14, 14),
			offset = Vector3.new(0, 7, 2),
			color = rgb(240, 236, 225),
			material = Enum.Material.Marble,
		},
		{ size = Vector3.new(26, 2, 16), offset = Vector3.new(0, 15, 2), color = rgb(190, 90, 60) },
		{
			size = Vector3.new(1.5, 6, 6),
			offset = Vector3.new(-17, 0.75, -4),
			color = rgb(120, 180, 230),
			shape = "cylinder",
		},
	},
	{ -- 8 Penthouse Tower: very tall, slim, glass
		{
			size = Vector3.new(12, 48, 12),
			offset = Vector3.new(0, 24, 2),
			color = rgb(90, 130, 170),
			material = Enum.Material.Glass,
		},
		{ size = Vector3.new(14, 1, 14), offset = Vector3.new(0, 48.5, 2), color = rgb(230, 230, 230) },
	},
	{ -- 9 Private Island Portal: glowing ring
		{
			size = Vector3.new(2, 22, 22),
			offset = Vector3.new(0, 12, 2),
			color = rgb(90, 220, 255),
			shape = "disc",
			material = Enum.Material.Neon,
		},
		{
			size = Vector3.new(16, 1, 16),
			offset = Vector3.new(0, 0.5, 2),
			color = rgb(230, 210, 150),
			material = Enum.Material.Sand,
		},
	},
	{ -- 10 Billionaire Estate: big, gold trim, golden statue
		{
			size = Vector3.new(28, 20, 16),
			offset = Vector3.new(0, 10, 3),
			color = rgb(245, 240, 230),
			material = Enum.Material.Marble,
		},
		{
			size = Vector3.new(30, 2, 18),
			offset = Vector3.new(0, 21, 3),
			color = rgb(212, 175, 55),
			material = Enum.Material.Metal,
		},
		{
			size = Vector3.new(3, 8, 3),
			offset = Vector3.new(-18, 4, -6),
			color = rgb(212, 175, 55),
			material = Enum.Material.Metal,
		},
		{
			size = Vector3.new(3, 3, 3),
			offset = Vector3.new(-18, 9.5, -6),
			color = rgb(212, 175, 55),
			material = Enum.Material.Metal,
			shape = "ball",
		},
	},
}

function Greybox.house(level: number, anchor: CFrame): Model
	local blocks = HOUSES[math.clamp(level, 1, #HOUSES)]
	return make("House", blocks, anchor)
end

-- Properties: shape by type, height by price tier, colour by id.
local PROPERTY_COLORS: { [string]: Color3 } = {
	stall_street = rgb(230, 120, 60),
	stall_food = rgb(240, 200, 70),
	stall_kiosk = rgb(80, 170, 220),
	shop_corner = rgb(70, 160, 110),
	apt_studio = rgb(170, 140, 200),
	shop_boutique = rgb(230, 120, 170),
	apt_building = rgb(150, 120, 100),
	shop_luxury = rgb(30, 30, 30),
	apt_tower = rgb(120, 150, 190),
	shop_mall = rgb(200, 200, 210),
	apt_resort = rgb(60, 190, 180),
	shop_hq = rgb(212, 175, 55),
}

function Greybox.property(propertyId: string, propertyType: string, cost: number, anchor: CFrame): Model
	local color = PROPERTY_COLORS[propertyId] or rgb(180, 180, 180)
	-- 50 -> ~2.5 studs tall ... 6,000,000 -> ~14 studs
	local height = 2 + math.log10(math.max(cost, 10)) * 1.8
	local blocks: { Block }
	if propertyType == "Stall" then
		blocks = {
			{
				size = Vector3.new(5, height * 0.5, 3),
				offset = Vector3.new(0, height * 0.25, 0),
				color = rgb(120, 90, 60),
				material = Enum.Material.Wood,
			},
			{
				size = Vector3.new(6, 0.4, 4),
				offset = Vector3.new(0, height + 0.2, 0),
				color = color,
				material = Enum.Material.Fabric,
			}, -- awning
			{
				size = Vector3.new(0.4, height * 0.5, 0.4),
				offset = Vector3.new(-2.6, height * 0.75, -1.6),
				color = rgb(90, 70, 50),
			},
			{
				size = Vector3.new(0.4, height * 0.5, 0.4),
				offset = Vector3.new(2.6, height * 0.75, -1.6),
				color = rgb(90, 70, 50),
			},
		}
	elseif propertyType == "Shop" then
		blocks = {
			{
				size = Vector3.new(7, height, 6),
				offset = Vector3.new(0, height / 2, 0),
				color = color,
				material = Enum.Material.Brick,
			},
			{
				size = Vector3.new(7.2, 1, 0.5),
				offset = Vector3.new(0, height - 0.8, -3.2),
				color = rgb(255, 240, 200),
				material = Enum.Material.Neon,
			}, -- sign
		}
	else -- Apartment: tall and thin
		blocks = {
			{
				size = Vector3.new(5, height * 1.6, 5),
				offset = Vector3.new(0, height * 0.8, 0),
				color = color,
				material = Enum.Material.Concrete,
			},
		}
	end
	return make(`Prop_{propertyId}`, blocks, anchor)
end

return Greybox
