extends Node

@export var combat_scene: PackedScene
@export var map_scene: PackedScene
@export var reward_scene: PackedScene
@export var starter_pool: Array[SymbolData]

var run: RunState

func _ready() -> void:
	start_new_run()

func start_new_run() -> void:
	run = RunState.create(starter_pool, GlobalSettings.easy_mode_hp_buff)
	#show_map()

#func show_map() -> void:
	#var m := map_scene.instantiate()
	#m.setup(run)
	#m.node_selected.connect(_on_node_selected)
	#_swap(m)

#func _on_node_selected(node: MapNode) -> void:
	#match node.type:
		#MapNode.Type.COMBAT, MapNode.Type.BOSS:
			#var c := combat_scene.instantiate()
			#c.setup(CombatContext.new(run, node.enemy))
			#c.combat_finished.connect(_on_combat_finished)
			#_swap(c)
		## TODO: SHOP, EVENT, REST later, same pattern
#
#func _on_combat_finished(victory: bool, cash_reward: int) -> void:
	#if not victory:
		#show_game_over()   # restart = start_new_run(), not reload_current_scene()
		#return
	#run.add_cash(cash_reward)
	#show_reward()  # reward scene calls run.add_symbol(...) etc. then signals done -> show_map()

func _swap(scene: Node) -> void:
	for child in $SceneRoot.get_children():
		child.queue_free()
	$SceneRoot.add_child(scene)
