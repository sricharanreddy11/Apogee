class_name RocketConfig
extends RefCounted

var rocket_name: String = ""
var command_pod_id: String = ""
## First to fire is index 0, the physical bottom of the rocket.
var stages: Array[StageConfig] = []
var attachment_ids: Array[String] = []
var cosmetic_order: Array[String] = []


func copy() -> RocketConfig:
	var result := RocketConfig.new()
	result.rocket_name = rocket_name
	result.command_pod_id = command_pod_id
	for stage_config in stages:
		# Preserve missing-stage entries so validation can explain an invalid design.
		result.stages.append(stage_config.copy() if stage_config != null else null)
	result.attachment_ids.assign(attachment_ids)
	result.cosmetic_order.assign(cosmetic_order)
	return result
