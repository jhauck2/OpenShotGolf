class_name RangeClubCatalog
extends RefCounted

const DEFAULT_CLUB_LABEL := "DRIVER"
const LABELS := [
	"DRIVER",
	"3W",
	"5W",
	"4H",
	"3I",
	"4I",
	"5I",
	"6I",
	"7I",
	"8I",
	"9I",
	"PW",
	"GW",
	"SW",
	"LW"
]


static func normalize_label(label: String) -> String:
	var normalized := label.strip_edges().to_upper()
	if normalized in LABELS:
		return normalized

	return DEFAULT_CLUB_LABEL
