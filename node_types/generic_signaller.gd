class_name GenericSignaller
extends Node3D

signal event(what: StringName, data: Variant)

func emit(what: StringName, data: Variant = null) -> void:
	event.emit(what, data)

