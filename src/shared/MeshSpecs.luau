-- Сгенерировано scripts/gen_meshes.py: габариты мешей в «кадре объекта» (Y вверх, начало —
-- центр основания на земле, 1 = 1 stud при масштабе 1). size — габариты, offset — центр габаритов.
-- MeshPart растягивает меш на Size, поэтому Props/Meshes ставит Size = size·s, CFrame = база·offset·s.
return {
	arch = { size = Vector3.new(2.688, 1.0278, 1.2679), offset = Vector3.new(-0.0316, 0.5139, 0.0435), tris = 520 },
	crag = { size = Vector3.new(1.9616, 3.4589, 1.4647), offset = Vector3.new(-0.0334, 1.7295, -0.0537), tris = 1280 },
	ice_chunk = { size = Vector3.new(2.4715, 1.6687, 2.1215), offset = Vector3.new(0.0793, 0.8343, -0.001), tris = 80 },
	ice_crystal = { size = Vector3.new(1.4101, 1.3, 0.9713), offset = Vector3.new(0.0418, 0.65, 0.0571), tris = 168 },
	isle_cap = { size = Vector3.new(2.1502, 0.5728, 2.1652), offset = Vector3.new(0.0243, 0.1564, -0.032), tris = 308 },
	isle_rock = { size = Vector3.new(1.9787, 1.87, 2.0809), offset = Vector3.new(0.0582, -0.915, -0.0946), tris = 400 },
	mesa = { size = Vector3.new(2.7339, 1.0, 2.0422), offset = Vector3.new(0.0402, 0.5, -0.0453), tris = 1020 },
	mountain_rock = { size = Vector3.new(2.0, 1.1096, 1.989), offset = Vector3.new(0.0, 0.5548, 0.0), tris = 840 },
	mountain_snow = { size = Vector3.new(0.8493, 0.6413, 0.7659), offset = Vector3.new(0.0753, 0.809, -0.0433), tris = 260 },
	pine_foliage = { size = Vector3.new(1.1026, 0.854, 1.1309), offset = Vector3.new(0.0287, 0.573, 0.0), tris = 448 },
	pine_snow = { size = Vector3.new(0.7352, 0.7065, 0.7541), offset = Vector3.new(0.0191, 0.6668, 0.0), tris = 448 },
	rock_a = { size = Vector3.new(2.8778, 1.193, 1.9871), offset = Vector3.new(0.0354, 0.5965, 0.0522), tris = 320 },
	rock_b = { size = Vector3.new(1.8691, 1.1683, 1.6307), offset = Vector3.new(-0.0522, 0.5842, -0.0263), tris = 320 },
	snowdrift = { size = Vector3.new(3.1728, 0.6685, 1.6618), offset = Vector3.new(-0.1023, 0.2843, -0.0022), tris = 504 },
}
