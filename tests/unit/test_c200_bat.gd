extends GutTest
## Chimora 200 list items 55 (shorter repeat animations), 59 (escape chance in words),
## 66 (foe heals with an item once per battle) and 76 (rare Spirlings' battle theme).

const Side := BattleModel.Side

func before_all() -> void:
	Database.load_all()

func after_each() -> void:
	RepeatShort.reset()

# --- 55 ---------------------------------------------------------------------------------------

func test_repeat_animation_is_quicker_the_second_time() -> void:
	assert_eq(RepeatShort.speed("art:Cinder Nip"), 1.0, "first time at full length")
	assert_eq(RepeatShort.speed("art:Cinder Nip"), RepeatShort.REPEAT_SPEED, "second time quicker")
	assert_eq(RepeatShort.speed("art:Fizz Pop"), 1.0, "another art still plays in full")
	assert_gt(RepeatShort.REPEAT_SPEED, 1.0)
	RepeatShort.reset()
	assert_eq(RepeatShort.speed("art:Cinder Nip"), 1.0, "a new session shows it in full again")
