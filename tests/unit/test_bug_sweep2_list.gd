extends GutTest
## Bug sweep 2: the same row focused twice in one frame (era menu shots, 21 times) logged
## "Signal 'process_frame' is already connected to ... _restore_scroll_step".

func _rows(n: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in n:
		out.append({"text": "Row %d" % i})
	return out

func test_focusing_a_remembered_row_twice_in_one_frame_logs_no_error() -> void:
	var host := MenuHost.new()
	add_child_autofree(host)
	await wait_process_frames(1)
	var p: ListPicker = host.picker
	p.pick("Deep", _rows(30), true, 20)
	await wait_process_frames(3)
	var at: int = p._scroll.scroll_vertical
	p.picked.emit(20)
	await wait_process_frames(1)
	p.pick("Deep", _rows(30), true, 20)
	p._focus_row(20)
	p._focus_row(20)
	await wait_process_frames(5)
	assert_engine_error_count(0, "one restore step per row and frame")
	assert_eq(p._scroll.scroll_vertical, at, "the list is still back where it was")
	p.picked.emit(-1)
