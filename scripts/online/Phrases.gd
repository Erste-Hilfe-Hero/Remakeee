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
const WAVE: String = "%s waves at you."
const THANKS: String = "%s says thanks!"

static func text(i: int) -> String:
	return LIST[i] if i >= 0 and i < LIST.size() else LIST[0]
