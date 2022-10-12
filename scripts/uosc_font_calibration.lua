local assdraw = require('mp.assdraw')
local opt = require('mp.options')
local utils = require('mp.utils')

local options = {
	timeline_style = 'line',
	timeline_line_width = 2,
	timeline_line_width_fullscreen = 3,
	timeline_line_width_minimized_scale = 10,
	timeline_size_min = 2,
	timeline_size_max = 40,
	timeline_size_min_fullscreen = 0,
	timeline_size_max_fullscreen = 60,
	timeline_start_hidden = false,
	timeline_persistency = 'paused',
	timeline_opacity = 0.9,
	timeline_border = 1,
	timeline_step = 5,
	timeline_chapters_opacity = 0.8,

	controls = 'menu,gap,subtitles,<has_many_audio>audio,<has_many_video>video,<has_many_edition>editions,<stream>stream-quality,gap,space,speed,space,shuffle,loop-playlist,loop-file,gap,prev,items,next,gap,fullscreen',
	controls_size = 32,
	controls_size_fullscreen = 40,
	controls_margin = 8,
	controls_spacing = 2,
	controls_persistency = '',

	volume = 'right',
	volume_size = 40,
	volume_size_fullscreen = 52,
	volume_persistency = '',
	volume_opacity = 0.9,
	volume_border = 1,
	volume_step = 1,

	speed_persistency = '',
	speed_opacity = 0.6,
	speed_step = 0.1,
	speed_step_is_factor = false,

	menu_item_height = 36,
	menu_item_height_fullscreen = 50,
	menu_min_width = 260,
	menu_min_width_fullscreen = 360,
	menu_opacity = 1,
	menu_parent_opacity = 0.4,

	top_bar = 'no-border',
	top_bar_size = 40,
	top_bar_size_fullscreen = 46,
	top_bar_persistency = '',
	top_bar_controls = true,
	top_bar_title = true,
	top_bar_title_opacity = 0.8,

	window_border_size = 1,
	window_border_opacity = 0.8,

	autoload = false,
	shuffle = false,

	ui_scale = 1,
	font_scale = 1,
	text_border = 1.2,
	pause_on_click_shorter_than = 0, -- deprecated by below
	click_threshold = 0,
	click_command = 'cycle pause; script-binding uosc/flash-pause-indicator',
	flash_duration = 1000,
	proximity_in = 40,
	proximity_out = 120,
	foreground = 'ffffff',
	foreground_text = '000000',
	background = '000000',
	background_text = 'ffffff',
	total_time = false,
	time_precision = 0,
	font_bold = false,
	autohide = false,
	buffered_time_threshold = 60,
	pause_indicator = 'flash',
	curtain_opacity = 0.5,
	stream_quality_options = '4320,2160,1440,1080,720,480,360,240,144',
	media_types = '3g2,3gp,aac,aiff,ape,apng,asf,au,avi,avif,bmp,dsf,f4v,flac,flv,gif,h264,h265,j2k,jp2,jfif,jpeg,jpg,jxl,m2ts,m4a,m4v,mid,midi,mj2,mka,mkv,mov,mp3,mp4,mp4a,mp4v,mpeg,mpg,oga,ogg,ogm,ogv,opus,png,rm,rmvb,spx,svg,tak,tga,tta,tif,tiff,ts,vob,wav,weba,webm,webp,wma,wmv,wv,y4m',
	subtitle_types = 'aqt,ass,gsub,idx,jss,lrc,mks,pgs,pjs,psb,rt,slt,smi,sub,sup,srt,ssa,ssf,ttxt,txt,usf,vt,vtt',
	font_height_to_letter_width_ratio = 0.5,
	default_directory = '~/',
	chapter_ranges = 'openings:30abf964,endings:30abf964,ads:c54e4e80',
	chapter_range_patterns = 'openings:オープニング;endings:エンディング',
}
opt.read_options(options, 'uosc')

local config = {
	-- sets max rendering frequency in case the
	-- native rendering frequency could not be detected
	font = mp.get_property('options/osd-font'),
}

---@param number number
function round(number) return math.floor(number + 0.5) end

---@param min number
---@param value number
---@param max number
function clamp(min, value, max) return math.max(min, math.min(value, max)) end

---@param rgba string `rrggbb` or `rrggbbaa` hex string.
function serialize_rgba(rgba)
	local a = rgba:sub(7, 8)
	return {
		color = rgba:sub(5, 6) .. rgba:sub(3, 4) .. rgba:sub(1, 2),
		opacity = clamp(0, tonumber(#a == 2 and a or 'ff', 16) / 255, 1),
	}
end

-- Color shorthands
local fg, bg = serialize_rgba(options.foreground).color, serialize_rgba(options.background).color
local fgt, bgt = serialize_rgba(options.foreground_text).color, serialize_rgba(options.background_text).color

---@param itable table
---@param compare fun(value: any, index: number)
---@param from_end? boolean Search from the end of the table.
---@return number|nil index
---@return any|nil value
function itable_find(itable, compare, from_end)
	local from, to, step = from_end and #itable or 1, from_end and 1 or #itable, from_end and -1 or 1
	for index = from, to, step do
		if compare(itable[index], index) then return index, itable[index] end
	end
end

---@param itable table
---@param decider fun(value: any, index: number)
function itable_filter(itable, decider)
	local filtered = {}
	for index, value in ipairs(itable) do
		if decider(value, index) then filtered[#filtered + 1] = value end
	end
	return filtered
end

---@param opacity number 0-1
function opacity_to_alpha(opacity)
	return 255 - math.ceil(255 * opacity)
end

local ass_mt = getmetatable(assdraw.ass_new())

-- Text
-- Named `txt` because `ass.text` is a value.
---@param x number
---@param y number
---@param align number
---@param value string|number
---@param opts {size: number; font?: string; color?: string; bold?: boolean; italic?: boolean; border?: number; border_color?: string; shadow?: number; shadow_color?: string; rotate?: number; wrap?: number; opacity?: number; clip?: string}
function ass_mt:txt(x, y, align, value, opts)
	local border_size = opts.border or 0
	local shadow_size = opts.shadow or 0
	local tags = '\\pos(' .. x .. ',' .. y .. ')\\rDefault\\an' .. align .. '\\blur0'
	-- font
	tags = tags .. '\\fn' .. (opts.font or config.font)
	-- font size
	tags = tags .. '\\fs' .. opts.size
	-- bold
	if opts.bold or (opts.bold == nil and options.font_bold) then tags = tags .. '\\b1' end
	-- italic
	if opts.italic then tags = tags .. '\\i1' end
	-- rotate
	if opts.rotate then tags = tags .. '\\frz' .. opts.rotate end
	-- wrap
	if opts.wrap then tags = tags .. '\\q' .. opts.wrap end
	-- border
	tags = tags .. '\\bord' .. border_size
	-- shadow
	tags = tags .. '\\shad' .. shadow_size
	-- colors
	tags = tags .. '\\1c&H' .. (opts.color or bgt)
	if border_size > 0 then tags = tags .. '\\3c&H' .. (opts.border_color or bg) end
	if shadow_size > 0 then tags = tags .. '\\4c&H' .. (opts.shadow_color or bg) end
	-- opacity
	if opts.opacity then tags = tags .. string.format('\\alpha&H%X&', opacity_to_alpha(opts.opacity)) end
	-- clip
	if opts.clip then tags = tags .. opts.clip end
	-- render
	self:new_event()
	self.text = self.text .. '{' .. tags .. '}' .. value
end

---@alias CodePointRange {[1]: integer; [2]: integer}
---@alias UnicodeBlock {[1]: CodePointRange; [2]: string}

-- https://en.wikipedia.org/wiki/Unicode_block
---@type UnicodeBlock[]
unicode_blocks = {
	{{0, 127}, "Basic Latin[g]"}, -- 0 BMP	Latin (52 characters), Common (76 characters)
	{{128, 255}, "Latin-1 Supplement[h]"}, -- 0 BMP	Latin (64 characters), Common (64 characters)
	{{256, 383}, "Latin Extended-A"}, -- 0 BMP	Latin
	{{384, 591}, "Latin Extended-B"}, -- 0 BMP	Latin
	{{592, 687}, "IPA Extensions"}, -- 0 BMP	Latin
	{{688, 767}, "Spacing Modifier Letters"}, -- 0 BMP	Bopomofo (2 characters), Latin (14 characters), Common (64 characters)
	{{768, 879}, "Combining Diacritical Marks"}, -- 0 BMP	Inherited
	{{880, 1023}, "Greek and Coptic"}, -- 0 BMP	Coptic (14 characters), Greek (117 characters), Common (4 characters)
	{{1024, 1279}, "Cyrillic"}, -- 0 BMP	Cyrillic (254 characters), Inherited (2 characters)
	{{1280, 1327}, "Cyrillic Supplement"}, -- 0 BMP	Cyrillic
	{{1328, 1423}, "Armenian"}, -- 0 BMP	Armenian
	{{1424, 1535}, "Hebrew"}, -- 0 BMP	Hebrew
	{{1536, 1791}, "Arabic"}, -- 0 BMP	Arabic (238 characters), Common (6 characters), Inherited (12 characters)
	{{1792, 1871}, "Syriac"}, -- 0 BMP	Syriac
	{{1872, 1919}, "Arabic Supplement"}, -- 0 BMP	Arabic
	{{1920, 1983}, "Thaana"}, -- 0 BMP	Thaana
	{{1984, 2047}, "NKo"}, -- 0 BMP	Nko
	{{2048, 2111}, "Samaritan"}, -- 0 BMP	Samaritan
	{{2112, 2143}, "Mandaic"}, -- 0 BMP	Mandaic
	{{2144, 2159}, "Syriac Supplement"}, -- 0 BMP	Syriac
	{{2160, 2207}, "Arabic Extended-B"}, -- 0 BMP	Arabic
	{{2208, 2303}, "Arabic Extended-A"}, -- 0 BMP	Arabic (95 characters), Common (1 character)
	{{2304, 2431}, "Devanagari"}, -- 0 BMP	Devanagari (122 characters), Common (2 characters), Inherited (4 characters)
	{{2432, 2559}, "Bengali"}, -- 0 BMP	Bengali
	{{2560, 2687}, "Gurmukhi"}, -- 0 BMP	Gurmukhi
	{{2688, 2815}, "Gujarati"}, -- 0 BMP	Gujarati
	{{2816, 2943}, "Oriya"}, -- 0 BMP	Oriya
	{{2944, 3071}, "Tamil"}, -- 0 BMP	Tamil
	{{3072, 3199}, "Telugu"}, -- 0 BMP	Telugu
	{{3200, 3327}, "Kannada"}, -- 0 BMP	Kannada
	{{3328, 3455}, "Malayalam"}, -- 0 BMP	Malayalam
	{{3456, 3583}, "Sinhala"}, -- 0 BMP	Sinhala
	{{3584, 3711}, "Thai"}, -- 0 BMP	Thai (86 characters), Common (1 character)
	{{3712, 3839}, "Lao"}, -- 0 BMP	Lao
	{{3840, 4095}, "Tibetan"}, -- 0 BMP	Tibetan (207 characters), Common (4 characters)
	{{4096, 4255}, "Myanmar"}, -- 0 BMP	Myanmar
	{{4256, 4351}, "Georgian"}, -- 0 BMP	Georgian (87 characters), Common (1 character)
	{{4352, 4607}, "Hangul Jamo"}, -- 0 BMP	Hangul
	{{4608, 4991}, "Ethiopic"}, -- 0 BMP	Ethiopic
	{{4992, 5023}, "Ethiopic Supplement"}, -- 0 BMP	Ethiopic
	{{5024, 5119}, "Cherokee"}, -- 0 BMP	Cherokee
	{{5120, 5759}, "Unified Canadian Aboriginal Syllabics"}, -- 0 BMP	Canadian Aboriginal
	{{5760, 5791}, "Ogham"}, -- 0 BMP	Ogham
	{{5792, 5887}, "Runic"}, -- 0 BMP	Runic (86 characters), Common (3 characters)
	{{5888, 5919}, "Tagalog"}, -- 0 BMP	Tagalog
	{{5920, 5951}, "Hanunoo"}, -- 0 BMP	Hanunoo (21 characters), Common (2 characters)
	{{5952, 5983}, "Buhid"}, -- 0 BMP	Buhid
	{{5984, 6015}, "Tagbanwa"}, -- 0 BMP	Tagbanwa
	{{6016, 6143}, "Khmer"}, -- 0 BMP	Khmer
	{{6144, 6319}, "Mongolian"}, -- 0 BMP	Mongolian (155 characters), Common (3 characters)
	{{6320, 6399}, "Unified Canadian Aboriginal Syllabics Extended"}, -- 0 BMP	Canadian Aboriginal
	{{6400, 6479}, "Limbu"}, -- 0 BMP	Limbu
	{{6480, 6527}, "Tai Le"}, -- 0 BMP	Tai Le
	{{6528, 6623}, "New Tai Lue"}, -- 0 BMP	New Tai Lue
	{{6624, 6655}, "Khmer Symbols"}, -- 0 BMP	Khmer
	{{6656, 6687}, "Buginese"}, -- 0 BMP	Buginese
	{{6688, 6831}, "Tai Tham"}, -- 0 BMP	Tai Tham
	{{6832, 6911}, "Combining Diacritical Marks Extended"}, -- 0 BMP	Inherited
	{{6912, 7039}, "Balinese"}, -- 0 BMP	Balinese
	{{7040, 7103}, "Sundanese"}, -- 0 BMP	Sundanese
	{{7104, 7167}, "Batak"}, -- 0 BMP	Batak
	{{7168, 7247}, "Lepcha"}, -- 0 BMP	Lepcha
	{{7248, 7295}, "Ol Chiki"}, -- 0 BMP	Ol Chiki
	{{7296, 7311}, "Cyrillic Extended-C"}, -- 0 BMP	Cyrillic
	{{7312, 7359}, "Georgian Extended"}, -- 0 BMP	Georgian
	{{7360, 7375}, "Sundanese Supplement"}, -- 0 BMP	Sundanese
	{{7376, 7423}, "Vedic Extensions"}, -- 0 BMP	Common (16 characters), Inherited (27 characters)
	{{7424, 7551}, "Phonetic Extensions"}, -- 0 BMP	Cyrillic (2 characters), Greek (15 characters), Latin (111 characters)
	{{7552, 7615}, "Phonetic Extensions Supplement"}, -- 0 BMP	Greek (1 character), Latin (63 characters)
	{{7616, 7679}, "Combining Diacritical Marks Supplement"}, -- 0 BMP	Inherited
	{{7680, 7935}, "Latin Extended Additional"}, -- 0 BMP	Latin
	{{7936, 8191}, "Greek Extended"}, -- 0 BMP	Greek
	{{8192, 8303}, "General Punctuation"}, -- 0 BMP	Common (109 characters), Inherited (2 characters)
	{{8304, 8351}, "Superscripts and Subscripts"}, -- 0 BMP	Latin (15 characters), Common (27 characters)
	{{8352, 8399}, "Currency Symbols"}, -- 0 BMP	Common
	{{8400, 8447}, "Combining Diacritical Marks for Symbols"}, -- 0 BMP	Inherited
	{{8448, 8527}, "Letterlike Symbols"}, -- 0 BMP	Greek (1 character), Latin (4 characters), Common (75 characters)
	{{8528, 8591}, "Number Forms"}, -- 0 BMP	Latin (41 characters), Common (19 characters)
	{{8592, 8703}, "Arrows"}, -- 0 BMP	Common
	{{8704, 8959}, "Mathematical Operators"}, -- 0 BMP	Common
	{{8960, 9215}, "Miscellaneous Technical"}, -- 0 BMP	Common
	{{9216, 9279}, "Control Pictures"}, -- 0 BMP	Common
	{{9280, 9311}, "Optical Character Recognition"}, -- 0 BMP	Common
	{{9312, 9471}, "Enclosed Alphanumerics"}, -- 0 BMP	Common
	{{9472, 9599}, "Box Drawing"}, -- 0 BMP	Common
	{{9600, 9631}, "Block Elements"}, -- 0 BMP	Common
	{{9632, 9727}, "Geometric Shapes"}, -- 0 BMP	Common
	{{9728, 9983}, "Miscellaneous Symbols"}, -- 0 BMP	Common
	{{9984, 10175}, "Dingbats"}, -- 0 BMP	Common
	{{10176, 10223}, "Miscellaneous Mathematical Symbols-A"}, -- 0 BMP	Common
	{{10224, 10239}, "Supplemental Arrows-A"}, -- 0 BMP	Common
	{{10240, 10495}, "Braille Patterns"}, -- 0 BMP	Braille
	{{10496, 10623}, "Supplemental Arrows-B"}, -- 0 BMP	Common
	{{10624, 10751}, "Miscellaneous Mathematical Symbols-B"}, -- 0 BMP	Common
	{{10752, 11007}, "Supplemental Mathematical Operators"}, -- 0 BMP	Common
	{{11008, 11263}, "Miscellaneous Symbols and Arrows"}, -- 0 BMP	Common
	{{11264, 11359}, "Glagolitic"}, -- 0 BMP	Glagolitic
	{{11360, 11391}, "Latin Extended-C"}, -- 0 BMP	Latin
	{{11392, 11519}, "Coptic"}, -- 0 BMP	Coptic
	{{11520, 11567}, "Georgian Supplement"}, -- 0 BMP	Georgian
	{{11568, 11647}, "Tifinagh"}, -- 0 BMP	Tifinagh
	{{11648, 11743}, "Ethiopic Extended"}, -- 0 BMP	Ethiopic
	{{11744, 11775}, "Cyrillic Extended-A"}, -- 0 BMP	Cyrillic
	{{11776, 11903}, "Supplemental Punctuation"}, -- 0 BMP	Common
	{{11904, 12031}, "CJK Radicals Supplement"}, -- 0 BMP	Han
	{{12032, 12255}, "Kangxi Radicals"}, -- 0 BMP	Han
	{{12272, 12287}, "Ideographic Description Characters"}, -- 0 BMP	Common
	{{12288, 12351}, "CJK Symbols and Punctuation"}, -- 0 BMP	Han (15 characters), Hangul (2 characters), Common (43 characters), Inherited (4 characters)
	{{12352, 12447}, "Hiragana"}, -- 0 BMP	Hiragana (89 characters), Common (2 characters), Inherited (2 characters)
	{{12448, 12543}, "Katakana"}, -- 0 BMP	Katakana (93 characters), Common (3 characters)
	{{12544, 12591}, "Bopomofo"}, -- 0 BMP	Bopomofo
	{{12592, 12687}, "Hangul Compatibility Jamo"}, -- 0 BMP	Hangul
	{{12688, 12703}, "Kanbun"}, -- 0 BMP	Common
	{{12704, 12735}, "Bopomofo Extended"}, -- 0 BMP	Bopomofo
	{{12736, 12783}, "CJK Strokes"}, -- 0 BMP	Common
	{{12784, 12799}, "Katakana Phonetic Extensions"}, -- 0 BMP	Katakana
	{{12800, 13055}, "Enclosed CJK Letters and Months"}, -- 0 BMP	Hangul (62 characters), Katakana (47 characters), Common (146 characters)
	{{13056, 13311}, "CJK Compatibility"}, -- 0 BMP	Katakana (88 characters), Common (168 characters)
	{{13312, 19903}, "CJK Unified Ideographs Extension A"}, -- 0 BMP	Han
	{{19904, 19967}, "Yijing Hexagram Symbols"}, -- 0 BMP	Common
	{{19968, 40959}, "CJK Unified Ideographs"}, -- 0 BMP	Han
	{{40960, 42127}, "Yi Syllables"}, -- 0 BMP	Yi
	{{42128, 42191}, "Yi Radicals"}, -- 0 BMP	Yi
	{{42192, 42239}, "Lisu"}, -- 0 BMP	Lisu
	{{42240, 42559}, "Vai"}, -- 0 BMP	Vai
	{{42560, 42655}, "Cyrillic Extended-B"}, -- 0 BMP	Cyrillic
	{{42656, 42751}, "Bamum"}, -- 0 BMP	Bamum
	{{42752, 42783}, "Modifier Tone Letters"}, -- 0 BMP	Common
	{{42784, 43007}, "Latin Extended-D"}, -- 0 BMP	Latin (188 characters), Common (5 characters)
	{{43008, 43055}, "Syloti Nagri"}, -- 0 BMP	Syloti Nagri
	{{43056, 43071}, "Common Indic Number Forms"}, -- 0 BMP	Common
	{{43072, 43135}, "Phags-pa"}, -- 0 BMP	Phags Pa
	{{43136, 43231}, "Saurashtra"}, -- 0 BMP	Saurashtra
	{{43232, 43263}, "Devanagari Extended"}, -- 0 BMP	Devanagari
	{{43264, 43311}, "Kayah Li"}, -- 0 BMP	Kayah Li (47 characters), Common (1 character)
	{{43312, 43359}, "Rejang"}, -- 0 BMP	Rejang
	{{43360, 43391}, "Hangul Jamo Extended-A"}, -- 0 BMP	Hangul
	{{43392, 43487}, "Javanese"}, -- 0 BMP	Javanese (90 characters), Common (1 character)
	{{43488, 43519}, "Myanmar Extended-B"}, -- 0 BMP	Myanmar
	{{43520, 43615}, "Cham"}, -- 0 BMP	Cham
	{{43616, 43647}, "Myanmar Extended-A"}, -- 0 BMP	Myanmar
	{{43648, 43743}, "Tai Viet"}, -- 0 BMP	Tai Viet
	{{43744, 43775}, "Meetei Mayek Extensions"}, -- 0 BMP	Meetei Mayek
	{{43776, 43823}, "Ethiopic Extended-A"}, -- 0 BMP	Ethiopic
	{{43824, 43887}, "Latin Extended-E"}, -- 0 BMP	Latin (56 characters), Greek (1 character), Common (3 characters)
	{{43888, 43967}, "Cherokee Supplement"}, -- 0 BMP	Cherokee
	{{43968, 44031}, "Meetei Mayek"}, -- 0 BMP	Meetei Mayek
	{{44032, 55215}, "Hangul Syllables"}, -- 0 BMP	Hangul
	{{55216, 55295}, "Hangul Jamo Extended-B"}, -- 0 BMP	Hangul
	{{55296, 56191}, "High Surrogates"}, -- 0 BMP	Unknown
	{{56192, 56319}, "High Private Use Surrogates"}, -- 0 BMP	Unknown
	{{56320, 57343}, "Low Surrogates"}, -- 0 BMP	Unknown
	{{57344, 63743}, "Private Use Area"}, -- 0 BMP	Unknown
	{{63744, 64255}, "CJK Compatibility Ideographs"}, -- 0 BMP	Han
	{{64256, 64335}, "Alphabetic Presentation Forms"}, -- 0 BMP	Armenian (5 characters), Hebrew (46 characters), Latin (7 characters)
	{{64336, 65023}, "Arabic Presentation Forms-A"}, -- 0 BMP	Arabic (629 characters), Common (2 characters)
	{{65024, 65039}, "Variation Selectors"}, -- 0 BMP	Inherited
	{{65040, 65055}, "Vertical Forms"}, -- 0 BMP	Common
	{{65056, 65071}, "Combining Half Marks"}, -- 0 BMP	Cyrillic (2 characters), Inherited (14 characters)
	{{65072, 65103}, "CJK Compatibility Forms"}, -- 0 BMP	Common
	{{65104, 65135}, "Small Form Variants"}, -- 0 BMP	Common
	{{65136, 65279}, "Arabic Presentation Forms-B"}, -- 0 BMP	Arabic (140 characters), Common (1 character)
	{{65280, 65519}, "Halfwidth and Fullwidth Forms"}, -- 0 BMP	Hangul (52 characters), Katakana (55 characters), Latin (52 characters), Common (66 characters)
	{{65520, 65535}, "Specials"}, -- 0 BMP	Common
	{{65536, 65663}, "Linear B Syllabary"}, -- 1 SMP	Linear B
	{{65664, 65791}, "Linear B Ideograms"}, -- 1 SMP	Linear B
	{{65792, 65855}, "Aegean Numbers"}, -- 1 SMP	Common
	{{65856, 65935}, "Ancient Greek Numbers"}, -- 1 SMP	Greek
	{{65936, 65999}, "Ancient Symbols"}, -- 1 SMP	Greek (1 character), Common (13 characters)
	{{66000, 66047}, "Phaistos Disc"}, -- 1 SMP	Common (45 characters), Inherited (1 character)
	{{66176, 66207}, "Lycian"}, -- 1 SMP	Lycian
	{{66208, 66271}, "Carian"}, -- 1 SMP	Carian
	{{66272, 66303}, "Coptic Epact Numbers"}, -- 1 SMP	Common (27 characters), Inherited (1 character)
	{{66304, 66351}, "Old Italic"}, -- 1 SMP	Old Italic
	{{66352, 66383}, "Gothic"}, -- 1 SMP	Gothic
	{{66384, 66431}, "Old Permic"}, -- 1 SMP	Old Permic
	{{66432, 66463}, "Ugaritic"}, -- 1 SMP	Ugaritic
	{{66464, 66527}, "Old Persian"}, -- 1 SMP	Old Persian
	{{66560, 66639}, "Deseret"}, -- 1 SMP	Deseret
	{{66640, 66687}, "Shavian"}, -- 1 SMP	Shavian
	{{66688, 66735}, "Osmanya"}, -- 1 SMP	Osmanya
	{{66736, 66815}, "Osage"}, -- 1 SMP	Osage
	{{66816, 66863}, "Elbasan"}, -- 1 SMP	Elbasan
	{{66864, 66927}, "Caucasian Albanian"}, -- 1 SMP	Caucasian Albanian
	{{66928, 67007}, "Vithkuqi"}, -- 1 SMP	Vithkuqi
	{{67072, 67455}, "Linear A"}, -- 1 SMP	Linear A
	{{67456, 67519}, "Latin Extended-F"}, -- 1 SMP	Latin
	{{67584, 67647}, "Cypriot Syllabary"}, -- 1 SMP	Cypriot
	{{67648, 67679}, "Imperial Aramaic"}, -- 1 SMP	Imperial Aramaic
	{{67680, 67711}, "Palmyrene"}, -- 1 SMP	Palmyrene
	{{67712, 67759}, "Nabataean"}, -- 1 SMP	Nabataean
	{{67808, 67839}, "Hatran"}, -- 1 SMP	Hatran
	{{67840, 67871}, "Phoenician"}, -- 1 SMP	Phoenician
	{{67872, 67903}, "Lydian"}, -- 1 SMP	Lydian
	{{67968, 67999}, "Meroitic Hieroglyphs"}, -- 1 SMP	Meroitic Hieroglyphs
	{{68000, 68095}, "Meroitic Cursive"}, -- 1 SMP	Meroitic Cursive
	{{68096, 68191}, "Kharoshthi"}, -- 1 SMP	Kharoshthi
	{{68192, 68223}, "Old South Arabian"}, -- 1 SMP	Old South Arabian
	{{68224, 68255}, "Old North Arabian"}, -- 1 SMP	Old North Arabian
	{{68288, 68351}, "Manichaean"}, -- 1 SMP	Manichaean
	{{68352, 68415}, "Avestan"}, -- 1 SMP	Avestan
	{{68416, 68447}, "Inscriptional Parthian"}, -- 1 SMP	Inscriptional Parthian
	{{68448, 68479}, "Inscriptional Pahlavi"}, -- 1 SMP	Inscriptional Pahlavi
	{{68480, 68527}, "Psalter Pahlavi"}, -- 1 SMP	Psalter Pahlavi
	{{68608, 68687}, "Old Turkic"}, -- 1 SMP	Old Turkic
	{{68736, 68863}, "Old Hungarian"}, -- 1 SMP	Old Hungarian
	{{68864, 68927}, "Hanifi Rohingya"}, -- 1 SMP	Hanifi Rohingya
	{{69216, 69247}, "Rumi Numeral Symbols"}, -- 1 SMP	Arabic
	{{69248, 69311}, "Yezidi"}, -- 1 SMP	Yezidi
	{{69312, 69375}, "Arabic Extended-C"}, -- 1 SMP	Arabic
	{{69376, 69423}, "Old Sogdian"}, -- 1 SMP	Old Sogdian
	{{69424, 69487}, "Sogdian"}, -- 1 SMP	Sogdian
	{{69488, 69551}, "Old Uyghur"}, -- 1 SMP	Old Uyghur
	{{69552, 69599}, "Chorasmian"}, -- 1 SMP	Chorasmian
	{{69600, 69631}, "Elymaic"}, -- 1 SMP	Elymaic
	{{69632, 69759}, "Brahmi"}, -- 1 SMP	Brahmi
	{{69760, 69839}, "Kaithi"}, -- 1 SMP	Kaithi
	{{69840, 69887}, "Sora Sompeng"}, -- 1 SMP	Sora Sompeng
	{{69888, 69967}, "Chakma"}, -- 1 SMP	Chakma
	{{69968, 70015}, "Mahajani"}, -- 1 SMP	Mahajani
	{{70016, 70111}, "Sharada"}, -- 1 SMP	Sharada
	{{70112, 70143}, "Sinhala Archaic Numbers"}, -- 1 SMP	Sinhala
	{{70144, 70223}, "Khojki"}, -- 1 SMP	Khojki
	{{70272, 70319}, "Multani"}, -- 1 SMP	Multani
	{{70320, 70399}, "Khudawadi"}, -- 1 SMP	Khudawadi
	{{70400, 70527}, "Grantha"}, -- 1 SMP	Grantha (85 characters), Inherited (1 character)
	{{70656, 70783}, "Newa"}, -- 1 SMP	Newa
	{{70784, 70879}, "Tirhuta"}, -- 1 SMP	Tirhuta
	{{71040, 71167}, "Siddham"}, -- 1 SMP	Siddham
	{{71168, 71263}, "Modi"}, -- 1 SMP	Modi
	{{71264, 71295}, "Mongolian Supplement"}, -- 1 SMP	Mongolian
	{{71296, 71375}, "Takri"}, -- 1 SMP	Takri
	{{71424, 71503}, "Ahom"}, -- 1 SMP	Ahom
	{{71680, 71759}, "Dogra"}, -- 1 SMP	Dogra
	{{71840, 71935}, "Warang Citi"}, -- 1 SMP	Warang Citi
	{{71936, 72031}, "Dives Akuru"}, -- 1 SMP	Dives Akuru
	{{72096, 72191}, "Nandinagari"}, -- 1 SMP	Nandinagari
	{{72192, 72271}, "Zanabazar Square"}, -- 1 SMP	Zanabazar Square
	{{72272, 72367}, "Soyombo"}, -- 1 SMP	Soyombo
	{{72368, 72383}, "Unified Canadian Aboriginal Syllabics Extended-A"}, -- 1 SMP	Canadian Aboriginal
	{{72384, 72447}, "Pau Cin Hau"}, -- 1 SMP	Pau Cin Hau
	{{72448, 72543}, "Devanagari Extended-A"}, -- 1 SMP	Devanagari
	{{72704, 72815}, "Bhaiksuki"}, -- 1 SMP	Bhaiksuki
	{{72816, 72895}, "Marchen"}, -- 1 SMP	Marchen
	{{72960, 73055}, "Masaram Gondi"}, -- 1 SMP	Masaram Gondi
	{{73056, 73135}, "Gunjala Gondi"}, -- 1 SMP	Gunjala Gondi
	{{73440, 73471}, "Makasar"}, -- 1 SMP	Makasar
	{{73472, 73567}, "Kawi"}, -- 1 SMP	Kawi
	{{73648, 73663}, "Lisu Supplement"}, -- 1 SMP	Lisu
	{{73664, 73727}, "Tamil Supplement"}, -- 1 SMP	Tamil
	{{73728, 74751}, "Cuneiform"}, -- 1 SMP	Cuneiform
	{{74752, 74879}, "Cuneiform Numbers and Punctuation"}, -- 1 SMP	Cuneiform
	{{74880, 75087}, "Early Dynastic Cuneiform"}, -- 1 SMP	Cuneiform
	{{77712, 77823}, "Cypro-Minoan"}, -- 1 SMP	Cypro Minoan
	{{77824, 78895}, "Egyptian Hieroglyphs"}, -- 1 SMP	Egyptian Hieroglyphs
	{{78896, 78943}, "Egyptian Hieroglyph Format Controls"}, -- 1 SMP	Egyptian Hieroglyphs
	{{82944, 83583}, "Anatolian Hieroglyphs"}, -- 1 SMP	Anatolian Hieroglyphs
	{{92160, 92735}, "Bamum Supplement"}, -- 1 SMP	Bamum
	{{92736, 92783}, "Mro"}, -- 1 SMP	Mro
	{{92784, 92879}, "Tangsa"}, -- 1 SMP	Tangsa
	{{92880, 92927}, "Bassa Vah"}, -- 1 SMP	Bassa Vah
	{{92928, 93071}, "Pahawh Hmong"}, -- 1 SMP	Pahawh Hmong
	{{93760, 93855}, "Medefaidrin"}, -- 1 SMP	Medefaidrin
	{{93952, 94111}, "Miao"}, -- 1 SMP	Miao
	{{94176, 94207}, "Ideographic Symbols and Punctuation"}, -- 1 SMP	Han (4 characters), Khitan Small Script (1 character), Nushu (1 character), Tangut (1 character)
	{{94208, 100351}, "Tangut"}, -- 1 SMP	Tangut
	{{100352, 101119}, "Tangut Components"}, -- 1 SMP	Tangut
	{{101120, 101631}, "Khitan Small Script"}, -- 1 SMP	Khitan Small Script
	{{101632, 101759}, "Tangut Supplement"}, -- 1 SMP	Tangut
	{{110576, 110591}, "Kana Extended-B"}, -- 1 SMP	Katakana
	{{110592, 110847}, "Kana Supplement"}, -- 1 SMP	Hiragana (255 characters), Katakana (1 character)
	{{110848, 110895}, "Kana Extended-A"}, -- 1 SMP	Hiragana (32 characters), Katakana (3 characters)
	{{110896, 110959}, "Small Kana Extension"}, -- 1 SMP	Hiragana (4 characters), Katakana (5 characters)
	{{110960, 111359}, "Nushu"}, -- 1 SMP	Nüshu
	{{113664, 113823}, "Duployan"}, -- 1 SMP	Duployan
	{{113824, 113839}, "Shorthand Format Controls"}, -- 1 SMP	Common
	{{118528, 118735}, "Znamenny Musical Notation"}, -- 1 SMP	Common (116 characters), Inherited (69 characters)
	{{118784, 119039}, "Byzantine Musical Symbols"}, -- 1 SMP	Common
	{{119040, 119295}, "Musical Symbols"}, -- 1 SMP	Common (211 characters), Inherited (22 characters)
	{{119296, 119375}, "Ancient Greek Musical Notation"}, -- 1 SMP	Greek
	{{119488, 119519}, "Kaktovik Numerals"}, -- 1 SMP	Common
	{{119520, 119551}, "Mayan Numerals"}, -- 1 SMP	Common
	{{119552, 119647}, "Tai Xuan Jing Symbols"}, -- 1 SMP	Common
	{{119648, 119679}, "Counting Rod Numerals"}, -- 1 SMP	Common
	{{119808, 120831}, "Mathematical Alphanumeric Symbols"}, -- 1 SMP	Common
	{{120832, 121519}, "Sutton SignWriting"}, -- 1 SMP	SignWriting
	{{122624, 122879}, "Latin Extended-G"}, -- 1 SMP	Latin
	{{122880, 122927}, "Glagolitic Supplement"}, -- 1 SMP	Glagolitic
	{{122928, 123023}, "Cyrillic Extended-D"}, -- 1 SMP	Cyrillic
	{{123136, 123215}, "Nyiakeng Puachue Hmong"}, -- 1 SMP	Nyiakeng Puachue Hmong
	{{123536, 123583}, "Toto"}, -- 1 SMP	Toto
	{{123584, 123647}, "Wancho"}, -- 1 SMP	Wancho
	{{124112, 124159}, "Nag Mundari"}, -- 1 SMP	Mundari
	{{124896, 124927}, "Ethiopic Extended-B"}, -- 1 SMP	Ethiopic
	{{124928, 125151}, "Mende Kikakui"}, -- 1 SMP	Mende Kikakui
	{{125184, 125279}, "Adlam"}, -- 1 SMP	Adlam
	{{126064, 126143}, "Indic Siyaq Numbers"}, -- 1 SMP	Common
	{{126208, 126287}, "Ottoman Siyaq Numbers"}, -- 1 SMP	Common
	{{126464, 126719}, "Arabic Mathematical Alphabetic Symbols"}, -- 1 SMP	Arabic
	{{126976, 127023}, "Mahjong Tiles"}, -- 1 SMP	Common
	{{127024, 127135}, "Domino Tiles"}, -- 1 SMP	Common
	{{127136, 127231}, "Playing Cards"}, -- 1 SMP	Common
	{{127232, 127487}, "Enclosed Alphanumeric Supplement"}, -- 1 SMP	Common
	{{127488, 127743}, "Enclosed Ideographic Supplement"}, -- 1 SMP	Hiragana (1 character), Common (63 characters)
	{{127744, 128511}, "Miscellaneous Symbols and Pictographs"}, -- 1 SMP	Common
	{{128512, 128591}, "Emoticons"}, -- 1 SMP	Common
	{{128592, 128639}, "Ornamental Dingbats"}, -- 1 SMP	Common
	{{128640, 128767}, "Transport and Map Symbols"}, -- 1 SMP	Common
	{{128768, 128895}, "Alchemical Symbols"}, -- 1 SMP	Common
	{{128896, 129023}, "Geometric Shapes Extended"}, -- 1 SMP	Common
	{{129024, 129279}, "Supplemental Arrows-C"}, -- 1 SMP	Common
	{{129280, 129535}, "Supplemental Symbols and Pictographs"}, -- 1 SMP	Common
	{{129536, 129647}, "Chess Symbols"}, -- 1 SMP	Common
	{{129648, 129791}, "Symbols and Pictographs Extended-A"}, -- 1 SMP	Common
	{{129792, 130047}, "Symbols for Legacy Computing"}, -- 1 SMP	Common
	{{131072, 173791}, "CJK Unified Ideographs Extension B"}, -- 2 SIP	Han
	{{173824, 177983}, "CJK Unified Ideographs Extension C"}, -- 2 SIP	Han
	{{177984, 178207}, "CJK Unified Ideographs Extension D"}, -- 2 SIP	Han
	{{178208, 183983}, "CJK Unified Ideographs Extension E"}, -- 2 SIP	Han
	{{183984, 191471}, "CJK Unified Ideographs Extension F"}, -- 2 SIP	Han
	{{194560, 195103}, "CJK Compatibility Ideographs Supplement"}, -- 2 SIP	Han
	{{196608, 201551}, "CJK Unified Ideographs Extension G"}, -- 3 TIP	Han
	{{201552, 205743}, "CJK Unified Ideographs Extension H"}, -- 3 TIP	Han
	{{917504, 917631}, "Tags"}, -- 14 SSP	Common
	{{917760, 917999}, "Variation Selectors Supplement"}, -- 14 SSP	Inherited
	{{983040, 1048575}, "Supplementary Private Use Area-A"}, -- 15 PUA-A	Unknown
	{{1048576, 1114111}, "Supplementary Private Use Area-B"}, -- 16 PUA-B	Unknown
}

-- Some other characters can also be combined https://en.wikipedia.org/wiki/Combining_character
---@type UnicodeBlock[]
local unicode_blocks_combining = itable_filter(unicode_blocks, function(block) return block[2]:find("^Combining ") end)

-- Egyptian Hieroglyph Format Controls and Shorthand format Controls
---@type UnicodeBlock[]
local unicode_blocks_controls = itable_filter(unicode_blocks, function(block) return block[2]:find("Controls$") end)

-- not sure how to deal with those https://en.wikipedia.org/wiki/Spacing_Modifier_Letters
---@type any, UnicodeBlock
local _, unicode_spacing_modifier = itable_find(unicode_blocks, function(block) return block[2]:find("Spacing Modifier Letters") end)

---@type {[integer]: boolean}
local unicode_control_chars = {
	-- C0
	[0] = true, -- Null character
	[1] = true, -- Start of Heading
	[2] = true, -- Start of Text
	[3] = true, -- End-of-text character
	[4] = true, -- End-of-transmission character
	[5] = true, -- Enquiry character
	[6] = true, -- Acknowledge character
	[7] = true, -- Bell character
	[8] = true, -- Backspace
	[9] = true, -- Horizontal tab
	[10] = true, -- Line feed
	[11] = true, -- Vertical tab
	[12] = true, -- Form feed
	[13] = true, -- Carriage return
	[14] = true, -- Shift Out
	[15] = true, -- Shift In
	[16] = true, -- Data Link Escape
	[17] = true, -- Device Control 1
	[18] = true, -- Device Control 2
	[19] = true, -- Device Control 3
	[20] = true, -- Device Control 4
	[21] = true, -- Negative-acknowledge character
	[22] = true, -- Synchronous Idle
	[23] = true, -- End of Transmission Block
	[24] = true, -- Cancel character
	[25] = true, -- End of Medium
	[26] = true, -- Substitute character
	[27] = true, -- Escape character
	[28] = true, -- File Separator
	[29] = true, -- Group Separator
	[30] = true, -- Record Separator
	[31] = true, -- Unit Separator

	[127] = true, -- Delete

	-- C1
	[128] = true, -- Padding Character
	[129] = true, -- High Octet Preset
	[130] = true, -- Break Permitted Here
	[131] = true, -- No Break Here
	[132] = true, -- Index
	[133] = true, -- Next Line
	[134] = true, -- Start of Selected Area
	[135] = true, -- End of Selected Area
	[136] = true, -- Character (Horizontal) Tabulation Set
	[137] = true, -- Character (Horizontal) Tabulation with Justification
	[138] = true, -- Line (Vertical) Tabulation Set
	[139] = true, -- Partial Line Forward (Down
	[140] = true, -- Partial Line Backward (Up
	[141] = true, -- Reverse Line Feed (Index
	[142] = true, -- Single-Shift Two
	[143] = true, -- Single-Shift Three
	[144] = true, -- Device Control String
	[145] = true, -- Private Use One
	[146] = true, -- Private Use Two
	[147] = true, -- Set Transmit State
	[148] = true, -- Cancel character
	[149] = true, -- Message Waiting
	[150] = true, -- Start of Protected Area
	[151] = true, -- End of Protected Area
	[152] = true, -- Start of String
	[153] = true, -- Single Graphic Character Introducer
	[154] = true, -- Single Character Introducer
	[155] = true, -- Control Sequence Introducer
	[156] = true, -- String Terminator
	[157] = true, -- Operating System Command
	[158] = true, -- Private Message
	[159] = true, -- Application Program Command
}

---@type {[integer]: boolean}
local unicode_zero_width = {
	[847] = true, -- combining grapheme joiner
	[8203] = true, -- zero-width space
	[8204] = true, -- zero-width non-joiner
	[8205] = true, -- zero-width joiner
	[8288] = true, -- word joiner
	[65279] = true, -- zero-width non-breaking space
	[8232] = true, -- line separator
	[8233] = true, -- paragraph separator
	[8206] = true, -- left-to-right mark
	[8207] = true, -- right-to-left mark
	[1564] = true, -- Arabic Letter	Strong
	[8234] = true, -- Left-to-Right Embedding
	[8237] = true, -- Left-to-Right Override
	[8235] = true, -- Right-to-Left Embedding
	[8238] = true, -- Right-to-Left Override
	[8236] = true, -- Pop Directional Format
	[8294] = true, -- Left-to-Right Isolate
	[8295] = true, -- Right-to-Left Isolate
	[8296] = true,-- First Strong Isolate
	[8297] = true, -- Pop Directional Isolate
}

---Convert Unicode code point to utf-8 string
---@param unicode integer
---@return string?
local function unicode_to_utf8(unicode)
	if unicode < 128 then return string.char(unicode)
	else
		local byte_count = 2
		if unicode < 2048 then
		elseif unicode < 65536 then byte_count = 3
		elseif unicode < 1114112 then byte_count = 4
		else return end -- too big

		local res = {}
		local shift = 2 ^ 6
		local after_shift = unicode
		for _ = byte_count, 2, -1 do
			local before_shift = after_shift
			after_shift = math.floor(before_shift / shift)
			table.insert(res, 1, before_shift - after_shift * shift + 128)
		end
		shift = 2 ^ (8 - byte_count)
		table.insert(res, 1, after_shift + math.floor(255 / shift) * shift)
		return string.char(unpack(res))
	end
end

local text_osd = mp.create_osd_overlay("ass-events")
---@param text string|number
---@param font_size number
---@return number, number, number, number
local function bounds_of_text(text, font_size)
	local ass = assdraw.ass_new()
	ass:txt(0, 0, 7, text, {size = font_size, opacity = 0.2})
	local w, h, _ = mp.get_osd_size()
	text_osd.res_x, text_osd.res_y = w, h
	text_osd.data = ass.text
	text_osd.compute_bounds = true

	local res = text_osd:update()
	-- text_osd:remove()
	return res.x0, res.y0, res.x1, res.y1
end

---@type {[integer]: boolean}
local zero_width_chars = {}
for _, collection in ipairs({unicode_control_chars, unicode_zero_width}) do
	for uni, _ in pairs(collection) do
		zero_width_chars[uni] = true
	end
end

---@type UnicodeBlock[]
local zero_width_blocks = {}
for _,collection in ipairs({unicode_blocks_combining, unicode_blocks_controls, {unicode_spacing_modifier}}) do
	for _, block in ipairs(collection) do
		zero_width_blocks[#zero_width_blocks + 1] = block
	end
end

---@param unicode integer
function character_width(unicode)
	if zero_width_chars[unicode] then return 0 end

	for _, block in ipairs(zero_width_blocks) do
		local range = block[1]
		if unicode >= range[1] and unicode <= range[2] then return 0 end
	end

	local character = unicode_to_utf8(unicode)

	local font_size = 100
	local char_count = 20

	characters = {}
	for i = 1, char_count do
		characters[i] = character
	end

	local _, _, x1, _ = bounds_of_text('fff', font_size)
	return x1
end

for unicode = 0, 65535 do
	local start = mp.get_time()
	local width = character_width(unicode)
	local time = start - mp.get_time()
	print(unicode, width, time)
	--TODO: store result somewhere
end
