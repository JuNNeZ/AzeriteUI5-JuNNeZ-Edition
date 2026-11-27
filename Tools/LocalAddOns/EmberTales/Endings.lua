local _, ns = ...

-- These episodes assume only the events shared by the three voices. Most
-- take place afterwards, so a hearsay account can lead into a personal memory.
local endings = {
	war1_medivh = {
		short = { { "EMOTE", "sets his cup beside the fire and leaves room for another." } },
		extended = {
			{ "SAY", "The carter told me that someone eventually asked him for the old route. They were looking for a house along the road." },
			{ "SAY", "He took the ledger from its shelf and found the directions beneath the cost of a sack of grain. The first turn was marked by a pear tree." },
			{ "SAY", "The tree was gone by then. He made the traveller wait until he could think of something that was still there." },
			{ "EMOTE", "follows a turning in the dirt with the end of a twig." }
		}
	},
	war2_alleria = {
		short = { { "EMOTE", "steadies the cup in both hands before passing it on." } },
		extended = {
			{ "SAY", "The soldier told the story again when we came to a ford. A girl waiting there had a load of washing and her hands were full." },
			{ "SAY", "He went across first with a stick and found the flat stones. He showed her where to step by keeping one boot on each stone until she came up beside him." },
			{ "SAY", "Before we went on he put the stick where the next person could reach it. The girl was the one who thought to weigh it down against the current." },
			{ "EMOTE", "places a small stone on the end of a loose branch." }
		}
	},
	war2_khadgar_portal = {
		short = { { "EMOTE", "runs his thumb around the rim of his cup and sits quietly for a moment." } },
		extended = {
			{ "SAY", "On a later visit I heard a child reading one of the plaques aloud. She stopped halfway through and asked her father what 'presumed' meant." },
			{ "SAY", "He looked at the plaque for a while. Then he told her what he remembered his own mother saying when word came that the portal had closed." },
			{ "SAY", "She asked him which part of that was written on the stone. He took her back to the beginning and let her read it herself." },
			{ "EMOTE", "turns his palms towards the warmth of the fire." }
		}
	},
	war3_rexxar_baine = {
		short = { { "EMOTE", "leaves a dry piece of wood where the next watcher can reach it." } },
		extended = {
			{ "SAY", "The next time I saw the tauren in Moonglade, he'd brought a young apprentice. She took the first watch while the rest of us talked." },
			{ "SAY", "At dawn we found a cup warming by the coals. She had set it there for somebody who'd said he would be back before it grew light." },
			{ "SAY", "I offered to take the next watch. She showed me how far to set the cup from the heat so it would be warm when he put both hands around it." },
			{ "SAY", "Elune-adore.", darnassian = true }
		}
	},
	rexxar_theramore = {
		short = { { "SAY", "I'd still like to hear what the people on the next boat remembered." } },
		extended = {
			{ "SAY", "On another visit to Theramore I saw a man teaching a child to tie a mooring line. I knew the knot because someone had shown it to me there once." },
			{ "SAY", "The child asked if a knot was meant to hold a boat still all the time. The man said it was there to hold it until somebody knew where they wanted to go." },
			{ "SAY", "I thought of the people who had come across the sea certain they already knew where they ought to go. We helped the child tie the knot again." },
			{ "EMOTE", "pulls a loose thread free and knots it around a finger." }
		}
	},
	war3_barrow = {
		short = { { "EMOTE", "makes sure the next person can see the path to the fire." } },
		extended = {
			{ "SAY", "A long time afterwards I found a young druid setting out the lamps one at a time. I asked what she was waiting for." },
			{ "SAY", "She said an older teacher was coming home on foot. She had put the first lamp where he used to put it himself. The rest marked the road as it was now." },
			{ "SAY", "I asked if she'd walk with him when he arrived. She said that was why she'd put her own lamp out last." },
			{ "SAY", "Elune-adore.", darnassian = true }
		}
	},
	war3_cenarius = {
		short = { { "EMOTE", "stills his hands and listens to the trees for a moment." } },
		extended = {
			{ "SAY", "A little later I walked back through that part of Ashenvale and found someone carrying a branch away. For a moment I thought of asking them to leave it." },
			{ "SAY", "They showed me where it had already put one root down. They were moving it because the path around it had grown narrow." },
			{ "SAY", "I helped find it somewhere it might take hold again. I had been waiting for a sign we could start over, and the branch had already got on with it." },
			{ "EMOTE", "brushes some earth away from the edge of his boot." }
		}
	},
	war1_boats = {
		short = { { "SAY", "There are worse things you can do with a little time than remember somebody's name." } },
		extended = {
			{ "SAY", "On another visit to Stormwind a young person asked me how old her neighbour had been when the city fell. I asked whether she'd ever heard the woman tell it herself." },
			{ "SAY", "She said yes, twice. The first time she'd counted how many people made it onto a boat. The second time she'd learnt the way a name sounded." },
			{ "SAY", "I asked her to say it. She had the pronunciation right. I had been wrong to think it mattered only to people who could remember the old city." },
			{ "EMOTE", "traces a name in the ash and leaves it there." }
		}
	},
	war2_banner = {
		short = { { "SAY", "If you're going a long way tomorrow, ask who has a needle before you set out." } },
		extended = {
			{ "SAY", "I went looking for another person who'd fought at Blackrock. He didn't remember a banner. He remembered how many people were missing when he sat down that evening." },
			{ "SAY", "One wasn't missing at all. The man had taken off his torn cloak and lent the sound part to somebody who needed a sling. He looked different without it." },
			{ "SAY", "I asked how he'd recognised him in the end. He said he'd heard him asking after the fellow who'd borrowed his needle." },
			{ "EMOTE", "checks his pocket as if he might still have it." }
		}
	},
	hyjal_accord = {
		short = { { "SAY", "If anyone wants a drink now, there is enough to go round." } },
		extended = {
			{ "SAY", "Years later someone in another camp asked how water had been carried that day. I showed him a better grip by hauling a barrel with him." },
			{ "SAY", "He asked who had taught me. I thought of all the people I'd heard telling it and couldn't choose one who would have admitted to giving a lesson." },
			{ "SAY", "So I told him it was something I'd learnt on a road. He passed the knowledge on when somebody else came to lift the barrel." },
			{ "EMOTE", "reaches to steady the nearest cup." }
		}
	},
	magni_memorial = {
		short = { { "SAY", "Sully Balloo. That's the name he wanted me to remember." } },
		extended = {
			{ "SAY", "On another visit I heard an apprentice practising letters on a scrap of stone. He'd kept getting one of the names wrong." },
			{ "SAY", "The mason asked him to say it first. He did, and halfway through I realised he already knew who the name belonged to." },
			{ "SAY", "That was all he needed. The next mark was a little crooked, but the name was right." },
			{ "EMOTE", "brushes a fleck of ash from the point of his finger." }
		}
	},
	cairne_horn = {
		short = { { "SAY", "I think I'll keep a seat for the people who carried it home." } },
		extended = {
			{ "SAY", "The next time I was in Moonglade, the hunter's companion knew me by the way I asked about the people left out of stories." },
			{ "SAY", "He told me the hunter couldn't make tea for more than one person without forgetting which cups he'd already filled. It was plainly a story he'd been waiting to tell." },
			{ "SAY", "When the hunter came back, there were three cups ready. I can't remember which of us had remembered to fill mine." },
			{ "EMOTE", "slides a cup closer to the next seat." }
		}
	},
	tyrande_ring = {
		short = { { "SAY", "Well. That's one of the reasons I still ask if there's room at the fire." } },
		extended = {
			{ "SAY", "Much later, outside the temple, I saw another traveller trying to tell a pack of young people which way to go. Every answer he gave brought him two more questions." },
			{ "SAY", "I stayed to listen. When he talked about getting lost, the nearest listener took a twig and drew the turn he'd missed in the dirt." },
			{ "SAY", "I asked him afterwards whether he'd felt up to telling the story. He said he'd felt up to walking there. It hadn't occurred to him there was anything else he needed to be ready for." },
			{ "SAY", "Elune-adore.", darnassian = true }
		}
	},
	tirion_portrait = {
		short = { { "EMOTE", "rests both hands on his knees and gives the fire a moment." } },
		extended = {
			{ "SAY", "After I heard what had become of the portrait, I asked a travelling painter what she noticed first when a family sat for a picture." },
			{ "SAY", "She said it was the little gap each person left for the one who would be sitting next to them. It took a while for everyone to stop moving their chairs." },
			{ "SAY", "I think about that now when somebody tells me what it's like to look at a picture of people they can't sit beside anymore." },
			{ "EMOTE", "moves his cloak from the nearest empty place." }
		}
	},
	illidan_freed = {
		short = { { "SAY", "I still like to hear how that story reached other people." } },
		extended = {
			{ "SAY", "Years later a traveller asked me which of the two accounts I kept. I said both. She thought that meant I couldn't make up my mind." },
			{ "SAY", "I told her there were people I wanted to remember, and sometimes all I had left was the exact sort of argument they would have started." },
			{ "SAY", "She asked whether I wanted those two at the same fire again. I said yes. I'd put an extra seat between them and be glad of the company." },
			{ "EMOTE", "shifts a little as though making room." }
		}
	},
	arthas_home = {
		short = { { "EMOTE", "sits in silence long enough for someone else to speak." } },
		extended = {
			{ "SAY", "I once met two people who had lived in Lordaeron, each quite sure they remembered the other one's street." },
			{ "SAY", "They drew it in the mud. First the well, then a corner where somebody sold bread, then a building whose door could never quite be shut." },
			{ "SAY", "They agreed about where their roads met. After that they didn't seem to mind so much that they'd remembered different things." },
			{ "EMOTE", "draws two short lines from opposite sides of the ash until they meet." }
		}
	},
	woodwyrd = {
		short = { { "EMOTE", "lets the fire go quiet for a few breaths." } },
		extended = {
			{ "SAY", "On the way out, I found some dry moss in the lee of a rock. I nearly took it to kindle a fire. Then I saw a little bird pulling at the edge of it." },
			{ "SAY", "I walked on. At the next camp a traveller was cross that I hadn't brought anything dry." },
			{ "SAY", "I told her there had been someone using it. She asked who. I said I didn't think the bird and I were on first-name terms yet." },
			{ "EMOTE", "leaves a little space beside the warmest stones." }
		}
	},
	dartol_rod = {
		short = { { "SAY", "I try to give people a moment before I decide what they are now." } },
		extended = {
			{ "SAY", "Later, when I had to bring the rod back to Raene, I caught myself looking for my reflection once more. The moonwell was quite still that day." },
			{ "SAY", "I didn't use the rod. I just watched a person who looked terribly sure he knew who he was." },
			{ "SAY", "A stranger came to the edge of the water and stood a little way off. I moved my pack an inch. It was surprising how much room that made." },
			{ "EMOTE", "moves his pack clear of the nearest seat." }
		}
	},
	shore_light = {
		short = { { "SAY", "Leave one flame if someone's still out on the road." } },
		extended = {
			{ "SAY", "The next time I passed that shelter, there was a second lantern hanging higher up. I asked the woman why she'd put it there." },
			{ "SAY", "She said the low one was for her brother. The high one showed ships the hard edge of the shore. He'd helped her fasten it when he got back." },
			{ "SAY", "I helped refill both lamps. We didn't say a great deal about who might see them." },
			{ "SAY", "Elune-adore.", darnassian = true }
		}
	},
	billy_pie = {
		short = { { "SAY", "I ask about the price before I ask about the necklace now." } },
		extended = {
			{ "SAY", "The next time I came to the farm, there was a pie cooling on the sill. I asked what had gone missing this time." },
			{ "SAY", "Bernice said she was trying a new crust. She cut me a slice and asked if I'd tell her the truth about it." },
			{ "SAY", "I said I needed another bite to be sure. She looked over the top of her cup and told me I sounded just like Billy." },
			{ "EMOTE", "makes a small gesture of surrender." }
		}
	},
	mornbrew = {
		short = { { "SAY", "Take a sip now, while yours is still warm." } },
		extended = {
			{ "SAY", "When I finally got back to Nori, he looked at the mug and asked if Durnan had made his usual noise on the first sip." },
			{ "SAY", "I tried to imitate it. Nori nodded, poured me a cup of my own, and told me I could practise for as long as I liked." },
			{ "SAY", "We sat there until the last of the light went. He never asked me to hurry again that day." },
			{ "EMOTE", "blows across the rim of his mug." }
		}
	},
	marsh_gas = {
		short = { { "SAY", "I'm quite happy for the future to walk the last few steps itself." } },
		extended = {
			{ "SAY", "The next morning my boot washed up. It was tied to a little piece of rope someone had used to fish it out." },
			{ "SAY", "Sleebo wanted to know if I was coming back for a second batch. I asked what he'd call a man who returned to the same mud twice." },
			{ "SAY", "He said 'experienced'. I said 'wearing my old boots'. We made a deal after that." },
			{ "EMOTE", "looks down to check that both boots are still present." }
		}
	},
	spare_seat = {
		short = { { "EMOTE", "leaves the empty place by the fire clear." } },
		extended = {
			{ "SAY", "In the morning I put a piece of dry wood by the stone before I left. I couldn't think how to thank him in a way we both understood." },
			{ "SAY", "He saw me doing it and put another piece beside it. He pointed at the road, then at the two pieces." },
			{ "SAY", "I think he meant the next traveller would be glad of them. I started leaving two pieces behind after that." },
			{ "EMOTE", "sets two bits of dry wood a handspan apart." }
		}
	},
	tin_cup_rain = {
		short = { { "SAY", "If it starts raining, you know what to do." } },
		extended = {
			{ "SAY", "By morning my little roof had blown away and there was a frog sitting next to the cup. It looked as if it had been there longer than I had." },
			{ "SAY", "I left the cup upright that time. The frog sat in it before I'd finished packing." },
			{ "SAY", "I went back for it later, when it was empty. It is still the only cup I've owned that served two guests before it served me." },
			{ "EMOTE", "checks inside his cup before taking the last sip." }
		}
	},
	cat_rafters = {
		short = { { "SAY", "If you need me, I'll be staying on this side of the branches." } },
		extended = {
			{ "SAY", "I came back to Nighthaven years later and found a young apprentice staring up at those rafters. I asked what he was thinking." },
			{ "SAY", "He said he was working out how to get to the top. I asked him to work it out from the top back down, too." },
			{ "SAY", "He thought I was being sensible. I didn't tell him how much linen it took me to become that sensible." },
			{ "EMOTE", "flattens a crease in his cloak with both hands." }
		}
	},
	first_patient = {
		short = { { "SAY", "If your boot gives you trouble, I happen to know which end of a needle to hold." } },
		extended = {
			{ "SAY", "The hunter came to find me again a winter later. I asked if it was her ankle. She said she'd heard I was putting off mending my own cloak." },
			{ "SAY", "I'd been folding the torn part under when I went out. I thought I'd hidden it. She said her boot had taught her what to look for." },
			{ "SAY", "We made tea first. She insisted on that. Then I held the cloth while she found the part that would take a stitch." },
			{ "SAY", "I still like the way that patch looks. She used the thread she had instead of pretending it matched." }
		}
	},
	boot_seed = {
		short = { { "SAY", "If you have something worth planting, take it out of your boot." } },
		extended = {
			{ "SAY", "When my plant finally came up, its stem was crooked and it grew away from the other one. I suggested turning it around." },
			{ "SAY", "My sister said it had found the bit of sun that came through under the step. I came out the next morning to see if she was right." },
			{ "SAY", "She was. There was only enough sun there to warm a hand. I put mine down beside the leaves for a while." },
			{ "EMOTE", "opens his hand to the warmth of the fire." }
		}
	},
	listening_tree = {
		short = { { "SAY", "I'll wash my own cup tonight. You can hold me to it." } },
		extended = {
			{ "SAY", "I showed the tree to a child once and told him where the nest had been." },
			{ "SAY", "He asked how long I'd sat there with my sister. I said I thought we had stayed about an hour." },
			{ "SAY", "When I told her what I'd said, she laughed. She remembered bringing a blanket because we'd stayed until dawn." },
			{ "EMOTE", "looks through the smoke as if checking the colour of the sky." }
		}
	},
	first_lesson = {
		short = { { "SAY", "There's room here if the hill's been hard on your knees." } },
		extended = {
			{ "SAY", "Much later, my shan'do asked me to show an apprentice where the fresh water ran." },
			{ "SAY", "The apprentice wanted to take the short path. I nearly told him no before he'd finished asking." },
			{ "SAY", "I let him try it. I took the longer route and had water ready for him when he came round the last bend." },
			{ "SAY", "He took a cup, asked if I wanted help carrying the rest, and saved me a great deal of time." }
		}
	},
	bear_lesson = {
		short = { { "EMOTE", "sits quite still for a few breaths." } },
		extended = {
			{ "SAY", "When I next came to Moonglade, I had an injury that made my hands shake. I had come for herbs and meant to leave quickly." },
			{ "SAY", "I sat down in the same spot I'd waited in as an apprentice. There was a beetle crossing a stone. I waited for it to get to the other side." },
			{ "SAY", "Someone came by and saw me there. She asked whether I needed help. This time I had the good sense to say yes." },
			{ "SAY", "Elune-adore.", darnassian = true }
		}
	},
	hyjal = {
		short = { { "EMOTE", "leaves a little room beside him at the fire." } },
		extended = {
			{ "SAY", "I went back to the mountain once with a young kaldorei who wanted to know where her father had stood." },
			{ "SAY", "We found an old strip of cloth tied high in a branch. She guessed it marked the line of battle. I told her it might have marked the way to the water." },
			{ "SAY", "She tied another strip below it, low enough for a child to reach.", replies = {
				{ "What did she tie there?", "SAY", "A scrap from her own cloak. She didn't have anything of her father's with her." }
			} },
			{ "SAY", "Elune-adore.", darnassian = true }
		}
	},
	westfall = {
		short = { { "SAY", "If you pass through Westfall, knock softly." } },
		extended = {
			{ "SAY", "I passed the boy's house in Westfall again as the light was failing. There was a board across the window, and I thought his mother had finally given up." },
			{ "SAY", "Then I saw she'd wedged it under the sill like a step. Her boy had always been short for his age." },
			{ "EMOTE", "turns an upturned piece of bark over with the toe of his boot." },
			{ "SAY", "Did I see him? No. The board was worn enough that somebody had used it. I left it where it was." }
		}
	},
	lordaeron = {
		short = { { "EMOTE", "warms his hands in silence." } },
		extended = {
			{ "SAY", "Some time after that, I heard somebody outside the ruins humming a tune I'd heard in an inn before the war." },
			{ "SAY", "I knew the chorus and joined in. We got two lines in before he stopped me. I'd learnt it from people who'd fled south. They'd changed the words." },
			{ "SAY", "He taught me the old line and asked to hear the new one again. We sang each version once before we went our separate ways." },
			{ "SAY", "Since then, whenever somebody tells me what the people of Lordaeron used to sing, I ask them to sing it twice." }
		}
	},
	stalvan = {
		short = { { "EMOTE", "lets the lid of his pouch fall shut." } },
		extended = {
			{ "SAY", "I went back to Goldshire once and asked the innkeeper what a schoolmaster would have had to carry when he left." },
			{ "SAY", "He reached under the counter and found a piece of chalk. I said even a good teacher would have needed more than that. He said there was a time he'd have given anything for someone to teach him his letters." },
			{ "SAY", "I didn't ask if Stalvan had taught him. He was rubbing the chalk between his fingers hard enough to turn it to powder." },
			{ "EMOTE", "brushes the dust from his own fingertips." }
		}
	},
	thandol = {
		short = { { "SAY", "Next time you catch a cart on that bridge, let it cross first." } },
		extended = {
			{ "SAY", "I walked that way again after the crossing was clear. A girl on the north side was handing little pieces of bread to the carters." },
			{ "SAY", "I asked who'd paid for it. She said it had all come out a little burnt, and her father had said to give it to anyone who'd had a worse day than the baker." },
			{ "SAY", "I ate mine against the stone rail. The girl offered me another when I couldn't think of anything to say about the crust." },
			{ "SAY", "I had two. It was a good day to have bread, even bread like that." }
		}
	},
	anilia = {
		short = { { "EMOTE", "brushes a little ash away from the empty seat." } },
		extended = {
			{ "SAY", "The next time I heard her name, someone in Ashenvale was telling a girl how to choose a branch for an arrow shaft." },
			{ "SAY", "She called it Anilia's way. It meant looking down the length of it with your eyes half closed. The girl learnt the trick before she asked who Anilia was." },
			{ "SAY", "I stayed to hear that answer. There wasn't a satyr in it." },
			{ "SAY", "Elune-adore.", darnassian = true }
		}
	},
	bear_nappy = {
		short = { { "EMOTE", "checks the seams of his gloves and gives the fire a rueful look." } },
		extended = {
			{ "SAY", "I saw the dwarf's wife again some weeks later. I asked whether the nappy leaked. She said it hadn't got as far as being tested." },
			{ "SAY", "The baby refused to take a nap unless she could hold a corner of it. Her mother had sewn the softest piece onto the child's blanket and wouldn't risk taking it off." },
			{ "SAY", "Apparently the dwarf had asked whether an elf might be willing to fetch another twelve. His wife told him he could ask me himself.", replies = {
				{ "Did he ask you again?", "SAY", "He brought me a cup of tea. We drank it in comfortable silence. I think he knew that was as far as he was getting." }
			} },
			{ "SAY", "If he ever asks, I'll be happy to teach him how to climb a tree." }
		}
	},
	wetlands_crates = {
		short = { { "EMOTE", "holds his boots near the fire to dry." } },
		extended = {
			{ "SAY", "A few days later I passed the same stretch of shore at low tide. I saw the murlocs keeping food dry on the lid of one of those crates." },
			{ "SAY", "I had a piece of dry rope left from the harbour. I set it down at the edge of the camp and waited to see what they would do." },
			{ "SAY", "Before long they had the lid tied to two posts so it wouldn't wash away. It took them less time than it took Karl to unwrap his statue." },
			{ "EMOTE", "lifts his cup in a quiet toast towards the shore." }
		}
	},
	duskwood_supper = {
		short = { { "SAY", "Let that be a lesson. Eat first, and ask the cook afterwards." } },
		extended = {
			{ "SAY", "The next time I saw Chef Grual, he asked how Jitters had liked the cakes. I said he'd tasted the sea. The chef put his knife down for a moment." },
			{ "SAY", "He wrapped up another parcel. I expected it to be spider again, but the first thing that came out was a bruised apple." },
			{ "SAY", "There was bread underneath. Grual said to let him know if Jitters wanted more, and to tell him he didn't have to call it a feast." },
			{ "EMOTE", "breaks a piece of bread and leaves half within easy reach of the next seat." }
		}
	},
	rolled_satchel = {
		short = { { "SAY", "That's enough about walking. I'm sitting down now." } },
		extended = {
			{ "SAY", "Much later, someone met me at the foot of the wall and asked if the trail was worth following. She'd come all the way from the dam and looked ready to sit down in the road." },
			{ "SAY", "I showed her where to put her feet on the cart. She asked how I knew which foothold was wrong. I pointed to the patch on my cloak." },
			{ "SAY", "She climbed up and shouted that she'd found it. I was halfway through telling her how to get down when she called back that she was staying put." },
			{ "SAY", "I looked up a little later and saw her boots sticking out of the sleeping bag. I counted that as the first time I'd given anyone good directions." }
		}
	}
}

for _, story in ipairs(ns.stories) do
	story.endings = endings[story.id]
end
