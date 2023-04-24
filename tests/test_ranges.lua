

local example_chapters = {
	openings = {
		yes = {
			'OP',
			'Opening',
		},
		no = {
			'Opening the box'
		}
	},
	intros = {
		yes = {
			'Avant',
			'FUNI intro',
			'Intro',
			'Prologue',
		},
		no = {
		}
	},
	endings = {
		yes = {
			'ED',
			'Ending',
		},
		no = {
			'end of the thread',
			'trending',
		}
	},
	outros = {
		yes = {
			'closing',
			'Outro',
			'Preview',
			'PV',
		},
		no = {
		}
	}
}

local simple_ranges = {
	{name = 'openings', patterns = {
			'^op ', '^op$', ' op$',
			'^opening$', ' opening$'
		}, requires_next_chapter = true},
	{name = 'intros', patterns = {
			'^intro$', ' intro$',
			'^avant$', '^prologue$'
		}, requires_next_chapter = true},
	{name = 'endings', patterns = {
			'^ed ', '^ed$', ' ed$',
			'^ending ', '^ending$', ' ending$',
		}},
	{name = 'outros', patterns = {
			'^outro$', ' outro$',
			'^closing$', '^closing ',
			'^preview$', '^pv$',
		}},
}

local function find_any(s, patterns)
	for _, pattern in ipairs(patterns) do
		if s:find(pattern) then
			return true
		end
	end
	return false
end

local function test_examples(examples, patterns, name, should_match)
	local pass = true
	for _, example in ipairs(examples) do
		if find_any(example:lower(), patterns) ~= should_match then
			print(string.format('False %s in %s "%s"', should_match and 'negative' or 'positive', name, example))
			pass = false
		end
	end
	return pass
end

local pass = true
for _, range in ipairs(simple_ranges) do
	pass = test_examples(example_chapters[range.name].yes, range.patterns, range.name, true) and pass
	pass = test_examples(example_chapters[range.name].no, range.patterns, range.name, false) and pass
end
if pass then
	print('All pass')
end
