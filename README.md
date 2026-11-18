# LANCommander Game Servers

Docker images for dedicated game servers, maintained by the team behind
[LANCommander](https://lancommander.app). Every image is published to Docker Hub under
`lancommander/<name>` and is built from its own directory in [`Servers/`](Servers).

## Layout

Every image has the same shape:

```text
Servers/<Name>/
├── Dockerfile        # build file; title/description/LANCommander labels live here
├── README.md         # docs; also pushed to Docker Hub as the image description
├── compose.yml       # ready-to-run example, identical to the one in README.md
├── server.json       # Docker Hub image name (and optional extra tag suffixes)
├── Documentation/    # longer docs, published to the LANCommander docs site
├── Hooks/<HookPoint>/NN-Name.ps1   # PowerShell hooks copied into the image
└── Scripts/ ...      # launchers and other files the Dockerfile COPYs
```

`<Name>` is PascalCase (`CounterStrikeSource`, `HalfLife2Deathmatch`). It's the prefix of the
image's release tags and of its `server:<Name>` issue label. The image name is in `server.json`
and doesn't always match the directory (`Battlefield1942` → `lancommander/bf1942`).

`server.json`:

```json
{
  "image": "lancommander/counterstrikesource"
}
```

| Key | Meaning |
|---|---|
| `image` | Docker Hub repository. Required. |
| `base` | `true` for base layers other images build on (Base, SteamCMD, WINE). |
| `tagSuffixes` | Extra tag variants. WINE uses `["", "-gui"]` to keep pushing its old `-gui` aliases. |

The base images form a chain: `Base` → `SteamCMD` → `HalfLife` → `NaturalSelection`, and
`Base` → `WINE`. Game images build `FROM lancommander/<base>:latest`, so a base change reaches
them when they're next built; it doesn't rebuild them.

## Builds and releases

One workflow ([`.github/workflows/build.yml`](.github/workflows/build.yml)) handles every image.

| Event | What happens |
|---|---|
| Pull request, push to `main` | Builds only the images whose directories changed. Nothing is pushed. Changes to only `README.md`, `compose.yml` or `Documentation/` don't rebuild. |
| README change on `main` | Pushes that image's README to Docker Hub as its description. |
| Tag `<Name>/v<version>` | Builds `Servers/<Name>`, pushes `lancommander/<image>:<version>` and `:latest`, and updates the Docker Hub description from its README. |
| Manual run (Actions → Build images) | Builds the listed images (or `all`) with a chosen version; pushes unless told not to. |

To release Counter-Strike: Source 1.0.1:

```bash
git tag CounterStrikeSource/v1.0.1
git push origin CounterStrikeSource/v1.0.1
```

The workflow needs the repository secrets `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` (a token
with read/write/delete access, which updating the Docker Hub description requires), and
`DOCUMENTATION_DISPATCH_TOKEN` for the docs site.

## Building locally

```bash
docker build -t lancommander/counterstrikesource:local Servers/CounterStrikeSource

# against a locally built base image
docker build -t lancommander/steamcmd:local Servers/SteamCMD
docker build --build-arg BASE_IMAGE=lancommander/steamcmd:local \
  -t lancommander/counterstrikesource:local Servers/CounterStrikeSource
```

## Adding a server

1. Copy the closest existing server directory to `Servers/<Name>/` and rename everything in it.
2. Set `image` in `server.json`, and the title/description labels in the Dockerfile.
3. Keep the compose example in `README.md` and `compose.yml` identical.
4. Run `python3 scripts/servers.py generate` to add it to the issue form and the lists below,
   then `python3 scripts/servers.py check`. CI runs the same check.

## Issues

Use the **Server problem** form and pick the server; the issue is labelled `server:<Name>` for
triage. Requests for new games use the **New server request** form.

## Images

<!-- BEGIN GENERATED bases (scripts/servers.py generate) -->
| Base image | Image | Directory |
|---|---|---|
| LANCommander Game Server Base | [`lancommander/base`](https://hub.docker.com/r/lancommander/base) | [`Servers/Base`](Servers/Base) |
| Generic SteamCMD Game Server | [`lancommander/steamcmd`](https://hub.docker.com/r/lancommander/steamcmd) | [`Servers/SteamCMD`](Servers/SteamCMD) |
| Generic WINE Runtime Image | [`lancommander/wine`](https://hub.docker.com/r/lancommander/wine) | [`Servers/WINE`](Servers/WINE) |
<!-- END GENERATED bases -->

<!-- BEGIN GENERATED servers (scripts/servers.py generate) -->
| Server | Image | Directory |
|---|---|---|
| Age of Chivalry | [`lancommander/ageofchivalry`](https://hub.docker.com/r/lancommander/ageofchivalry) | [`Servers/AgeOfChivalry`](Servers/AgeOfChivalry) |
| Aliens vs. Predator 2 | [`lancommander/aliensvspredator2`](https://hub.docker.com/r/lancommander/aliensvspredator2) | [`Servers/AliensVsPredator2`](Servers/AliensVsPredator2) |
| America's Army | [`lancommander/americasarmy`](https://hub.docker.com/r/lancommander/americasarmy) | [`Servers/AmericasArmy`](Servers/AmericasArmy) |
| AquaNox | [`lancommander/aquanox`](https://hub.docker.com/r/lancommander/aquanox) | [`Servers/AquaNox`](Servers/AquaNox) |
| Atomic Bomberman | [`lancommander/atomicbomberman`](https://hub.docker.com/r/lancommander/atomicbomberman) | [`Servers/AtomicBomberman`](Servers/AtomicBomberman) |
| Battlefield 1942 | [`lancommander/bf1942`](https://hub.docker.com/r/lancommander/bf1942) | [`Servers/Battlefield1942`](Servers/Battlefield1942) |
| Battlefield: Bad Company 2 | [`lancommander/battlefieldbadcompany2`](https://hub.docker.com/r/lancommander/battlefieldbadcompany2) | [`Servers/BattlefieldBadCompany2`](Servers/BattlefieldBadCompany2) |
| Battlefield Vietnam | [`lancommander/battlefieldvietnam`](https://hub.docker.com/r/lancommander/battlefieldvietnam) | [`Servers/BattlefieldVietnam`](Servers/BattlefieldVietnam) |
| Blockland | [`lancommander/blockland`](https://hub.docker.com/r/lancommander/blockland) | [`Servers/Blockland`](Servers/Blockland) |
| Call of Duty | [`lancommander/callofduty`](https://hub.docker.com/r/lancommander/callofduty) | [`Servers/CallOfDuty`](Servers/CallOfDuty) |
| Call of Duty 2 | [`lancommander/callofduty2`](https://hub.docker.com/r/lancommander/callofduty2) | [`Servers/CallOfDuty2`](Servers/CallOfDuty2) |
| Call of Duty 4: Modern Warfare | [`lancommander/callofduty4`](https://hub.docker.com/r/lancommander/callofduty4) | [`Servers/CallOfDuty4`](Servers/CallOfDuty4) |
| Call of Juarez: Bound in Blood | [`lancommander/callofjuarezboundinblood`](https://hub.docker.com/r/lancommander/callofjuarezboundinblood) | [`Servers/CallOfJuarezBoundInBlood`](Servers/CallOfJuarezBoundInBlood) |
| Chivalry: Medieval Warfare | [`lancommander/chivalry`](https://hub.docker.com/r/lancommander/chivalry) | [`Servers/Chivalry`](Servers/Chivalry) |
| Command & Conquer: Renegade | [`lancommander/commandandconquerrenegade`](https://hub.docker.com/r/lancommander/commandandconquerrenegade) | [`Servers/CommandAndConquerRenegade`](Servers/CommandAndConquerRenegade) |
| Commandos: Behind Enemy Lines | [`lancommander/commandosbehindenemylines`](https://hub.docker.com/r/lancommander/commandosbehindenemylines) | [`Servers/CommandosBehindEnemyLines`](Servers/CommandosBehindEnemyLines) |
| Counter-Strike: Source | [`lancommander/counterstrikesource`](https://hub.docker.com/r/lancommander/counterstrikesource) | [`Servers/CounterStrikeSource`](Servers/CounterStrikeSource) |
| Daikatana | [`lancommander/daikatana`](https://hub.docker.com/r/lancommander/daikatana) | [`Servers/Daikatana`](Servers/Daikatana) |
| Day of Defeat: Source | [`lancommander/dayofdefeatsource`](https://hub.docker.com/r/lancommander/dayofdefeatsource) | [`Servers/DayOfDefeatSource`](Servers/DayOfDefeatSource) |
| Deer Hunter 2005 | [`lancommander/deerhunter2005`](https://hub.docker.com/r/lancommander/deerhunter2005) | [`Servers/DeerHunter2005`](Servers/DeerHunter2005) |
| Delta Force: Black Hawk Down | [`lancommander/deltaforceblackhawkdown`](https://hub.docker.com/r/lancommander/deltaforceblackhawkdown) | [`Servers/DeltaForceBlackHawkDown`](Servers/DeltaForceBlackHawkDown) |
| Deus Ex | [`lancommander/deusex`](https://hub.docker.com/r/lancommander/deusex) | [`Servers/DeusEx`](Servers/DeusEx) |
| Devastation | [`lancommander/devastation`](https://hub.docker.com/r/lancommander/devastation) | [`Servers/Devastation`](Servers/Devastation) |
| Doom 3 | [`lancommander/doom3`](https://hub.docker.com/r/lancommander/doom3) | [`Servers/Doom3`](Servers/Doom3) |
| Double Action: Boogaloo | [`lancommander/doubleactionboogaloo`](https://hub.docker.com/r/lancommander/doubleactionboogaloo) | [`Servers/DoubleActionBoogaloo`](Servers/DoubleActionBoogaloo) |
| Star Trek: Elite Force | [`lancommander/eliteforce`](https://hub.docker.com/r/lancommander/eliteforce) | [`Servers/EliteForce`](Servers/EliteForce) |
| Far Cry | [`lancommander/farcry`](https://hub.docker.com/r/lancommander/farcry) | [`Servers/FarCry`](Servers/FarCry) |
| F.E.A.R. | [`lancommander/fear`](https://hub.docker.com/r/lancommander/fear) | [`Servers/FEAR`](Servers/FEAR) |
| Fistful of Frags | [`lancommander/fistfuloffrags`](https://hub.docker.com/r/lancommander/fistfuloffrags) | [`Servers/FistfulOfFrags`](Servers/FistfulOfFrags) |
| Freelancer | [`lancommander/freelancer`](https://hub.docker.com/r/lancommander/freelancer) | [`Servers/Freelancer`](Servers/Freelancer) |
| Giants: Citizen Kabuto | [`lancommander/giantscitizenkabuto`](https://hub.docker.com/r/lancommander/giantscitizenkabuto) | [`Servers/GiantsCitizenKabuto`](Servers/GiantsCitizenKabuto) |
| Global Operations | [`lancommander/globaloperations`](https://hub.docker.com/r/lancommander/globaloperations) | [`Servers/GlobalOperations`](Servers/GlobalOperations) |
| GoldenEye: Source | [`lancommander/goldeneyesource`](https://hub.docker.com/r/lancommander/goldeneyesource) | [`Servers/GoldenEyeSource`](Servers/GoldenEyeSource) |
| Half-Life | [`lancommander/halflife`](https://hub.docker.com/r/lancommander/halflife) | [`Servers/HalfLife`](Servers/HalfLife) |
| Half-Life 2: Deathmatch | [`lancommander/halflife2deathmatch`](https://hub.docker.com/r/lancommander/halflife2deathmatch) | [`Servers/HalfLife2Deathmatch`](Servers/HalfLife2Deathmatch) |
| Hexen II | [`lancommander/hexen2`](https://hub.docker.com/r/lancommander/hexen2) | [`Servers/Hexen2`](Servers/Hexen2) |
| Ice Lakes | [`lancommander/icelakes`](https://hub.docker.com/r/lancommander/icelakes) | [`Servers/IceLakes`](Servers/IceLakes) |
| Jedi Knight: Jedi Academy | [`lancommander/jediacademy`](https://hub.docker.com/r/lancommander/jediacademy) | [`Servers/JediAcademy`](Servers/JediAcademy) |
| Star Wars Jedi Knight: Dark Forces II | [`lancommander/jediknight`](https://hub.docker.com/r/lancommander/jediknight) | [`Servers/JediKnight`](Servers/JediKnight) |
| Jedi Knight II: Jedi Outcast | [`lancommander/jedioutcast`](https://hub.docker.com/r/lancommander/jedioutcast) | [`Servers/JediOutcast`](Servers/JediOutcast) |
| King Arthur's Gold | [`lancommander/kingarthursgold`](https://hub.docker.com/r/lancommander/kingarthursgold) | [`Servers/KingArthursGold`](Servers/KingArthursGold) |
| Kiss: Psycho Circus - The Nightmare Child | [`lancommander/kisspsychocircus`](https://hub.docker.com/r/lancommander/kisspsychocircus) | [`Servers/KissPsychoCircus`](Servers/KissPsychoCircus) |
| Left 4 Dead | [`lancommander/left4dead`](https://hub.docker.com/r/lancommander/left4dead) | [`Servers/Left4Dead`](Servers/Left4Dead) |
| Left 4 Dead 2 | [`lancommander/left4dead2`](https://hub.docker.com/r/lancommander/left4dead2) | [`Servers/Left4Dead2`](Servers/Left4Dead2) |
| Legends of Might and Magic | [`lancommander/legendsofmightandmagic`](https://hub.docker.com/r/lancommander/legendsofmightandmagic) | [`Servers/LegendsOfMightAndMagic`](Servers/LegendsOfMightAndMagic) |
| Marvel Heroes | [`lancommander/marvelheroes`](https://hub.docker.com/r/lancommander/marvelheroes) | [`Servers/MarvelHeroes`](Servers/MarvelHeroes) |
| Medal of Honor: Allied Assault | [`lancommander/medalofhonoralliedassault`](https://hub.docker.com/r/lancommander/medalofhonoralliedassault) | [`Servers/MedalOfHonorAlliedAssault`](Servers/MedalOfHonorAlliedAssault) |
| Minecraft: Java Edition | [`lancommander/minecraft`](https://hub.docker.com/r/lancommander/minecraft) | [`Servers/Minecraft`](Servers/Minecraft) |
| Mobile Forces | [`lancommander/mobileforces`](https://hub.docker.com/r/lancommander/mobileforces) | [`Servers/MobileForces`](Servers/MobileForces) |
| The Elder Scrolls III: Morrowind | [`lancommander/morrowind`](https://hub.docker.com/r/lancommander/morrowind) | [`Servers/Morrowind`](Servers/Morrowind) |
| Natural Selection | [`lancommander/naturalselection`](https://hub.docker.com/r/lancommander/naturalselection) | [`Servers/NaturalSelection`](Servers/NaturalSelection) |
| James Bond 007: Nightfire | [`lancommander/nightfire`](https://hub.docker.com/r/lancommander/nightfire) | [`Servers/Nightfire`](Servers/Nightfire) |
| The Operative: No One Lives Forever | [`lancommander/noonelivesforever`](https://hub.docker.com/r/lancommander/noonelivesforever) | [`Servers/NoOneLivesForever`](Servers/NoOneLivesForever) |
| OpenArena | [`lancommander/openarena`](https://hub.docker.com/r/lancommander/openarena) | [`Servers/OpenArena`](Servers/OpenArena) |
| Pirates, Vikings, and Knights II | [`lancommander/piratesvikingsandknightsii`](https://hub.docker.com/r/lancommander/piratesvikingsandknightsii) | [`Servers/PiratesVikingsAndKnightsII`](Servers/PiratesVikingsAndKnightsII) |
| Portal Knights | [`lancommander/portalknights`](https://hub.docker.com/r/lancommander/portalknights) | [`Servers/PortalKnights`](Servers/PortalKnights) |
| Postal 2 | [`lancommander/postal2`](https://hub.docker.com/r/lancommander/postal2) | [`Servers/Postal2`](Servers/Postal2) |
| Project Zomboid | [`lancommander/projectzomboid`](https://hub.docker.com/r/lancommander/projectzomboid) | [`Servers/ProjectZomboid`](Servers/ProjectZomboid) |
| Quake | [`lancommander/quake`](https://hub.docker.com/r/lancommander/quake) | [`Servers/Quake`](Servers/Quake) |
| Quake II | [`lancommander/quake2`](https://hub.docker.com/r/lancommander/quake2) | [`Servers/Quake2`](Servers/Quake2) |
| Quake 3 | [`lancommander/quake3`](https://hub.docker.com/r/lancommander/quake3) | [`Servers/Quake3`](Servers/Quake3) |
| Tom Clancy's Rainbow Six 3: Raven Shield | [`lancommander/ravenshield`](https://hub.docker.com/r/lancommander/ravenshield) | [`Servers/RavenShield`](Servers/RavenShield) |
| Realm Wars | [`lancommander/realmwars`](https://hub.docker.com/r/lancommander/realmwars) | [`Servers/RealmWars`](Servers/RealmWars) |
| Red Faction | [`lancommander/redfaction`](https://hub.docker.com/r/lancommander/redfaction) | [`Servers/RedFaction`](Servers/RedFaction) |
| Return to Castle Wolfenstein | [`lancommander/rtcw`](https://hub.docker.com/r/lancommander/rtcw) | [`Servers/RTCW`](Servers/RTCW) |
| Rune | [`lancommander/rune`](https://hub.docker.com/r/lancommander/rune) | [`Servers/Rune`](Servers/Rune) |
| Serious Sam: The First Encounter | [`lancommander/serioussamthefirstencounter`](https://hub.docker.com/r/lancommander/serioussamthefirstencounter) | [`Servers/SeriousSamTheFirstEncounter`](Servers/SeriousSamTheFirstEncounter) |
| Shogo: Mobile Armor Division | [`lancommander/shogo`](https://hub.docker.com/r/lancommander/shogo) | [`Servers/Shogo`](Servers/Shogo) |
| Soldat | [`lancommander/soldat`](https://hub.docker.com/r/lancommander/soldat) | [`Servers/Soldat`](Servers/Soldat) |
| Star Wars: Battlefront | [`lancommander/starwarsbattlefront`](https://hub.docker.com/r/lancommander/starwarsbattlefront) | [`Servers/StarWarsBattlefront`](Servers/StarWarsBattlefront) |
| Star Wars: Battlefront II | [`lancommander/starwarsbattlefront2`](https://hub.docker.com/r/lancommander/starwarsbattlefront2) | [`Servers/StarWarsBattlefront2`](Servers/StarWarsBattlefront2) |
| Star Wars: Republic Commando | [`lancommander/starwarsrepubliccommando`](https://hub.docker.com/r/lancommander/starwarsrepubliccommando) | [`Servers/StarWarsRepublicCommando`](Servers/StarWarsRepublicCommando) |
| Thievery | [`lancommander/thievery`](https://hub.docker.com/r/lancommander/thievery) | [`Servers/Thievery`](Servers/Thievery) |
| Tremulous | [`lancommander/tremulous`](https://hub.docker.com/r/lancommander/tremulous) | [`Servers/Tremulous`](Servers/Tremulous) |
| Starsiege: Tribes | [`lancommander/tribes`](https://hub.docker.com/r/lancommander/tribes) | [`Servers/Tribes`](Servers/Tribes) |
| Tribes 2 | [`lancommander/tribes2`](https://hub.docker.com/r/lancommander/tribes2) | [`Servers/Tribes2`](Servers/Tribes2) |
| Tribes: Vengeance | [`lancommander/tribesvengeance`](https://hub.docker.com/r/lancommander/tribesvengeance) | [`Servers/TribesVengeance`](Servers/TribesVengeance) |
| Tron 2.0 | [`lancommander/tron2`](https://hub.docker.com/r/lancommander/tron2) | [`Servers/Tron2`](Servers/Tron2) |
| Unreal Tournament 2004 | [`lancommander/ut2004`](https://hub.docker.com/r/lancommander/ut2004) | [`Servers/UT2004`](Servers/UT2004) |
| Vietcong | [`lancommander/vietcong`](https://hub.docker.com/r/lancommander/vietcong) | [`Servers/Vietcong`](Servers/Vietcong) |
| Wolfenstein | [`lancommander/wolfenstein2009`](https://hub.docker.com/r/lancommander/wolfenstein2009) | [`Servers/Wolfenstein2009`](Servers/Wolfenstein2009) |
| XIII | [`lancommander/xiii`](https://hub.docker.com/r/lancommander/xiii) | [`Servers/XIII`](Servers/XIII) |
| Zandronum | [`lancommander/zandronum`](https://hub.docker.com/r/lancommander/zandronum) | [`Servers/Zandronum`](Servers/Zandronum) |
<!-- END GENERATED servers -->

## License

MIT. See [LICENSE](LICENSE).
