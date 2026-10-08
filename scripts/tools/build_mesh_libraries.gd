@tool
extends EditorScript

# Gera as MeshLibraries do GridMap. Rodar no Script Editor com File > Run (Ctrl+Shift+X).

const VILLAGE := "res://assets/quaternius_village/models"
const DUNGEON := "res://assets/kaykit_dungeon/models"
const OUTPUT_DIR := "res://resources/mesh_libraries"
const PREVIEW_SIZE := 128

const LIBRARIES := {
	"ground": [
		{"dir": VILLAGE, "prefixes": ["Floor_Brick", "Floor_RedBrick", "Floor_UnevenBrick"]},
		{"dir": DUNGEON, "prefixes": ["floor_dirt_small", "floor_tile_small", "floor_wood_small"]},
	],
	"village_structure": [
		{"dir": VILLAGE, "prefixes": ["Floor_Wood", "Wall_", "Corner_", "Stairs_Exterior", "HoleCover",
				"Balcony", "Overhang_", "Prop_ExteriorBorder"]},
		{"dir": VILLAGE, "prefixes": ["Roof_RoundTiles_6x8", "Roof_RoundTiles_8x8", "Roof_Front_Brick6", "Roof_Front_Brick8"]},
	],
}


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	for library_name: String in LIBRARIES:
		var library := MeshLibraryBuilder.build(LIBRARIES[library_name])
		_add_previews(library)
		var path := OUTPUT_DIR.path_join(library_name + ".res")
		var error := ResourceSaver.save(library, path)
		if error != OK:
			push_error("Falha ao salvar %s: %s" % [path, error_string(error)])
			continue
		print("%s: %d pecas" % [path, library.get_item_list().size()])


func _add_previews(library: MeshLibrary) -> void:
	var ids := library.get_item_list()
	var meshes: Array[Mesh] = []
	for id in ids:
		meshes.append(library.get_item_mesh(id))
	var previews := EditorInterface.make_mesh_previews(meshes, PREVIEW_SIZE)
	for i in ids.size():
		library.set_item_preview(ids[i], previews[i])
