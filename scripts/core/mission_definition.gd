class_name MissionDefinition
extends RefCounted

var id: String = ""
var title: String = ""
var objective_text: String = ""
var budget_credits: int = 0
var reward_credits: int = 0
var scenario: Dictionary = {}
var allowed_part_ids: Array[String] = []
var required_part_ids: Array[String] = []
var win_conditions: Dictionary = {}
var discovery_ids: Array[String] = []
