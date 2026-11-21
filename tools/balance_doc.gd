extends SceneTree
## Rewrites the generated sections of docs/BALANCE.md (plan area 2, item 881):
##   godot --headless --path . -s res://tools/balance_doc.gd            data and simulator sections
##   godot --headless --path . -s res://tools/balance_doc.gd -- --data  data sections only (fast)
## Called by tools/balance/run_all.sh after every balance change. Loaded at run time like
## tools/balance_sim.gd, because the autoloads only exist once the tree runs.

func _initialize() -> void:
	var data_only: bool = "--data" in OS.get_cmdline_user_args()
	var bd: GDScript = load("res://scripts/core/BalanceDoc.gd")
	var bs: GDScript = load("res://scripts/core/BalanceSim.gd")
	load("res://scripts/core/Database.gd").call("load_all")
	var path: String = str(bd.get("DOC_PATH"))
	var doc: String = FileAccess.get_file_as_string(path)
	for name: String in bd.get("DATA_SECTIONS"):
		doc = bd.call("replace_section", doc, name, bd.call("section", name))
	if not data_only:
		var duel: Dictionary = bs.call("run", 36, 10, 1234, [] as Array[String], 1)
		doc = bd.call("replace_section", doc, "changes", bd.call("changes_table", duel))
		# The report's own headings move one level down to sit under "Full report at Lv36".
		var report: String = str(bs.call("report", duel)).replace("# Balance report\n", "").replace("\n## ", "\n### ")
		doc = bd.call("replace_section", doc, "report_lv36", report)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(doc)
	f.close()
	print("Wrote %s%s." % [path, " (data sections)" if data_only else ""])
	quit()
