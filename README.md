# Note
The goal of this project is that everything is built and run inside Docker with no changes of source of OneCLI or NanoClaw
```bash
git clone --branch=v2.0.63 git@github.com:nanocoai/nanoclaw.git
git clone --branch=v1.24.0 git@github.com:onecli/onecli.git

# This must remain clean
git -C onecli/ status --ignored
git -C nanoclaw/ status --ignored
```

# First time setup
```bash
cp res/gen_env.sample.sh res/gen_env.sh # and configure API key
```

# Setup with Docker out of Docker

```bash
./res/gen_env.sh
docker compose -f docker-compose.dood.yml up -d --build --wait
docker compose -f docker-compose.dood.yml exec -u node nanoclaw pnpm exec tsx scripts/init-cli-agent.ts --display-name "My Name" --agent-name "NanoClaw1"
docker compose -f docker-compose.dood.yml exec -u node nanoclaw pnpm run chat "tell me something about cats"
```

Delete all persistent local data:

```bash
docker compose -f docker-compose.dood.yml down -v
```

# Setup with Docker in Docker

```bash
./res/gen_env.sh
docker compose -f docker-compose.dind.yml up -d --build --wait
docker compose -f docker-compose.dind.yml exec -u node nanoclaw pnpm exec tsx scripts/init-cli-agent.ts --display-name "My Name" --agent-name "NanoClaw1"
docker compose -f docker-compose.dind.yml exec -u node nanoclaw pnpm run chat "tell me something about cats"

# Inspect the docker inside
docker compose -f docker-compose.dind.yml exec nanoclaw docker ps -a
```

Delete all persistent local data:

```bash
docker compose -f docker-compose.dind.yml down -v
```
