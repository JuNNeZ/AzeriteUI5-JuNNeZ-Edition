local _, ns = ...

local stories = {
	{
		id = "cat_rafters", title = "The Cat Above the Door", voice = "memory", personal = true,
		note = "Nighthaven · An early lesson in thinking like a cat.",
		sources = {},
		lines = {
			{ "SAY", "The first time I managed to take a cat's shape and keep it, I went up into the rafters in Nighthaven. There was a roomful of people who'd said I couldn't. I wanted them to look up." },
			{ "SAY", "The climb was easy. It took me half an hour to admit that everything I could put a paw on going up was behind me on the way down.", replies = {
				{ "How did you get down?", "SAY", "A woman hanging linen put her basket on a stool. I got both front paws in and we pretended I'd meant to inspect the laundry.", cues = { { "down", "rafters", "cat" }, { "how", "climb", "help", "get" } } }
			}, aside = { "SAY", "Elune, I could have done with a little less dignity.", darnassian = true } },
			{ "EMOTE", "checks the branches directly overhead before carrying on." },
			{ "SAY", "My shan'do saw the whole thing. She said I'd learnt to go up like a cat. When I asked what else there was to learn, she handed me the basket." },
			{ "SAY", "I folded linen until supper. Every time she passed the door she looked up, just as I'd wanted." }
		},
		variants = {
			hearsay = {
				{ "SAY", "A woman in Nighthaven swore there'd been a cat in the rafters with the expression of a druid who'd misplaced his feet. She was remarkably kind about his chances of ever being seen again." },
				{ "SAY", "She says she left a basket below him, went back to her work, and heard the smallest thump. When she looked again there was a young man folding her linen." },
				{ "EMOTE", "takes a very long sip." },
				{ "SAY", "In her telling, he never said thank you. I thought I had. I may still have been a cat when I said it." }
			},
			inference = {
				{ "SAY", "I used to wonder why my shan'do watched the cat in the rafters without fetching a ladder." },
				{ "SAY", "She could see the basket was coming. She could also see I knew it was there. All she had to do was let me decide I wanted help more than I wanted to look graceful." },
				{ "EMOTE", "turns both palms upwards." },
				{ "SAY", "That's the explanation I prefer. There is also the possibility she wanted somebody to do the folding." }
			}
		}
	},
	{
		id = "first_patient", title = "The Patient Who Said No", voice = "memory", personal = true,
		note = "Ashenvale · His first visit as a healer without his mentor.",
		sources = {},
		lines = {
			{ "SAY", "My first patient on my own was a hunter in Ashenvale who'd limped home with a thorn through the sole of her boot. I had my hands lifted before I'd asked her a thing." },
			{ "SAY", "She said no. I thought she was afraid it would hurt. She asked if I'd ever tried getting a boot off once the ankle had swollen around it.", aside = {
				"SAY", "Some of us learn to look terribly solemn before we learn how to be any help."
			} },
			{ "SAY", "So I put the kettle on and found a small knife. She told me where to cut the stitches so she could sew the boot together later.", replies = {
				{ "Did you heal her?", "SAY", "Once the boot and the thorn were out, she asked me to. Then she showed me how to stitch the boot.", cues = { { "heal", "healed", "hunter", "boot", "thorn" }, { "did", "how", "help", "after" } } }
			} },
			{ "EMOTE", "brushes his thumb along the seam of his own boot." },
			{ "SAY", "She gave me the spare needle. I still carry one in the same pocket." }
		},
		variants = {
			hearsay = {
				{ "SAY", "I heard my first patient tell the story to another hunter. In her version, a young druid stood in her doorway looking terribly worried about casting a spell badly." },
				{ "SAY", "She said she could tell he'd be all right when he asked where she kept her kettle. I remember asking because I needed something to do with my hands." },
				{ "SAY", "She never mentioned the spell when she told it. She told the other hunter he could trust me with a knife and a good pair of boots." },
				{ "EMOTE", "raises his cup a little, as if to an old friend." }
			},
			inference = {
				{ "SAY", "I thought a hunter refusing help meant she wanted to be left alone. She had already put a second cup out by the time I reached the door." },
				{ "SAY", "She showed me the damaged stitches, not the wound. When I finally asked what she wanted done first, she passed me a knife handle-first." },
				{ "SAY", "I think she knew exactly what sort of help she wanted. It took me a while to notice she'd been showing me." },
				{ "EMOTE", "turns the handle of his cup towards the next person." }
			}
		}
	},
	{
		id = "boot_seed", title = "The Seed in My Boot", voice = "memory", personal = true,
		note = "Ashenvale · A seed and a disagreement with his sister.",
		sources = {},
		lines = {
			{ "SAY", "My sister gave me a seed to plant when I left home to train. I carried it in my boot, wrapped in a bit of cloth. It was the one place I couldn't forget it." },
			{ "SAY", "My first shan'do asked why I never planted it. I said I was waiting until I knew enough to make it grow.", aside = {
				"SAY", "I was forever waiting to be good at things before I let anyone see me try."
			} },
			{ "SAY", "When I went home, my sister asked how it was doing. I showed her the seed, and she got another one out of a kitchen jar.", replies = {
				{ "What kind of seed?", "SAY", "A squash. She could never understand why I carried a perfectly ordinary squash seed halfway across Ashenvale.", cues = { { "seed", "squash", "plant" }, { "kind", "which", "what", "grow" } } }
			} },
			{ "EMOTE", "holds a thumb and finger close together." },
			{ "SAY", "We planted both by the doorstep. The one from the jar came up first. She put a marker by mine so I'd know which patch to water." }
		},
		variants = {
			hearsay = {
				{ "SAY", "My sister likes to say she sent me off to learn druidry with a squash seed, and I brought it home entirely unchanged." },
				{ "SAY", "She tells people she put her own seed beside it because she thought I'd lost the first. I remember her asking if I wanted the two planted close enough to keep each other company." },
				{ "SAY", "In every telling she has the better squash. I won't argue with her about that. I've eaten it." },
				{ "EMOTE", "shakes his head with the hint of a smile." }
			},
			inference = {
				{ "SAY", "I always assumed my sister picked the smallest thing she could give me when I left for training. There was no room left in my pack." },
				{ "SAY", "Years later I saw her hand another seed to someone leaving. She told them where the jar would be if they needed a second." },
				{ "SAY", "It occurs to me I could have planted mine anywhere. Maybe she was giving me a reason to let her know where I'd ended up." },
				{ "EMOTE", "rests a hand briefly against the side of his boot." }
			}
		}
	},
	{
		id = "listening_tree", title = "The Tree I Couldn't Hear", voice = "memory", personal = true,
		note = "Ashenvale · An invented childhood memory.",
		sources = {},
		lines = {
			{ "SAY", "When I was little, I used to climb a tree in Ashenvale with a crooked limb. I told my family it was because I could hear the forest better up there." },
			{ "SAY", "My sister said I climbed it because I couldn't hear her calling me in to wash the bowls. She was right. I resented her for it all the way down.", replies = {
				{ "What was your sister like?", "SAY", "She had a better ear for lies than I had for trees. If you ask her, she still does.", cues = { { "sister" }, { "who", "like", "name", "older" } } }
			}, aside = { "SAY", "I still think anyone who washes the bowls ought to have first pick of where to sit." } },
			{ "EMOTE", "looks up through the branches before looking back at the fire." },
			{ "SAY", "One night I went up to get away from an argument and heard a whole nest moving on the other side of the trunk. I'd been climbing past it all summer." },
			{ "SAY", "I came down and washed both our bowls. I wanted her to come up with me the next night." }
		},
		variants = {
			hearsay = {
				{ "SAY", "My sister says I spent half my childhood up a tree. She only exaggerates about how often she had to come up after me." },
				{ "SAY", "She remembers the first night I asked her to climb it with me. She thought I wanted her to cover for me. I wanted her to hear the nest I'd found." },
				{ "EMOTE", "tips his head as if expecting to hear something in the dark." },
				{ "SAY", "She says she heard it before I did, and that she kept quiet so I'd have the pleasure of pointing it out." }
			},
			inference = {
				{ "SAY", "I used to think my sister knew where to find me in Ashenvale because she could follow my tracks. I was very careful to leave tracks that went the wrong way." },
				{ "SAY", "Years later I noticed you can see the crooked limb of that tree from our old doorstep. You can see anyone sitting on it, too." },
				{ "SAY", "What do you suppose she thought, watching me climb out there and pretend I'd escaped the chores?" },
				{ "EMOTE", "smiles into his cup." }
			}
		}
	},
	{
		id = "first_lesson", title = "My Shan'do's Bad Knee", voice = "memory", personal = true,
		note = "Ashenvale · His first lessons with an imagined mentor.",
		sources = {},
		lines = {
			{ "SAY", "My first shan'do made me take the same path through Ashenvale every morning. I used to get angry because the route was slow and wound twice around the hill." },
			{ "SAY", "One day I went straight up the hill. She was waiting at the top, sitting down. She asked what I'd seen. I told her I'd seen how much time the other path wasted.", aside = {
				"SAY", "I still dislike a lesson whose first requirement is pretending you don't know the answer."
			} },
			{ "SAY", "She asked if I'd seen the fox den, the fresh water, or which part of the slope she'd have trouble walking down on her bad knee.", replies = {
				{ "Why the longer route?", "SAY", "There were more places to sit down, and she could lean on the same trees on the way back.", cues = { { "route", "path", "longer", "knee" }, { "why", "how", "what" } } }
			} },
			{ "EMOTE", "rubs the side of his knee through the cloth." },
			{ "SAY", "The next morning I carried two cups. I still wanted to know where the fox was. I also wanted her to be able to stop before she had to ask." }
		},
		variants = {
			hearsay = {
				{ "SAY", "My shan'do told this better than I do. She said she'd finally found an apprentice quick enough to climb a hill and slow enough to take a month to notice what was on it." },
				{ "SAY", "According to her, I brought a cup up the hill to show I'd learnt something. According to me, I brought two cups because I was thirsty and had a little sense by then." },
				{ "EMOTE", "sets his cup down with exaggerated care." },
				{ "SAY", "She kept the second cup. I think she liked that part of her version best." }
			},
			inference = {
				{ "SAY", "I used to think my shan'do had planned every lesson. She always knew which roots to sit on and which side of the hill would stay dry." },
				{ "SAY", "Then I remembered it rained the night she stopped taking the short path. I think her knee hurt, and she'd simply found a better route." },
				{ "SAY", "I wonder how many so-called teachings started because someone needed a more comfortable place to sit." },
				{ "EMOTE", "moves a loose stone out from under the edge of his seat." }
			}
		}
	},
	{
		id = "bear_lesson", title = "The Bear Who Let Me Wait", voice = "memory", personal = true,
		note = "Moonglade · His account of a lesson with the Great Bear Spirit.",
		sources = { "https://www.wowhead.com/forever/quest=5929/great-bear-spirit" },
		lines = {
			{ "SAY", "Dendrite Starblaze sent me to the Great Bear Spirit in Moonglade. I practised three ways to ask about strength on the way there." },
			{ "SAY", "I went straight to the longest one. Afterwards I stood there waiting to hear whether I'd been clever enough.", aside = { "SAY", "Elune, I must have been hard to put up with.", darnassian = true } },
			{ "SAY", "By the time I stopped thinking about my speech, I'd noticed how much noise I was making every time I moved my feet.", replies = {
				{ "What did the bear teach you?", "SAY", "I came away thinking strength was worth little if I couldn't keep still when someone needed me to.", cues = { { "bear", "spirit", "lesson" }, { "teach", "taught", "learn", "lesson" } } }
			} },
			{ "EMOTE", "loosens his fingers around the cup." },
			{ "SAY", "Dendrite asked me what I had learnt. I gave him the short answer. That was how I could tell I'd learnt something." }
		},
		variants = {
			hearsay = {
				{ "SAY", "A druid I trained beside likes to tell people I spent an afternoon trying to impress the Great Bear Spirit." },
				{ "SAY", "She told me later she'd done the same thing. We had each thought the other knew how to do it properly." },
				{ "EMOTE", "looks out into the trees for a breath." },
				{ "SAY", "Dendrite knew us both well enough to send us one at a time. I think that was a kindness." }
			},
			inference = {
				{ "SAY", "I used to think Dendrite sent me to the Great Bear Spirit because he couldn't answer the questions I kept asking." },
				{ "SAY", "Years later I heard an apprentice ask him the same thing. I had an answer ready myself. Dendrite simply told her where to go and let her get on with it." },
				{ "SAY", "I think he knew she'd remember what she noticed on her own. I can't tell you half of what I'd rehearsed on the way there." },
				{ "EMOTE", "drops a single twig on the fire and watches it settle." }
			}
		}
	}
}

for _, story in ipairs(stories) do
	ns.stories[#ns.stories + 1] = story
end
