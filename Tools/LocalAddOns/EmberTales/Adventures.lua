local _, ns = ...

-- Quest references anchor the place and errand. The druid's mishaps and
-- private dealings are his roleplay, including the dwarf's request for hides.
local adventures = {
	{
		id = "woodwyrd", title = "A Nest in the Branches", voice = "memory",
		note = "Shen'dralas · Looking for the treant Woodwyrd.",
		sources = { "https://www.wowhead.com/forever/quest=93594/word-of-the-woods" },
		lines = {
			{ "SAY", "In Shen'dralas I was asked to look for a treant named Woodwyrd. The person who sent me remembered him standing still at night so small things could nest in his branches." },
			{ "SAY", "I stopped by a tree with a nest in it and asked whether it had seen him. A bird leaned out. I waited a good while for the tree to do the same.", aside = {
				"SAY", "I have been made to feel foolish by grander things than a bird. Few have managed it with less effort."
			} },
			{ "SAY", "I left that tree alone. Later, when I was sure I'd found the right one, I found myself speaking very softly.", replies = {
				{ "Why speak softly?", "SAY", "The person who sent me had called Woodwyrd a friend. By then I was thinking about what might still be sleeping up there.", cues = { { "softly", "quiet", "whisper", "nest" }, { "why", "what", "did" } } }
			} },
			{ "EMOTE", "listens briefly to the branches overhead." },
			{ "SAY", "Whatever else happened in those woods, that is what I remember best. I went looking for a great walking tree and spent most of the afternoon trying not to disturb a nest." }
		},
		variants = {
			hearsay = {
				{ "SAY", "Woodwyrd was described to me in Shen'dralas as someone who tended the blooms by day and stood very still at night." },
				{ "SAY", "I took the second part to mean he slept. The person who knew him said no, the small things in the branches slept. It was polite to let them." },
				{ "SAY", "I thought about that for a long while. You can go a great distance on a description like that and still have trouble recognising a face." },
				{ "EMOTE", "watches the space between two branches." }
			},
			inference = {
				{ "SAY", "When someone in Shen'dralas asked me to look for Woodwyrd, the first thing they described was what he did for the smallest things in the woods." },
				{ "SAY", "I had expected a direction or a description of his bark. Instead they told me about the nests." },
				{ "SAY", "I think they were telling me what to look for. I just needed longer to learn which part of the description mattered." },
				{ "EMOTE", "moves one boot away from a little movement in the grass." }
			}
		}
	},
	{
		id = "dartol_rod", title = "A Furbolg's Reflection", voice = "memory",
		note = "Ashenvale · Bringing Dartol's completed rod to Shael'dryn.",
		sources = {
			"https://www.wowhead.com/forever/quest=1055/raenes-cleansing",
			"https://www.wowhead.com/forever/quest=1046/raenes-cleansing"
		},
		lines = {
			{ "SAY", "I took Dartol's rod back to Shael'dryn at the moonwell. A druid is used to borrowing a shape, so I thought I'd know how it would feel." },
			{ "SAY", "I had looked down at the reflection and found furbolg shoulders where mine should have been. It was the way my old pack still hung off one shoulder that made me laugh.", aside = {
				"SAY", "I suppose anybody can change shape. It takes rather longer to learn to pack evenly."
			} },
			{ "SAY", "Shael'dryn asked what I'd noticed besides my own reflection. I had to admit I'd spent quite a lot of the walk noticing how people looked at me.", replies = {
				{ "What did the rod do?", "SAY", "It gave me a furbolg's shape. It didn't give me a furbolg's lifetime of knowing what to do with it.", cues = { { "rod", "dartol", "furbolg", "shape" }, { "what", "did", "how", "turn" } } }
			} },
			{ "EMOTE", "shifts the strap on his shoulder." },
			{ "SAY", "She told me that was worth remembering the next time I went looking for a reason someone had given me a wide berth." }
		},
		variants = {
			hearsay = {
				{ "SAY", "A sentinel told me she saw a furbolg at the edge of the moonwell. She knew it was an elf by the way he kept trying to fix his pack with the wrong hand." },
				{ "SAY", "Shael'dryn remembered an elf bringing back a completed rod. She was kind enough to leave the story of the pack out of it." },
				{ "SAY", "I wish the sentinel had done the same. Then again, I wouldn't have remembered the afternoon so clearly without her telling." },
				{ "EMOTE", "checks which shoulder the strap is on." }
			},
			inference = {
				{ "SAY", "I heard Dartol's rod called a disguise more than once. The people who saw through it remembered habits, not faces." },
				{ "SAY", "They saw how I wore my pack, how far I stood from the water, which hand I raised in greeting before I thought about it." },
				{ "SAY", "I can borrow a shape. I still carry an awful lot of myself into it." },
				{ "EMOTE", "settles back into his usual seat." }
			}
		}
	},
	{
		id = "billy_pie", title = "The Price of a Pie", voice = "memory",
		note = "Elwynn Forest · A lost necklace and a pork belly pie.",
		sources = {
			"https://www.wowhead.com/forever/quest=86/pie-for-billy",
			"https://www.wowhead.com/forever/quest=84/back-to-billy"
		},
		lines = {
			{ "SAY", "I asked Billy Maclure in Elwynn if he knew where a missing necklace had gone. He told me he might remember after a pork belly pie." },
			{ "SAY", "Bernice baked it with meat I'd fetched from the boars near the farms. Then she told me exactly what she hoped would happen to the boy when he ate it.", aside = {
				"SAY", "I have never seen anyone pinch a pastry crust with quite that much feeling."
			} },
			{ "SAY", "I carried it over to Billy. He finished the edge first. By the time he got to the middle, he'd remembered where I ought to look.", replies = {
				{ "Did you get the necklace?", "SAY", "Yes. Goldtooth had it. Billy could have told me that in the time it took him to eat the first bite.", cues = { { "necklace", "goldtooth" }, { "where", "who", "get", "find", "found", "had" } } }
			} },
			{ "EMOTE", "brushes a crumb from his knee." },
			{ "SAY", "On my way back, Bernice asked if I'd passed along her message. I told her the boy had eaten too fast for me to get a word in. She put another pie in the oven." }
		},
		variants = {
			hearsay = {
				{ "SAY", "I heard from a farmhand in Elwynn that Billy Maclure knew where a missing necklace had gone. He also knew exactly who baked the best pie." },
				{ "SAY", "Bernice told it differently. In her version, a perfectly good pie had been spent to find out what a boy might have told us for the price of an honest question." },
				{ "SAY", "I had already asked the honest question. I was the one she sent for the boar meat." },
				{ "EMOTE", "holds both hands up, empty." }
			},
			inference = {
				{ "SAY", "Billy knew which pie he wanted, who could make it and who would come asking about the necklace. He barely stopped to think." },
				{ "SAY", "Bernice knew he would ask for a pie before I told her. She was already clearing the flour off a shelf." },
				{ "SAY", "I thought I'd walked into a mystery. I think I walked into an argument those two had been having for years." },
				{ "EMOTE", "nudges a stray crumb back onto his plate." }
			}
		}
	},
	{
		id = "mornbrew", title = "Five Minutes to Anvilmar", voice = "memory",
		note = "Dun Morogh · Nori Pridedrift's delivery of hot mornbrew.",
		sources = { "https://www.wowhead.com/forever/quest=3364/scalding-mornbrew-delivery" },
		lines = {
			{ "SAY", "Nori Pridedrift handed me a mug in Dun Morogh and said I had five minutes to get it to Durnan Furcutter in Anvilmar while it was still hot." },
			{ "SAY", "I wrapped it in the spare cloth inside my coat. By the second bend I couldn't feel my ears, but I knew exactly where the mug was.", aside = {
				"SAY", "Elune, I had never been so jealous of a hot drink.", darnassian = true
			} },
			{ "SAY", "Durnan took one sip, sighed and said he was going to sit for a while. I thought that sounded marvellous.", replies = {
				{ "Was it still hot?", "SAY", "Hot enough. He blew on it before the first sip. I remember because I was doing the same thing to my fingers.", cues = { { "brew", "mornbrew", "mug", "drink", "hot", "cold" }, { "still", "hot", "cold", "warm" } } }
			} },
			{ "EMOTE", "cups his hands around his own mug." },
			{ "SAY", "Then I remembered I had promised to bring the mug back. At least there was no hurry once it was empty." }
		},
		variants = {
			hearsay = {
				{ "SAY", "Nori tells it as the day he trusted an elf with the most important delivery in Dun Morogh. Durnan remembers it as the day his drink turned up on time." },
				{ "SAY", "I remember the man in the doorway who asked whether I'd been chased all the way to Anvilmar. I told him the thing chasing me was cold." },
				{ "EMOTE", "tucks his hands a little deeper into his sleeves." },
				{ "SAY", "That is roughly the only thing on which the three of us agree." }
			},
			inference = {
				{ "SAY", "I thought Nori was in such a hurry because Durnan hated a cold drink. Then I watched him sit down and take his first proper break." },
				{ "SAY", "Nobody else came to cover for Durnan or told him to rest. A hot cup gave him an excuse he could hold in both hands." },
				{ "SAY", "I suspect that's what Nori was really trying to get there before it grew cold." },
				{ "EMOTE", "leaves the mug within easy reach." }
			}
		}
	},
	{
		id = "marsh_gas", title = "Eight Vials of the Future", voice = "memory",
		note = "Riverglades · Sleebo Fizzlespout and his marsh-gas engine.",
		sources = { "https://www.wowhead.com/forever/quest=96063/gaseous-gold" },
		lines = {
			{ "SAY", "Sleebo Fizzlespout told me the future was bubbling up out of a pond in the Riverglades. He wanted eight vials of it." },
			{ "SAY", "The trick was to get to the vent without planting your boot in the mud. I worked that out just after I planted my boot in the mud.", aside = {
				"SAY", "I admire anyone who can call something the future and get someone else to stand in it."
			} },
			{ "SAY", "By the eighth vial I'd learned to take three steps back before I checked whether I'd caught anything.", replies = {
				{ "What was it for?", "SAY", "An engine. Sleebo told me that much. The inside of it was a trade secret.", cues = { { "gas", "vials", "sleebo", "engine" }, { "what", "for", "why", "work" } } }
			} },
			{ "EMOTE", "gives one heel a little twist against the ground." },
			{ "SAY", "When I got back, he asked how I'd managed to get hold of so much. I pointed at my missing boot. He asked whether I wanted a dry seat or a higher price. I said both." }
		},
		variants = {
			hearsay = {
				{ "SAY", "A goblin in the Riverglades told me he'd seen a druid bottle eight helpings of marsh gas. In his telling, the druid knew exactly what he was doing." },
				{ "SAY", "Another person remembered an elf walking out of the marsh with one boot. I asked which of those people she'd rather trust with an engine." },
				{ "SAY", "She said she'd trust either of them to bring the gas. She wanted Sleebo to stand nearest when it started." },
				{ "EMOTE", "takes half a step farther from the fire." }
			},
			inference = {
				{ "SAY", "Sleebo said the gas came up by the ton. He spent a long while checking each of my little vials against the light." },
				{ "SAY", "That made me wonder whether there was a difference between how much of a thing the world gives you and how much you can persuade it to put in a bottle." },
				{ "SAY", "If there is, I suspect the whole future will have to wait for somebody to solve it without losing a boot." },
				{ "EMOTE", "scrapes something imaginary off the side of his heel." }
			}
		}
	},
	{
		id = "bear_nappy", title = "Twelve Intact Scalps", voice = "memory",
		note = "Darkshore · A private errand after Buzzbox 525.",
		sources = { "https://www.wowhead.com/forever/quest=1003/buzzbox-525" },
		lines = {
			{ "SAY", "Wizbang once sent me after four bear scalps in Darkshore. The machine wanted them for beer. I thought I'd heard the strangest request Auberdine had to offer." },
			{ "SAY", "Then a dwarf on the docks asked me for twelve. Intact, he said. He had a new bairn at home and was working on something that couldn't have a hole in it." },
			{ "EMOTE", "holds a finger and thumb apart to show the size of a tear." },
			{ "SAY", "I must have fought eighty bears before I had twelve he'd take. Eighty if I count the ones that chased me up a tree twice. Which I do.", replies = {
				{ "Did you count them?", "SAY", "I started keeping tally after the second tree. By then I was in a mood to round up.", cues = { { "bears", "eighty", "80", "them" }, { "count", "many", "really" } } },
				{ "Why did you agree?", "SAY", "He asked while his daughter was asleep on his chest. You try saying no to a man who doesn't dare move his eyebrows for fear of waking her.", cues = { { "agree", "help", "yes" }, { "why", "what" } } }
			}, aside = { "SAY", "If a dwarf ever says the word 'intact' twice, ask what he's making before you agree to anything." } },
			{ "SAY", "When I brought them in, I asked what she was getting. A winter coat? A rug? He said, 'A nice nappy. Her mother asked for a spare.'" },
			{ "SAY", "Elune, grant me patience.", darnassian = true },
			{ "SAY", "She grew out of it by spring. I'm told it makes a very good tea cosy." }
		},
		variants = {
			hearsay = {
				{ "SAY", "A dockhand in Auberdine still tells the story of the dwarf who asked for twelve intact bear scalps. In his version, the elf who brought them back had fought a hundred bears." },
				{ "SAY", "In the dwarf's version, the elf did it in one afternoon. His wife says the only thing either of those men got right was what she needed the hides for." },
				{ "SAY", "A spare nappy. By the time the story reached me again, it was a winter cloak for a princess." },
				{ "EMOTE", "drinks slowly, looking very hard at the fire." }
			},
			inference = {
				{ "SAY", "Looking back, the dwarf wanted the twelve pieces all about the same size. He kept folding a bit of cloth into thirds while we talked." },
				{ "SAY", "He asked if I could get the fur soft and whether I'd mind being paid in soap. At the time I thought he was doing something terribly secret." },
				{ "SAY", "Then his wife came down to the docks with the baby and asked if he'd told me it was only for a spare nappy." },
				{ "SAY", "Isn't it odd what a man can convince himself he's been hired for when he doesn't want to ask a simple question?" }
			}
		}
	},
	{
		id = "wetlands_crates", title = "The King in a Barrel", voice = "memory",
		note = "Wetlands · Searching the murloc camps for lost cargo.",
		sources = { "https://www.wowhead.com/forever/quest=281/reclaiming-goods" },
		lines = {
			{ "SAY", "Karl Boran sent me up the Wetlands coast to recover a little statue of King Terenas. The murlocs had taken it off the Blind Princess along with some of her cargo." },
			{ "SAY", "I waited for the first camp to go quiet. It took a good while. Every time I reached for a lid, someone on the beach found a new reason to shout." },
			{ "EMOTE", "pries at the rim of his cup with a thumbnail." },
			{ "SAY", "I opened the first crate and found an armful of red bottles. I carried them off anyway. I'd spent half the afternoon getting near the thing." },
			{ "SAY", "I had to try two more containers before I found His Majesty. I told him he was lucky the murlocs hadn't learned to pack with less straw.", replies = {
				{ "What was in the bottles?", "SAY", "Healing potions. A relief. I'd been duped by one suspicious drink in Darkshore already." }
			} },
			{ "SAY", "Karl asked if the statue had suffered any damage. I said it had kept its feet drier than I had." }
		},
		variants = {
			hearsay = {
				{ "SAY", "A sailor from the Blind Princess told me the first crate the murlocs took was the one they could carry without bumping into each other." },
				{ "SAY", "A man at the harbour swore they'd picked it because it sounded valuable. I asked him what a valuable crate sounded like." },
				{ "SAY", "He tapped his cup and said, 'Like you're about to lose the deposit on it.'" },
				{ "EMOTE", "runs his fingers around the base of the cup before setting it down." }
			},
			inference = {
				{ "SAY", "One crate on the Wetlands shore held potions. Farther along, in a different container, was a king made of stone. Scratch marks and wet straw in all the wrong places." },
				{ "SAY", "I kept wondering why murlocs would steal a statue. The first crate gave me a better question. Why did I think they'd opened it before carrying it away?" },
				{ "EMOTE", "sets his cup and a pebble behind two pieces of bark." },
				{ "SAY", "If you had to pick up one of those in a hurry, in water up to your waist, would you stop to look inside first?" }
			}
		}
	},
	{
		id = "duskwood_supper", title = "Supper for Jitters", voice = "memory",
		note = "Duskwood · A hungry man and Chef Grual's crab cakes.",
		sources = { "https://www.wowhead.com/forever/quest=5/jitters-growling-gut", "https://www.wowhead.com/forever/quest=240/return-to-jitters" },
		lines = {
			{ "SAY", "Jitters was hiding out near Raven Hill. He'd been living on grubs and weeds, he said, and asked me to fetch the crab cakes Chef Grual makes in Darkshire." },
			{ "SAY", "Grual sent me looking for spider legs. I asked when the crab went in. He just asked whether I'd rather go back and explain to Jitters why he hadn't any supper." },
			{ "EMOTE", "wipes an imaginary speck from his sleeve." },
			{ "SAY", "I took it back wrapped in a cloth. Jitters smelled it through the cloth and asked if it was the real thing.", replies = {
				{ "Did you tell him?", "SAY", "I told him it was hot. That was the part he needed to know before he got his fingers in it." },
				{ "A blessing for Jitters", "SAY", "May you never have to make a feast out of weeds again.", darnassian = true }
			} },
			{ "SAY", "He ate in silence for a while. Then he folded the cloth up as neat as could be, handed it back and asked if I'd tell the chef he'd tasted the sea." }
		},
		variants = {
			hearsay = {
				{ "SAY", "The woman at the next table in Darkshire swore Chef Grual's crab cakes had once been made with actual crab." },
				{ "SAY", "A man at the bar said they'd always been spider and that she'd only started complaining after she learned the recipe." },
				{ "SAY", "Grual brought them another plate. They finished it before either remembered what they'd been arguing about." },
				{ "EMOTE", "glances at whatever is cooking over the fire." }
			},
			inference = {
				{ "SAY", "I spent a while trying to understand why a man hiding in Duskwood asked for crab cakes. He could have asked for bread and been eating an hour sooner." },
				{ "SAY", "Then I saw the care with which he folded the cloth afterwards. I do that too when someone makes me something I used to eat at home." },
				{ "SAY", "Could be he knew about the spider legs all along. He asked for them by the name he remembered from before he had to hide." },
				{ "EMOTE", "folds a corner of his cloak back off the ground." }
			}
		}
	},
	{
		id = "rolled_satchel", title = "All That for a Nap", voice = "memory",
		note = "Loch Modan and Hillsbrad · The trail to the Cozy Sleeping Bag.",
		sources = { "https://www.wowhead.com/forever/quest=79976/this-must-be-the-place" },
		lines = {
			{ "SAY", "I followed a trail of little clues that took me out onto a ledge on the Loch Modan dam. There was a carved eagle there. I was hoping to find a way back up." },
			{ "SAY", "The trail went on to Thoradin's Wall. I climbed it by way of an overturned cart, lost my footing once and finished the climb in a temper." },
			{ "SAY", "Elune, let the next clue be on the ground.", darnassian = true },
			{ "SAY", "At the end I found a rolled-up satchel. Inside it was a sleeping bag.", replies = {
				{ "Was it worth it?", "SAY", "Ask again after I've slept. That's what I told the first person who asked." }
			} },
			{ "SAY", "I was going to be annoyed about that. Then I put the thing down, meant to sit for a moment and woke up after sunset." }
		},
		variants = {
			hearsay = {
				{ "SAY", "A traveller in Hillsbrad told me a druid had gone up Thoradin's Wall like a cat. A second traveller told me he'd gone up it like a cat being carried by the scruff." },
				{ "SAY", "Both agreed he'd climbed past a hanging bag and stopped looking when he found a satchel." },
				{ "SAY", "I never did find out which view either of them had from below. I do know what I looked like when I came down again. Well rested." },
				{ "EMOTE", "tries very hard to look dignified." }
			},
			inference = {
				{ "SAY", "Whoever left the trail knew which ledges people would trust their boots on. The eagle was where you'd catch sight of it just as you thought about turning back." },
				{ "SAY", "The last clue was a bag hung out where someone below could see it. The thing worth carrying away was tucked closer to hand." },
				{ "SAY", "I used to think they were hiding treasure. I've since wondered if they'd found a good place to sleep and taken a curious way of passing it on." },
				{ "EMOTE", "glances over at the softest-looking patch of ground." }
			}
		}
	}
}

for _, story in ipairs(adventures) do
	story.adventure = true
	ns.stories[#ns.stories + 1] = story
end
