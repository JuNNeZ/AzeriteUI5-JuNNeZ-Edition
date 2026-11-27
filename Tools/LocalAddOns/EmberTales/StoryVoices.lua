local _, ns = ...

ns.voices = {
	{ id = "memory", label = "I was there" },
	{ id = "hearsay", label = "I heard a tale" },
	{ id = "inference", label = "I put it together" }
}

-- Each voice has its own script. Keep the original scripts at their existing
-- positions so characters can resume a performance from an older installation.
local variants = {
	hyjal = {
		memory = {
			{ "EMOTE", "cups both hands around a coal until it gives off a little heat." },
			{ "SAY", "I remember Hyjal by the weight of wet wool. We tore our cloaks into strips, dipped them in the stream, and bound whatever we could reach." },
			{ "SAY", "The orc beside me held the water bowl while I worked. I never asked which banner he'd followed up the mountain.", replies = {
				{ "Did you learn his name?", "SAY", "Gorak. He told me when I asked him to sign for a fresh blanket." }
			} },
			{ "SAY", "Elune-adore.", darnassian = true },
			{ "SAY", "I went back for that bowl the next morning. There were three little stones in it. Someone had marked a grave with the rest." }
		},
		inference = {
			{ "SAY", "Every account of Hyjal I heard from a commander ended with the demon falling. The people who stayed to bury the dead all began there." },
			{ "SAY", "One kaldorei remembered seeing a wet blanket laid on the ground. An orc remembered a wet blanket hung from a branch to mark the way back." },
			{ "EMOTE", "sets a fresh twig where two charred branches cross." },
			{ "SAY", "Maybe they meant the same blanket. Maybe it went up after the last wounded person was carried down. I've wondered who decided it was time to take it down again." }
		}
	},
	westfall = {
		memory = {
			{ "SAY", "I was walking through Westfall when a woman asked if I'd seen her son. She described his coat before she mentioned the scarf." },
			{ "SAY", "I had seen a red scarf that morning. I had spent the rest of the walk thinking about which road to avoid." },
			{ "EMOTE", "draws two tracks in the dirt with the end of a stick." },
			{ "SAY", "I told her which way the boy had gone. She thanked me twice and set off along the very road I'd been trying to avoid." }
		},
		hearsay = {
			{ "SAY", "A mason in Stormwind told me a story about Westfall. He swore a boy had come to the city looking for work and gone home wearing a red scarf." },
			{ "SAY", "The boy's mother told the story differently. In her version, he'd gone to find out why his father was still owed wages.", replies = {
				{ "Who was the father?", "SAY", "She didn't tell me. She gave me the name of an inn where he used to wait for work." }
			} },
			{ "EMOTE", "lets the fire burn quietly for a moment." },
			{ "SAY", "Both people told me they'd seen the same boy. Neither could tell me whether he'd been paid." }
		}
	},
	lordaeron = {
		memory = {
			{ "SAY", "I made it as far as the ruins of Lordaeron once. I waited with my back against a broken wall while someone below tried to fix a door." },
			{ "SAY", "She called up for a stone to prop it open. I passed the first one that fit through the gap. She passed it back. It had somebody's name on it." },
			{ "EMOTE", "rolls a little stone out from beneath his boot." },
			{ "SAY", "I put it where I'd found it. She asked for a stick instead. We never introduced ourselves." }
		},
		inference = {
			{ "SAY", "The people who fled Lordaeron told me which streets they'd taken to get out. A Forsaken woman could tell me which cellar each street had been built over." },
			{ "SAY", "She also remembered which doors opened inward. I asked how she knew. She said she used to be the one who came around asking for the rent." },
			{ "EMOTE", "draws a small square beside another in the ash." },
			{ "SAY", "I keep hearing that the people down there built a city from nothing. I think some of them carried a whole street down with them, one door at a time." }
		}
	}
}
for _, story in ipairs(ns.stories) do
	story.variants = variants[story.id]
end

local stories = {
	{
		id = "stalvan", title = "The Schoolmaster's Name", voice = "hearsay",
		note = "The old papers that lead from Duskwood to Goldshire.",
		sources = {
			"https://www.wowhead.com/forever/quest=68/the-legend-of-stalvan",
			"https://www.wowhead.com/forever/quest=74/the-legend-of-stalvan"
		},
		lines = {
			{ "SAY", "Someone in Darkshire asked me to look into a schoolmaster named Stalvan. An innkeeper in Goldshire remembered the name before he remembered the man." },
			{ "SAY", "There was an old crate at the inn. The person who opened it told me something dead had been waiting for the lid to move.", replies = {
				{ "Did you see the ghost?", "SAY", "I heard the account over breakfast. The man telling it kept both feet planted on his own chest of belongings." }
			} },
			{ "EMOTE", "turns his cup a little so the handle faces the fire." },
			{ "SAY", "I asked what was written on the papers. The innkeeper asked whether I'd ever read a dead man's letters without wishing I'd put them back." }
		},
		variants = {
			memory = {
				{ "SAY", "I carried a name from Darkshire to Goldshire. Stalvan. I expected the innkeeper to ask how to spell it." },
				{ "SAY", "Instead he asked whether we'd be opening the old crate that night. I said in the morning would do." },
				{ "EMOTE", "raises his eyebrows a fraction." },
				{ "SAY", "It was the way he said 'good' that made me want to leave before morning." }
			},
			inference = {
				{ "SAY", "The thing about the name Stalvan is that people remember it in different places. A name in Darkshire. A crate in Goldshire. Papers that make you go back to ask the next question." },
				{ "SAY", "Whenever I asked what happened, people told me who'd kept the papers. Whenever I asked why they'd kept them, they told me what had happened." },
				{ "SAY", "Someone wanted that story found. I can't tell whether it was the living who put it in order." },
				{ "EMOTE", "brushes a stray scrap of bark away from the edge of the fire." }
			}
		}
	},
	{
		id = "thandol", title = "The Bridge That Held", voice = "memory",
		note = "The Dark Iron attack on the Thandol Span.",
		sources = {
			"https://www.wowhead.com/forever/quest=631/the-thandol-span",
			"https://www.wowhead.com/forever/quest=633/the-thandol-span"
		},
		lines = {
			{ "EMOTE", "lays two twigs across a gap in the ashes." },
			{ "SAY", "I came to Thandol after the blast. On the near side, a dwarf was counting carts. He was counting the ones that still had to cross." },
			{ "SAY", "He asked me to walk a mule halfway over. It would follow me, he said, if I didn't look down.", replies = {
				{ "Did you look down?", "SAY", "Of course I did. The mule was kind enough to stop until I was done." }
			} },
			{ "SAY", "I heard later about the cache of explosives. That morning all I knew was that there were more carts than there were people willing to cross with them." }
		},
		variants = {
			hearsay = {
				{ "SAY", "Rhag Garmason told people about the explosion. A carter told me what happened to the sound after it. He said the valley went so quiet he could hear a wheel spinning." },
				{ "SAY", "A third man swore there was another cache across the Span. The carter believed him and took the load off his wagon one sack at a time." },
				{ "EMOTE", "drums his fingers twice on his knee, then stops." },
				{ "SAY", "When it was safe to cross, the carter put every sack back. I asked what he was carrying. Flour. The people north of the bridge still needed bread." }
			},
			inference = {
				{ "SAY", "Dun Modr was under siege. A scout failed to come back. Then word of an explosives cache came from the other side of the Thandol Span." },
				{ "SAY", "I thought I'd understand it better if I drew the roads. All I could see on my little map was how far a sack of flour would have to go if the last crossing fell." },
				{ "EMOTE", "breaks a twig where it crosses the edge of the ash." },
				{ "SAY", "It made me wonder how many days' bread the person who chose that bridge had counted before the first barrel went down." }
			}
		}
	},
	{
		id = "anilia", title = "Anilia's Name", voice = "hearsay",
		note = "A kaldorei's loss to the satyrs of Ashenvale.",
		sources = { "https://www.wowhead.com/forever/quest=1032/satyr-slaying" },
		lines = {
			{ "SAY", "Ishnu-alah. Do you know the name Anilia? A kaldorei in Ashenvale asked travellers to bring back satyr horns for what had happened to her." },
			{ "SAY", "One of those travellers told me the man counted the horns himself. Another swore he looked up at every footstep while he counted.", replies = {
				{ "Who took her?", "SAY", "He named the satyrs. The people who told me this could agree on that much." },
				{ "A quiet blessing", "SAY", "May someone say her name at home tonight.", darnassian = true }
			} },
			{ "EMOTE", "brushes ash from the edge of an empty seat." },
			{ "SAY", "They both knew where to find the satyrs. I had to ask them twice to tell me her name." }
		},
		variants = {
			memory = {
				{ "SAY", "I was in Ashenvale the day a man asked for satyr horns. I asked how many. He answered with her name. Anilia." },
				{ "SAY", "Guide her home, Mother Moon.", darnassian = true },
				{ "SAY", "There was a mark on the table where he'd been setting down the proof people brought him. I put a cup over the mark, since his hands were cold." },
				{ "SAY", "He picked up the cup and asked if I knew Anilia. I stayed a while longer." }
			},
			inference = {
				{ "SAY", "In Ashenvale a man wanted proof that we'd struck back at the satyrs. I could understand the horns. I kept thinking about the way he said Anilia's name before he named the price." },
				{ "SAY", "Later I heard a traveller tell the story with only the price left in it. I asked where he'd heard it. He'd heard it from another traveller." },
				{ "SAY", "Imagine another winter of that. The figure might go up. Her name would be gone entirely." },
				{ "SAY", "Elune-adore.", darnassian = true }
			}
		}
	}
}

for _, story in ipairs(stories) do
	ns.stories[#ns.stories + 1] = story
end
