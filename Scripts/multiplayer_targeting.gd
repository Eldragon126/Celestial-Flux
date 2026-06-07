extends RefCounted
class_name MultiplayerTargeting


static func nearest_player(origin: Vector2, tree: SceneTree) -> Node2D:
	if tree == null:
		return null
	var best_player: Node2D = null
	var best_distance := INF
	var players := live_players(tree)
	for player in players:
		if _player_is_dead(player):
			continue
		var distance := player.global_position.distance_squared_to(origin)
		if distance < best_distance:
			best_distance = distance
			best_player = player
	return best_player


static func first_live_player(tree: SceneTree) -> Node2D:
	if tree == null:
		return null
	var players := live_players(tree)
	for player in players:
		if not _player_is_dead(player):
			return player
	return null


static func local_player(tree: SceneTree) -> Node2D:
	if tree == null:
		return null
	var players := live_players(tree)
	for player in players:
		var is_local_value: Variant = player.get("network_is_local")
		if typeof(is_local_value) == TYPE_BOOL and bool(is_local_value) and not _player_is_dead(player):
			return player
	return first_live_player(tree)


static func live_players(tree: SceneTree) -> Array[Node2D]:
	var players: Array[Node2D] = []
	if tree == null:
		return players
	if RuntimeRegistry != null:
		RuntimeRegistry.fill_group(&"Player", players)
	else:
		for node in tree.get_nodes_in_group("Player"):
			var player := node as Node2D
			if player != null:
				players.append(player)
	for index in range(players.size() - 1, -1, -1):
		var player := players[index]
		if player == null or not is_instance_valid(player) or player.is_queued_for_deletion():
			players.remove_at(index)
	return players


static func _player_is_dead(player: Node) -> bool:
	if player == null:
		return true
	if player.has_method("is_death_in_progress") and bool(player.call("is_death_in_progress")):
		return true
	if player.has_method("is_dead") and bool(player.call("is_dead")):
		return true
	return bool(player.get_meta(&"death_in_progress", false))
