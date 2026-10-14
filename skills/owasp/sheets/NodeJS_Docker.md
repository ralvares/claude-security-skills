# Node.js Docker Cheat Sheet

Production-grade guidelines for building optimized, secure Node.js Docker images. Useful for any Node.js app, esp.:

- frontend app using server-side rendering (SSR) Node.js capabilities for React.
- Node.js Docker image for microservices running Fastify, NestJS, other frameworks.

## 1) Use explicit and deterministic Docker base image tags

Docker images referenced by tags; no tag → default `:latest`.

So specifying below in Dockerfile always builds latest image built by **Node.js Docker working group**:

### FROM node

Shortcomings of default `node` image:

1. Inconsistent builds. Like `lockfiles` give deterministic `npm ci` behavior, want deterministic docker image builds. Building from node (= `node:latest` tag) pulls newly built `node` image every build. Avoid non-deterministic behavior.
2. node Docker image based on full-fledged OS, full of libraries/tools you may not need. Two downsides: bigger image = bigger download, more storage, longer download + rebuild; and potentially introduces vulnerabilities from all those libraries/tools.

`node` image quite big, includes hundreds of vulnerabilities of various types/severities. Default starting baseline: 642 vulnerabilities, hundreds of megabytes downloaded on every pull and build.

Recommendations:

1. Use small Docker images: smaller software footprint → fewer vulnerability vectors; smaller size → faster builds
2. Use Docker image digest (static SHA256 hash of image): ensures deterministic builds from base image.

Use Long Term Support (LTS) Node.js version, minimal `alpine` image type for smallest size + footprint:

### FROM node:lts-alpine

This base image directive still pulls new builds of tag. Find `SHA256` hash in Docker Hub for this Node.js tag, or run following after pulling image locally, find `Digest` field in output:

    $ docker pull node:lts-alpine
    lts-alpine: Pulling from library/node
    0a6724ff3fcd: Already exists
    9383f33fa9f3: Already exists
    b6ae88d676fe: Already exists
    565e01e00588: Already exists
    Digest: sha256:b2da3316acdc2bec442190a1fe10dc094e7ba4121d029cb32075ff59bb27390a
    Status: Downloaded newer image for node:lts-alpine
    docker.io/library/node:lts-alpine

Another way to find `SHA256` hash:

    $ docker images --digests
    REPOSITORY                     TAG              DIGEST                                                                    IMAGE ID       CREATED             SIZE
    node                           lts-alpine       sha256:b2da3316acdc2bec442190a1fe10dc094e7ba4121d029cb32075ff59bb27390a   51d926a5599d   2 weeks ago         116MB

Update Dockerfile:

    FROM node@sha256:b2da3316acdc2bec442190a1fe10dc094e7ba4121d029cb32075ff59bb27390a
    WORKDIR /usr/src/app
    COPY . /usr/src/app
    RUN npm ci
    CMD "npm" "start"

But Dockerfile above specifies image name without tag → ambiguity about exact tag; unreadable, hard to maintain, poor developer experience.

Fix: provide full base image tag for Node.js version matching that `SHA256` hash:

    FROM node:lts-alpine@sha256:b2da3316acdc2bec442190a1fe10dc094e7ba4121d029cb32075ff59bb27390a
    WORKDIR /usr/src/app
    COPY . /usr/src/app
    RUN npm ci
    CMD "npm" "start"

## 2) Install only production dependencies in the Node.js Docker image

Directive below installs all dependencies incl. `devDependencies`, not needed for functional app. Adds unneeded security risk from dev dependency packages, inflates image size.

**`RUN npm ci`**

Enforce deterministic builds with `npm ci`. Prevents CI surprises: halts on any deviation from lockfile.

Production image: install only production dependencies deterministically. Best practice:

**`RUN npm ci --omit=dev`**

Updated Dockerfile:

    FROM node:lts-alpine@sha256:b2da3316acdc2bec442190a1fe10dc094e7ba4121d029cb32075ff59bb27390a
    WORKDIR /usr/src/app
    COPY . /usr/src/app
    RUN npm ci --omit=dev
    CMD "npm" "start"

## 3) Optimize Node.js tooling for production

Ensure all frameworks/libraries use optimal performance + security settings.

Add Dockerfile directive:

**`ENV NODE_ENV production`**

Looks redundant (production-only deps already in `npm ci` phase), but `NODE_ENV=production` has other effects beyond dependency installation.

Some frameworks/libraries only enable optimized production configuration if `NODE_ENV` = `production`. Regardless of opinion on this practice, know it.

E.g., Express documentation outlines importance of setting this env var for performance + security optimizations:

`NODE_ENV` performance impact could be very significant.

Many other libraries may also expect this variable; set in Dockerfile.

Updated Dockerfile w/ `NODE_ENV` baked in:

    FROM node:lts-alpine@sha256:b2da3316acdc2bec442190a1fe10dc094e7ba4121d029cb32075ff59bb27390a
    ENV NODE_ENV production
    WORKDIR /usr/src/app
    COPY . /usr/src/app
    RUN npm ci --omit=dev
    CMD "npm" "start"

## 4) Don’t run containers as root

Principle of least privilege: long-time Unix security control; always follow when running containerized Node.js web apps.

Threat: attacker compromising web app via command injection or directory path traversal acts as user owning app process. If root, can do virtually everything in container, incl. attempting container escape or privilege escalation. Don't risk it.

**“friends don’t let friends run containers as root!”**

Official `node` Docker image + variants like `alpine` include least-privileged user of same name: `node`. But running process as `node` alone not enough. E.g., following may not let app function well:

    USER node
    CMD "npm" "start"

`USER` Dockerfile directive only ensures process owned by `node` user. Files copied earlier with `COPY` are owned by root (Docker default).

Complete, proper way to drop privileges, w/ current Dockerfile practices:

    FROM node:lts-alpine@sha256:b2da3316acdc2bec442190a1fe10dc094e7ba4121d029cb32075ff59bb27390a
    ENV NODE_ENV production
    WORKDIR /usr/src/app
    COPY --chown=node:node . /usr/src/app
    RUN npm ci --omit=dev
    USER node
    CMD "npm" "start"

## 5) Properly handle events to safely terminate a Node.js Docker web application

Common mistake: how process is invoked. All following variants are bad patterns to avoid:

- `CMD “npm” “start”`
- `CMD [“yarn”, “start”]`
- `CMD “node” “server.js”`
- `CMD “start-app.sh”`

Key concerns for properly running + terminating Node.js Docker apps:

1. Orchestration engine (Docker Swarm, Kubernetes, Docker engine itself) must send signals to container process. Mostly termination signals: `SIGTERM`, `SIGKILL`.
2. Process may run indirectly; not always guaranteed to receive these signals.
3. Linux kernel treats process ID 1 (PID) differently from any other process ID.

Start with Dockerfile example being built:

**`CMD "npm" "start"`**

Two caveats. First: indirectly running node app by invoking npm client. npm CLI does not forward all events to node runtime; easily tested.

In Node.js app set event handler for `SIGHUP` that logs to console on each event. Example:

    function handle(signal) {
       console.log(`*^!@4=> Received event: ${signal}`)
    }
    process.on('SIGHUP', handle)

Run container, then send `SIGHUP` using `docker` CLI `--signal` flag:

**`$ docker kill --signal=SIGHUP elastic_archimedes`**

Nothing happens: npm client does not forward signals to spawned node process.

Second caveat: two ways to specify `CMD` in Dockerfile, not the same:

1. shellform: container spawns shell interpreter wrapping process. Shell may not forward signals to your process.
2. execform: directly spawns process, no shell wrapper. JSON array notation, e.g., `CMD [“npm”, “start”]`. Signals sent to container go directly to process.

Improve Dockerfile process execution directive:

**`CMD ["node", "server.js"]`**

Invokes node directly: receives all signals, no shell interpreter wrapper.

New pitfall though.

Processes running as PID 1 take on some init system responsibilities (typically initializing OS + processes). Kernel treats PID 1 differently: `SIGTERM` to running process won't invoke default fallback of killing process if process hasn't set a handler for it.

<!-- textlint-disable terminology -->
Node.js Docker working group recommendation: “Node.js was not designed to run as PID 1 which leads to unexpected behaviour when running inside of Docker. For example, a Node.js process running as PID 1 will not respond to SIGINT (CTRL-C) and similar signals”.
<!-- textlint-enable terminology -->

Solution: tool acting as init process: invoked as PID 1, spawns Node.js app as another process, proxies all signals to it. Prefer smallest possible tooling footprint to avoid adding vulnerabilities to image.

One such tool: dumb-init, statically linked, small footprint. Setup:

    RUN apk add dumb-init
    CMD ["dumb-init", "node", "server.js"]

Updated Dockerfile. `dumb-init` install placed right after image declaration to benefit from Docker layer caching:

    FROM node:lts-alpine@sha256:b2da3316acdc2bec442190a1fe10dc094e7ba4121d029cb32075ff59bb27390a
    RUN apk add dumb-init
    ENV NODE_ENV production
    WORKDIR /usr/src/app
    COPY --chown=node:node . .
    RUN npm ci --omit=dev
    USER node
    CMD ["dumb-init", "node", "server.js"]

Good to know: `docker kill` and `docker stop` only send signals to container process with PID 1. If shell script runs your Node.js app, note shell instance (e.g., `/bin/sh`) doesn’t forward signals to child processes → app never gets `SIGTERM`.

## 6) Graceful tear down for your Node.js web applications

Shut down processes properly + gracefully without disrupting users.

Node.js app receiving interrupt signal `SIGINT` or `CTRL+C` is abruptly killed unless event handlers set otherwise. Connected clients immediately disconnected. Imagine hundreds of Node.js web containers orchestrated by Kubernetes scaling up/down or handling errors: poor user experience.

Simulate: stock Fastify app, endpoint with inherent 60 seconds delayed response:

    fastify.get('/delayed', async (request, reply) => {
     const SECONDS_DELAY = 60000
     await new Promise(resolve => {
         setTimeout(() => resolve(), SECONDS_DELAY)
     })
     return { hello: 'delayed world' }
    })
     
    const start = async () => {
     try {
       await fastify.listen(PORT, HOST)
       console.log(`*^!@4=> Process id: ${process.pid}`)
     } catch (err) {
       fastify.log.error(err)
       process.exit(1)
     }
    }
     
    start()

Run app, send HTTP request to endpoint:

`$ time curl https://localhost:3000/delayed`

Hit `CTRL+C` in running Node.js console: curl request exits abruptly. Same experience users get when containers tear down.

Better:

1. Set event handler for termination signals like `SIGINT`, `SIGTERM`.
2. Handler waits for clean up (database connections, ongoing HTTP requests etc.).
3. Handler then terminates Node.js process.

With Fastify, handler calls fastify.close(), returns promise to await; Fastify also responds to every new connection with HTTP status code 503 signaling app unavailable.

Add event handler:

    async function closeGracefully(signal) {
       console.log(`*^!@4=> Received signal to terminate: ${signal}`)
     
       await fastify.close()
       // await db.close() if we have a db connection in this app
       // await other things we should cleanup nicely
       process.exit()
    }
    process.on('SIGINT', closeGracefully)
    process.on('SIGTERM', closeGracefully)

More generic web app concern than Dockerfile, but even more important in orchestrated environments.

## 7) Find and fix security vulnerabilities in your Node.js docker image

See Docker Security Cheat Sheet - Use static analysis tools

## 8) Use multi-stage builds

Multi-stage builds: move from simple, potentially erroneous Dockerfile to separated build steps, avoiding leaking sensitive info. Also use bigger base image to install dependencies/compile native npm packages, then copy artifacts into small production base image (e.g., alpine).

### Prevent sensitive information leak

Sensitive info leakage use-case more common than thought.

Building Docker images for work: likely maintain private npm packages → need secret `NPM_TOKEN` available to npm install.

Example:

    FROM node:lts-alpine@sha256:b2da3316acdc2bec442190a1fe10dc094e7ba4121d029cb32075ff59bb27390a
    RUN apk add dumb-init
    ENV NODE_ENV production
    ENV NPM_TOKEN 1234
    WORKDIR /usr/src/app
    COPY --chown=node:node . .
    #RUN npm ci --omit=dev
    RUN echo "//registry.npmjs.org/:_authToken=$NPM_TOKEN" > .npmrc && \
       npm ci --omit=dev
    USER node
    CMD ["dumb-init", "node", "server.js"]

Leaves `.npmrc` file with secret npm token inside Docker image. Deleting afterwards:

    RUN echo "//registry.npmjs.org/:_authToken=$NPM_TOKEN" > .npmrc && \
       npm ci --omit=dev
    RUN rm -rf .npmrc

`.npmrc` still available in different layer of image. If image public or accessible, token compromised. Better:

    RUN echo "//registry.npmjs.org/:_authToken=$NPM_TOKEN" > .npmrc && \
       npm ci --omit=dev; \
       rm -rf .npmrc

Now Dockerfile itself must be treated as secret asset: contains secret npm token.

Docker supports passing arguments into build process:

    ARG NPM_TOKEN
    RUN echo "//registry.npmjs.org/:_authToken=$NPM_TOKEN" > .npmrc && \
       npm ci --omit=dev; \
       rm -rf .npmrc

Build:

**`$ docker build . -t nodejs-tutorial --build-arg NPM_TOKEN=1234`**

Still a pitfall: build arguments passed like that are kept in history log. Run:

**`$ docker history nodejs-tutorial`**

Prints:

    IMAGE          CREATED              CREATED BY                                      SIZE      COMMENT
    b4c2c78acaba   About a minute ago   CMD ["dumb-init" "node" "server.js"]            0B        buildkit.dockerfile.v0
    <missing>      About a minute ago   USER node                                       0B        buildkit.dockerfile.v0
    <missing>      About a minute ago   RUN |1 NPM_TOKEN=1234 /bin/sh -c echo "//reg…   5.71MB    buildkit.dockerfile.v0
    <missing>      About a minute ago   ARG NPM_TOKEN                                   0B        buildkit.dockerfile.v0
    <missing>      About a minute ago   COPY . . # buildkit                             15.3kB    buildkit.dockerfile.v0
    <missing>      About a minute ago   WORKDIR /usr/src/app                            0B        buildkit.dockerfile.v0
    <missing>      About a minute ago   ENV NODE_ENV=production                         0B        buildkit.dockerfile.v0
    <missing>      About a minute ago   RUN /bin/sh -c apk add dumb-init # buildkit     1.65MB    buildkit.dockerfile.v0

Secret npm token visible. Better secret management exists for container images, but multi-stage builds are mitigation here + show building minimal images.

### Introducing multi-stage builds for Node.js Docker images

Separation of Concerns applied to Node.js Docker images. First stage image builds everything app needs to run: install npm packages, compile native npm modules if necessary.

Second stage = production Docker image: optimized and published to registry. First image (`build` image) discarded; left as dangling image on build Docker host until cleaned.

Dockerfile so far, in two stages:

    # --------------> The build image
    FROM node:latest AS build
    ARG NPM_TOKEN
    WORKDIR /usr/src/app
    COPY package*.json /usr/src/app/
    RUN echo "//registry.npmjs.org/:_authToken=$NPM_TOKEN" > .npmrc && \
       npm ci --omit=dev && \
       rm -f .npmrc
     
    # --------------> The production image
    FROM node:lts-alpine@sha256:b2da3316acdc2bec442190a1fe10dc094e7ba4121d029cb32075ff59bb27390a
    RUN apk add dumb-init
    ENV NODE_ENV production
    USER node
    WORKDIR /usr/src/app
    COPY --chown=node:node --from=build /usr/src/app/node_modules /usr/src/app/node_modules
    COPY --chown=node:node . /usr/src/app
    CMD ["dumb-init", "node", "server.js"]

Bigger image chosen for `build` stage: may need tooling like `gcc` (GNU Compiler Collection) to compile native npm packages, or other needs.

Second stage: special `COPY` notation copies `node_modules/` folder from build image into new production base image.

`NPM_TOKEN` passed as build argument to intermediary `build` image no longer visible in `docker history nodejs-tutorial` output: not in production image.

## 9) Keeping unnecessary files out of your Node.js Docker images

`.gitignore` avoids polluting git repo with unnecessary/sensitive files; same for Docker images.

`.dockerignore`: Docker skips sending glob pattern matches in it to Docker daemon. Files ideally avoided in image:

    .dockerignore
    node_modules
    npm-debug.log
    Dockerfile
    .git
    .gitignore

`node_modules/` important to skip: otherwise simplistic starting Dockerfile would copy local `node_modules/` into container as-is.

    FROM node@sha256:b2da3316acdc2bec442190a1fe10dc094e7ba4121d029cb32075ff59bb27390a
    WORKDIR /usr/src/app
    COPY . /usr/src/app
    RUN npm ci
    CMD "npm" "start"

Even more important with multi-stage builds. 2nd stage reminder:

    # --------------> The production image
    FROM node:lts-alpine
    RUN apk add dumb-init
    ENV NODE_ENV production
    USER node
    WORKDIR /usr/src/app
    COPY --chown=node:node --from=build /usr/src/app/node_modules /usr/src/app/node_modules
    COPY --chown=node:node . /usr/src/app
    CMD ["dumb-init", "node", "server.js"]

`COPY . /usr/src/app` from 2nd stage also copies local node\_modules/ into image. Big no-no: may copy modified source code inside `node_modules/`.

Wildcard `COPY .` may also copy sensitive files (credentials, local configuration) into image.

`.dockerignore` take-aways:

- Skip potentially modified copies of `node_modules/` in image.
- Prevents secrets exposure, e.g., credentials in `.env` or `aws.json` reaching Node.js Docker image.
- Speeds builds: ignores files that would cause cache invalidation (e.g., modified log file or local environment config invalidating cache at local-directory copy layer).

## 10) Mounting secrets into the Docker build image

`.dockerignore` is all-or-nothing; can't be toggled per stage in multi-stage build.

Why matters: want `.npmrc` in build stage (secret npm token for private packages; maybe proxy/registry config), but not in production stage image (sensitive info like secret npm token).

One mitigation: mount local file system available for build stage; better way exists.

Docker secrets (relatively new capability) fits `.npmrc`:

- `docker build` command-line arguments define new secret ID + reference file as secret source.
- In Dockerfile, add flags to `RUN` directive installing production npm: mounts file referenced by secret ID to target location (local directory `.npmrc` file).
- `.npmrc` mounted as secret; never copied into Docker image.
- Add `.npmrc` to `.dockerignore` so it never reaches image (build or production).

Updated `.dockerignore`:

    .dockerignore
    node_modules
    npm-debug.log
    Dockerfile
    .git
    .gitignore
    .npmrc

Complete Dockerfile, with updated RUN directive installing npm packages w/ `.npmrc` mount point:

    # --------------> The build image
    FROM node:latest AS build
    WORKDIR /usr/src/app
    COPY package*.json /usr/src/app/
    RUN --mount=type=secret,mode=0644,id=npmrc,target=/usr/src/app/.npmrc npm ci --omit=dev
     
    # --------------> The production image
    FROM node:lts-alpine
    RUN apk add dumb-init
    ENV NODE_ENV production
    USER node
    WORKDIR /usr/src/app
    COPY --chown=node:node --from=build /usr/src/app/node_modules /usr/src/app/node_modules
    COPY --chown=node:node . /usr/src/app
    CMD ["dumb-init", "node", "server.js"]

Build command:

    docker build . -t nodejs-tutorial --secret id=npmrc,src=.npmrc

**Note:** Secrets new Docker feature; older version may need Buildkit enabled:

    DOCKER_BUILDKIT=1 docker build . -t nodejs-tutorial --build-arg NPM_TOKEN=1234 --secret id=npmrc,src=.npmrc

## References

- Node.js Docker: Best Practices
- Docker: Build secrets
