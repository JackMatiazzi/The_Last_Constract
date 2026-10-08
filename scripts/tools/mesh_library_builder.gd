@tool
class_name MeshLibraryBuilder
extends RefCounted

# regra: {"dir": pasta, "prefixes": [...], "scale": opcional}


static func build(rules: Array) -> MeshLibrary:
	var library := MeshLibrary.new()
	for rule: Dictionary in rules:
		for file in _matching_files(rule):
			_add_item(library, rule["dir"].path_join(file), rule.get("scale", 1.0))
	return library


static func _matching_files(rule: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for file in DirAccess.get_files_at(rule["dir"]):
		if file.ends_with(".gltf") and _starts_with_any(file, rule["prefixes"]):
			result.append(file)
	result.sort()
	return result


static func _starts_with_any(text: String, prefixes: Array) -> bool:
	return prefixes.any(func(prefix: String) -> bool: return text.begins_with(prefix))


static func _add_item(library: MeshLibrary, path: String, scale: float) -> void:
	var root := (load(path) as PackedScene).instantiate()
	var mesh := _merge_meshes(root, Transform3D.IDENTITY.scaled(Vector3.ONE * scale))
	root.free()

	var id := library.get_last_unused_item_id()
	library.create_item(id)
	library.set_item_name(id, path.get_file().get_basename())
	library.set_item_mesh(id, mesh)
	library.set_item_shapes(id, [mesh.create_trimesh_shape(), Transform3D.IDENTITY])


static func _merge_meshes(root: Node, base: Transform3D) -> ArrayMesh:
	var merged := ArrayMesh.new()
	for mesh_instance: MeshInstance3D in root.find_children("*", "MeshInstance3D"):
		var xform := base * _transform_relative_to(mesh_instance, root)
		for surface in mesh_instance.mesh.get_surface_count():
			var surface_tool := SurfaceTool.new()
			surface_tool.append_from(mesh_instance.mesh, surface, xform)
			surface_tool.commit(merged)
			merged.surface_set_material(merged.get_surface_count() - 1,
					mesh_instance.mesh.surface_get_material(surface))
	return merged


static func _transform_relative_to(node: Node3D, root: Node) -> Transform3D:
	var xform := node.transform
	var parent := node.get_parent()
	while parent != root and parent is Node3D:
		xform = (parent as Node3D).transform * xform
		parent = parent.get_parent()
	return xform
