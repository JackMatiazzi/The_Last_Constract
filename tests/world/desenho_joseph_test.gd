extends GdUnitTestSuite

# o mapa de desenho tem de usar as mesmas pecas e grades da vila, para o que for desenhado nele
# servir no jogo sem ajuste

const SKETCH := preload("res://scenes/maps/desenho_joseph.tscn")
const VILLAGE := preload("res://scenes/maps/village.tscn")
const GRIDS := ["Chao", "Estrutura", "Objetos"]

var sketch: Node3D


func before_test() -> void:
	sketch = auto_free(SKETCH.instantiate())
	add_child(sketch)


func test_uses_the_same_pieces_and_grids_as_the_village() -> void:
	var village: Node3D = auto_free(VILLAGE.instantiate())
	for grid_name in GRIDS:
		var mine := sketch.get_node(grid_name) as GridMap
		var reference := village.get_node(grid_name) as GridMap
		assert_object(mine.mesh_library).override_failure_message(grid_name).is_same(reference.mesh_library)
		assert_vector(mine.cell_size).override_failure_message(grid_name).is_equal(reference.cell_size)
		assert_vector(mine.position).override_failure_message(grid_name).is_equal(reference.position)


func test_starts_empty_for_him_to_draw() -> void:
	for grid_name in GRIDS:
		assert_int((sketch.get_node(grid_name) as GridMap).get_used_cells().size()).override_failure_message(grid_name).is_equal(0)


func test_objects_placed_on_it_can_break() -> void:
	assert_object(sketch.get_node("Objetos")).is_instanceof(BreakableProps)
