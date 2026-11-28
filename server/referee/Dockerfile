# Battle referee (plan area 7, item 2687): Godot 4.7.2 headless with the game's battle code and
# data. Build context is the repository root (see server/docker-compose.yml).
FROM barichello/godot-ci:4.7.2
RUN apt-get update -q && DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends postgresql-client \
	&& rm -rf /var/lib/apt/lists/*
WORKDIR /game
# The game project without tests, docs and store files. The referee itself only runs
# scripts/battle/ (BattleReferee), but the project's class names and autoloads need the rest.
COPY project.godot ./
COPY scripts ./scripts
COPY data ./data
COPY scenes ./scenes
COPY art ./art
COPY audio ./audio
COPY shaders ./shaders
COPY addons ./addons
COPY server/referee ./server/referee
RUN godot --headless --path /game --import >/dev/null 2>&1 || true
CMD ["bash", "/game/server/referee/run.sh"]
