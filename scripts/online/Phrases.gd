class_name Phrases
extends RefCounted
## Set phrases for greetings (item 141). There is no free text anywhere online: the server only
## stores the phrase number, and every phone shows it in its own language. Append new phrases at
## the end; never reorder (old mail keeps its number). The server accepts numbers 0-31.

const LIST: Array[String] = [
	"Hello!",
	"Thanks!",
	"Good luck!",
	"Well played!",
	"See you soon!",
	"Have fun!",
	"Let's train together!",
	"Nice team!",
	"I sent you a gift!",
	"Good morning!",
	"Good night!",
	"Your echo helped me a lot!",
	"Ready for a duel?",
	"The world goal is close!",
	"I sealed a Rift!",
	"Sorry, no time today.",
]
## Which phrase numbers each place may use (plan area 7, item 2877); the server checks the same
## lists (server_config.phrases_allowed). A menu phrase never turns up in a duel.
const CONTEXTS: Dictionary = {
	"post": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
	"duel": [0, 1, 2, 3, 5, 12],
	"bund": [0, 1, 2, 4, 5, 6, 9, 10, 13, 14, 15],
	"raid": [0, 1, 2, 3, 14],
}
const WAVE: String = "%s waves at you."
const THANKS: String = "%s says thanks!"

static func text(i: int) -> String:
	return LIST[i] if i >= 0 and i < LIST.size() else LIST[0]

## The phrase numbers [param context] may use, in list order.
static func allowed(context: String) -> Array:
	return CONTEXTS.get(context, [])
