class_name StageConfig
extends RefCounted

var engine_id: String = ""
var tank_ids: Array[String] = []


func copy() -> StageConfig:
	var result := StageConfig.new()
	result.engine_id = engine_id
	result.tank_ids.assign(tank_ids)
	return result
