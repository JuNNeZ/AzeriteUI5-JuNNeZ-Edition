local _, ns = ...

local stories = {
	{
		id = "hyjal_accord", title = "The Road Both Camps Took", voice = "hearsay", familiar = true,
		note = "Mount Hyjal · Jaina Proudmoore and Thrall's wartime alliance.",
		sources = { "https://worldofwarcraft.blizzard.com/en-us/story/timeline/chapter-4", "https://us.media.blizzard.com/manuals/wow/wow-classic-manual-enUS.pdf" },
		perspectives = {
			memory = "An imagined memory of carrying supplies between camps during the Battle of Mount Hyjal. The druid heard the leaders had joined forces.",
			hearsay = "Two invented witnesses remember how the camps worked together. Jaina and Thrall's cooperation is established; their private discussions are outside the narrator's knowledge.",
			inference = "The druid wonders how the alliance became real to the people on the road. The supply details and his interpretation are original roleplay."
		},
		lines = {
			{ "SAY", "I asked an orc veteran what he remembered of the day Thrall and Jaina fought on the same side. He said he remembered a human touching his shoulder." },
			{ "SAY", "The human wanted him to set down a water barrel so they could carry it together. There was a rough part of the path ahead where the barrel kept catching." },
			{ "SAY", "A woman who'd tended the wounded told me she'd thought someone would have to explain who was allowed to take water when the two camps started sending people." },
			{ "SAY", "She said the men who delivered the first barrel never asked. One held it still and the other tipped it. She filled whatever cups people brought her.", aside = {
				"SAY", "I think about her whenever someone tells me an alliance is made entirely by the people who announce it."
			} },
			{ "SAY", "The orc didn't ask me to remember the name of the man who took the other handle. He said he wished he knew it himself.", question = "How would you have asked the other camp for help that night?", replies = {
				{ "How do you know?", "SAY", "The alliance at Hyjal is well remembered. The part about the barrel comes from people who were there, and neither told me what the leaders said to each other.", cues = { { "you", "alliance", "hyjal", "barrel" }, { "know", "heard", "told", "there" } } }
			} }
		},
		variants = {
			memory = {
				{ "SAY", "I remember carrying a cup up a path on Hyjal after word came that Thrall and Jaina had put their people on the same side for the battle." },
				{ "SAY", "I had dipped the cup from a barrel at our camp. The first person who asked for a drink wore a colour I'd only learnt to watch for as a warning." },
				{ "SAY", "I slowed down. He watched me for a moment, pointed to my knees, and took the cup while I found somewhere to sit. I'd been walking on it too long." },
				{ "SAY", "When he gave the cup back it was still half full. He had taken only a little. I realised then he didn't know how far I had to go for more." },
				{ "SAY", "I told him where the barrel was. He pointed out a shorter path that had stayed quiet. I remember that better than I remember hearing the agreement announced.", question = "What was the first thing somebody from the other camp did for you?", replies = {
					{ "How do you know?", "SAY", "I recall the cup and the path. I heard about the accord the same way most people did, from others trying to get on with the work.", cues = { { "you", "accord", "cup", "hyjal" }, { "know", "heard", "told", "there" } } }
				} }
			},
			inference = {
				{ "SAY", "I've been told the account of Jaina and Thrall's accord at Hyjal more times than I can count. I kept noticing that the tellers disagreed about when it felt real." },
				{ "SAY", "A runner said it was when a human lit the way down. A healer said it was when she ran out of water and somebody she didn't know went for more." },
				{ "SAY", "Both had already been told there was an agreement. They could have named the people who made it. The names hadn't told them who would come back." },
				{ "SAY", "I wonder if each of them was waiting for the first ordinary reason to believe it. The sort of thing you'd never think to leave out until you started telling a history." },
				{ "SAY", "The next time someone tells me what the two armies did together, I'll ask who went for the water. Perhaps they remember a third version.", question = "What would have convinced you the other camp meant to stay?", replies = {
					{ "How do you know?", "SAY", "People who were on the mountain told me what they saw. I put the accounts beside one another. The conclusion is mine.", cues = { { "you", "water", "hyjal", "healer" }, { "know", "heard", "told", "sure" } } }
				} }
			}
		}
	},
	{
		id = "magni_memorial", title = "The Stone Magni Asked For", voice = "memory", familiar = true,
		note = "Ironforge · Magni Bronzebeard and the memorial for Sully Balloo.",
		sources = { "https://www.wowhead.com/forever/quest=700/a-kings-tribute" },
		perspectives = {
			memory = "Firsthand if your druid reported the memorial's completion to Magni in A King's Tribute. The mason's actions and the druid's reactions are imagined.",
			hearsay = "An invented worker remembers the masonry and the conversation afterwards. The stone from Lordaeron and the tribute to Sully Balloo are in the quest.",
			inference = "The druid thinks about what the stone and Magni's words meant to the people who made the memorial. He does not claim to know the king's private thoughts."
		},
		lines = {
			{ "SAY", "A mason in Ironforge sent me to tell King Magni that Sully Balloo's memorial was finished. He'd spoken quite warmly about the stone, which came from Lordaeron." },
			{ "SAY", "I thought a king would want to hear how long the work had taken or whether the stone would last. I remembered the mason rubbing the dust off his fingertips." },
			{ "SAY", "Magni spoke about Sully instead. He said the granite was a small thing alongside the man's life, and he hoped it would help people remember what Sully had given." },
			{ "SAY", "On the way back I asked the mason if he'd known Sully. He said he hadn't. He had asked somebody who did to tell him how to spell the name.", aside = {
				"SAY", "I've never forgotten the care with which he asked. I wish I'd asked him who taught him that."
			} },
			{ "SAY", "Next time I pass through Ironforge I think I'll stop for a breath. I know the name the mason wanted to be sure of now.", question = "Is there a name you would make sure nobody carved wrong?", replies = {
				{ "How do you know?", "SAY", "I carried the message to Magni. He spoke of Sully and the memorial. The mason's question about the name is the part I remember from our own talk.", cues = { { "you", "magni", "sully", "mason" }, { "know", "told", "there", "heard" } } }
			} }
		},
		variants = {
			hearsay = {
				{ "SAY", "A man who helped finish Sully Balloo's memorial in Ironforge told me the stone had come from Lordaeron. He said the last thing he did was brush it clean." },
				{ "SAY", "I asked if he'd been there when they told Magni. He hadn't. Someone came back from the king and said he'd spoken about what Sully had done, not about the work." },
				{ "SAY", "The man sounded quite glad about that. I had asked him first about the stone because I didn't know Sully's name well enough to ask for him." },
				{ "SAY", "He told me the name slowly and asked what I remembered of Lordaeron. I told him what I'd heard of people who'd walked south carrying almost nothing." },
				{ "SAY", "He said the granite had come a long way too. By then I understood why he'd wanted me to remember who it had come all that way for.", question = "Who first told you the story behind a monument you know?", replies = {
					{ "How do you know?", "SAY", "I heard it from someone who helped with the work. What the king said had been brought back to him by another person.", cues = { { "you", "magni", "stone", "memorial" }, { "know", "told", "heard", "there" } } }
				} }
			},
			inference = {
				{ "SAY", "I wondered why a mason from Ironforge spoke of the stone in Sully Balloo's memorial as if it made him think of someone he had known." },
				{ "SAY", "The stone came from Lordaeron. I knew he had worked it and carried some of the dust home on his clothes, but he didn't leave the name to chance." },
				{ "SAY", "Magni said he hoped people would remember what Sully had given. I think the mason's part was to make sure there was a name they could ask about." },
				{ "SAY", "I have walked past names cut so high I could scarcely make them out. I tend to remember the ones I was told once before I saw them on a wall." },
				{ "SAY", "Maybe that is why I'm telling you his. It would be a shame to come all the way to Ironforge and think you remembered only the stone.", question = "Which names do people remember where you come from, and who taught you them?", replies = {
					{ "How do you know?", "SAY", "The memorial, the stone and the king's tribute are the parts I know. What the mason meant by telling me about it is my reading.", cues = { { "you", "magni", "stone", "memorial" }, { "know", "guess", "heard", "sure" } } }
				} }
			}
		}
	},
	{
		id = "cairne_horn", title = "What Cairne Sent After the Horn", voice = "hearsay", familiar = true,
		note = "Mulgore · A Shu'halo hunter's account of Cairne and Arra'chea.",
		sources = { "https://www.wowhead.com/forever/quest=776/rites-of-the-earthmother" },
		perspectives = {
			memory = "He recalls a conversation in Moonglade with a hunter and an interpreter. His memory of that meeting is original roleplay; he did not do the Horde quest.",
			hearsay = "A tauren hunter’s account reaches him via an interpreter in Moonglade. Cairne asking for the horn and sending a party for the carcass comes from the quest.",
			inference = "He interprets the hunt from what a hunter told him in Moonglade. The quest establishes the errand, not Cairne's private reasons."
		},
		lines = {
			{ "SAY", "A tauren hunter in Moonglade told me Cairne Bloodhoof had sent him after Arra'chea, a great kodo out on the plains. Another druid helped us understand one another." },
			{ "SAY", "I expected the story to reach its end when the hunter brought back the horn. He laughed at that and asked the interpreter where I'd got the idea the work stopped there." },
			{ "SAY", "Cairne praised the hunt and sent people for the hide and meat. The hunter was pleased the interpreter remembered that part without having to be told twice.", aside = {
				"SAY", "I have heard many stories that end conveniently before anyone has to carry something heavy."
			} },
			{ "SAY", "By the time we were done speaking, I could tell you more about who went back for the kodo than how the hunter had managed to bring it down." },
			{ "SAY", "When I saw him again I asked after the people who'd helped him. He said I was learning to ask for the rest of a story.", question = "Whose part of a hunt do your people remember when the fire is lit?", replies = {
				{ "How do you know?", "SAY", "I heard it from a hunter in Moonglade, through a druid who interpreted. I've never had Cairne send me down to hunt in Mulgore.", cues = { { "you", "cairne", "hunter", "horn" }, { "know", "heard", "told", "there" } } }
			} }
		},
		variants = {
			memory = {
				{ "SAY", "I remember sitting with two druids in Moonglade. One told us about bringing a kodo's horn to Cairne. The other helped me follow the words." },
				{ "SAY", "I asked how long a person had to carry a horn like that. The hunter put both hands out to show its size, then leaned over to reach for the kettle." },
				{ "SAY", "He wanted to tell us about the people Cairne sent after the carcass. The kettle began to boil, and we all tried to take it off the fire at once." },
				{ "SAY", "The interpreter laughed. By then I understood why we hadn't got to the end yet. I no longer needed every word of what the three of us were talking about." },
				{ "SAY", "It was an ordinary evening in Moonglade. I think of it now when someone tells a story that ends with one person doing all the work.", question = "Have you ever understood the point of a story before you understood all the words?", replies = {
					{ "How do you know?", "SAY", "The evening in Moonglade is what I remember. The hunt was somebody else's, and another druid translated it for me.", cues = { { "you", "horn", "cairne", "moonglade" }, { "know", "heard", "told", "there" } } }
				} }
			},
			inference = {
				{ "SAY", "The first time I heard about Cairne asking for Arra'chea's horn, I thought the horn must have been the point. It was what the hunter had been told to bring." },
				{ "SAY", "Then, every time I heard the account in Moonglade, the hunter talked about the people Cairne sent for the hide and meat. That was where he spent the most time." },
				{ "SAY", "I wonder if I was listening for success and he was telling me what he owed. We had to go slowly enough with translation that I could hear the difference." },
				{ "SAY", "I've been asked for proof of an errand often enough. It doesn't always occur to me to ask what becomes of the things I left once I had my proof." },
				{ "SAY", "That seems worth asking next time someone tells me they came home with the prize. Perhaps the story was just getting to where everyone else comes in.", question = "What tends to be left out of the stories people tell about their own successes?", replies = {
					{ "How do you know?", "SAY", "I heard the hunt from the hunter. The difference between the way he told it and the way I heard it is what I'm trying to explain.", cues = { { "you", "horn", "cairne", "hunt" }, { "know", "heard", "told", "guess" } } }
				} }
			}
		}
	},
	{
		id = "tyrande_ring", title = "The Ring I Brought Tyrande", voice = "memory", familiar = true,
		note = "Darnassus · Tyrande, Jer'kai's signet and a story for the young.",
		sources = { "https://www.wowhead.com/forever/quest=2972/doling-justice" },
		perspectives = {
			memory = "Firsthand if your druid made the delivery in Doling Justice. The details of his reaction and the young listeners are original roleplay.",
			hearsay = "A courier who delivered Jer'kai's signet told him about the temple visit. The courier's anecdotes are original roleplay.",
			inference = "He knows the purpose of the ring from the people who sent it and guesses what the younger listeners needed."
		},
		lines = {
			{ "SAY", "I went to the Temple of the Moon with Jer'kai's ring in my pocket and a speech ready in my head. I was meant to tell Tyrande that the priestess was well." },
			{ "SAY", "Before I could deliver the speech, Tyrande asked whether I had a story for the young adventurers in the temple. There were more of them than I had noticed on the way in.", aside = {
				"SAY", "Elune, I could remember the whole speech and none of their names.", darnassian = true
			} },
			{ "SAY", "I looked at the muddy hem of the nearest one's cloak and realised I'd prepared a speech for the only person in the room who didn't need it." },
			{ "SAY", "The ring would tell her whose errand I'd been on. Someone else needed to hear where I'd gone wrong, so they could leave by a better road than I had." },
			{ "SAY", "I've carried other messages since. When someone asks me to tell a story, I first look around to see who might need to hear it.", question = "What story would you tell someone who was taking their first journey out of Darnassus?", replies = {
				{ "How do you know?", "SAY", "I brought the signet myself. Tyrande asked for a tale in the Temple of the Moon. The speech I forgot was entirely my own fault.", cues = { { "you", "tyrande", "ring", "temple" }, { "know", "there", "told", "witness" } } }
			} }
		},
		variants = {
			hearsay = {
				{ "SAY", "A courier from Feralas told me he brought Jer'kai's ring to Tyrande. He had spent most of the road trying to decide how a person addresses a High Priestess." },
				{ "SAY", "He needn't have worried. What threw him was her asking if he had a tale he could share with the younger adventurers. All his practice went out of his head." },
				{ "SAY", "The young people asked about the walk back instead of his audience with Tyrande. One wanted to know what he did when his boots filled with water." },
				{ "SAY", "That was about all he could remember telling them. When he told me the story, he still remembered exactly where he was standing when the question came." },
				{ "SAY", "I have heard people retell the visit with all sorts of advice from the High Priestess. The courier was quite certain most of the advice came from the children.", question = "What would you have wanted to ask the courier when you were young?", replies = {
					{ "How do you know?", "SAY", "The courier told me himself. I remember his embarrassment better than I remember the words he put in anyone else's mouth.", cues = { { "you", "courier", "tyrande" }, { "know", "told", "heard" } } }
				} }
			},
			inference = {
				{ "SAY", "Jer'kai sent a ring with a messenger to Darnassus. It could say who had sent him, and when he got there he could say whether she was well." },
				{ "SAY", "I wondered why the temple asked such visitors to tell the younger ones stories when the important information would fit on a scrap of paper." },
				{ "SAY", "Then I watched a young traveller argue over which road to take because nobody had ever told her where the low path flooded in the rain." },
				{ "SAY", "The messenger had probably noticed a hundred things irrelevant to the ring. One of them might save the next person an afternoon of walking in wet boots." },
				{ "SAY", "That's what I think Tyrande was making room for. A story can get the useful part across long after the formal message has been delivered.", question = "What do you know now that you wish somebody had told you before your first trip?", replies = {
					{ "How do you know?", "SAY", "Jer'kai's ring and the request for tales are the part I know. Why Tyrande asked is my own reading of it.", cues = { { "you", "ring", "tyrande" }, { "know", "guess", "assume", "sure" } } }
				} }
			}
		}
	},
	{
		id = "tirion_portrait", title = "The Portrait Behind the Moons", voice = "hearsay", familiar = true,
		note = "Plaguelands · Tirion Fordring and the family portrait hidden in Stratholme.",
		sources = { "https://www.wowhead.com/forever/quest=5848/of-love-and-family" },
		perspectives = {
			memory = "Firsthand if your druid retrieved the portrait and returned it in Of Love and Family. His feelings and incidental details are original.",
			hearsay = "A traveller who returned the portrait describes Tirion's response. The traveller's voice and memories are original roleplay.",
			inference = "He pieces together the painter's explanation and a traveller's account of the return. He has no access to Tirion's thoughts."
		},
		lines = {
			{ "SAY", "A traveller in the Plaguelands told me Tirion Fordring had asked for a picture. I thought he meant a map. She said it was the portrait of his family." },
			{ "SAY", "The painter had hidden it behind a painting of the twin moons. My friend said she stopped to brush the dust off the edge before she dared bring it to him." },
			{ "SAY", "Tirion saw it and wept. She had thought she might have to explain where she'd found it. She told me she never had a chance to say a word." },
			{ "SAY", "She remembered holding the picture steady, even after he had hold of it. For a little while she wasn't sure he trusted his hands to carry it." },
			{ "SAY", "Of all the stories I've heard about Tirion, that's the one I think of when someone asks what people fight to keep.", question = "If you could go back for one thing you'd left at home, what would you look for?", replies = {
				{ "How do you know?", "SAY", "The person who brought the picture to him told me. She remembered what she saw. I can only guess what the man himself remembered.", cues = { { "you", "tirion", "portrait", "traveller" }, { "know", "told", "saw", "heard" } } }
			} }
		},
		variants = {
			memory = {
				{ "SAY", "I went into Stratholme looking for a painting of two moons. The painter had told me what lay underneath, and I found myself clearing the old paint away very carefully." },
				{ "SAY", "I had heard Tirion Fordring spoken of often enough that I thought I'd know what to say when I met him again. I rehearsed something on the way back." },
				{ "SAY", "He saw the family portrait and began to weep. I kept one hand at the bottom of the frame so he could take his time with it.", aside = {
					"SAY", "I am glad I had the good sense to leave the speech on the road."
				} },
				{ "SAY", "There were many things I'd meant to ask him about those days. I thought none would make the next few moments any easier, so I stood quietly." },
				{ "SAY", "When I think of the trip now, I have to remind myself there were two moons on the outside. I always remember the picture underneath first.", question = "Have you ever brought something back to someone and only then understood why they wanted it?", replies = {
					{ "How do you know?", "SAY", "I carried the portrait back to Tirion. I saw how he took it. Anything about what he was thinking would be my guess.", cues = { { "you", "tirion", "portrait" }, { "know", "there", "saw" } } }
				} }
			},
			inference = {
				{ "SAY", "Tirion's family portrait had hung openly for years before the painter hid it. I kept wondering what made a painting of the twin moons a good place." },
				{ "SAY", "A traveller suggested people had grown used to it being there, and most would walk past the same wall a hundred times without looking properly." },
				{ "SAY", "I thought about how many objects I've walked past because I knew who they belonged to and believed I'd see the owner again the next morning." },
				{ "SAY", "Then someone told me how Tirion wept when the portrait came back. Tirion must have recognised it straight away. That was about as far as the witness could tell me." },
				{ "SAY", "My guess is the painter hid it where a stranger would see two moons and somebody who knew the family would think to look again.", question = "Is there a place at home you would know even with every familiar thing removed?", replies = {
					{ "How do you know?", "SAY", "The hiding place comes from the painter and the return from the traveller. Why that particular cover worked is what I've tried to put together.", cues = { { "you", "painter", "portrait" }, { "know", "guess", "sure", "told" } } }
				} }
			}
		}
	},
	{
		id = "illidan_freed", title = "The Night Illidan Walked Free", voice = "hearsay", familiar = true,
		note = "Third War · What people said after Tyrande freed Illidan.",
		sources = { "https://news.blizzard.com/en-gb/article/23679744/burning-crusade-classic-the-story-so-far" },
		perspectives = {
			memory = "He remembers how he received the news during the war. This original scene gives him no firsthand knowledge of the prison or Tyrande's decision.",
			hearsay = "He heard accounts after Illidan's release. The division between the invented speakers is roleplay. Their motives for the release are guesses.",
			inference = "He compares the fact of Illidan's release with how different people described it. He does not know Tyrande's private reasons."
		},
		lines = {
			{ "SAY", "The first time I heard Illidan had walked free, I thought the person telling me had got the name wrong. She said it again and told me Tyrande had freed him." },
			{ "SAY", "A Sentinel I knew thought it was about an old wrong. A fighter returning from the war thought it was about getting another blade between us and the Legion." },
			{ "SAY", "Neither had been there with Tyrande. They spoke as if they'd heard her reasons plainly and had only come to me because I seemed to have missed the news." },
			{ "SAY", "I listened to them both because I trusted them both. Later I learned to ask what a person saw before I asked what they thought it meant.", aside = {
				"SAY", "That habit has spared me more arguments than it has ever ended."
			} },
			{ "SAY", "All these years later, I can tell you they agreed on who was free. I can still hear how differently they said his name.", question = "What did your people hear about Illidan when word first reached them?", replies = {
				{ "How do you know?", "SAY", "I heard the news from people coming out of the war. Tyrande freed him. Their explanations of why were their own.", cues = { { "you", "tyrande", "sentinel", "illidan" }, { "know", "told", "sure", "heard" } } }
			} }
		},
		variants = {
			memory = {
				{ "SAY", "I remember the walk home on the day someone said Illidan was free. I stepped aside to let a woman pass and we heard the same name again from farther down the road." },
				{ "SAY", "She stood there with a bundle of food in her arms until someone told her it was Tyrande who had freed him. Then we kept walking, both more slowly." },
				{ "SAY", "I had never seen what was behind the prison doors. I had heard enough about what the Legion was doing that I could understand why people were afraid." },
				{ "SAY", "That woman asked what I thought would happen next. I remember answering as if I knew. I can't remember a single thing I predicted, which is probably for the best." },
				{ "SAY", "What I do remember is that she handed me half the food just before we parted. Whatever we thought of the news, she knew we both had to eat.", question = "Do you remember where you were when you first heard his name?", replies = {
					{ "How do you know?", "SAY", "I remember hearing about his release on the road. I was nowhere near his prison, and neither was the person walking beside me.", cues = { { "you", "prison", "road", "illidan" }, { "know", "there", "hear", "saw" } } }
				} }
			},
			inference = {
				{ "SAY", "I kept two different accounts of Illidan's release in my head until I realised I could lay them side by side and ask what each teller had noticed first." },
				{ "SAY", "One began with a prisoner being freed. The other began with enemies at the edges of the forest and too few people to hold them back." },
				{ "SAY", "Both reached the same act and made a different thing of it. The first person kept coming back to the prisoner. The second kept counting who'd come home." },
				{ "SAY", "I thought that might explain the quarrel better than anything I could guess about Tyrande. I was fond of the two people who told me." },
				{ "SAY", "Sometimes when I tell their story I still find myself trying to decide which of them I would want to be sitting next to on that evening.", question = "If the two accounts came from people you trusted, who would you ask next?", replies = {
					{ "How do you know?", "SAY", "I know the release happened. The pattern is mine, from listening to two people tell it differently.", cues = { { "you", "tyrande", "illidan", "pattern" }, { "know", "guess", "sure", "told" } } }
				} }
			}
		}
	},
	{
		id = "arthas_home", title = "When the Prince Came Home", voice = "hearsay", familiar = true,
		note = "Lordaeron · Arthas' return and a guard's account of the city's fall.",
		sources = { "https://news.blizzard.com/en-gb/article/24302500/warcraft-iii-reforged-forsaken-kingdom-what-s-next-panel-recap" },
		perspectives = {
			memory = "He remembers meeting a refugee after the fall. The encounter is original. He did not witness Arthas's return.",
			hearsay = "A fictional guard tells him what he remembers outside the throne room. The return and killing of Terenas are established in Warcraft III.",
			inference = "He compares a guard and a refugee's account of the welcome and the aftermath. He does not know the prince's motives."
		},
		lines = {
			{ "SAY", "A man who had stood guard in Lordaeron told me people came out to welcome Prince Arthas. He remembered being sure the crowd would know when to go home." },
			{ "SAY", "He told me that part twice. The first time he said people were cheering. The second time he told me who in the crowd he had been hoping to see." },
			{ "SAY", "The news came out that Arthas had killed his father. The guard said by then he no longer knew who he was waiting for orders from." },
			{ "SAY", "I asked him what the prince had looked like. He admitted he'd been watching the people nearest the door and had barely looked at the man he'd come to see." },
			{ "SAY", "I still hear that in his voice when people tell me everyone must have known what was about to happen.", question = "What did you first hear about Lordaeron, and who told you?", replies = {
				{ "How do you know?", "SAY", "A former guard told me after the city fell. He remembered the welcome outside. The news from the throne room reached him later.", cues = { { "you", "arthas", "guard", "lordaeron" }, { "know", "told", "there", "heard" } } }
			} }
		},
		variants = {
			memory = {
				{ "SAY", "I remember meeting a woman travelling south after Lordaeron fell. She had packed a key in a scrap of cloth and taken almost nothing else." },
				{ "SAY", "I asked whether the key was heavy. She said it was the lightest thing she was carrying. Then she asked if I knew for certain what had happened to King Terenas." },
				{ "SAY", "Someone on the road had told us Arthas killed him. That was all I knew. I had to admit I didn't know whether there was anything left for the key to open.", aside = {
					"SAY", "I ought to have asked whether she wanted water first."
				} },
				{ "SAY", "She wrapped it again and asked where the road forked. I remember walking far enough with her that she could see for herself which way the path went." },
				{ "SAY", "When people ask me what the fall of Lordaeron was like, I can tell them about that road. There are people who could tell you much more.", question = "What would you bring if you thought you might never see your door again?", replies = {
					{ "How do you know?", "SAY", "I remember the woman and the key. The news about Arthas was already travelling south with everyone else.", cues = { { "you", "key", "arthas", "woman" }, { "know", "there", "told", "heard" } } }
				} }
			},
			inference = {
				{ "SAY", "One person told me Lordaeron had cheered when Arthas came back. Another was sure nobody could have welcomed him if they'd known what he'd done." },
				{ "SAY", "I asked when they'd each heard that the king was dead. The first had been in the city when the prince came home. The second heard the tale farther south." },
				{ "SAY", "They were talking about different moments, each with the knowledge they had then. It took me a while to realise I'd been trying to make them agree about one afternoon." },
				{ "SAY", "I still don't know what the people in the crowd expected. I know one of them had come hoping to see someone else who was meant to be standing guard." },
				{ "SAY", "That is the part I go back to. Before they knew what we know now, they were people waiting for somebody to come home.", question = "Which part of that day do you think reached the people furthest from the city first?", replies = {
					{ "How do you know?", "SAY", "The guard and a person travelling south told me different pieces. The order is something I've tried to work out from what each of them knew.", cues = { { "you", "king", "order", "guard" }, { "know", "guess", "heard", "told" } } }
				} }
			}
		}
	}
}

for _, story in ipairs(stories) do
	ns.stories[#ns.stories + 1] = story
end
