class_name SquareClubCatalog
extends RefCounted

const DEFAULT_CLUB_CODE := "0204"

# Alignment stick is a special "club" the device uses to enter alignment mode
# (RegularCode 0008 in the squaregolf-connector reference). It is intentionally
# kept out of CLUBS so it does not appear as a selectable shot club; the
# alignment-mode flow that uses it is implemented separately.
const ALIGNMENT_STICK_CODE := "0008"

# Square Hex Code Lookup. Codes mirror the squaregolf-connector RegularCode
# values. Note: 0b06 is the Approach/Gap wedge (GW); the Square hardware has no
# distinct lob-wedge code.
const CLUBS := {
	"Driver": "0204",
	"Putter": "0107",
	"3 Wood": "0305",
	"5 Wood": "0505",
	"7 Wood": "0705",
	"4 Iron": "0406",
	"5 Iron": "0506",
	"6 Iron": "0606",
	"7 Iron": "0706",
	"8 Iron": "0806",
	"9 Iron": "0906",
	"PW": "0a06",
	"GW": "0b06",
	"SW": "0c06"
}


static func labels() -> Array:
	return CLUBS.keys()


static func code_for(label: String) -> String:
	return str(CLUBS.get(label, DEFAULT_CLUB_CODE))


static func is_valid_code(code: String) -> bool:
	for club_code in CLUBS.values():
		if str(club_code) == code:
			return true
	return false


static func is_alignment_stick(code: String) -> bool:
	return code == ALIGNMENT_STICK_CODE
