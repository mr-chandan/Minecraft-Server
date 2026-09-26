# Shared Minecraft server (1.21.8)

The world lives on GitHub. Whoever wants to play downloads the latest world, hosts it on their own PC,
and uploads it back when they stop. Only one person hosts at a time; everyone else joins that person.
Free, no queue, no paid hosting.

## For friends (one time)
1. The owner adds you as a collaborator on the GitHub repo (you need a free GitHub account).
2. Double-click `setup.bat`. It installs Git and Java, downloads the world, and puts **Play Minecraft** on your Desktop.
3. Sign in to GitHub in the browser window that pops up.

## Every time you want to play
1. Double-click **Play Minecraft**.
2. If nobody is hosting, you become the host. In Minecraft use Multiplayer > Direct Connect > `localhost`.
   The very first time you host, your browser opens playit.gg: sign in with Google, click Approve, click Create tunnel,
   choose Minecraft Java, then copy the address at the top and paste it into the black window. Once only.
3. If someone is already hosting, the window shows the address to join instead.
4. To finish, type `stop` in the black window and press Enter. Wait for "World uploaded". Never close the window with the X.

## If something went wrong
- Closed the window by mistake or PC crashed: double-click `sync.bat` in `C:\Users\<you>\MinecraftServer`.
- "X is already hosting" but they are not: ask them to run `sync.bat`, which removes the lock.
- Upload keeps failing: check internet, run `sync.bat` again. Your work is saved locally until it uploads.

## Files
- `play.bat` installs anything missing (Git, Java, playit), pulls, locks, runs tunnel + server, then uploads.
- `sync.bat` uploads the world and removes the host lock.
- `setup.bat` one-time installer to send to friends.
- `my-address.txt` your personal playit address (not shared, created on first host).
