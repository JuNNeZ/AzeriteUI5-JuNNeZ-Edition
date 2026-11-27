local _, ns = ...

-- Stage directions, private recollections, and invented people are original RP.
-- Sources establish what happened in the world, not the druid's personal history.
ns.stories = {
	{
		id = "hyjal", title = "When Hyjal Burned", voice = "hearsay",
		note = "Hyjal after the Third War.",
		sources = {
			"https://www.wowhead.com/forever/quest=89473/the-well-of-eternity"
		},
		lines = {
			{ "EMOTE", "turns a twig between his fingers before laying it across the embers." },
			{ "SAY", "I asked three people what they remembered of Hyjal. The sentry told me about the horns. My old shan'do spoke of the quiet when the horns stopped." },
			{ "SAY", "The third was an orc. He wanted to know whether we'd buried his friend.", replies = {
				{ "The orc's name", "SAY", "Gorak. He said it twice, since I got it wrong the first time. His friend was called Hargan.", cues = { { "orc", "friend", "gorak", "hargan", "he", "his" }, { "name", "named", "called" } } },
				{ "How did you meet?", "SAY", "He found me by the stream, washing soot out of a bandage. He had a better question than the ones I'd been asking.", cues = { { "orc", "gorak", "him", "he", "you" }, { "meet", "met", "find", "found" } } }
			}, aside = { "SAY", "I have more time for the one who asks who was buried than for the one who asks whose side won." } },
			{ "SAY", "I told him I'd find out. It took me two summers to learn the man's name." },
			{ "SAY", "When I went back to tell him, I found his daughter instead. She asked me the same question.", replies = {
				{ "Did you find the grave?", "SAY", "There was a cairn. My shan'do remembered building it. We walked up to it together, his daughter and I.", cues = { { "grave", "body", "cairn" }, { "find", "found", "where", "buried" } } },
				{ "A word for the fallen", "SAY", "May the road home be kinder than the road up the mountain.", darnassian = true }
			} },
			{ "SAY", "Elune-adore.", darnassian = true },
			{ "SAY", "People always ask me how we won that night. I wish they'd ask me who we went back for." }
		}
	},
	{
		id = "westfall", title = "The Red Scarves", voice = "inference",
		note = "Westfall, the red scarves and the old stonemasons.",
		sources = {
			"https://www.wowhead.com/forever/quest=135/the-defias-brotherhood",
			"https://www.wowhead.com/forever/quest=142/the-defias-brotherhood"
		},
		lines = {
			{ "EMOTE", "rubs a pinch of dirt between his fingers." },
			{ "SAY", "In Westfall I met a woman who'd taken the handle off her door. I said Ishnu-alah. She just pointed to the window and told me her son could still get in that way.", replies = {
				{ "How did you greet her?", "SAY", "Ishnu-alah.", darnassian = true }
			} },
			{ "SAY", "She'd seen him on the road the week before, with a red scarf over his mouth.", replies = {
				{ "Did he come home?", "SAY", "There was a bowl waiting for him when I left. That's as much as I know." }
			} },
			{ "SAY", "In Stormwind, a mason told me how proud he'd been of the walls. In Westfall, a guard asked whether I'd heard anything about the old stonemasons.", replies = {
				{ "Who leads them?", "SAY", "VanCleef is the name I heard. If you want proof, speak to Gryan Stoutmantle. I heard it over a meal.", cues = { { "defias", "them", "brotherhood", "vancleef" }, { "leads", "leader", "who", "runs" } } }
			}, aside = { "SAY", "I mistrust a city that remembers who paid for its walls better than who built them." } },
			{ "SAY", "I wondered if I'd been hearing two halves of the same story. The mason wouldn't tell me what he'd been paid." },
			{ "EMOTE", "lets the dirt slip through his fingers." },
			{ "SAY", "I still think about that window. Every night she left it open, and every morning she swept the sill." }
		}
	},
	{
		id = "lordaeron", title = "The City Under the Ruins", voice = "hearsay",
		note = "The founding of the Undercity after Lordaeron's fall.",
		sources = {
			"https://news.blizzard.com/en-gb/article/24301511/wage-war-once-more-with-warcraft-iii-reforged-forsaken-kingdom",
			"https://news.blizzard.com/en-gb/article/24302500/warcraft-iii-reforged-forsaken-kingdom-what-s-next-panel-recap"
		},
		lines = {
			{ "EMOTE", "holds his palms over the fire for a moment." },
			{ "SAY", "A traveller once told me the ruins of Lordaeron were empty. Later, a woman from below those ruins told me she'd spent a week arguing over where to put a door." },
			{ "SAY", "She spoke of the days when the Forsaken began to make a city down there. I asked if she'd known Sylvanas.", replies = {
				{ "Who told you?", "SAY", "She asked me to leave her name out of the story. I said I would, and I have.", cues = { { "woman", "she", "you", "source" }, { "told", "name", "source" } } },
				{ "Did she know Sylvanas?", "SAY", "I never got an answer. She asked whose hands I thought had hung all the doors." }
			}, aside = { "SAY", "I liked her. I suppose there are people on both sides who would want me to say that more quietly." } },
			{ "SAY", "She told me her neighbour could mend a hinge in the dark. He'd done it for a living before the Scourge came." },
			{ "SAY", "I sometimes wonder how many of the people under that city once paid him to fix their doors above it." },
			{ "EMOTE", "glances past the edge of the firelight." },
			{ "SAY", "Anyway, that's how I heard it. If you meet someone from Lordaeron, ask what they remember. Sit long enough to hear the answer.", replies = {
				{ "A quiet farewell", "SAY", "Ande'thoras-ethil.", darnassian = true }
			} }
		}
	}
}
