extends EditorImportPlugin

const SEGMENT_TYPE = preload("source.gd").SEGMENT_TYPE
const positive_num_pattern : String = "(?:\\+?(?:[0-9]*\\.)?[0-9]+(?:e[+\\-]?[0-9]+)?(?![0-9]))"
const num_pattern : String = "(?:[+\\-]?(?:[0-9]*\\.)?[0-9]+(?:e[+\\-]?[0-9]+)?(?![0-9]))"
const any_sep : String = ")[^0-9+\\-\\.]*("
const sep_pattern : String = "(?:[\\s]*(?:[\\s]|(?:,[\\s]*)))"
const optional_sep_pattern : String = "(?:[\\s]*(?:(?:,[\\s]*)?))"
const next_num_pattern : String = "(?:(?:[+\\-]|(?:"+sep_pattern+"[+\\-]?))(?:[0-9]*\\.)?[0-9]+(?:e[+\\-]?[0-9]+)?(?![0-9]))"
const point_pattern : String = "(?:"+num_pattern+next_num_pattern+")"
const next_point_pattern : String = "(?:"+next_num_pattern+next_num_pattern+")"
const quad_pattern : String = "(?:"+num_pattern+next_num_pattern+next_num_pattern+next_num_pattern+")"
const next_quad_pattern : String = "(?:"+next_num_pattern+next_num_pattern+next_num_pattern+next_num_pattern+")"
const cube_pattern : String = "(?:"+num_pattern+next_num_pattern+next_num_pattern+next_num_pattern+next_num_pattern+next_num_pattern+")"
const next_cube_pattern : String = "(?:"+next_num_pattern+next_num_pattern+next_num_pattern+next_num_pattern+next_num_pattern+next_num_pattern+")"
const arc_pattern : String = "(?:"+positive_num_pattern+sep_pattern+positive_num_pattern+next_num_pattern+sep_pattern+"[01]"+optional_sep_pattern+"[01]"+next_num_pattern+next_num_pattern+")"
const path_pattern : String = "(?:(?:[Aa][\\s]*"+arc_pattern+"(?:"+sep_pattern+arc_pattern+")*)|(?:[Cc][\\s]*"+cube_pattern+"(?:"+next_cube_pattern+")*)|(?:[HVhv][\\s]*"+num_pattern+"(?:"+next_num_pattern+")*)|(?:[LMTlmt][\\s]*"+point_pattern+"(?:"+next_point_pattern+")*)|(?:[QSqs][\\s]*"+quad_pattern+"(?:"+next_quad_pattern+")*)|(?:[Zz]))"
const transform_pattern : String = "(?:(?:[Mm][Aa][Tt][Rr][Ii][Xx]\\s*\\(\\s*("+num_pattern+")("+next_num_pattern+")("+next_num_pattern+")("+next_num_pattern+")("+next_num_pattern+")("+next_num_pattern+")\\s*\\))|(?:[Tt][Rr][Aa][Nn][Ss][Ll][Aa][Tt][Ee]\\s*\\(\\s*("+num_pattern+")("+next_num_pattern+")?\\s*\\))|(?:[Ss][Cc][Aa][Ll][Ee]\\s*\\(\\s*("+num_pattern+")("+next_num_pattern+")?\\s*\\))|(?:[Rr][Oo][Tt][Aa][Tt][Ee]\\s*\\(\\s*("+num_pattern+")("+next_num_pattern+"("+next_num_pattern+")?)?\\s*\\))|(?:[Rr][Oo][Tt][Aa][Tt][Ee]\\s*\\(\\s*("+num_pattern+")("+next_num_pattern+"("+next_num_pattern+")?)?\\s*\\))|(?:[Ss][Kk][Ee][Ww][Xx]\\s*\\(\\s*("+num_pattern+")\\s*\\))|(?:[Ss][Kk][Ee][Ww][Yy]\\s*\\(\\s*("+num_pattern+")\\s*\\)))"
const style_pattern : String = "(?:([\\-A-Za-z]+)\\s*\\:\\s*([^;\\s](?:\\s*[^;\\s])*))"
const linejoin_pattern : String = "(?:"+\
	"(?:[Aa][Rr][Cc][Ss])|"+\
	"(?:[Bb][Ee][Vv][Ee][Ll])|"+\
	"(?:[Mm][Ii][Tt][Ee][Rr])|"+\
	"(?:[Mm][Ii][Tt][Ee][Rr]-[Cc][Ll][Ii][Pp])|"+\
	"(?:[Rr][Oo][Uu][Nn][Dd]))"
const linecap_pattern : String = "(?:"+\
	"(?:[Bb][Uu][Tt][Tt])|"+\
	"(?:[Rr][Oo][Uu][Nn][Dd])|"+\
	"(?:[Ss][Qq][Uu][Aa][Rr][Ee]))"
const color_keyword_pattern : String = "(?:"+\
	"(?:[Aa][Ll][Ii][Cc][Ee][Bb][Ll][Uu][Ee])|"+\
	"(?:[Aa][Nn][Tt][Ii][Qq][Uu][Ee][Ww][Hh][Ii][Tt][Ee])|"+\
	"(?:[Aa][Qq][Uu][Aa])|"+\
	"(?:[Aa][Qq][Uu][Aa][Mm][Aa][Rr][Ii][Nn][Ee])|"+\
	"(?:[Aa][Zz][Uu][Rr][Ee])|"+\
	"(?:[Bb][Ee][Ii][Gg][Ee])|"+\
	"(?:[Bb][Ii][Ss][Qq][Uu][Ee])|"+\
	"(?:[Bb][Ll][Aa][Cc][Kk])|"+\
	"(?:[Bb][Ll][Aa][Nn][Cc][Hh][Ee][Dd][Aa][Ll][Mm][Oo][Nn][Dd])|"+\
	"(?:[Bb][Ll][Uu][Ee])|"+\
	"(?:[Bb][Ll][Uu][Ee][Vv][Ii][Oo][Ll][Ee][Tt])|"+\
	"(?:[Bb][Rr][Oo][Ww][Nn])|"+\
	"(?:[Bb][Uu][Rr][Ll][Yy][Ww][Oo][Oo][Dd])|"+\
	"(?:[Cc][Aa][Dd][Ee][Tt][Bb][Ll][Uu][Ee])|"+\
	"(?:[Cc][Hh][Aa][Rr][Tt][Rr][Ee][Uu][Ss][Ee])|"+\
	"(?:[Cc][Hh][Oo][Cc][Oo][Ll][Aa][Tt][Ee])|"+\
	"(?:[Cc][Oo][Rr][Aa][Ll])|"+\
	"(?:[Cc][Oo][Rr][Nn][Ff][Ll][Oo][Ww][Ee][Rr][Bb][Ll][Uu][Ee])|"+\
	"(?:[Cc][Oo][Rr][Nn][Ss][Ii][Ll][Kk])|"+\
	"(?:[Cc][Rr][Ii][Mm][Ss][Oo][Nn])|"+\
	"(?:[Cc][Yy][Aa][Nn])|"+\
	"(?:[Dd][Aa][Rr][Kk][Bb][Ll][Uu][Ee])|"+\
	"(?:[Dd][Aa][Rr][Kk][Cc][Yy][Aa][Nn])|"+\
	"(?:[Dd][Aa][Rr][Kk][Gg][Oo][Ll][Dd][Ee][Nn][Rr][Oo][Dd])|"+\
	"(?:[Dd][Aa][Rr][Kk][Gg][Rr][Aa][Yy])|"+\
	"(?:[Dd][Aa][Rr][Kk][Gg][Rr][Ee][Ee][Nn])|"+\
	"(?:[Dd][Aa][Rr][Kk][Gg][Rr][Ee][Yy])|"+\
	"(?:[Dd][Aa][Rr][Kk][Kk][Hh][Aa][Kk][Ii])|"+\
	"(?:[Dd][Aa][Rr][Kk][Mm][Aa][Gg][Ee][Nn][Tt][Aa])|"+\
	"(?:[Dd][Aa][Rr][Kk][Oo][Ll][Ii][Vv][Ee][Gg][Rr][Ee][Ee][Nn])|"+\
	"(?:[Dd][Aa][Rr][Kk][Oo][Rr][Aa][Nn][Gg][Ee])|"+\
	"(?:[Dd][Aa][Rr][Kk][Oo][Rr][Cc][Hh][Ii][Dd])|"+\
	"(?:[Dd][Aa][Rr][Kk][Rr][Ee][Dd])|"+\
	"(?:[Dd][Aa][Rr][Kk][Ss][Aa][Ll][Mm][Oo][Nn])|"+\
	"(?:[Dd][Aa][Rr][Kk][Ss][Ee][Aa][Gg][Rr][Ee][Ee][Nn])|"+\
	"(?:[Dd][Aa][Rr][Kk][Ss][Ll][Aa][Tt][Ee][Bb][Ll][Uu][Ee])|"+\
	"(?:[Dd][Aa][Rr][Kk][Ss][Ll][Aa][Tt][Ee][Gg][Rr][Aa][Yy])|"+\
	"(?:[Dd][Aa][Rr][Kk][Ss][Ll][Aa][Tt][Ee][Gg][Rr][Ee][Yy])|"+\
	"(?:[Dd][Aa][Rr][Kk][Tt][Uu][Rr][Qq][Uu][Oo][Ii][Ss][Ee])|"+\
	"(?:[Dd][Aa][Rr][Kk][Vv][Ii][Oo][Ll][Ee][Tt])|"+\
	"(?:[Dd][Ee][Ee][Pp][Pp][Ii][Nn][Kk])|"+\
	"(?:[Dd][Ee][Ee][Pp][Ss][Kk][Yy][Bb][Ll][Uu][Ee])|"+\
	"(?:[Dd][Ii][Mm][Gg][Rr][Aa][Yy])|"+\
	"(?:[Dd][Ii][Mm][Gg][Rr][Ee][Yy])|"+\
	"(?:[Dd][Oo][Dd][Gg][Ee][Rr][Bb][Ll][Uu][Ee])|"+\
	"(?:[Ff][Ii][Rr][Ee][Bb][Rr][Ii][Cc][Kk])|"+\
	"(?:[Ff][Ll][Oo][Rr][Aa][Ll][Ww][Hh][Ii][Tt][Ee])|"+\
	"(?:[Ff][Oo][Rr][Ee][Ss][Tt][Gg][Rr][Ee][Ee][Nn])|"+\
	"(?:[Ff][Uu][Cc][Hh][Ss][Ii][Aa])|"+\
	"(?:[Gg][Aa][Ii][Nn][Ss][Bb][Oo][Rr][Oo])|"+\
	"(?:[Gg][Hh][Oo][Ss][Tt][Ww][Hh][Ii][Tt][Ee])|"+\
	"(?:[Gg][Oo][Ll][Dd])|"+\
	"(?:[Gg][Oo][Ll][Dd][Ee][Nn][Rr][Oo][Dd])|"+\
	"(?:[Gg][Rr][Aa][Yy])|"+\
	"(?:[Gg][Rr][Ee][Ee][Nn])|"+\
	"(?:[Gg][Rr][Ee][Ee][Nn][Yy][Ee][Ll][Ll][Oo][Ww])|"+\
	"(?:[Gg][Rr][Ee][Yy])|"+\
	"(?:[Hh][Oo][Nn][Ee][Yy][Dd][Ee][Ww])|"+\
	"(?:[Hh][Oo][Tt][Pp][Ii][Nn][Kk])|"+\
	"(?:[Ii][Nn][Dd][Ii][Aa][Nn][Rr][Ee][Dd])|"+\
	"(?:[Ii][Nn][Dd][Ii][Gg][Oo])|"+\
	"(?:[Ii][Vv][Oo][Rr][Yy])|"+\
	"(?:[Kk][Hh][Aa][Kk][Ii])|"+\
	"(?:[Ll][Aa][Vv][Ee][Nn][Dd][Ee][Rr])|"+\
	"(?:[Ll][Aa][Vv][Ee][Nn][Dd][Ee][Rr][Bb][Ll][Uu][Ss][Hh])|"+\
	"(?:[Ll][Aa][Ww][Nn][Gg][Rr][Ee][Ee][Nn])|"+\
	"(?:[Ll][Ee][Mm][Oo][Nn][Cc][Hh][Ii][Ff][Ff][Oo][Nn])|"+\
	"(?:[Ll][Ii][Gg][Hh][Tt][Bb][Ll][Uu][Ee])|"+\
	"(?:[Ll][Ii][Gg][Hh][Tt][Cc][Oo][Rr][Aa][Ll])|"+\
	"(?:[Ll][Ii][Gg][Hh][Tt][Cc][Yy][Aa][Nn])|"+\
	"(?:[Ll][Ii][Gg][Hh][Tt][Gg][Oo][Ll][Dd][Ee][Nn][Rr][Oo][Dd][Yy][Ee][Ll][Ll][Oo][Ww])|"+\
	"(?:[Ll][Ii][Gg][Hh][Tt][Gg][Rr][Aa][Yy])|"+\
	"(?:[Ll][Ii][Gg][Hh][Tt][Gg][Rr][Ee][Ee][Nn])|"+\
	"(?:[Ll][Ii][Gg][Hh][Tt][Gg][Rr][Ee][Yy])|"+\
	"(?:[Ll][Ii][Gg][Hh][Tt][Pp][Ii][Nn][Kk])|"+\
	"(?:[Ll][Ii][Gg][Hh][Tt][Ss][Aa][Ll][Mm][Oo][Nn])|"+\
	"(?:[Ll][Ii][Gg][Hh][Tt][Ss][Ee][Aa][Gg][Rr][Ee][Ee][Nn])|"+\
	"(?:[Ll][Ii][Gg][Hh][Tt][Ss][Kk][Yy][Bb][Ll][Uu][Ee])|"+\
	"(?:[Ll][Ii][Gg][Hh][Tt][Ss][Ll][Aa][Tt][Ee][Gg][Rr][Aa][Yy])|"+\
	"(?:[Ll][Ii][Gg][Hh][Tt][Ss][Ll][Aa][Tt][Ee][Gg][Rr][Ee][Yy])|"+\
	"(?:[Ll][Ii][Gg][Hh][Tt][Ss][Tt][Ee][Ee][Ll][Bb][Ll][Uu][Ee])|"+\
	"(?:[Ll][Ii][Gg][Hh][Tt][Yy][Ee][Ll][Ll][Oo][Ww])|"+\
	"(?:[Ll][Ii][Mm][Ee])|"+\
	"(?:[Ll][Ii][Mm][Ee][Gg][Rr][Ee][Ee][Nn])|"+\
	"(?:[Ll][Ii][Nn][Ee][Nn])|"+\
	"(?:[Mm][Aa][Gg][Ee][Nn][Tt][Aa])|"+\
	"(?:[Mm][Aa][Rr][Oo][Oo][Nn])|"+\
	"(?:[Mm][Ee][Dd][Ii][Uu][Mm][Aa][Qq][Uu][Aa][Mm][Aa][Rr][Ii][Nn][Ee])|"+\
	"(?:[Mm][Ee][Dd][Ii][Uu][Mm][Bb][Ll][Uu][Ee])|"+\
	"(?:[Mm][Ee][Dd][Ii][Uu][Mm][Oo][Rr][Cc][Hh][Ii][Dd])|"+\
	"(?:[Mm][Ee][Dd][Ii][Uu][Mm][Pp][Uu][Rr][Pp][Ll][Ee])|"+\
	"(?:[Mm][Ee][Dd][Ii][Uu][Mm][Ss][Ee][Aa][Gg][Rr][Ee][Ee][Nn])|"+\
	"(?:[Mm][Ee][Dd][Ii][Uu][Mm][Ss][Ll][Aa][Tt][Ee][Bb][Ll][Uu][Ee])|"+\
	"(?:[Mm][Ee][Dd][Ii][Uu][Mm][Ss][Pp][Rr][Ii][Nn][Gg][Gg][Rr][Ee][Ee][Nn])|"+\
	"(?:[Mm][Ee][Dd][Ii][Uu][Mm][Tt][Uu][Rr][Qq][Uu][Oo][Ii][Ss][Ee])|"+\
	"(?:[Mm][Ee][Dd][Ii][Uu][Mm][Vv][Ii][Oo][Ll][Ee][Tt][Rr][Ee][Dd])|"+\
	"(?:[Mm][Ii][Dd][Nn][Ii][Gg][Hh][Tt][Bb][Ll][Uu][Ee])|"+\
	"(?:[Mm][Ii][Nn][Tt][Cc][Rr][Ee][Aa][Mm])|"+\
	"(?:[Mm][Ii][Ss][Tt][Yy][Rr][Oo][Ss][Ee])|"+\
	"(?:[Mm][Oo][Cc][Cc][Aa][Ss][Ii][Nn])|"+\
	"(?:[Nn][Aa][Vv][Aa][Jj][Oo][Ww][Hh][Ii][Tt][Ee])|"+\
	"(?:[Nn][Aa][Vv][Yy])|"+\
	"(?:[Oo][Ll][Dd][Ll][Aa][Cc][Ee])|"+\
	"(?:[Oo][Ll][Ii][Vv][Ee])|"+\
	"(?:[Oo][Ll][Ii][Vv][Ee][Dd][Rr][Aa][Bb])|"+\
	"(?:[Oo][Rr][Aa][Nn][Gg][Ee])|"+\
	"(?:[Oo][Rr][Aa][Nn][Gg][Ee][Rr][Ee][Dd])|"+\
	"(?:[Oo][Rr][Cc][Hh][Ii][Dd])|"+\
	"(?:[Pp][Aa][Ll][Ee][Gg][Oo][Ll][Dd][Ee][Nn][Rr][Oo][Dd])|"+\
	"(?:[Pp][Aa][Ll][Ee][Gg][Rr][Ee][Ee][Nn])|"+\
	"(?:[Pp][Aa][Ll][Ee][Tt][Uu][Rr][Qq][Uu][Oo][Ii][Ss][Ee])|"+\
	"(?:[Pp][Aa][Ll][Ee][Vv][Ii][Oo][Ll][Ee][Tt][Rr][Ee][Dd])|"+\
	"(?:[Pp][Aa][Pp][Aa][Yy][Aa][Ww][Hh][Ii][Pp])|"+\
	"(?:[Pp][Ee][Aa][Cc][Hh][Pp][Uu][Ff][Ff])|"+\
	"(?:[Pp][Ee][Rr][Uu])|"+\
	"(?:[Pp][Ii][Nn][Kk])|"+\
	"(?:[Pp][Ll][Uu][Mm])|"+\
	"(?:[Pp][Oo][Ww][Dd][Ee][Rr][Bb][Ll][Uu][Ee])|"+\
	"(?:[Pp][Uu][Rr][Pp][Ll][Ee])|"+\
	"(?:[Rr][Ee][Dd])|"+\
	"(?:[Rr][Oo][Ss][Yy][Bb][Rr][Oo][Ww][Nn])|"+\
	"(?:[Rr][Oo][Yy][Aa][Ll][Bb][Ll][Uu][Ee])|"+\
	"(?:[Ss][Aa][Dd][Dd][Ll][Ee][Bb][Rr][Oo][Ww][Nn])|"+\
	"(?:[Ss][Aa][Ll][Mm][Oo][Nn])|"+\
	"(?:[Ss][Aa][Nn][Dd][Yy][Bb][Rr][Oo][Ww][Nn])|"+\
	"(?:[Ss][Ee][Aa][Gg][Rr][Ee][Ee][Nn])|"+\
	"(?:[Ss][Ee][Aa][Ss][Hh][Ee][Ll][Ll])|"+\
	"(?:[Ss][Ii][Ee][Nn][Nn][Aa])|"+\
	"(?:[Ss][Ii][Ll][Vv][Ee][Rr])|"+\
	"(?:[Ss][Kk][Yy][Bb][Ll][Uu][Ee])|"+\
	"(?:[Ss][Ll][Aa][Tt][Ee][Bb][Ll][Uu][Ee])|"+\
	"(?:[Ss][Ll][Aa][Tt][Ee][Gg][Rr][Aa][Yy])|"+\
	"(?:[Ss][Ll][Aa][Tt][Ee][Gg][Rr][Ee][Yy])|"+\
	"(?:[Ss][Nn][Oo][Ww])|"+\
	"(?:[Ss][Pp][Rr][Ii][Nn][Gg][Gg][Rr][Ee][Ee][Nn])|"+\
	"(?:[Ss][Tt][Ee][Ee][Ll][Bb][Ll][Uu][Ee])|"+\
	"(?:[Tt][Aa][Nn])|"+\
	"(?:[Tt][Ee][Aa][Ll])|"+\
	"(?:[Tt][Hh][Ii][Ss][Tt][Ll][Ee])|"+\
	"(?:[Tt][Oo][Mm][Aa][Tt][Oo])|"+\
	"(?:[Tt][Uu][Rr][Qq][Uu][Oo][Ii][Ss][Ee])|"+\
	"(?:[Vv][Ii][Oo][Ll][Ee][Tt])|"+\
	"(?:[Ww][Hh][Ee][Aa][Tt])|"+\
	"(?:[Ww][Hh][Ii][Tt][Ee])|"+\
	"(?:[Ww][Hh][Ii][Tt][Ee][Ss][Mm][Oo][Kk][Ee])|"+\
	"(?:[Yy][Ee][Ll][Ll][Oo][Ww])|"+\
	"(?:[Yy][Ee][Ll][Ll][Oo][Ww][Gg][Rr][Ee][Ee][Nn])|"+\
	"(?:[Tt][Rr][Aa][Nn][Ss][Pp][Aa][Rr][Ee][Nn][Tt]))"
const color_pattern : String = "(?:"+color_keyword_pattern+"|(?:#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f](?:[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])?)|(?:[Rr][Gg][Bb]\\s*\\(\\s*"+num_pattern+"%?\\s*,\\s*"+num_pattern+"%?\\s*,\\s*"+num_pattern+"%?\\s*\\))|(?:[Rr][Gg][Bb][Aa]\\s*\\(\\s*"+num_pattern+"%?\\s*,\\s*"+num_pattern+"%?\\s*,\\s*"+num_pattern+"%?\\s*,\\s*"+num_pattern+"%?\\s*\\)))"
const url_pattern : String = "(?:[Uu][Rr][Ll]\\s*\\(\\s*(?:#([^\\)]*)|\'#([^\']*)\'|\"#([^\"]*)\")\\s*\\))"
const paint_pattern : String = "(?:(?:[Nn][Oo][Nn][Ee])|"+color_pattern+"|"+url_pattern+")"
var viewBox_regex : RegEx = RegEx.new()
var alpha_regex : RegEx = RegEx.new()
var value_regex : RegEx = RegEx.new()
var path_regex : RegEx = RegEx.new()
var path_split_regex : RegEx = RegEx.new()
var num_regex : RegEx = RegEx.new()
var point_regex : RegEx = RegEx.new()
var quad_regex : RegEx = RegEx.new()
var cube_regex : RegEx = RegEx.new()
var arc_regex : RegEx = RegEx.new()
var transform_regex : RegEx = RegEx.new()
var transform_split_regex : RegEx = RegEx.new()
var points_regex : RegEx = RegEx.new()
var style_regex : RegEx = RegEx.new()
var styles_regex : RegEx = RegEx.new()
var linejoin_regex : RegEx = RegEx.new()
var linecap_regex : RegEx = RegEx.new()
var color_regex : RegEx = RegEx.new()
var url_regex : RegEx = RegEx.new()
var paint_regex : RegEx = RegEx.new()
var trim_whitespace_regex : RegEx = RegEx.new()

const color_map : Dictionary = {
	"transparent": Color(0x00000000),
	"aliceblue": Color(0xF0F8FFFF),
	"antiquewhite": Color(0xFAEBD7FF),
	"aqua": Color(0x00FFFFFF),
	"aquamarine": Color(0x7FFFD4FF),
	"azure": Color(0xF0FFFFFF),
	"beige": Color(0xF5F5DCFF),
	"bisque": Color(0xFFE4C4FF),
	"black": Color(0x000000FF),
	"blanchedalmond": Color(0xFFEBCDFF),
	"blue": Color(0x0000FFFF),
	"blueviolet": Color(0x8A2BE2FF),
	"brown": Color(0xA52A2AFF),
	"burlywood": Color(0xDEB887FF),
	"cadetblue": Color(0x5F9EA0FF),
	"chartreuse": Color(0x7FFF00FF),
	"chocolate": Color(0xD2691EFF),
	"coral": Color(0xFF7F50FF),
	"cornflowerblue": Color(0x6495EDFF),
	"cornsilk": Color(0xFFF8DCFF),
	"crimson": Color(0xDC143CFF),
	"cyan": Color(0x00FFFFFF),
	"darkblue": Color(0x00008BFF),
	"darkcyan": Color(0x008B8BFF),
	"darkgoldenrod": Color(0xB8860BFF),
	"darkgray": Color(0xA9A9A9FF),
	"darkgreen": Color(0x006400FF),
	"darkgrey": Color(0xA9A9A9FF),
	"darkkhaki": Color(0xBDB76BFF),
	"darkmagenta": Color(0x8B008BFF),
	"darkolivegreen": Color(0x556B2FFF),
	"darkorange": Color(0xFF8C00FF),
	"darkorchid": Color(0x9932CCFF),
	"darkred": Color(0x8B0000FF),
	"darksalmon": Color(0xE9967AFF),
	"darkseagreen": Color(0x8FBC8FFF),
	"darkslateblue": Color(0x483D8BFF),
	"darkslategray": Color(0x2F4F4FFF),
	"darkslategrey": Color(0x2F4F4FFF),
	"darkturquoise": Color(0x00CED1FF),
	"darkviolet": Color(0x9400D3FF),
	"deeppink": Color(0xFF1493FF),
	"deepskyblue": Color(0x00BFFFFF),
	"dimgray": Color(0x696969FF),
	"dimgrey": Color(0x696969FF),
	"dodgerblue": Color(0x1E90FFFF),
	"firebrick": Color(0xB22222FF),
	"floralwhite": Color(0xFFFAF0FF),
	"forestgreen": Color(0x228B22FF),
	"fuchsia": Color(0xFF00FFFF),
	"gainsboro": Color(0xDCDCDCFF),
	"ghostwhite": Color(0xF8F8FFFF),
	"gold": Color(0xFFD700FF),
	"goldenrod": Color(0xDAA520FF),
	"gray": Color(0x808080FF),
	"green": Color(0x008000FF),
	"greenyellow": Color(0xADFF2FFF),
	"grey": Color(0x808080FF),
	"honeydew": Color(0xF0FFF0FF),
	"hotpink": Color(0xFF69B4FF),
	"indianred": Color(0xCD5C5CFF),
	"indigo": Color(0x4B0082FF),
	"ivory": Color(0xFFFFF0FF),
	"khaki": Color(0xF0E68CFF),
	"lavender": Color(0xE6E6FAFF),
	"lavenderblush": Color(0xFFF0F5FF),
	"lawngreen": Color(0x7CFC00FF),
	"lemonchiffon": Color(0xFFFACDFF),
	"lightblue": Color(0xADD8E6FF),
	"lightcoral": Color(0xF08080FF),
	"lightcyan": Color(0xE0FFFFFF),
	"lightgoldenrodyellow": Color(0xFAFAD2FF),
	"lightgray": Color(0xD3D3D3FF),
	"lightgreen": Color(0x90EE90FF),
	"lightgrey": Color(0xD3D3D3FF),
	"lightpink": Color(0xFFB6C1FF),
	"lightsalmon": Color(0xFFA07AFF),
	"lightseagreen": Color(0x20B2AAFF),
	"lightskyblue": Color(0x87CEFAFF),
	"lightslategray": Color(0x778899FF),
	"lightslategrey": Color(0x778899FF),
	"lightsteelblue": Color(0xB0C4DEFF),
	"lightyellow": Color(0xFFFFE0FF),
	"lime": Color(0x00FF00FF),
	"limegreen": Color(0x32CD32FF),
	"linen": Color(0xFAF0E6FF),
	"magenta": Color(0xFF00FFFF),
	"maroon": Color(0x800000FF),
	"mediumaquamarine": Color(0x66CDAAFF),
	"mediumblue": Color(0x0000CDFF),
	"mediumorchid": Color(0xBA55D3FF),
	"mediumpurple": Color(0x9370DBFF),
	"mediumseagreen": Color(0x3CB371FF),
	"mediumslateblue": Color(0x7B68EEFF),
	"mediumspringgreen": Color(0x00FA9AFF),
	"mediumturquoise": Color(0x48D1CCFF),
	"mediumvioletred": Color(0xC71585FF),
	"midnightblue": Color(0x191970FF),
	"mintcream": Color(0xF5FFFAFF),
	"mistyrose": Color(0xFFE4E1FF),
	"moccasin": Color(0xFFE4B5FF),
	"navajowhite": Color(0xFFDEADFF),
	"navy": Color(0x000080FF),
	"oldlace": Color(0xFDF5E6FF),
	"olive": Color(0x808000FF),
	"olivedrab": Color(0x6B8E23FF),
	"orange": Color(0xFFA500FF),
	"orangered": Color(0xFF4500FF),
	"orchid": Color(0xDA70D6FF),
	"palegoldenrod": Color(0xEEE8AAFF),
	"palegreen": Color(0x98FB98FF),
	"paleturquoise": Color(0xAFEEEEFF),
	"palevioletred": Color(0xDB7093FF),
	"papayawhip": Color(0xFFEFD5FF),
	"peachpuff": Color(0xFFDAB9FF),
	"peru": Color(0xCD853FFF),
	"pink": Color(0xFFC0CBFF),
	"plum": Color(0xDDA0DDFF),
	"powderblue": Color(0xB0E0E6FF),
	"purple": Color(0x800080FF),
	"red": Color(0xFF0000FF),
	"rosybrown": Color(0xBC8F8FFF),
	"royalblue": Color(0x4169E1FF),
	"saddlebrown": Color(0x8B4513FF),
	"salmon": Color(0xFA8072FF),
	"sandybrown": Color(0xF4A460FF),
	"seagreen": Color(0x2E8B57FF),
	"seashell": Color(0xFFF5EEFF),
	"sienna": Color(0xA0522DFF),
	"silver": Color(0xC0C0C0FF),
	"skyblue": Color(0x87CEEBFF),
	"slateblue": Color(0x6A5ACDFF),
	"slategray": Color(0x708090FF),
	"slategrey": Color(0x708090FF),
	"snow": Color(0xFFFAFAFF),
	"springgreen": Color(0x00FF7FFF),
	"steelblue": Color(0x4682B4FF),
	"tan": Color(0xD2B48CFF),
	"teal": Color(0x008080FF),
	"thistle": Color(0xD8BFD8FF),
	"tomato": Color(0xFF6347FF),
	"turquoise": Color(0x40E0D0FF),
	"violet": Color(0xEE82EEFF),
	"wheat": Color(0xF5DEB3FF),
	"white": Color(0xFFFFFFFF),
	"whitesmoke": Color(0xF5F5F5FF),
	"yellow": Color(0xFFFF00FF),
	"yellowgreen": Color(0x9ACD32FF)
}

func _init():
	viewBox_regex.compile("^\\s*("+num_pattern+")\\s+("+num_pattern+")\\s+("+num_pattern+")\\s+("+num_pattern+")\\s*$")
	alpha_regex.compile("^\\s*("+num_pattern+"%?)\\s*$")
	value_regex.compile("^\\s*("+num_pattern+")\\s*$")
	path_regex.compile("^\\s*(?:"+path_pattern+"\\s*)*$")
	path_split_regex.compile(path_pattern)
	num_regex.compile("("+num_pattern+")")
	point_regex.compile("("+num_pattern+any_sep+num_pattern+")")
	quad_regex.compile("("+num_pattern+any_sep+num_pattern+any_sep+num_pattern+any_sep+num_pattern+")")
	cube_regex.compile("("+num_pattern+any_sep+num_pattern+any_sep+num_pattern+any_sep+num_pattern+any_sep+num_pattern+any_sep+num_pattern+")")
	arc_regex.compile("("+positive_num_pattern+any_sep+positive_num_pattern+any_sep+num_pattern+any_sep+"[01]"+any_sep+"[01]"+any_sep+num_pattern+any_sep+num_pattern+")")
	transform_regex.compile("^\\s*(?:"+transform_pattern+"\\s*)*$")
	transform_split_regex.compile(transform_pattern)
	points_regex.compile("^\\s*(?:"+point_pattern+"\\s*)*$")
	style_regex.compile(style_pattern)
	styles_regex.compile("^[\\s;]*"+style_pattern+"(?:\\s*;[\\s;]*"+style_pattern+")*[\\s;]*$")
	linejoin_regex.compile("^\\s*("+linejoin_pattern+")\\s*$")
	linecap_regex.compile("^\\s*("+linecap_pattern+")\\s*$")
	color_regex.compile("^\\s*("+color_pattern+")\\s*$")
	url_regex.compile("^\\s*"+url_pattern+"\\s*$")
	paint_regex.compile("^\\s*("+paint_pattern+")\\s*$")

func get_importer_name():
	return "vector2d.svg"

func get_visible_name():
	return "Vector2D"

func get_recognized_extensions():
	return ["svg"]

func get_save_extension():
	return "tscn"

func get_resource_type():
	return "PackedScene"

func get_preset_count():
	return 1

func get_preset_name(i):
	return "Default"

func get_import_options(i):
	return []

func get_priority() -> float:
	return 2.0

func import(source_file: String, save_path: String, options: Dictionary, platform_variants: Array, gen_files: Array) -> int:
	var xml : XMLParser = XMLParser.new()
	var err : int = xml.open(source_file)
	if err != OK:
		return err

	var scene : PackedScene = PackedScene.new()

	while xml.get_node_type() != 1:
		err = xml.read()
		if err != OK:
			return err

	if xml.get_node_name() != "svg":
		return ERR_FILE_CORRUPT

	err = _parse_svg(xml, scene, source_file.get_file().get_basename())
	if err != OK:
		return err

	var filename = save_path + "." + get_save_extension()
	return ResourceSaver.save(filename, scene)

func _parse_svg(xml : XMLParser, scene : PackedScene, name : String) -> int:
	var err : int
	var root : Node2D = Node2D.new()
	root.name = name

	var viewBox : RegExMatch = viewBox_regex.search(xml.get_named_attribute_value_safe("viewBox"))
	var width : RegExMatch = value_regex.search(xml.get_named_attribute_value_safe("width"))
	var height : RegExMatch = value_regex.search(xml.get_named_attribute_value_safe("height"))
	if viewBox:
		root.transform = root.transform.translated(Vector2(-float(viewBox.get_string(1)), -float(viewBox.get_string(2))))
		var viewBox_w : float = float(viewBox.get_string(3))
		var viewBox_h : float = float(viewBox.get_string(4))
		if !is_zero_approx(viewBox_w) && width:
			var w : float = float(width.get_string(1))
			root.transform = root.transform.scaled(Vector2(w/viewBox_w, 1.0))
		if !is_zero_approx(viewBox_h) && height:
			var h : float = float(height.get_string(1))
			root.transform = root.transform.scaled(Vector2(1.0, h/viewBox_h))

	var elements : Array = []
	var id_map : Dictionary = {}

	if !xml.is_empty():
		err = xml.read()
		if err != OK:
			return err
		while xml.get_node_type() != XMLParser.NODE_ELEMENT_END:
			if xml.get_node_type() == XMLParser.NODE_ELEMENT:
				err = _parse_element(xml, elements, id_map)
				if err != OK:
					return err
			err = xml.read()
			if err != OK:
				return err

	if xml.get_node_name() != "svg":
		return ERR_FILE_CORRUPT

	var style : Dictionary = {
		"fill": "black",
		"fill-rule": "nonzero",
		"fill-opacity": "1",
		"stroke": "none",
		"stroke-opacity": "1",
		"stroke-width": "1",
		"stroke-linecap": "butt",
		"stroke-linejoin": "miter",
		"stroke-miterlimit": "4",
		"stroke-dasharray": "none",
		"stroke-dashoffset": "0"
	}

	for element in elements:
		_expand_element(root, root, element, id_map, style)

	return scene.pack(root)

func _expand_element(parent : Node2D, root : Node2D, element : ParsedElement, id_map : Dictionary, style : Dictionary) -> void:
	if element.type < 0:
		return
	var node : Node2D
	style = _inherit_style(style, element.style)
	if element.type == 1:
		node = preload("shape.gd").new()
		parent.add_child(node)
		node.owner = root
		node.shape = element.shape
		_apply_style(node, root, id_map, style)
	else:
		node = Node2D.new()
		parent.add_child(node)
		node.owner = root
	node.name = element.name
	node.transform = element.transform
	for child in element.children:
		_expand_element(node, root, child, id_map, style)
	if element.type == 2 && id_map.has(element.link):
		_expand_element(node, root, id_map[element.link], id_map, style)

func _inherit_style(inherited_style : Dictionary, explicit_style : Dictionary) -> Dictionary:
	#TODO: Remove non-inheritable style definitions
	var style : Dictionary = inherited_style.duplicate()
	for k in explicit_style.keys():
		style[k] = explicit_style[k]
	return style

func _parse_element(xml : XMLParser, elements : Array, id_map : Dictionary) -> int:
	var element : ParsedElement = ParsedElement.new()
	elements.push_back(element)
	if xml.has_attribute("inkscape:label"):
		element.name = xml.get_named_attribute_value_safe("inkscape:label")
	elif xml.has_attribute("id"):
		element.name = xml.get_named_attribute_value_safe("id")
	else:
		element.name = xml.get_node_name()
	if xml.has_attribute("id"):
		id_map[xml.get_named_attribute_value_safe("id")] = element
	element.transform = _parse_transform(xml.get_named_attribute_value_safe("transform"))
	_parse_style(xml, element.style)
	match xml.get_node_name():
		#TODO: use element, gradient element
		"path":
			return _parse_path(xml, element)
		"rect":
			return _parse_rect(xml, element)
		"circle":
			return _parse_circle(xml, element)
		"ellipse":
			return _parse_ellipse(xml, element)
		"line":
			return _parse_line(xml, element)
		"polyline":
			return _parse_polygon(xml, element, false)
		"polygon":
			return _parse_polygon(xml, element, true)
		"g":
			return _parse_group(xml, element, id_map)
		"defs":
			element.type = -1
			return _parse_group(xml, element, id_map)
		"use":
			return _parse_use(xml, element)
		"linearGradient":
			return _parse_gradient(xml, element, false)
		"radialGradient":
			return _parse_gradient(xml, element, true)
		_:
			element.type = -1
			xml.skip_section()
			return OK

func _parse_path(xml : XMLParser, element : ParsedElement) -> int:
	element.type = 1
	element.shape = Vector2DShapeDefinition.new()
	element.shape.segments = _parse_path_def(xml.get_named_attribute_value_safe("d"))
	xml.skip_section()
	return OK

func _parse_rect(xml : XMLParser, element : ParsedElement) -> int:
	element.type = 1
	var r : Rect2 = Rect2(float(xml.get_named_attribute_value_safe("x")), float(xml.get_named_attribute_value_safe("y")), float(xml.get_named_attribute_value_safe("width")), float(xml.get_named_attribute_value_safe("height")))
	var rx : float = float(xml.get_named_attribute_value_safe("rx"))
	var ry : float = float(xml.get_named_attribute_value_safe("ry"))
	element.shape = Vector2DShapeDefinition.new()
	if rx > 0.0 && ry > 0.0:
		element.shape.segments = [[SEGMENT_TYPE.START, r.position+Vector2(rx, 0.0), 1], [SEGMENT_TYPE.LINEAR, r.position+Vector2(r.size.x-rx, 0.0)], [SEGMENT_TYPE.ARC, r.position+Vector2(r.size.x-rx, 0.0), r.position+Vector2(r.size.x-rx, ry), r.position+Vector2(r.size.x, ry), r.position+Vector2(r.size.x, ry)], [SEGMENT_TYPE.LINEAR, r.end-Vector2(0.0, ry)], [SEGMENT_TYPE.ARC, r.end-Vector2(0.0, ry), r.end-Vector2(rx, ry), r.end-Vector2(rx, 0.0), r.end-Vector2(rx, 0.0)], [SEGMENT_TYPE.LINEAR, r.position+Vector2(rx, r.size.y)], [SEGMENT_TYPE.ARC, r.position+Vector2(rx, r.size.y), r.position+Vector2(rx, r.size.y-ry), r.position+Vector2(0.0, r.size.y-ry), r.position+Vector2(0.0, r.size.y-ry)], [SEGMENT_TYPE.LINEAR, r.position+Vector2(0.0, ry)], [SEGMENT_TYPE.ARC, r.position+Vector2(0.0, ry), r.position+Vector2(rx, ry), r.position+Vector2(rx, 0.0), r.position+Vector2(rx, 0.0)]]
	else:
		element.shape.segments = [[SEGMENT_TYPE.START, r.position, 1], [SEGMENT_TYPE.LINEAR, r.position+Vector2(r.size.x, 0.0)], [SEGMENT_TYPE.LINEAR, r.end], [SEGMENT_TYPE.LINEAR, r.position+Vector2(0.0, r.size.y)]]
	xml.skip_section()
	return OK

func _parse_circle(xml : XMLParser, element : ParsedElement) -> int:
	element.type = 1
	var c : Vector2 = Vector2(float(xml.get_named_attribute_value_safe("cx")), float(xml.get_named_attribute_value_safe("cy")))
	var r : float = float(xml.get_named_attribute_value_safe("r"))
	element.shape = Vector2DShapeDefinition.new()
	element.shape.segments = [[SEGMENT_TYPE.START, c-Vector2(r, 0.0), 1], [SEGMENT_TYPE.ARC, c+Vector2(0.0, r), c, c+Vector2(r, 0.0), c+Vector2(r, 0.0)], [SEGMENT_TYPE.ARC, c-Vector2(0.0, r), c, c-Vector2(r, 0.0), c-Vector2(r, 0.0)]]
	xml.skip_section()
	return OK

func _parse_ellipse(xml : XMLParser, element : ParsedElement) -> int:
	element.type = 1
	var c : Vector2 = Vector2(float(xml.get_named_attribute_value_safe("cx")), float(xml.get_named_attribute_value_safe("cy")))
	var rx : float = float(xml.get_named_attribute_value_safe("rx"))
	var ry : float = float(xml.get_named_attribute_value_safe("ry"))
	element.shape = Vector2DShapeDefinition.new()
	element.shape.segments = [[SEGMENT_TYPE.START, c-Vector2(rx, 0.0), 1], [SEGMENT_TYPE.ARC, c+Vector2(0.0, ry), c, c+Vector2(rx, 0.0), c+Vector2(rx, 0.0)], [SEGMENT_TYPE.ARC, c+Vector2(0.0, -ry), c, c+Vector2(-rx, 0.0), c+Vector2(-rx, 0.0)]]
	xml.skip_section()
	return OK

func _parse_line(xml : XMLParser, element : ParsedElement) -> int:
	element.type = 1
	var s : Vector2 = Vector2(float(xml.get_named_attribute_value_safe("x1")), float(xml.get_named_attribute_value_safe("y1")))
	var e : Vector2 = Vector2(float(xml.get_named_attribute_value_safe("x2")), float(xml.get_named_attribute_value_safe("y2")))
	element.shape = Vector2DShapeDefinition.new()
	element.shape.segments = [[SEGMENT_TYPE.START, s, 0], [SEGMENT_TYPE.LINEAR, e]]
	xml.skip_section()
	return OK

func _parse_polygon(xml : XMLParser, element : ParsedElement, closed : bool) -> int:
	element.type = 1
	var first : bool = true
	var segments : Array = []
	var def : String = xml.get_named_attribute_value_safe("points")
	if points_regex.search(def):
		for inst in point_regex.search_all(def):
			var p : Vector2 = Vector2(float(inst.get_string(1)), float(inst.get_string(2)))
			if first:
				segments.push_back([SEGMENT_TYPE.START, p, 1 if closed else 0])
				first = false
			else:
				segments.push_back([SEGMENT_TYPE.LINEAR, p])
	element.shape = Vector2DShapeDefinition.new()
	element.shape.segments = segments
	xml.skip_section()
	return OK

func _parse_use(xml : XMLParser, element : ParsedElement) -> int:
	var href : String = xml.get_named_attribute_value_safe("href") if xml.has_attribute("href") else xml.get_named_attribute_value_safe("xlink:href")
	if href && href.substr(0, 1) == "#":
		element.type = 2
		element.link = href.substr(1)
	xml.skip_section()
	return OK

func _parse_gradient(xml : XMLParser, element : ParsedElement, radial : bool) -> int:
	element.type = -3 if radial else -2
	element.transform = _parse_transform(xml.get_named_attribute_value_safe("gradientTransform"))
	if xml.get_named_attribute_value_safe("spreadMethod") == "repeat":
		element.gradient_spread_method = 1
	elif xml.get_named_attribute_value_safe("spreadMethod") == "reflect":
		element.gradient_spread_method = 2
	if radial:
		element.gradient_point2 = Vector2(float(xml.get_named_attribute_value_safe("cx")), float(xml.get_named_attribute_value_safe("cy")))
		element.gradient_point1 = Vector2(float(xml.get_named_attribute_value_safe("fx")) if xml.has_attribute("fx") else element.gradient_point2.x, float(xml.get_named_attribute_value_safe("fy")) if xml.has_attribute("fy") else element.gradient_point2.y)
		element.gradient_radius1 = float(xml.get_named_attribute_value_safe("fr") if xml.has_attribute("fr") else 0.0)
		element.gradient_radius2 = float(xml.get_named_attribute_value_safe("r"))
	else:
		element.gradient_point1 = Vector2(float(xml.get_named_attribute_value_safe("x1")), float(xml.get_named_attribute_value_safe("y1")))
		element.gradient_point2 = Vector2(float(xml.get_named_attribute_value_safe("x2")), float(xml.get_named_attribute_value_safe("y2")))

	var colors : PoolColorArray = PoolColorArray()
	var offsets : PoolRealArray = PoolRealArray()

	var href : String = xml.get_named_attribute_value_safe("href") if xml.has_attribute("href") else xml.get_named_attribute_value_safe("xlink:href")
	if href && href.substr(0, 1) == "#":
		element.link = href.substr(1)

	var err : int

	var name : String = xml.get_node_name()

	if !xml.is_empty():
		err = xml.read()
		if err != OK:
			return err
		while xml.get_node_type() != XMLParser.NODE_ELEMENT_END:
			if xml.get_node_type() == XMLParser.NODE_ELEMENT:
				if xml.get_node_name() == "stop":
					var styles : Dictionary = {
						"stop-color": "black",
						"stop-opacity": ""
					}
					_parse_style(xml, styles)
					var color : Color = _parse_color(styles["stop-color"])
					var offset : float = 0.0
					var m : RegExMatch
					m = alpha_regex.search(xml.get_named_attribute_value_safe("offset"))
					if m:
						offset = float(m.get_string(1))*0.01
					m = alpha_regex.search(styles["stop-opacity"])
					if m:
						color.a = color.a*float(m.get_string(1))
					offsets.append(offset)
					colors.append(color)
				xml.skip_section()
			err = xml.read()
			if err != OK:
				return err

	element.gradient = Gradient.new()
	element.gradient.colors = colors
	element.gradient.offsets = offsets

	if xml.get_node_name() != name:
		return ERR_FILE_CORRUPT
	return OK

func _parse_group(xml : XMLParser, element : ParsedElement, id_map : Dictionary) -> int:
	var err : int

	var name : String = xml.get_node_name()

	if !xml.is_empty():
		err = xml.read()
		if err != OK:
			return err
		while xml.get_node_type() != XMLParser.NODE_ELEMENT_END:
			if xml.get_node_type() == XMLParser.NODE_ELEMENT:
				err = _parse_element(xml, element.children, id_map)
				if err != OK:
					return err
			err = xml.read()
			if err != OK:
				return err

	if xml.get_node_name() != name:
		return ERR_FILE_CORRUPT
	return OK

func _parse_path_def(def : String) -> Array:
	var c : Vector2 = Vector2.ZERO
	var q : Vector2 = Vector2.ZERO
	var p : Vector2 = Vector2.ZERO
	var s : Array = []
	var segments : Array = []
	if path_regex.search(def):
		for cmd in path_split_regex.search_all(def):
			match cmd.get_string(0)[0]:
				'A':
					c = Vector2.ZERO
					q = Vector2.ZERO
					for inst in arc_regex.search_all(cmd.get_string(0)):
						var e : Vector2 = Vector2(float(inst.get_string(6)), float(inst.get_string(7)))
						var r : Vector2 = Vector2(float(inst.get_string(1)), float(inst.get_string(2)))
						var a : float = float(inst.get_string(3))*(PI/180.0)
						var t : Vector2 = 0.5*(e-p).rotated(-a)
						var dc : float = r.x*r.x*t.y*t.y+r.y*r.y*t.x*t.x
						if !is_zero_approx(dc):
							dc = (r.x*r.x*r.y*r.y-r.x*r.x*t.y*t.y-r.y*r.y*t.x*t.x)/dc
							if dc > 0.0:
								dc = sqrt(dc)
							else:
								dc = 0.0
						else:
							dc = 0.0
						if inst.get_string(4) != inst.get_string(5):
							dc = -dc
						var ac : Vector2 = Vector2(dc*r.x*t.y/r.y, -dc*r.y*t.x/r.x).rotated(a)+0.5*(p+e)
						var rx : Vector2 = ac+r.x*Vector2.RIGHT.rotated(a)
						var ry : Vector2 = ac+r.y*(Vector2.UP if inst.get_string(5) == '0' else Vector2.DOWN).rotated(a)
						segments.push_back([SEGMENT_TYPE.ARC, rx, ac, ry, e])
						p = e
				'a':
					c = Vector2.ZERO
					q = Vector2.ZERO
					for inst in arc_regex.search_all(cmd.get_string(0)):
						var e : Vector2 = p+Vector2(float(inst.get_string(6)), float(inst.get_string(7)))
						var r : Vector2 = Vector2(float(inst.get_string(1)), float(inst.get_string(2)))
						var a : float = float(inst.get_string(3))*(PI/180.0)
						var t : Vector2 = 0.5*(e-p).rotated(-a)
						var dc : float = r.x*r.x*t.y*t.y+r.y*r.y*t.x*t.x
						if !is_zero_approx(dc):
							dc = (r.x*r.x*r.y*r.y-r.x*r.x*t.y*t.y-r.y*r.y*t.x*t.x)/dc
							if dc > 0.0:
								dc = sqrt(dc)
							else:
								dc = 0.0
						else:
							dc = 0.0
						if inst.get_string(4) != inst.get_string(5):
							dc = -dc
						var ac : Vector2 = Vector2(dc*r.x*t.y/r.y, -dc*r.y*t.x/r.x).rotated(a)+0.5*(p+e)
						var rx : Vector2 = ac+r.x*Vector2.RIGHT.rotated(a)
						var ry : Vector2 = ac+r.y*(Vector2.UP if inst.get_string(5) == '0' else Vector2.DOWN).rotated(a)
						segments.push_back([SEGMENT_TYPE.ARC, rx, ac, ry, e])
						p = e
				'C':
					q = Vector2.ZERO
					for inst in cube_regex.search_all(cmd.get_string(0)):
						var e : Vector2 = Vector2(float(inst.get_string(5)), float(inst.get_string(6)))
						c = Vector2(float(inst.get_string(3)), float(inst.get_string(4)))
						segments.push_back([SEGMENT_TYPE.CUBIC, Vector2(float(inst.get_string(1)), float(inst.get_string(2))), c, e])
						p = e
						c -= p
				'c':
					q = Vector2.ZERO
					for inst in cube_regex.search_all(cmd.get_string(0)):
						var e : Vector2 = p+Vector2(float(inst.get_string(5)), float(inst.get_string(6)))
						c = p+Vector2(float(inst.get_string(3)), float(inst.get_string(4)))
						segments.push_back([SEGMENT_TYPE.CUBIC, p+Vector2(float(inst.get_string(1)), float(inst.get_string(2))), c, e])
						p = e
						c -= p
				'H':
					c = Vector2.ZERO
					q = Vector2.ZERO
					for inst in num_regex.search_all(cmd.get_string(0)):
						p.x = float(inst.get_string(1))
						segments.push_back([SEGMENT_TYPE.LINEAR, p])
				'h':
					c = Vector2.ZERO
					q = Vector2.ZERO
					for inst in num_regex.search_all(cmd.get_string(0)):
						p.x += float(inst.get_string(1))
						segments.push_back([SEGMENT_TYPE.LINEAR, p])
				'L':
					c = Vector2.ZERO
					q = Vector2.ZERO
					for inst in point_regex.search_all(cmd.get_string(0)):
						p = Vector2(float(inst.get_string(1)), float(inst.get_string(2)))
						segments.push_back([SEGMENT_TYPE.LINEAR, p])
				'l':
					c = Vector2.ZERO
					q = Vector2.ZERO
					for inst in point_regex.search_all(cmd.get_string(0)):
						p += Vector2(float(inst.get_string(1)), float(inst.get_string(2)))
						segments.push_back([SEGMENT_TYPE.LINEAR, p])
				'M':
					c = Vector2.ZERO
					q = Vector2.ZERO
					var first : bool = true
					for inst in point_regex.search_all(cmd.get_string(0)):
						p = Vector2(float(inst.get_string(1)), float(inst.get_string(2)))
						if first:
							s = [SEGMENT_TYPE.START, p, 0]
							segments.push_back(s)
							first = false
						else:
							segments.push_back([SEGMENT_TYPE.LINEAR, p])
				'm':
					c = Vector2.ZERO
					q = Vector2.ZERO
					var first : bool = true
					for inst in point_regex.search_all(cmd.get_string(0)):
						p += Vector2(float(inst.get_string(1)), float(inst.get_string(2)))
						if first:
							s = [SEGMENT_TYPE.START, p, 0]
							segments.push_back(s)
							first = false
						else:
							segments.push_back([SEGMENT_TYPE.LINEAR, p])
				'Q':
					c = Vector2.ZERO
					for inst in quad_regex.search_all(cmd.get_string(0)):
						var e : Vector2 = Vector2(float(inst.get_string(3)), float(inst.get_string(4)))
						q = Vector2(float(inst.get_string(1)), float(inst.get_string(2)))
						segments.push_back([SEGMENT_TYPE.QUADRIC, q, e])
						p = e
						q -= p
				'q':
					c = Vector2.ZERO
					for inst in quad_regex.search_all(cmd.get_string(0)):
						var e : Vector2 = p+Vector2(float(inst.get_string(3)), float(inst.get_string(4)))
						q = p+Vector2(float(inst.get_string(1)), float(inst.get_string(2)))
						segments.push_back([SEGMENT_TYPE.QUADRIC, q, e])
						p = e
						q -= p
				'S':
					q = Vector2.ZERO
					for inst in quad_regex.search_all(cmd.get_string(0)):
						var e : Vector2 = Vector2(float(inst.get_string(3)), float(inst.get_string(4)))
						var t : Vector2 = p-c
						c = Vector2(float(inst.get_string(1)), float(inst.get_string(2)))
						segments.push_back([SEGMENT_TYPE.CUBIC, t, c, e])
						p = e
						c -= p
				's':
					q = Vector2.ZERO
					for inst in quad_regex.search_all(cmd.get_string(0)):
						var e : Vector2 = p+Vector2(float(inst.get_string(3)), float(inst.get_string(4)))
						var t : Vector2 = p-c
						c = p+Vector2(float(inst.get_string(1)), float(inst.get_string(2)))
						segments.push_back([SEGMENT_TYPE.CUBIC, t, c, e])
						p = e
						c -= p
				'T':
					c = Vector2.ZERO
					for inst in point_regex.search_all(cmd.get_string(0)):
						var e : Vector2 = Vector2(float(inst.get_string(1)), float(inst.get_string(2)))
						q = p-q
						segments.push_back([SEGMENT_TYPE.QUADRIC, q, e])
						p = e
						q -= p
				't':
					c = Vector2.ZERO
					for inst in point_regex.search_all(cmd.get_string(0)):
						var e : Vector2 = p+Vector2(float(inst.get_string(1)), float(inst.get_string(2)))
						q = p-q
						segments.push_back([SEGMENT_TYPE.QUADRIC, q, e])
						p = e
						q -= p
				'V':
					c = Vector2.ZERO
					q = Vector2.ZERO
					for inst in num_regex.search_all(cmd.get_string(0)):
						p.y = float(inst.get_string(1))
						segments.push_back([SEGMENT_TYPE.LINEAR, p])
				'v':
					c = Vector2.ZERO
					q = Vector2.ZERO
					for inst in num_regex.search_all(cmd.get_string(0)):
						p.y += float(inst.get_string(1))
						segments.push_back([SEGMENT_TYPE.LINEAR, p])
				'Z', 'z':
					if s.size():
						s[2] = 1
						c = Vector2.ZERO
						q = Vector2.ZERO
						p = s[1]
	return segments

func _parse_transform(def : String) -> Transform2D:
	var ret : Transform2D = Transform2D.IDENTITY
	if transform_regex.search(def):
		for cmd in transform_split_regex.search_all(def):
			if cmd.get_string(1):
				ret *= Transform2D(Vector2(_extract_number(cmd.get_string(1)), _extract_number(cmd.get_string(2))), Vector2(_extract_number(cmd.get_string(3)), _extract_number(cmd.get_string(4))), Vector2(_extract_number(cmd.get_string(5)), _extract_number(cmd.get_string(6))))
			elif cmd.get_string(7):
				if cmd.get_string(8):
					ret *= Transform2D.IDENTITY.translated(Vector2(_extract_number(cmd.get_string(7)), _extract_number(cmd.get_string(8))))
				else:
					ret *= Transform2D.IDENTITY.translated(Vector2(_extract_number(cmd.get_string(7)), 0.0))
			elif cmd.get_string(9):
				if cmd.get_string(10):
					ret *= Transform2D.IDENTITY.scaled(Vector2(_extract_number(cmd.get_string(9)), _extract_number(cmd.get_string(10))))
				else:
					ret *= Transform2D.IDENTITY.scaled(Vector2(_extract_number(cmd.get_string(9)), _extract_number(cmd.get_string(9))))
			elif cmd.get_string(11):
				if cmd.get_string(13):
					ret *= Transform2D(_extract_number(cmd.get_string(9))*(PI/180.0), Vector2(-_extract_number(cmd.get_string(12)), -_extract_number(cmd.get_string(13)))).translated(Vector2(_extract_number(cmd.get_string(12)), _extract_number(cmd.get_string(13))))
				elif cmd.get_string(12):
					ret *= Transform2D(_extract_number(cmd.get_string(9))*(PI/180.0), Vector2(-_extract_number(cmd.get_string(12)), 0.0)).translated(Vector2(_extract_number(cmd.get_string(12)), 0.0))
				else:
					ret *= Transform2D(_extract_number(cmd.get_string(9))*(PI/180.0), Vector2.ZERO)
			elif cmd.get_string(14):
				ret *= Transform2D(Vector2.RIGHT, Vector2(tan(_extract_number(cmd.get_string(14))*(PI/180.0)), 1.0), Vector2.ZERO)
			elif cmd.get_string(15):
				ret *= Transform2D(Vector2(1.0, tan(_extract_number(cmd.get_string(15)))*(PI/180.0)), Vector2.DOWN, Vector2.ZERO)
	return ret

func _extract_number(def : String) -> float:
	for num in num_regex.search_all(def):
		return float(num.get_string(0))
	return 0.0
	

func _parse_style(xml : XMLParser, styles : Dictionary) -> void:
	var m : RegExMatch
	m = paint_regex.search(xml.get_named_attribute_value_safe("fill"))
	if m:
		styles["fill"] = m.get_string(1)
	m = paint_regex.search(xml.get_named_attribute_value_safe("stroke"))
	if m:
		styles["stroke"] = m.get_string(1)
	m = color_regex.search(xml.get_named_attribute_value_safe("stop-color"))
	if m:
		styles["stop-color"] = m.get_string(1)
	m = alpha_regex.search(xml.get_named_attribute_value_safe("fill-opacity"))
	if m:
		styles["fill-opacity"] = m.get_string(1)
	m = alpha_regex.search(xml.get_named_attribute_value_safe("stroke-opacity"))
	if m:
		styles["stroke-opacity"] = m.get_string(1)
	m = alpha_regex.search(xml.get_named_attribute_value_safe("stop-opacity"))
	if m:
		styles["stop-opacity"] = m.get_string(1)
	m = value_regex.search(xml.get_named_attribute_value_safe("stroke-width"))
	if m:
		styles["stroke-width"] = m.get_string(1)
	m = value_regex.search(xml.get_named_attribute_value_safe("stroke-miterlimit"))
	if m:
		styles["stroke-miterlimit"] = m.get_string(1)
	m = linejoin_regex.search(xml.get_named_attribute_value_safe("stroke-linejoin"))
	if m:
		styles["stroke-linejoin"] = m.get_string(1)
	m = linecap_regex.search(xml.get_named_attribute_value_safe("stroke-linecap"))
	if m:
		styles["stroke-linecap"] = m.get_string(1)
	if styles_regex.search(xml.get_named_attribute_value_safe("style")):
		for style in style_regex.search_all(xml.get_named_attribute_value_safe("style")):
			match style.get_string(1).to_lower():
				"fill", "stroke":
					m = paint_regex.search(style.get_string(2))
					if m:
						styles[style.get_string(1).to_lower()] = m.get_string(1)
				"stop-color":
					m = color_regex.search(style.get_string(2))
					if m:
						styles[style.get_string(1).to_lower()] = m.get_string(1)
				"fill-opacity", "stroke-opacity", "stop-opacity":
					m = alpha_regex.search(style.get_string(2))
					if m:
						styles[style.get_string(1).to_lower()] = m.get_string(1)
				"stroke-width", "stroke-miterlimit":
					m = value_regex.search(style.get_string(2))
					if m:
						styles[style.get_string(1).to_lower()] = m.get_string(1)
				"stroke-linejoin":
					m = linejoin_regex.search(style.get_string(2))
					if m:
						styles[style.get_string(1).to_lower()] = m.get_string(1)
				"stroke-linecap":
					m = linecap_regex.search(style.get_string(2))
					if m:
						styles[style.get_string(1).to_lower()] = m.get_string(1)
	#TODO: Parse style, fill, stroke, and other related attributes

func _apply_style(parent : Node2D, root : Node2D, id_map : Dictionary, styles : Dictionary):
	if styles["fill"].to_lower() != "none":
		var elem : Node2D = preload("fill.gd").new()
		elem.name = "fill"
		parent.add_child(elem)
		elem.owner = root
		var m : RegExMatch = url_regex.search(styles["fill"])
		if m:
			if id_map.has(m.get_string(1)):
				_apply_gradient(elem, id_map[m.get_string(1)], id_map)
			elif id_map.has(m.get_string(2)):
				_apply_gradient(elem, id_map[m.get_string(2)], id_map)
			elif id_map.has(m.get_string(3)):
				_apply_gradient(elem, id_map[m.get_string(3)], id_map)
		else:
			elem.color = _parse_color(styles["fill"])
		#TODO: Other properties
	if styles["stroke"].to_lower() != "none":
		var elem1 : Node2D = preload("stroke.gd").new()
		elem1.name = "stroke"
		parent.add_child(elem1)
		elem1.owner = root
		elem1.stroke_width = float(styles["stroke-width"])
		elem1.miter_limit = float(styles["stroke-miterlimit"])
		match styles["stroke-linejoin"]:
			"arcs":
				elem1.cap_type = 0
			"bevel":
				elem1.cap_type = 1
			"miter-clip":
				elem1.cap_type = 3
			"round":
				elem1.cap_type = 4
		match styles["stroke-linecap"]:
			"round":
				elem1.cap_type = 1
			"square":
				elem1.cap_type = 2
		#TODO: Other properties
		var elem2 : Node2D = preload("fill.gd").new()
		elem2.name = "color"
		elem1.add_child(elem2)
		elem2.owner = root
		var m : RegExMatch = url_regex.search(styles["stroke"])
		if m:
			if id_map.has(m.get_string(1)):
				_apply_gradient(elem2, id_map[m.get_string(1)], id_map)
			elif id_map.has(m.get_string(2)):
				_apply_gradient(elem2, id_map[m.get_string(2)], id_map)
			elif id_map.has(m.get_string(3)):
				_apply_gradient(elem2, id_map[m.get_string(3)], id_map)
		else:
			elem2.color = _parse_color(styles["stroke"])
		#TODO: Other properties

func _apply_gradient(elem : Node2D, gradient : ParsedElement, id_map : Dictionary):
	if gradient.type == -2:
		elem.paint_type = 1
	elif gradient.type == -3:
		elem.paint_type = 2
	else:
		return
	elem.gradient_point1 = gradient.gradient_point1
	elem.gradient_point2 = gradient.gradient_point2
	elem.gradient_radius1 = gradient.gradient_radius1
	elem.gradient_radius2 = gradient.gradient_radius2
	elem.gradient_spread_method = gradient.gradient_spread_method
	elem.gradient_transform = gradient.transform
	while gradient.link && id_map.has(gradient.link) && id_map[gradient.link].type == gradient.type:
		gradient = id_map[gradient.link]
	elem.gradient = gradient.gradient

func _parse_color(def : String) -> Color:
	if def.to_lower() in color_map:
		return color_map[def.to_lower()]
	if def[0] == "#":
		if def.length() == 4:
			def = def[0]+def[1]+def[1]+def[2]+def[2]+def[3]+def[3]
		return Color(def)
	#TODO: Decode rgb and rgba
	return Color(0xFF000000)

class ParsedElement:
	var name : String = ""
	var type : int = 0
	var children : Array = []
	var style : Dictionary = {}
	var transform : Transform2D = Transform2D.IDENTITY
	var link : String = ""
	var shape : Vector2DShapeDefinition = null
	var gradient : Gradient = null
	var gradient_point1 : Vector2 = Vector2.ZERO
	var gradient_point2 : Vector2 = Vector2.ZERO
	var gradient_radius1 : float = 0.0
	var gradient_radius2 : float = 0.0
	var gradient_spread_method : int
