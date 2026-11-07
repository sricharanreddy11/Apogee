class_name MissionDefinition
extends RefCounted

var id: String = ""
var title: String = ""
var objective_text: String = ""
## Navigation/progression metadata comes from data/missions/index.json.
var unlock_requirement: String = ""
var starting_location: String = ""
var destination: String = ""
var released: bool = true
## Old M01 files omit objective_type and retain the reach-altitude schema.
var objective_type: String = "reach_altitude"
var payload: Dictionary = {}
var budget_credits: int = 0
var reward_credits: int = 0
var scenario: Dictionary = {}
var allowed_part_ids: Array[String] = []
var required_part_ids: Array[String] = []
var win_conditions: Dictionary = {}
var discovery_ids: Array[String] = []
