# automatic-chainsaw

Automatic Chainsaw is a random placeholder name for game I could possibly make if I decide it's worth staring at a computer in my free time. The game has nothing to do with chainsaws.

## 9/19/2026
### Intro and Approach
I spend a lot of time using AI at work for software development and it's pretty easy to see how useful it is for writing good code, fast. Enterprise software also does not require a ton of creativity to develop and most of what I spend time thinking about is architecture and design. In general, this software is easy to plan and implement and rarely involves creating something truly unique.

However, when it comes to game development, effective use of AI tools becomes a bit trickier. It's tempting to think that any cool idea you have can be spun up into a fully functional game in a few hours with a few well-written prompts. In some cases this is true. For example, if my goal is to create a passable clone of flappy bird, I will have a functioning prototype in a few minutes. The problem is that a buggy clone of flappy bird has little to no real-world value. A product that required no artistic or intellectual merit to produce will not interest anyone looking for a meaningful gaming experience. There is obviously no commercial value, but more importantly there is no artistic value or original thought involved in the creation of the game. Even if you were able to vibe code an entire polished AAA game, the lack of original thought would be so obvious that even the most casual gamer would roll their eyes (probably).

Clearly AI cannot yet create fun games fully from scratch without significant guidance. Does that mean AI _can_ create fun games when guided by a human? I think... kinda. Anyone who has tried to vibe code their game idea will know that even with very specific prompting and guidance, AI still produces work that is a far cry from the awesome game you imagined. This is to be expected because unless you detail every exact possible aspect of the game, the AI must make decisions and assumptions on your behalf. The idea of detailing out an entire game with no ambiguity already exists and it's called just actually writing code.

What if you just try to emulate how most software is written? You could use AI to significantly speed up development and build up an impressive game in a fraction of the time it used to take. This is the pragmatic approach that will allow you to develop a thoughtfully designed game in a reasonable amount of time. However, game development has a unique challenge that is absent from most other types of software. It is very difficult to predict, plan, or even know exactly what you want _before_ starting development. Game development requires constant iteration, experimentation, and creativity. Game mechanics and ideas often present themselves during the development process.

It seems like AI would be the perfect tool for quickly iterating on a game, but the essential challenge then becomes one of maintenance. This is obviously not a new problem in any software system, but it is compounded by the speed at which code can be written and understood by the developer. The more you painstakingly read code and plan decoupled, general, robust systems, the more you negate the usefulness of the AI tools. Developing a game like this would still be much faster and easier than writing all the code yourself, but it still requires a great deal of software engineering to build a solid game.

I think the fundamental benefit of AI tools for game development is the ability to abstract away the software infrastructure required to make an idea come to life. On one end of the spectrum, you have completely vibe coded games where the software is entirely abstracted and an idea is realized through prompting alone. This obviously will not work for anything but the simplest projects because adding and iterating on a vibe coded game inevitably produces a slop coded mess that is impossible to understand and therefore develop. On the other side, you can write and merge code in small chunks, always cognizant of how each update is affecting the final product. The problem here is that software alone is not what makes a good game (despite what some nerds would tell you). Software is just the scaffolding that supports art, game design, and complex mechanics to produce something fun. Obviously software plays an important part in gameplay (like enemy AI for example) but it's ultimately just an expression of the game designer's ideas, translated into a language that computers understand. The actual "quality" of the software (readability, maintainability, scalability) is really just a measure of how efficiently a game _can be developed_. If you cannot add a feature without breaking ten other features, how can you possibly develop a game past a certain (low) level of complexity? Is there a way to use the power of AI tools to abstract any concerns unrelated to game design and avoid creating a bloated, spaghetti code, buggy, nightmare codebase?

Before I try to answer that question, I want to point out that this fundamental tradeoff of game development existed long before AI. It's simply a choice between having complete control over your game (writing a game engine from scratch in binary) and being able to develop, prototype, and iterate efficiently (no-code drag-and-drop game engine). I'm sure some hardcore brogrammers would happily burn me at the stake for daring to suggest that writing code is not an essential part of game design, but there are infinite ways to do the same thing using software. I _know_ that there are important differences between those implementations like performance and extensibility. But who the fuck wants to sit around debugging their 3D graphics engine when they can just see their game ideas come to life almost instantly? Not me, at least. Hence the existence of game engines, software designed to trivialize common, tedious workflows (like rendering 3D graphics) and still be general enough to create unique games.

Now you could use AI tools to create games using an existing game engine like Unity, but you are still constrained by the limitations of the engine and will need to learn how to use and navigate a complex UI. There's nothing I hate more than spending my time learning how to use software that will inevitably change or stop being supported, leaving me with the knowledge of some system that is useless in any other context. 

Now that I've defined the challenges associated with some of these approaches, it's easier to see the alternatives that remain. My goal is to take the strengths of these ideas and combine them in a way that maximizes the amount of time spent on pure _game design_. Things I don't want to do:

- Spend all my time writing code
- Spend all my time debugging code
- Reading any code at all
- Be constrained to the limitations of a prescriptive game engine
- Watch a YouTube tutorial on how to navigate Unreal Engine
- Have an AI make design decisions for me
- Create an artistically corrupt AI slop game

Things I want to do:

- Think about code as little as possible
- Have complete control over the art, writing, music, and game mechanics
- Learn and practice fundamental game design skills that are applicable in any context
- Make something not shitty

  Therefore the best approach I can think of is one that minimizes the  


