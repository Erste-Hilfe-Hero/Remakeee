class_name PathFinder
extends RefCounted
## Breadth-first search on the 4-direction grid, for tap-to-move.
## [param passable] is Callable(Vector2i) -> bool. Paths never include the start cell.

const ORDER: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
## Upper bound on visited cells, so a far-away tap never stalls a frame.
const MAX_VISITED: int = 1200

## Shortest path from [param start] to [param goal], or [] if unreachable.
static func find(start: Vector2i, goal: Vector2i, passable: Callable) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if start == goal or not passable.call(goal):
		return out
	return _search(start, func(c: Vector2i) -> bool: return c == goal, passable)

## Shortest path to any walkable cell next to [param target] (to talk to an NPC or read a sign).
## Returns [] when already adjacent or when no neighbour is reachable.
static func find_adjacent(start: Vector2i, target: Vector2i, passable: Callable) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if is_adjacent(start, target):
		return out
	return _search(start, func(c: Vector2i) -> bool: return is_adjacent(c, target), passable)

static func is_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1

static func _search(start: Vector2i, is_goal: Callable, passable: Callable) -> Array[Vector2i]:
	var came: Dictionary[Vector2i, Vector2i] = {start: start}
	var queue: Array[Vector2i] = [start]
	var head: int = 0
	while head < queue.size() and came.size() < MAX_VISITED:
		var c: Vector2i = queue[head]
		head += 1
		for d: Vector2i in ORDER:
			var n: Vector2i = c + d
			if came.has(n) or not passable.call(n):
				continue
			came[n] = c
			if is_goal.call(n):
				return _unwind(came, start, n)
			queue.append(n)
	var none: Array[Vector2i] = []
	return none

static func _unwind(came: Dictionary[Vector2i, Vector2i], start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var c: Vector2i = end
	while c != start:
		path.push_front(c)
		c = came[c]
	return path
