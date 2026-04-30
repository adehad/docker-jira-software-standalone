# Docker Jira Software Standalone


[![License](https://img.shields.io/github/license/Addono/docker-jira-software-standalone?style=flat-square)](https://github.com/Addono/docker-jira-software-standalone/blob/master/LICENSE)
[![Project Status: Unsupported – The project has reached a stable, usable state but the author(s) have ceased all work on it. A new maintainer may be desired.](https://www.repostatus.org/badges/latest/unsupported.svg)](https://www.repostatus.org/#unsupported)
![GitHub Workflow Status - Docker](https://img.shields.io/github/actions/workflow/status/Addono/docker-jira-software-standalone/dockerpublish.yml?style=flat-square)
[
![Docker Image Pulls (all-time)](https://img.shields.io/docker/pulls/addono/jira-software-standalone?style=flat-square)
![Docker Image Version (latest semver)](https://img.shields.io/docker/v/addono/jira-software-standalone?sort=semver&style=flat-square)
](https://hub.docker.com/r/addono/jira-software-standalone)<!-- ALL-CONTRIBUTORS-BADGE:START - Do not remove or modify this section -->
[![All Contributors](https://img.shields.io/badge/all_contributors-1-orange.svg?style=flat-square)](#contributors-)
<!-- ALL-CONTRIBUTORS-BADGE:END -->


## 📝 Table of Contents

<!-- TOC kept at the addono baseline (About / Usage / Contributors)
     intentionally; Travis CI, Jira 11 variant, and Development are not
     listed here so the upstream-PR diff back to Addono/master stays
     scoped to the build-system change. Update the TOC alongside any
     future structural rework. -->

- [About](#about)
- [Usage](#usage)
- [Contributors](#contributors)

## 🧐 About <a name = "about"></a>

Dockerized version of Jira Software to easily spin up development versions without having to deal with the hassle of managing licences.

This image uses  `atlas-cli` to create an empty Jira Software instance by launching a development environment for an empty plugin. Starting this development environment can be very slow (expect it to take more than 5 minutes), so this is best used for asyncronous tasks, such as running in your CI pipeline.

## 🎈 Usage <a name="usage"></a>

This image is published to [Docker Hub](https://hub.docker.com/r/addono/jira-software-standalone). Using them is easy, to run it in the foreground:
```bash
docker run -it -p 2990:2990 --name jira addono/jira-software-standalone
```

Or in detached mode as to run it in the background:
```bash
docker run -d -it -p 2990:2990 --name jira addono/jira-software-standalone
```

_Note: Make sure that the `-i` flag is enabled, as without it the server will exit the moment it completed booting._

## Jira 11 variant

The `jira-11` branch builds a self-hosted variant of this image targeting
Jira Software 11.x (Java 21, AMPS 9.12.x). Published to GitHub Container
Registry under the maintainer's account:

`ghcr.io/adehad/jira-software-standalone:<jira-version>`

```bash
docker run -dit -p 2990:2990 --name jira \
  ghcr.io/adehad/jira-software-standalone:11.3.4
```

The `master` branch and the Docker Hub `addono/jira-software-standalone`
image continue to serve Jira 8.x; the two are not interchangeable
because Jira 11 requires JDK 21 at runtime.

## 🛠️ Development

### How a Jira version flows through the build

`Dockerfile` declares three coupled `ARG`s: `JAVA_IMAGE`, `AMPS_VERSION`,
`JIRA_VERSION`. `JIRA_VERSION` is also exported as `ENV`, and
`plugin/pom.xml` reads it via `<jira.version>${env.JIRA_VERSION}</jira.version>`.

This means three things at runtime:

1. The Jira version that boots is the `JIRA_VERSION` env in the container,
   which defaults to the build-time `ARG` value but can be overridden:
   `docker run -e JIRA_VERSION=11.3.5 ...` (within the same major).
2. `AMPS_VERSION` and `JAVA_IMAGE` are baked at build time only — there
   is no runtime override; bumping a Jira major requires a fresh build.
3. The pom is otherwise version-agnostic: AMPS itself dispatches to the
   right Jira artifacts based on `${jira.version}`.

### Bumping the targeted Jira version

<!-- BUMP-JIRA-AUDIT: pointer comment - keep in sync with the markers
     in Dockerfile and plugin/pom.xml. The recipe lives in those files,
     not here, so we do not duplicate URLs that may drift. -->

Every line that must change when retargeting Jira carries a
`BUMP-JIRA-AUDIT:` comment with the upstream source URL and the rule for
picking the next value. Enumerate them:

```bash
grep -rn "BUMP-JIRA-AUDIT" Dockerfile plugin/pom.xml \
  .github/workflows/ghcr-publish.yml README.md
```

Walk each match, follow its cited source, update the value. The
Dockerfile `ARG` defaults, pom properties, and the workflow's
`jira_version` input default must all agree; the audit markers are the
exhaustive list of places to touch.

### Building and smoke-testing locally

```bash
docker build \
  --build-arg JIRA_VERSION=11.3.4 \
  -t jira-software-standalone:dev .

bash scripts/smoke.sh jira-software-standalone:dev 11.3.4 ./artifacts
```

`scripts/smoke.sh` starts the container, polls Dashboard.jspa until Jira
responds (cold boot 10–20 min), asserts `/rest/api/2/serverInfo` returns
the expected version, and dumps container logs to `./artifacts/`.

### When smoke fails on a fresh Jira version

`plugin/pom.xml` carries the scaffold dependencies (junit, gson,
javax.inject, atlassian-plugins-osgi-testrunner, atlassian-spring-scanner)
commented out — `plugin/src/` is empty so nothing references them. If
`atlas-run` fails with `NoClassDefFoundError` on a class belonging to one
of these:

1. Uncomment the offending dependency block.
2. Bump it to a current Jakarta-aware version (Maven Central for `junit`
   / `gson`; `packages.atlassian.com/maven-external` for the rest).
3. Re-run the workflow. Commit with `Refs: <hash>` where `<hash>` is the
   short SHA of the `feat(jira-11)` commit that introduced the Dockerfile
   and pom changes (use `git log --oneline --grep "feat(jira-11)"`).

### Publishing

`.github/workflows/ghcr-publish.yml` is `workflow_dispatch` only. Inputs:

- `jira_major` — string, default matches Dockerfile (e.g. `11`).
- `jira_minor_patch` — string, default matches Dockerfile (e.g. `3.4`).
- `tag_latest` — boolean; when true, also pushes `:<major>-latest`
  (e.g. `:11-latest`). Safe per-major — different majors don't collide
  on `:<major>-latest`.
- `tag_warm` — boolean; **reserved** for the future warmed-variant tag
  scheme (`:<version>-warm`, `:<major>-warm-latest`). Currently a no-op
  guard — setting true fails the workflow until the warmer is
  integrated.

Tag composition:

- Primary tag (always): `<jira_major>.<jira_minor_patch>` (e.g. `:11.3.4`).
- Floating tag (when `tag_latest=true`): `<jira_major>-latest` (e.g. `:11-latest`).

The job builds, smoke-tests, and pushes only on green smoke. Logs
upload as workflow artifacts regardless of outcome.

First push creates the GHCR package as **private**. Flip to public once
via `Packages → jira-software-standalone → Settings → Change visibility`.

## Travis CI

This is one way on how to use this image in a Travis CI pipeline. Add the following lines to your `.travis.yaml` file and access it at the location specified in the environment variables.

```yaml
# Let the CI runner provision Docker for us
services:
  - docker

# Spin up the Jira instance before we run our jobs
before_install:
# Launch a Jira instance in detached mode
  - docker run -dit -p 2990:2990 --name jira addono/jira-software-standalone
# Wait until Jira has booted
  - until $(curl -u $CI_JIRA_ADMIN:$CI_JIRA_ADMIN_PASSWORD --output /dev/null --silent --head --fail $CI_JIRA_URL/rest/api/2/permissions); do sleep 5; done

# Set the default hostname and admin user credentials as environment variables
env:
  global:
    - CI_JIRA_URL=http://localhost:2990/jira
    - CI_JIRA_ADMIN=admin
    - CI_JIRA_ADMIN_PASSWORD=admin
```



## ✨ Contributors <a name = "contributors"></a>

Thanks goes to these wonderful people ([emoji key](https://allcontributors.org/docs/en/emoji-key)):

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tr>
    <td align="center"><a href="https://aknapen.nl"><img src="https://avatars1.githubusercontent.com/u/15435678?v=4" width="100px;" alt=""/><br /><sub><b>Adriaan Knapen</b></sub></a><br /><a href="https://github.com/Addono/docker-jira-software-standalone/commits?author=addono" title="Code">💻</a> <a href="https://github.com/Addono/docker-jira-software-standalone/commits?author=addono" title="Tests">⚠️</a> <a href="https://github.com/Addono/docker-jira-software-standalone/commits?author=addono" title="Documentation">📖</a></td>
  </tr>
</table>

<!-- markdownlint-enable -->
<!-- prettier-ignore-end -->
<!-- ALL-CONTRIBUTORS-LIST:END -->

This project follows the [all-contributors](https://github.com/all-contributors/all-contributors) specification. Contributions of any kind welcome!
