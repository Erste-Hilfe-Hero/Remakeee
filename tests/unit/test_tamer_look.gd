extends GutTest
## Wayfarer look at new game (Ali, 7 Nov): skin tone, hair and coat colour, saved with the game
## and painted onto the tamer sheet by shaders/tamer_palette.gdshader.

func before_all() -> void:
	Database.load_all()

func test_new_game_keeps_the_picked_look() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 2, "", 1, 3, 4)
	assert_eq(GameState.tamer_color, 2)
	assert_eq(GameState.skin_tone, 3)
	assert_eq(GameState.hair_color, 4)
	var d: Dictionary = GameState.to_dict()
	assert_eq(int(d.tamer.skin), 3)
	assert_eq(int(d.tamer.hair), 4)
	GameState.new_game(GameState.Difficulty.TAMER, "Ann", 0, "")
	assert_eq(GameState.skin_tone, 0)
	GameState.from_dict(d)
	assert_eq(GameState.skin_tone, 3)
	assert_eq(GameState.hair_color, 4)

func test_out_of_range_and_old_saves_fall_back() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 0, "", 0, 99, -4)
	assert_eq(GameState.skin_tone, GameState.SKIN_TONES.size() - 1)
	assert_eq(GameState.hair_color, 0)
	var d: Dictionary = GameState.to_dict()
	(d.tamer as Dictionary).erase("skin")
	(d.tamer as Dictionary).erase("hair")
	GameState.from_dict(d)
	assert_eq(GameState.skin_tone, 0)
	assert_eq(GameState.hair_color, 0)

func test_every_option_has_a_name() -> void:
	assert_eq(GameState.SKIN_NAMES.size(), GameState.SKIN_TONES.size())
	assert_eq(GameState.HAIR_NAMES.size(), GameState.HAIR_COLORS.size())
	assert_eq(GameState.COAT_NAMES.size(), GameState.TAMER_COLORS.size())

func test_material_carries_the_colours() -> void:
	GameState.new_game(GameState.Difficulty.TAMER, "Tess", 1, "", 0, 2, 5)
	var m: ShaderMaterial = GameState.tamer_material()
	assert_not_null(m.shader)
	assert_eq(m.get_shader_parameter("skin"), GameState.SKIN_TONES[2])
	assert_eq(m.get_shader_parameter("hair"), GameState.HAIR_COLORS[5])
	assert_eq(m.get_shader_parameter("coat"), GameState.body_color())
