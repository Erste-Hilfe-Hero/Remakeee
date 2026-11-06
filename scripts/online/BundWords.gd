class_name BundWords
extends RefCounted
## Bund names are two numbers into these lists (plan area 7, item 2818), so nobody types a
## name and the server stores only the numbers. English "Amber Badgers", German "Bernstein-Dachse".
## Never reorder or remove words: existing bunds point at the positions. Add new words at the end.

const FIRST: Array[String] = [
	"Amber", "Ash", "Birch", "Bramble", "Brook", "Cedar", "Clover", "Cloud", "Copper", "Coral", "Crystal", "Dawn",
	"Dew", "Drift", "Dune", "Dusk", "Ember", "Elm", "Fern", "Flint", "Fog", "Frost", "Garnet", "Glade", "Glow",
	"Granite", "Hazel", "Heath", "Hearth", "Holly", "Honey", "Ink", "Iron", "Ivy", "Jade", "Juniper", "Kelp",
	"Lake", "Lantern", "Lark", "Lava", "Leaf", "Light", "Lily", "Linden", "Maple", "Marsh", "Meadow", "Mist",
	"Moon", "Moss", "Night", "Oak", "Opal", "Pebble", "Pine", "Plum", "Quartz", "Rain", "Reed", "Ridge", "Ripple",
	"River", "Rose", "Rowan", "Ruby", "Rust", "Sage", "Salt", "Sand", "Shadow", "Shell", "Silver", "Sky", "Slate",
	"Snow", "Spark", "Spring", "Star", "Stone", "Storm", "Stream", "Summer", "Sun", "Thistle", "Thorn", "Thunder",
	"Tide", "Timber", "Torch", "Twilight", "Valley", "Velvet", "Willow", "Wind", "Winter", "Wood", "Wren",
	"Yarrow", "Autumn", "Beacon", "Breeze", "Canyon", "Cliff", "Comet", "Crest", "Delta", "Echo", "Feather",
	"Field", "Flame", "Grove", "Harbor", "Hill", "Island", "Lotus", "Meteor", "Orchard", "Prairie", "Thicket",
]
const SECOND: Array[String] = [
	"Badgers", "Bears", "Bees", "Beetles", "Bells", "Blades", "Boats", "Bridges", "Builders", "Candles",
	"Carvers", "Cats", "Climbers", "Cranes", "Crows", "Dancers", "Deer", "Diggers", "Dreamers", "Drums", "Eagles",
	"Explorers", "Falcons", "Fireflies", "Fishers", "Flutes", "Foxes", "Friends", "Gardeners", "Geese", "Guards",
	"Guides", "Hares", "Hawks", "Hedgehogs", "Herons", "Hikers", "Hunters", "Keepers", "Kites", "Knots", "Lamps",
	"Larks", "Lights", "Lynxes", "Makers", "Mappers", "Mice", "Moles", "Moths", "Otters", "Owls", "Painters",
	"Pathfinders", "Pilots", "Pipers", "Poets", "Ravens", "Riders", "Rings", "Robins", "Rovers", "Runners",
	"Sailors", "Scouts", "Seekers", "Seeds", "Shields", "Singers", "Sparks", "Sparrows", "Squirrels", "Stars",
	"Storytellers", "Swallows", "Swans", "Tinkers", "Toads", "Tortoises", "Travelers", "Trees", "Voices",
	"Walkers", "Wanderers", "Watchers", "Weavers", "Whistlers", "Wings", "Wolves", "Wrens", "Archers", "Artists",
	"Bakers", "Banners", "Bards", "Beacons", "Brothers", "Circles", "Clans", "Companions", "Crafters",
	"Dragonflies", "Ferns", "Folk", "Gliders", "Hearts", "Heroes", "Islanders", "Jugglers", "Kin", "Lanterns",
	"Messengers", "Minstrels", "Nomads", "Oars", "Pioneers", "Ramblers", "Sisters", "Songbirds", "Tribe",
]
const FIRST_DE: Array[String] = [
	"Bernstein", "Aschen", "Birken", "Brombeer", "Bach", "Zedern", "Klee", "Wolken", "Kupfer", "Korallen",
	"Kristall", "Morgen", "Tau", "Treib", "Dünen", "Dämmer", "Glut", "Ulmen", "Farn", "Feuerstein", "Nebel",
	"Frost", "Granat", "Lichtungs", "Leucht", "Granit", "Hasel", "Heide", "Herd", "Stechpalmen", "Honig",
	"Tinten", "Eisen", "Efeu", "Jade", "Wacholder", "Tang", "See", "Laternen", "Lerchen", "Lava", "Blatt",
	"Licht", "Lilien", "Linden", "Ahorn", "Moor", "Wiesen", "Dunst", "Mond", "Moos", "Nacht", "Eichen", "Opal",
	"Kiesel", "Kiefern", "Pflaumen", "Quarz", "Regen", "Schilf", "Grat", "Wellen", "Fluss", "Rosen", "Ebereschen",
	"Rubin", "Rost", "Salbei", "Salz", "Sand", "Schatten", "Muschel", "Silber", "Himmels", "Schiefer", "Schnee",
	"Funken", "Quell", "Stern", "Stein", "Sturm", "Strom", "Sommer", "Sonnen", "Distel", "Dorn", "Donner",
	"Gezeiten", "Holz", "Fackel", "Zwielicht", "Tal", "Samt", "Weiden", "Wind", "Winter", "Wald", "Zaunkönig",
	"Schafgarben", "Herbst", "Leuchtfeuer", "Brisen", "Schlucht", "Klippen", "Kometen", "Kamm", "Delta", "Echo",
	"Feder", "Feld", "Flammen", "Hain", "Hafen", "Hügel", "Insel", "Lotus", "Meteor", "Obstgarten", "Prärie",
	"Dickicht",
]
const SECOND_DE: Array[String] = [
	"Dachse", "Bären", "Bienen", "Käfer", "Glocken", "Klingen", "Boote", "Brücken", "Bauleute", "Kerzen",
	"Schnitzer", "Katzen", "Kletterer", "Kraniche", "Krähen", "Tänzer", "Hirsche", "Gräber", "Träumer",
	"Trommeln", "Adler", "Entdecker", "Falken", "Glühwürmchen", "Fischer", "Flöten", "Füchse", "Freunde",
	"Gärtner", "Gänse", "Wächter", "Führer", "Hasen", "Habichte", "Igel", "Reiher", "Wanderer", "Sucher", "Hüter",
	"Drachen", "Knoten", "Lampen", "Lerchen", "Lichter", "Luchse", "Macher", "Kartenzeichner", "Mäuse",
	"Maulwürfe", "Motten", "Otter", "Eulen", "Maler", "Pfadfinder", "Lotsen", "Pfeifer", "Dichter", "Raben",
	"Reiter", "Ringe", "Rotkehlchen", "Streifer", "Läufer", "Segler", "Späher", "Suchende", "Samen", "Schilde",
	"Sänger", "Funken", "Spatzen", "Eichhörnchen", "Sterne", "Erzähler", "Schwalben", "Schwäne", "Tüftler",
	"Kröten", "Schildkröten", "Reisende", "Bäume", "Stimmen", "Gänger", "Streuner", "Beobachter", "Weber",
	"Pfeifende", "Schwingen", "Wölfe", "Zaunkönige", "Bogenschützen", "Künstler", "Bäcker", "Banner", "Barden",
	"Feuer", "Brüder", "Kreise", "Sippen", "Gefährten", "Handwerker", "Libellen", "Farne", "Leute", "Gleiter",
	"Herzen", "Helden", "Insulaner", "Gaukler", "Verwandten", "Laternen", "Boten", "Spielleute", "Nomaden",
	"Ruder", "Pioniere", "Bummler", "Schwestern", "Singvögel", "Stämme",
]

## The bund name in the game's language.
static func name_of(a: int, b: int) -> String:
	if a < 0 or a >= FIRST.size() or b < 0 or b >= SECOND.size():
		return "?"
	if Loc.language().begins_with("de"):
		return FIRST_DE[a] + "-" + SECOND_DE[b]
	return FIRST[a] + " " + SECOND[b]
