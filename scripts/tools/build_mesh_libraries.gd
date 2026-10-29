@tool
extends EditorScript

# Rodar pelo Script Editor (File > Run) sempre que mudar uma regra ou um asset.
# Telhados ficam por ultimo para nao mudar os ids das paredes ja pintadas no mapa.

const VILLAGE := "res://assets/quaternius_village/models"
const DUNGEON := "res://assets/kaykit_dungeon/models"
const OUTPUT_DIR := "res://resources/mesh_libraries"
const PREVIEW_SIZE := 128

const LIBRARIES := {
	# so pisos Quaternius: os do KayKit sao cor lisa e destoam do tijolo com textura;
	# o ponto final pega so a peca inteira de madeira, sem as metades e beiradas
	"ground": [
		{"dir": VILLAGE, "prefixes": ["Floor_Brick", "Floor_RedBrick", "Floor_UnevenBrick", "Floor_WoodDark.", "Floor_WoodLight."]},
	],
	"village_structure": [
		{"dir": VILLAGE, "prefixes": ["Floor_Wood", "Wall_", "Corner_", "Stairs_Exterior", "HoleCover",
				"Balcony", "Overhang_", "Prop_ExteriorBorder"]},
		{"dir": VILLAGE, "prefixes": ["Roof_RoundTiles_6x8", "Roof_RoundTiles_8x8", "Roof_Front_Brick6", "Roof_Front_Brick8"]},
	],
	"props": [
		{"dir": VILLAGE, "prefixes": ["Prop_Wagon", "Prop_WoodenFence", "Prop_Crate"]},
		{"dir": DUNGEON, "prefixes": ["torch_mounted", "keg"]},
		{"dir": DUNGEON, "prefixes": ["crates_stacked"], "scale": 0.6},
		{"dir": DUNGEON, "prefixes": ["barrel_large", "barrel_small_stack"], "scale": 0.55},
	],
	# calabouco: grade de 4 m no chao e de 2 m nas paredes, que caem na borda entre dois pisos
	"dungeon_ground": [
		{"dir": DUNGEON, "prefixes": ["floor_tile_large", "floor_tile_big_grate", "floor_dirt_large", "floor_wood_large"], "flat_top": 0.05},
	],
	"dungeon_structure": [
		{"dir": DUNGEON, "prefixes": ["wall", "pillar", "stairs"]},
	],
	"dungeon_props": [
		{"dir": DUNGEON, "prefixes": ["torch", "candle", "banner", "bottle", "shelf", "table", "chair", "stool",
				"chest", "trunk", "rubble", "column", "sword_shield", "keyring", "coin", "bed"]},
		{"dir": DUNGEON, "prefixes": ["keg", "crates_stacked", "barrel_large", "barrel_small"], "scale": 0.55},
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


# sem preview a paleta do GridMap mostra so os nomes
func _add_previews(library: MeshLibrary) -> void:
	var ids := library.get_item_list()
	var meshes: Array[Mesh] = []
	for id in ids:
		meshes.append(library.get_item_mesh(id))
	var previews := EditorInterface.make_mesh_previews(meshes, PREVIEW_SIZE)
	for i in ids.size():
		library.set_item_preview(ids[i], previews[i])
