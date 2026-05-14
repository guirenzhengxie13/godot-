class_name MoveValidator
extends Node

const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(1, -1),
	Vector2i(0, -1),
	Vector2i(-1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
]


func get_legal_moves(from_coord: Vector2i, occupied: Dictionary, valid_cells: Dictionary, only_jumps := false) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	if not only_jumps:
		moves.append_array(get_normal_moves(from_coord, occupied, valid_cells))
	moves.append_array(get_jump_moves(from_coord, occupied, valid_cells))
	return moves


func get_normal_moves(from_coord: Vector2i, occupied: Dictionary, valid_cells: Dictionary) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	for direction in DIRECTIONS:
		var target := from_coord + direction
		if valid_cells.has(target) and not occupied.has(target):
			moves.append(target)
	return moves


func get_jump_moves(from_coord: Vector2i, occupied: Dictionary, valid_cells: Dictionary) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	for direction in DIRECTIONS:
		var middle := from_coord + direction
		var target := from_coord + direction * 2
		if occupied.has(middle) and valid_cells.has(target) and not occupied.has(target):
			moves.append(target)
	return moves


func is_jump_move(from_coord: Vector2i, to_coord: Vector2i) -> bool:
	var delta := to_coord - from_coord
	for direction in DIRECTIONS:
		if delta == direction * 2:
			return true
	return false


func get_jumped_coord(from_coord: Vector2i, to_coord: Vector2i) -> Vector2i:
	var delta := to_coord - from_coord
	for direction in DIRECTIONS:
		if delta == direction * 2:
			return from_coord + direction
	return Vector2i(999999, 999999)


func has_jump_from(from_coord: Vector2i, occupied: Dictionary, valid_cells: Dictionary) -> bool:
	return not get_jump_moves(from_coord, occupied, valid_cells).is_empty()

