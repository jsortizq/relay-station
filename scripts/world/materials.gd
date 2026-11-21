class_name Mats
extends RefCounted
## Shared materials (created once, cached) so the art style stays coherent
## and draw calls batch well in the Compatibility renderer.

static var _cache := {}


static func solid(col: Color, roughness := 0.8, metallic := 0.1) -> StandardMaterial3D:
	var key := "s%s%.2f%.2f" % [col.to_html(), roughness, metallic]
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = roughness
		m.metallic = metallic
		_cache[key] = m
	return _cache[key]


static func glow(col: Color, energy := 2.0) -> StandardMaterial3D:
	var key := "g%s%.2f" % [col.to_html(), energy]
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = energy
		_cache[key] = m
	return _cache[key]


static func mesh_box(size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	return mi


static func mesh_cyl(radius: float, height: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	mi.mesh = c
	mi.material_override = mat
	return mi


static func mesh_sphere(radius: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2
	mi.mesh = s
	mi.material_override = mat
	return mi


static func box_shape(size: Vector3) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	return cs
