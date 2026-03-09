# HearthPhone

A smartphone-style UI addon for World of Warcraft. Gives your character a fully functional phone with apps, games, messaging, and social features — all inside the game.

![WoW](https://img.shields.io/badge/World%20of%20Warcraft-Retail-blue)

## Installation

1. Download the latest release from [Releases](../../releases)
2. Extract the folder into `World of Warcraft/_retail_/Interface/AddOns/`
3. Make sure the folder is named `HearthPhone`
4. Restart WoW or type `/reload`

## Slash Commands

| Command | Description |
|---------|-------------|
| `/phone` | Toggle the phone on/off |

## Apps

### Communication
- **Messages** — Guild, Party, Raid, Instance chat and DM whispers in one place
- **Phone** — Call your friends with a simulated voice call UI
- **Social Network** — Twitter/Reddit-style feed with posts, comments, emoji reactions, @mention tagging, and profile pages. Syncs with other HearthPhone users via addon channels.

### Games
- **Snake** — Classic snake game
- **Tetris** — Falling block puzzle
- **Tic-Tac-Toe** — Multiplayer, challenge friends
- **Battleship** — Multiplayer naval warfare
- **Candy Crush** — Match-3 puzzle
- **2048** — Sliding number tiles
- **Minesweeper** — Flag the mines
- **Flappy Bird** — Tap to fly through pipes
- **Wordle** — Daily word guessing game
- **Angry Birds** — Slingshot physics game
- **Space Invaders** — Retro arcade shooter
- **Temple Run** — Endless runner
- **Subway Surfers** — Lane-dodge runner
- **Agar.io** — Multiplayer blob eating game (shared channel, anyone with the addon can join)

### Tools
- **Calculator** — Basic math calculator
- **Calendar** — In-game calendar view
- **Timer** — Stopwatch and countdown timer
- **Notes** — Write and save notes
- **Weather** — Shows your current zone weather
- **Camera** — Screenshot tool
- **DPS Meter** — Combat damage tracker
- **Fitness Tracker** — Tracks steps, distance, and activity
- **Music Player** — Play custom MP3 files from the Music folder
- **Uber** — Flight map using hearthstones
- **Wallpapers** — Customize your lock screen and home screen backgrounds

## Features

- Draggable phone frame with realistic bezel
- Lock screen with swipe to unlock
- Status bar with clock, gold, and zone info
- Notification banners with click-to-open routing
- Multiplayer games and social features sync via hidden addon channels
- Persistent data saved across sessions (highscores, notes, posts, wallpapers)

## Adding Custom Music

Place `.mp3` files in the `HearthPhone/Music/` folder. They will appear in the Music app under "My Music".

## For Addon Developers

HearthPhone uses hidden addon message channels for multiplayer features:
- `xtHearthSocial` — Social network post/comment sync
- `xtHearthAgar` — Agar.io game state

## License

Feel free to use, modify, and share.
