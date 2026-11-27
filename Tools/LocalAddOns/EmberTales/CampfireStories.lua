local _, ns = ...

local stories = {
	{
		id = "shore_light", title = "A Light Along the Shore", campfire = true, voice = "memory",
		note = "Darkshore · An original tale about a lantern left burning.",
		sources = {},
		lines = {
			{ "SAY", "Along the Darkshore coast I once found a lantern hung low outside an empty shelter. I nearly took it in out of the weather." },
			{ "SAY", "A woman on the beach called up and asked me to turn the glass seaward. Her brother was late coming home. She couldn't see his boat and didn't want him guessing which light was hers.", replies = {
				{ "Did he come back?", "SAY", "Before dawn. I heard him call to her before I could see the boat.", cues = { { "boat", "brother", "he", "lantern" }, { "come", "back", "return", "safe" } } }
			} },
			{ "EMOTE", "makes a little shelter around the flame with his hands." },
			{ "SAY", "We sat a long while with that light behind us. She never asked me to promise he'd come home. She asked me to let her know when the oil ran low." }
		},
		variants = {
			hearsay = {
				{ "SAY", "An old coast hand told me you could tell who was waiting for someone by which way they turned the lantern glass." },
				{ "SAY", "I asked if he ever let his burn till morning. He said his sister had done that for years, and he'd grown used to finding it there." },
				{ "SAY", "It was much later that I realised he was the one I'd heard calling from the water once. He'd never asked my name that night either." },
				{ "EMOTE", "looks out past the light of the fire." }
			},
			inference = {
				{ "SAY", "I'd always thought a lamp hung by a door was there for whoever needed to find the door." },
				{ "SAY", "Then I saw how carefully someone turned one out to sea. The path outside the shelter was black, but she could see the glass from down on the beach." },
				{ "SAY", "I think there are two ways of waiting. One watches for what might come back. The other does something to make the way easier." },
				{ "EMOTE", "looks for a place where the light falls a little farther." }
			}
		}
	},
	{
		id = "spare_seat", title = "The Other Side of the Fire", campfire = true, voice = "memory",
		note = "The Barrens · An original story about sharing a camp.",
		sources = {},
		lines = {
			{ "SAY", "I came across a tauren tending a fire in the Barrens. I tried asking if I could sit. We couldn't make much of one another's words." },
			{ "SAY", "He moved a pot out of the smoke and kicked a flat stone towards me. I took it to mean sit. It might have meant put the pot back.", replies = {
				{ "Did you ever get his name?", "SAY", "No. I tried asking once. He thought I wanted more water and poured it for me.", cues = { { "tauren", "he", "his", "stranger" }, { "name", "called", "who", "named" } } }
			}, aside = { "SAY", "A flat stone is a better greeting than most things I've practised saying." } },
			{ "EMOTE", "slides his pack away from the nearest empty spot." },
			{ "SAY", "I sat. Nothing much happened after that. I'd spent all day walking, so nothing much was exactly what I'd hoped would happen." }
		},
		variants = {
			hearsay = {
				{ "SAY", "A caravan guard told me he once walked past a tauren and an elf sitting at the same fire. He assumed they were waiting for someone to interpret." },
				{ "SAY", "On his way back they were still there. He asked me later who had come to help them talk." },
				{ "EMOTE", "looks down at the fire for a quiet moment." },
				{ "SAY", "I told him the tauren had a pot and the elf had a dry place to sit. I think he was disappointed there wasn't more to it." }
			},
			inference = {
				{ "SAY", "The first time someone moved a stone over by a fire, I spent half the evening wondering whether I'd been invited to sit on it." },
				{ "SAY", "Then I noticed his own seat was higher up the slope than mine. The water ran under my boots and past his." },
				{ "SAY", "Perhaps I read too much into the stone. He did pass me a cup after I moved it, so I don't think I read very much into the cup." },
				{ "EMOTE", "holds the cup between his palms." }
			}
		}
	},
	{
		id = "tin_cup_rain", title = "The Rain in the Tin Cup", campfire = true, voice = "memory",
		note = "Wetlands · An original story about a rainy camp.",
		sources = {},
		lines = {
			{ "SAY", "Once in the Wetlands I spent an evening moving my tin cup around a camp trying to find a place where it wouldn't fill up with rain." },
			{ "SAY", "A traveller I was sharing the fire with asked what I was doing. I told her I was trying to keep my cup dry. She turned it upside down.", aside = {
				"SAY", "Elune, I was old enough to have thought of that.", darnassian = true
			} },
			{ "EMOTE", "turns one palm down and waits for a beat." },
			{ "SAY", "Then we both sat there watching the rain. It was the first thing I'd ever been taught by a person who never said a word after I answered her question." }
		},
		variants = {
			hearsay = {
				{ "SAY", "A traveller tells people she met a druid in the Wetlands who could talk a fire out of dying but couldn't keep the rain out of a tin cup." },
				{ "SAY", "For the record, someone else was keeping the fire going. I was busy trying to make a little roof out of a leaf." },
				{ "EMOTE", "props a bent leaf against the rim of his cup." },
				{ "SAY", "Her telling is better. I'm very fond of the bit where the druid can talk to fire." }
			},
			inference = {
				{ "SAY", "I've noticed that the camps I remember best are the ones where somebody fixed something small. Turned a cup over. Put the dry wood closer to the fire." },
				{ "SAY", "I can barely say what we were talking about the evening we sat in the rain in the Wetlands. I remember I hadn't had to think about the cup after she turned it." },
				{ "SAY", "Maybe that's why I could finally listen to the rain." },
				{ "EMOTE", "sits quietly for a few breaths." }
			}
		}
	}
}

for _, story in ipairs(stories) do
	ns.stories[#ns.stories + 1] = story
end
