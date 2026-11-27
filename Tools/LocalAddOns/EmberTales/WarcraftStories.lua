local _, ns = ...

local function AudienceLine(text, question, account, topics)
	return { "SAY", text, question = question, replies = {
		{ "How do you know?", "SAY", account, cues = { topics, { "know", "heard", "there", "told", "guess" } } }
	} }
end

local stories = {
	{
		id = "war1_medivh", title = "The Last Delivery to Karazhan", voice = "hearsay", warcraft = 1,
		note = "Warcraft I · How the news about Medivh reached people outside his tower.",
		sources = { "https://news.blizzard.com/en-us/article/23229617/warcraft-iii-the-story-so-far" },
		perspectives = {
			memory = "An invented visit to a trader long after the war. The druid saw a ledger and heard the family account.",
			hearsay = "An invented carter tells him what changed after Medivh's death. The documented account names Khadgar and Lothar in the confrontation.",
			inference = "He reasons from a trader's memories. He has no firsthand knowledge of the confrontation or the magical events inside Karazhan."
		},
		lines = {
			{ "SAY", "A carter told me his family used to carry goods part of the way to Karazhan. When a delivery stopped, the people on the road were always the last to hear why." },
			{ "SAY", "He remembered being told Khadgar and Lothar had confronted Medivh, and that Medivh was dead. His father still wanted to know what to do with a sack already loaded." },
			{ "SAY", "They took it off the cart, carried it inside, and stood it by the door. For several days his father left a little space beside it in case somebody came to collect it.", aside = {
				"SAY", "I think I'd have left the space there, too."
			} },
			{ "SAY", "Years afterwards the carter could still remember that door opening without anybody coming for the sack. He was less sure how many stories he'd heard about the tower by then." },
			AudienceLine("I asked when he stopped expecting an answer. He said the family began using the grain, one handful at a time. He didn't remember who took the first handful.",
				"What did your family keep doing when all the news in the world said things had changed?",
				"I heard the tower story from a carter who had lived on the route. The part he knew best was what his family did with the delivery.", { "you", "medivh", "carter", "khadgar" })
		},
		variants = {
			memory = {
				{ "SAY", "Long after the First War, a man in Stormwind showed me a ledger his father had kept. There was one delivery he had crossed out so hard the page had almost torn." },
				{ "SAY", "He told me it was the last load meant for the road to Karazhan. The news came back about Khadgar, Lothar and the death of Medivh before the cart went out." },
				{ "SAY", "I put a finger under the torn bit while he turned the page. The next thing in the book was somebody buying a little grain for home." },
				{ "SAY", "He asked if I thought his father should have left the old entry alone. I said I was glad he'd written down what happened to the grain." },
				AudienceLine("There are nights when I remember that conversation quite clearly. I can tell you which page he opened first, and what he was most careful to let me touch.",
					"Have you ever learnt something about a war from a record that wasn't trying to tell its history?",
					"I was there for the ledger. The owner had the family account. What happened between Khadgar and Medivh reached him by word of mouth.", { "you", "ledger", "karazhan", "khadgar" })
			},
			inference = {
				{ "SAY", "When I heard Medivh was killed during the First War, people told it as a clean change from one day to the next. A carter remembered several days of waiting." },
				{ "SAY", "He could tell me what he heard about Khadgar and Lothar. He could also tell me how long his father left something packed by the door before putting it away." },
				{ "SAY", "It occurred to me that knowing a lord was dead and understanding the road to his house would never be the same were things he learned at different speeds." },
				{ "SAY", "I wonder how many people were doing ordinary work that week because nobody had yet told them what ordinary work would look like when they began again." },
				AudienceLine("The carter said his father kept the road in the ledger. It stayed there long after there was any reason to know how to find the turning.",
					"What would have made it real to you that nobody was coming back for the delivery?",
					"The carter gave me the dates as he remembered them. The difference between hearing the news and living with it is my interpretation.", { "you", "carter", "medivh", "delivery" })
			}
		}
	},
	{
		id = "war2_alleria", title = "Alleria and the Far Bank", voice = "hearsay", warcraft = 2,
		note = "Warcraft II · Alleria Windrunner and the high elves sent to aid Lordaeron.",
		sources = { "https://news.blizzard.com/en-us/article/23229617/warcraft-iii-the-story-so-far" },
		perspectives = {
			memory = "He recalls an invented meeting with a veteran of the Second War. He did not march with Alleria.",
			hearsay = "An invented veteran describes a crossing made with high elf rangers. Alleria leading part of the aid from Quel'Thalas is established.",
			inference = "He puts together a veteran's account of relying on unfamiliar allies. The crossing and correspondence are original roleplay."
		},
		lines = {
			{ "SAY", "A veteran told me Alleria Windrunner came with the high elves sent to help Lordaeron. His first question for one of their rangers was whether he could see the far bank." },
			{ "SAY", "He could. The water ran over the stones in the middle, and a man with a pack could put both feet wrong just where the river looked easiest to cross." },
			{ "SAY", "The veteran remembered the ranger going first and standing with a pole until the others reached him. He didn't know the name of the person who lent him the pole.", aside = {
				"SAY", "I suspect a fair number of agreements have depended on the person who brought a long enough stick."
			} },
			{ "SAY", "I asked whether Alleria herself had been there. He said he'd heard her name when the company arrived. He knew the person in the river by the colour of his hands." },
			AudienceLine("When he told the story at home, he always began with Alleria. By the time he'd finished he was talking about a man who spent an afternoon standing in cold water.",
				"Who was the first person from another people that you had to trust?",
				"The high elves came to aid Lordaeron. An old soldier told me about the crossing. The ranger in the river was the part he could answer for.", { "you", "alleria", "ranger", "river" })
		},
		variants = {
			memory = {
				{ "SAY", "In Stormwind an old soldier asked whether I was related to the elf who helped him cross a river in the Second War. I asked him what sort of elf he'd been." },
				{ "SAY", "The man named Alleria Windrunner straight away. When I asked if that meant he'd crossed with her, he looked uncertain and drew a little picture on the table." },
				{ "SAY", "In the picture the ranger stood in the water. The man could even remember which hand the ranger had offered him. He was sorry he couldn't remember his name." },
				{ "SAY", "I told him he could remember several things a person might be glad to have remembered. He asked me to leave the little river there until he was ready to go." },
				AudienceLine("I sat with him a little longer. I never saw the place he drew. I could have shown you the shallows from his picture afterwards.",
					"Have you ever drawn a place so someone else could remember it with you?",
					"The old soldier showed me where they crossed. I remember the drawing and his company. The crossing was his memory.", { "you", "crossing", "ranger", "alleria" })
			},
			inference = {
				{ "SAY", "Someone once used Alleria's name to explain why the high elves came to help in the Second War. The man who said it couldn't remember the face of a single commander." },
				{ "SAY", "He could show me how a ranger had held a pole while he felt for a place to put his feet. I asked when he had learnt who sent those rangers." },
				{ "SAY", "He remembered later, after he had dried out. I think the order made a difference to him because there was already a person he could think of when he heard it." },
				{ "SAY", "I've heard people speak a famous name as if it were the whole answer to a question. Perhaps the name is sometimes how they start looking for the answer they actually kept." },
				AudienceLine("I think he used Alleria's name because that was the part the rest of us knew. The man in the river was the reason he kept telling it.",
					"Which name would get you to listen long enough to hear somebody you didn't already know?",
					"I heard the soldier. The reason he began with Alleria is something I've put together since.", { "you", "alleria", "soldier", "name" })
			}
		}
	},
	{
		id = "war2_khadgar_portal", title = "Khadgar's Name in Stone", voice = "memory", warcraft = 2,
		note = "Warcraft II: Beyond the Dark Portal · The expedition and Stormwind's memorial.",
		sources = { "https://worldofwarcraft.blizzard.com/en-gb/story/timeline/chapter-03", "https://news.blizzard.com/en-us/article/20142731/welcome-to-stormwind-a-guided-tour", "https://www.wowhead.com/news/warcraft-movie-characters-where-are-they-in-game-253458" },
		perspectives = {
			memory = "He remembers reading the memorial in Stormwind. The conversation and companion are original, and he knows only what the city believed about the expedition.",
			hearsay = "He repeats how someone in Stormwind understood the expedition and the closure of the portal. What happened to Khadgar beyond it is unknown to the narrator.",
			inference = "He interprets the public memorial and accounts heard from people waiting in Azeroth. He leaves the expedition's later fate unresolved."
		},
		lines = {
			{ "SAY", "At the entrance to Stormwind I stopped to read the stone beneath Khadgar. A woman beside me asked whether I had got to the bit about what they believed had happened to him." },
			{ "SAY", "I had. The expedition had gone through the Dark Portal and people here presumed he was dead. The woman asked if that was what I would have put on the stone." },
			{ "SAY", "I said I couldn't think of a better word for it. She thought a word could be right and still make her read it twice every time she passed.", aside = {
				"SAY", "I never understood how much room a small word could leave until I saw it cut in stone."
			} },
			{ "SAY", "We walked toward the city for a bit. Since I had stopped, she had someone to tell about the first time anybody brought the news that the portal was shut." },
			AudienceLine("I can't tell you what Khadgar saw on the other side. Sometimes I can remember the sound of our feet on the bridge better than the words on the stone.",
				"What would you put on a memorial for someone whose journey you couldn't follow?",
				"I read the stone. A woman in Stormwind told me what the news had sounded like here. I know if I tell the story where that knowledge ends.", { "you", "khadgar", "stone", "portal" })
		},
		variants = {
			hearsay = {
				{ "SAY", "Someone in Stormwind told me people were glad to hear the Dark Portal had been shut when Khadgar and the others were beyond it. Then they asked when he would be coming home." },
				{ "SAY", "The man telling me said he used to stop and read the inscription about Khadgar, hoping someone would think to put on a new line if they heard more." },
				{ "SAY", "I asked what he wanted the line to say. He said he would settle for hearing somebody had seen a fire from the other side and knew who lit it." },
				{ "SAY", "I suppose he had learnt enough from the people who came back from other wars to know there are times when much smaller news will do." },
				AudienceLine("The last time we spoke he gave me directions over the bridge. I asked if it was the quickest way. He said it was the way he always went.",
					"What small piece of news would have been enough for you?",
					"A man who read the memorial used to tell me what the city had heard. I don't have an account from the other side of the portal.", { "you", "khadgar", "stormwind", "portal" })
			},
			inference = {
				{ "SAY", "I always assumed a stone memorial was meant to settle the way a story would be told. I stood under Khadgar's stone long enough to hear people disagree over what the words meant." },
				{ "SAY", "They agreed the expedition went through and the portal was shut. They couldn't agree what to say to a child who asked where the people on the other side had gone." },
				{ "SAY", "One person said nobody here could be sure. The next said that was the reason people had gone to the trouble of putting their names where everyone would pass them." },
				{ "SAY", "I wondered if that was the best the city could do for them. It could hold onto their names while it waited for a very long time to hear the rest." },
				AudienceLine("I've had to wait for word from someone who just walked down a road. I have never known how far it must have felt to the people who stayed here.",
					"Do you think a memorial changes what people hope to hear?",
					"The memorial and the expedition are known. The reason people still stop at the stone is something I have thought about since.", { "you", "khadgar", "stone", "portal" })
			}
		}
	},
	{
		id = "war3_rexxar_baine", title = "The Day Rexxar Brought Baine Home", voice = "hearsay", warcraft = 3,
		note = "Warcraft III · Rexxar, Bovan Windtotem and Baine's return to Cairne.",
		sources = { "https://warcraft.wiki.gg/wiki/Old_Hatreds_(WC3_Orc)" },
		perspectives = {
			memory = "He remembers meeting a tauren in Moonglade afterwards. He did not join Rexxar in the rescue.",
			hearsay = "An invented tauren witness describes waiting for Baine's return. The campaign establishes the capture, Bovan's help, and the rescue.",
			inference = "He compares two accounts of how news reached Cairne. Private feelings and the specifics of the waiting are original roleplay."
		},
		lines = {
			{ "SAY", "A tauren in Moonglade told me about the day Rexxar brought Baine back to Cairne. Another druid helped translate when I got the names wrong." },
			{ "SAY", "The centaur had taken Baine. Bovan Windtotem helped Rexxar find him. The person telling it kept going back to what people at home were doing while they waited." },
			{ "SAY", "They kept a fire. They took turns standing where they could see the path, since everyone wanted to be there if word came and nobody could do it all day.", aside = {
				"SAY", "I wish more accounts of great rescues remembered who kept the fire."
			} },
			{ "SAY", "I asked what Rexxar said when he got back. The tauren shook his head. He had been listening to Cairne say his son's name, and that's the sound he remembered." },
			AudienceLine("I'd first heard Rexxar's name from somebody talking about a war. That was the first time somebody had used it and given me something else to go away thinking about.",
				"What would you do while you were waiting for somebody to come home?",
				"A tauren who waited told it to me in Moonglade. He knew the way the news came back. The rescue itself was Rexxar's and Bovan's story.", { "you", "rexxar", "baine", "cairne" })
		},
		variants = {
			memory = {
				{ "SAY", "The time I heard about Baine's rescue, I was in Moonglade trying to light a fire with wood that had got damp on the way there." },
				{ "SAY", "A tauren took the top piece off and gave me a dry one. While he worked, he told the druid between us something I recognised only by the name Rexxar." },
				{ "SAY", "It was about bringing Cairne's son back. He kept showing me how they had left space in the fire and where somebody was always looking down the path." },
				{ "SAY", "I thought at first he was telling me how to light the fire. By the time it caught I knew more about the day his people had waited than any battle in the story." },
				AudienceLine("I still do the same thing with damp wood. I can remember the hands that showed me. It was one of the few parts of the account I didn't have to ask someone to translate.",
					"Has anyone ever told you an important thing while showing you how to do something ordinary?",
					"The fire in Moonglade is what I saw. The man beside me told what his people remembered of Baine's return.", { "you", "baine", "fire", "moonglade" })
			},
			inference = {
				{ "SAY", "One person told me Rexxar's rescue of Baine began when Bovan helped him find where to go. Another began on the day Cairne first heard his son had been taken." },
				{ "SAY", "It sounded like a disagreement about the start until I asked the two of them what they had been doing when they heard the news." },
				{ "SAY", "One had heard it on the road and learnt the rest afterwards. The other had been home wondering whether anyone could still bring news worth hearing." },
				{ "SAY", "When they got to the return, neither had trouble with the names. I think what they disagreed about was how long it had taken for a good thing to happen." },
				AudienceLine("I know people who have spent an afternoon waiting and people who have spent an afternoon walking. They do not always tell you the same thing when they get to the fire.",
					"Which person would you ask how long it took to bring Baine home?",
					"I heard the accounts from tauren I met later. The reason they begin at different moments is my own guess.", { "you", "baine", "rexxar", "accounts" })
			}
		}
	},
	{
		id = "rexxar_theramore", title = "What They Called Rexxar", voice = "hearsay", warcraft = 3,
		note = "Warcraft III · Rexxar, Daelin Proudmoore and the fighting around Durotar.",
		sources = { "https://hearthstone.blizzard.com/en-gb/news/11218304" },
		perspectives = {
			memory = "An imagined visit to the docks after the fighting. The druid did not see Rexxar fight Daelin.",
			hearsay = "An invented human deckhand and a translated Horde account describe the same conflict. Rexxar's part in the fighting is established by Blizzard.",
			inference = "He compares how people associated with Theramore and Durotar spoke about Rexxar. Rexxar's choices are known to him only through those accounts."
		},
		lines = {
			{ "SAY", "A deckhand in Theramore told me about the fighting after Admiral Daelin Proudmoore came to Kalimdor. When the man got to Rexxar, he put his cup down." },
			{ "SAY", "A different account reached me in Moonglade, through a druid who could help with the words. That teller called Rexxar the Champion of the Horde almost before he'd said his name." },
			{ "SAY", "The deckhand said Daelin never came back. The other man spoke of a home they'd only just begun to build, and of the one they counted on to defend it." },
			{ "SAY", "They both remembered the word bear. Neither remembered the same man standing beside it. I have often wondered what I would have called him from either shore.", aside = {
				"SAY", "I have a soft spot for beasts who can travel without somebody announcing their title."
			} },
			{ "SAY", "When I came back through Theramore, I asked the deckhand about the people still there. He told me who'd helped him fix his boat.", question = "What name did the people you grew up with give Rexxar?", replies = {
				{ "How do you know?", "SAY", "One account came from Theramore and the other reached me through an interpreter in Moonglade. I wasn't there when Rexxar fought Daelin.", cues = { { "you", "rexxar", "daelin", "theramore" }, { "know", "there", "heard", "told" } } },
				{ "Who was the bear?", "SAY", "The teller in Moonglade called her Misha. He was surprised I asked for her name before I asked who won.", cues = { { "bear", "misha" }, { "name", "called", "who", "named" } } }
			} }
		},
		variants = {
			memory = {
				{ "SAY", "I came to the Theramore docks after the fighting. A deckhand asked me to hold a damp line while he found a dry part he could still tie." },
				{ "SAY", "Someone farther down the dock spoke Rexxar's name. The man next to me said the admiral was dead, and kept his eyes on what his hands were doing." },
				{ "SAY", "I already knew the name from another mouth. Someone farther north had said it with evident relief. The man at the docks sounded as if it still cost him something." },
				{ "SAY", "I had intended to ask what he'd seen. In the end he showed me which part of the line had to go over the cleat, and I held it." },
				{ "SAY", "That is the part I can answer for. Every time I hear a tidy account of those days, I remember how hard it was to get that wet rope to hold.", question = "Do you remember where you were when you first heard what had happened?", replies = {
					{ "How do you know?", "SAY", "I remember the docks and the man with the rope. People who'd been closer to it told me about Rexxar and the admiral.", cues = { { "you", "rexxar", "docks", "daelin" }, { "know", "there", "heard", "told" } } }
				} }
			},
			inference = {
				{ "SAY", "I hear Rexxar called a champion when the person telling it starts from Durotar. In Theramore the account more often begins with an admiral who came across the sea." },
				{ "SAY", "It took me a while to notice that each teller talked about a place first and a man second. Most were thinking about somebody they hoped would come home." },
				{ "SAY", "There are facts I can put together. Rexxar fought for Thrall's people. Daelin died. The people who were waiting for them had their own measure of how it ended." },
				{ "SAY", "I wouldn't tell the young ones they have to choose whose home mattered before they can make sense of what happened. I think both accounts make more sense afterwards." },
				{ "SAY", "The last man I asked had grown up near the docks. He said all he wanted then was to know whether the boats would still put out.", question = "Whose account would you look for next, if you could ask one person?", replies = {
					{ "How do you know?", "SAY", "I heard the story on both sides of that quarrel. The pattern belongs to me. The people who told it would probably put it another way.", cues = { { "you", "rexxar", "daelin", "account" }, { "know", "guess", "sure", "heard" } } }
				} }
			}
		}
	},
	{
		id = "war3_barrow", title = "A Light in the Barrow", voice = "memory", warcraft = 3,
		note = "Warcraft III · Tyrande, Malfurion and the awakening of the druids.",
		sources = { "https://news.blizzard.com/en-us/article/23229617/warcraft-iii-the-story-so-far", "https://worldofwarcraft.blizzard.com/en-us/story/timeline/chapter-4" },
		perspectives = {
			memory = "Optional participation in the Third War as a helper at a barrow entrance. The lantern and the newly awakened druid are original roleplay.",
			hearsay = "An invented keeper and one of the awakened druids remember the effort to bring their kin back. The speaker was not at the awakening.",
			inference = "He compares accounts told after the awakening. He knows the druids were called back to defend their home, but cannot know what each remembered of the Dream."
		},
		lines = {
			{ "SAY", "When we began bringing the sleeping druids back during the war, I took a lamp to a barrow entrance. All I was asked to do was keep it lit." },
			{ "SAY", "We had heard Tyrande had brought Malfurion back. I was half expecting a word from him by the time the first person came up. What I got was a question." },
			{ "SAY", "The man asked if a tree he remembered still stood past the bend. I knew which one he meant. It had come down long before we had a war to blame for it.", aside = {
				"SAY", "Elune, I wish he'd asked me an easier question first.", darnassian = true
			} },
			{ "SAY", "I told him. Then I said where the younger tree was growing now, and he asked if I'd walk there with him before anyone called him away again." },
			{ "SAY", "I did. I had meant to leave the lamp at the entrance. Somebody else kept it lit until we came back.", question = "What would you ask first if you'd slept through years you expected to have?", replies = {
				{ "How do you know?", "SAY", "I can speak for the lamp and the walk. The word about Tyrande and Malfurion reached us from the people coming to call the sleepers back.", cues = { { "you", "lamp", "barrow", "malfurion" }, { "know", "there", "heard", "told" } } }
			} }
		},
		variants = {
			hearsay = {
				{ "SAY", "A barrow keeper told me she prepared for the awakening by lighting every lamp she had. She was sure there'd be nowhere for them to see the sky." },
				{ "SAY", "One of the druids who woke remembered a light at the entrance, but he said he needed it mainly to see the faces of the people who'd been waiting." },
				{ "SAY", "Everybody had a question for him about the Dream. Eventually he asked if one of them might tell him which way he should walk to find a familiar tree." },
				{ "SAY", "The keeper said its place had changed while he slept. She hadn't considered that much of a change until she had to explain what had been there first." },
				{ "SAY", "They agreed on how many lamps were burning. That was the only part I could get them to tell the same way.", question = "What would you want the first familiar face to tell you?", replies = {
					{ "How do you know?", "SAY", "I heard it from a keeper and a druid who woke. I can't tell you what a person dreams in all that time.", cues = { { "you", "keeper", "lamps", "dream" }, { "know", "heard", "told", "there" } } }
				} }
			},
			inference = {
				{ "SAY", "I used to wonder why a lot of stories about the druid awakening ended at the moment their eyes opened. That was where the tales I heard from keepers grew interesting." },
				{ "SAY", "One remembered being asked about a tree. Another remembered somebody trying to find a person whose name everyone had to think about for longer than they wanted to." },
				{ "SAY", "I imagine the Dream couldn't prepare them for the small changes any more than it prepared them to hear the names of the people coming to ask for help." },
				{ "SAY", "All that fighting gave us reasons to hurry. I still think there was great kindness in whoever answered the first question a person asked, however ordinary it was." },
				{ "SAY", "It would have been tempting to tell them what we needed before we asked what they had been hoping to find.", question = "What would you explain first to a druid coming home after a long sleep?", replies = {
					{ "How do you know?", "SAY", "The keepers told me what people asked. I am guessing at what I would have wanted in their place.", cues = { { "you", "keepers", "dream", "guess" }, { "know", "heard", "sure", "told" } } }
				} }
			}
		}
	},
	{
		id = "war3_cenarius", title = "The Grove After Cenarius", voice = "memory", warcraft = 3,
		note = "Warcraft III · Ashenvale after Cenarius fell to Grom's Warsong.",
		sources = { "https://us.media.blizzard.com/manuals/wow/wow-classic-manual-enUS.pdf" },
		perspectives = {
			memory = "Optional participation in the aftermath as a druid arriving at a damaged grove. The scene is imagined; he did not see Cenarius die.",
			hearsay = "An invented Sentinel and fellow druid report what they learned afterwards. The narrator knows who fought Cenarius without knowing the details of the demon pact.",
			inference = "He compares what he saw in a damaged grove with news of Cenarius's death. His interpretation of other people's grief is original."
		},
		lines = {
			{ "SAY", "I went into a grove in Ashenvale after word came that Cenarius had fallen. Someone told me Grom Hellscream and the Warsong had killed him. I thought I had misheard." },
			{ "SAY", "I had spent so many mornings listening for familiar sounds that I kept trying to listen past the quiet. The first sound I could place was someone pulling a branch clear." },
			{ "SAY", "It was a woman who used to walk past me without stopping. She asked if I would hold the part that was still alive while she moved the rest.", aside = {
				"SAY", "Elune, I was glad she asked me for something I could still do.", darnassian = true
			} },
			{ "SAY", "We worked a while before either of us said his name. When she did, it was to wonder whether he'd have told us we were holding the branch too high." },
			{ "SAY", "There was a little spring in it when we lowered it. For the rest of that day I could stand to listen.", question = "What work would you go back to first when a place had changed like that?", replies = {
				{ "How do you know?", "SAY", "I saw what the fighting had left in the grove. The news of Grom and Cenarius had reached us before I got there.", cues = { { "you", "cenarius", "grom", "grove" }, { "know", "there", "heard", "told" } } }
			} }
		},
		variants = {
			hearsay = {
				{ "SAY", "A Sentinel told me she heard Cenarius had fallen while she was keeping watch in Ashenvale. Until then she'd been expecting to hear which way he had driven the Warsong." },
				{ "SAY", "A druid I knew went back looking for something he could bring away. He came home with his cloak folded under one arm and told me he had left everything there." },
				{ "SAY", "I asked him whether he had found anything worth bringing. He said he had spent most of the afternoon clearing the way for somebody who wasn't able to climb over what lay across it." },
				{ "SAY", "He kept the cloak folded because it had been a pad for their knees. He handed it to me to wash and went to sleep without trying to explain the war." },
				{ "SAY", "I have heard longer versions of those days. That is the one I remember when somebody asks how long it took us to believe the news.", question = "Who told you the first account you still remember of that war?", replies = {
					{ "How do you know?", "SAY", "A Sentinel told me when the news arrived. A fellow druid told me where he'd been afterwards. Neither was telling me how the fight began.", cues = { { "you", "cenarius", "sentinel", "druid" }, { "know", "heard", "told", "there" } } }
				} }
			},
			inference = {
				{ "SAY", "When I heard Cenarius had been killed in Ashenvale, I thought everybody who'd loved him would come to the same place looking for the same thing." },
				{ "SAY", "Some went back to the paths where he'd taught. Some tried to find people they'd lost in the fighting. One person I'd expected to come never came that season." },
				{ "SAY", "I thought he blamed himself. A long time later he told me he had spent those weeks looking after an old friend who couldn't get that far any more." },
				{ "SAY", "It hadn't occurred to me the grove might have been on his mind the whole time. I'd been judging what people felt by whether I saw them there." },
				{ "SAY", "I try to remember that now when somebody says they never saw you come back. They might not have been looking in the right place.", question = "Did your people have a place they went back to after the war?", replies = {
					{ "How do you know?", "SAY", "I heard what happened to Cenarius and watched where people went afterwards. I was wrong about at least one of them.", cues = { { "you", "cenarius", "place", "grove" }, { "know", "guess", "sure", "heard" } } }
				} }
			}
		}
	},
	{
		id = "war1_boats", title = "A Name for the Next Boat", voice = "hearsay", warcraft = 1,
		note = "Warcraft I · The fall of Stormwind and Lothar's refugees.",
		sources = { "https://worldofwarcraft.blizzard.com/en-us/story/timeline/chapter-1", "https://news.blizzard.com/en-us/article/23229617/warcraft-iii-the-story-so-far" },
		perspectives = {
			memory = "The druid remembers meeting one of Stormwind's survivors years later. He did not sail with Lothar; the encounter is imagined.",
			hearsay = "An invented refugee recalls the evacuation after the First War. Stormwind's fall and Lothar leading survivors north are established.",
			inference = "He compares stories that families told after rebuilding. He does not claim firsthand knowledge of the siege or the palace."
		},
		lines = {
			{ "SAY", "When I asked an old woman how she came north after Stormwind fell, I expected a story about Anduin Lothar. She told me about a board beside the water." },
			{ "SAY", "Someone wrote the names of people getting onto a boat so the ones who came a little later would know who'd already gone. Her mother made them add their neighbour." },
			{ "SAY", "The neighbour hadn't arrived. The woman remembering it said her mother wanted one thing left to tell him if he made it to the water after their boat had cast off." },
			{ "SAY", "Lothar led the survivors north. She was old enough to remember that part. She was also old enough to remember her mother trying to find whether another boat had followed." },
			{ "SAY", "She didn't know what happened to the board. I asked about the neighbour. She said she could still remember the name in the hand that wrote it.", question = "If you left a name for someone trying to find you, where would you put it?", replies = {
				{ "How do you know?", "SAY", "A woman who fled Stormwind told me about her boat. I heard her long after the First War, when she was living back in the city.", cues = { { "you", "boat", "lothar", "stormwind" }, { "know", "heard", "told", "there" } } }
			} }
		},
		variants = {
			memory = {
				{ "SAY", "Years after the First War I met a woman in the rebuilt city who wrote other people's names for them when they couldn't manage it themselves." },
				{ "SAY", "She wrote mine down for an innkeeper and asked me to check it. When I thanked her, she said the first name she'd ever tried to read was a neighbour's at the water." },
				{ "SAY", "She had left with the people Lothar led out after Stormwind fell. She wanted to know if there was anyone else at the inn who remembered the boats." },
				{ "SAY", "I said I hadn't been there. She asked if I minded listening for a while. There was somebody she'd wanted to find for years and she liked to say his name." },
				{ "SAY", "I let her tell me how to say it properly. Then I said it back. That is what I can remember of the First War without borrowing anyone else's eyes.", question = "Is there a name you learnt because somebody needed another person to remember it?", replies = {
					{ "How do you know?", "SAY", "I met her in Stormwind afterwards. She remembered the boats. I remember sitting by her while she told me.", cues = { { "you", "boat", "woman", "stormwind" }, { "know", "heard", "told", "there" } } }
				} }
			},
			inference = {
				{ "SAY", "I kept hearing about the boats that took people north after Stormwind fell. One story began with Lothar; another began with someone getting a name wrong." },
				{ "SAY", "At first I assumed the second teller had forgotten the important part. Then I heard her tell it to another survivor and watched how closely he listened." },
				{ "SAY", "He had left on another boat. He wanted to know who still had a chance of following him. Lothar could tell him where they were all trying to go." },
				{ "SAY", "I thought about that when the man asked her to repeat the name. The road north was the part they had in common. What they left behind wasn't." },
				{ "SAY", "Maybe that's why the first version takes less time to tell. If you start with the names, there is always somebody you want to go back for.", question = "What would you want written down if you were the last person off the shore?", replies = {
					{ "How do you know?", "SAY", "I heard the accounts after people came back to Stormwind. The difference I hear between them is my own reading.", cues = { { "you", "boats", "lothar", "account" }, { "know", "heard", "guess", "sure" } } }
				} }
			}
		}
	},
	{
		id = "war2_banner", title = "The Banner at Blackrock", voice = "hearsay", warcraft = 2,
		note = "Warcraft II · Lothar's death and Turalyon taking command.",
		sources = { "https://worldofwarcraft.blizzard.com/en-gb/story/timeline/chapter-2", "https://news.blizzard.com/en-us/article/23229617/warcraft-iii-the-story-so-far" },
		perspectives = {
			memory = "An imagined visit with a veteran in Ironforge years later. The druid remembers that meeting, not the battle.",
			hearsay = "An invented soldier from the Alliance army tells him what was visible from the rear. Lothar's death and Turalyon taking command are documented.",
			inference = "He compares veterans and families. He does not claim to know the exact words said at Blackrock or what either commander intended."
		},
		lines = {
			{ "SAY", "A veteran in Ironforge told me he was too far back at Blackrock to see Lothar fall. What he saw was everybody in front of him turning to look the same way." },
			{ "SAY", "Someone passed back the news that Doomhammer had killed him. A runner came after that and said Turalyon had taken command. Those were two different messages to a man at the rear." },
			{ "SAY", "He said he spent a while looking for a banner he could follow. When he eventually saw one, he realised he knew who was holding it." },
			{ "SAY", "He had shared a needle with the man that morning. I asked what that had to do with the battle. He said it gave him a place to look.", aside = {
				"SAY", "The histories I have heard are much better at keeping track of banners than of needles."
			} },
			{ "SAY", "When he told me about Blackrock again another year, he mentioned Turalyon in the same place. I still remembered enough to ask after the man with the needle.", question = "When you couldn't see the person in command, who would you have looked for?", replies = {
				{ "How do you know?", "SAY", "A veteran told me in Ironforge. He saw the rear of the line, and was careful about what he said he'd seen.", cues = { { "you", "veteran", "lothar", "blackrock" }, { "know", "there", "heard", "told" } } }
			} }
		},
		variants = {
			memory = {
				{ "SAY", "I didn't see the battle at Blackrock. I remember listening to a man in Ironforge who had. He asked me to help patch his old cloak as he spoke." },
				{ "SAY", "He told me the news of Lothar's death passed him just before he heard Turalyon was leading them. I asked him how he'd known it was true." },
				{ "SAY", "He said he hadn't, but he could see where his own companions were going. He held the edge of the cloth a little firmer while I tried to stitch it." },
				{ "SAY", "I had heard the names from people who could tell me what each army did. His story was the first that made me think how little of it one person could see." },
				{ "SAY", "He kept the cloak after we patched it. He told me he'd never learnt to sew one-handed, and asked me what I had learnt to do alone.", question = "What could you see on the day they told you an important thing had happened?", replies = {
					{ "How do you know?", "SAY", "I was there for the mending. He was there at Blackrock. I know which part of the story belongs to each of us.", cues = { { "you", "cloak", "blackrock", "veteran" }, { "know", "there", "heard", "told" } } }
				} }
			},
			inference = {
				{ "SAY", "The people who told me about Blackrock all reached the part where Lothar died and Turalyon took command. They put different amounts of time between those two things." },
				{ "SAY", "A soldier near the front remembered hearing the news almost together. Another was sure he had waited a lifetime. A man at home remembered not hearing anything at all." },
				{ "SAY", "I started asking where each of them had been when the news reached them. Once I knew that, their accounts began to fit better than either one was inclined to admit." },
				{ "SAY", "We know how it ended. I suspect that makes it difficult to remember the sort of day they had before they found out which way the battle had gone." },
				{ "SAY", "When I tell it, I try to leave a breath after Lothar's name. For many of the people who lived it, there was a good deal more than a breath.", question = "Which account would you trust for how long the wait felt?", replies = {
					{ "How do you know?", "SAY", "The veterans told me what reached them and where they were. The timing between their accounts is what I've tried to put together.", cues = { { "you", "timing", "blackrock", "lothar" }, { "know", "guess", "sure", "heard" } } }
				} }
			}
		}
	}
}

for _, story in ipairs(stories) do
	ns.stories[#ns.stories + 1] = story
end
