# Search BUMP-JIRA-AUDIT in this file to find every ARG that must be
# reviewed when targeting a different Jira version.

# BUMP-JIRA-AUDIT: Java runtime image. Jira 11.x = JDK 21 only;
# Jira 10.x = JDK 17; Jira 9.x = JDK 11; Jira 8.x = JDK 8.
# https://confluence.atlassian.com/adminjiraserver/supported-platforms-938846830.html
ARG JAVA_IMAGE=eclipse-temurin:8-jdk-jammy

# === base ====================================================================
# Common scaffolding shared by `unwarmed`, `warmer`, and `warmed`.
FROM ${JAVA_IMAGE} AS base

# BUMP-JIRA-AUDIT: AMPS (Atlassian Maven Plugin Suite). Verify the
# version is actually published in the Maven repo (release-notes pages
# can announce versions before they ship to Maven):
#   curl https://packages.atlassian.com/maven-external/com/atlassian/amps/atlassian-plugin-sdk/maven-metadata.xml
# Take the <release> value (or the latest <version> in the line you
# need). 8.2.x = Jira 8 (Java 8 / Spring 5 / javax.*); 9.0-9.2.x =
# Jira 10; 9.11.x = Jira 11. Release-notes index for context only:
# https://developer.atlassian.com/server/framework/atlassian-sdk/amps-sdk-release-notes/
# Note: AMPS_VERSION is consumed twice - by install-sdk.sh against the
# atlassian-plugin-sdk tarball, and by the pom against jira-maven-plugin.
# The two artifacts can drift: the SDK tarball ships 8.2.4-8.2.10 but
# jira-maven-plugin in the 8.2.x line tops out at 8.2.3, so 8.2.3 is
# the highest version that resolves on BOTH sides.
ARG AMPS_VERSION=8.2.3

# BUMP-JIRA-AUDIT: Jira version baked as default for atlas-run.
# Caller can override at runtime: docker run -e JIRA_VERSION=8.20.29 ...
# 8.20.x final = 8.20.30 (EOL Jan 2024).
# https://confluence.atlassian.com/jirasoftware/jira-software-8-20-x-release-notes-1086411771.html
ARG JIRA_VERSION=8.20.30
ENV JIRA_VERSION=${JIRA_VERSION}

# DEBIAN_FRONTEND is build-time only; ARG (not ENV) keeps it out of the
# final image's runtime environment. install-sdk.sh inherits the build
# env automatically.
ARG DEBIAN_FRONTEND=noninteractive
ENV PATH=/opt/atlassian-plugin-sdk/bin:${PATH}

# SDK install. Tarball is the only supported path - the apt repo at
# packages.atlassian.com/atlassian-sdk-deb was retired Feb 2018.
COPY scripts/install-sdk.sh /tmp/install-sdk.sh
RUN bash /tmp/install-sdk.sh "${AMPS_VERSION}" && rm /tmp/install-sdk.sh

WORKDIR /opt/jira-plugin
COPY plugin/ ./

EXPOSE 2990

# === warmer ==================================================================
# Build-time-only stage. Runs atlas-run in the background, polls
# /rest/api/2/serverInfo until 200, SIGTERMs the JVM, validates that
# the warmed paths exist + are non-empty. The `warmed` stage COPY-s
# those paths from this stage's filesystem.
FROM base AS warmer
COPY scripts/warm.sh /tmp/warm.sh
RUN bash /tmp/warm.sh && rm /tmp/warm.sh

# === warmed ==================================================================
# Runtime stage with the Maven cache + unpacked Jira webapp baked in.
# Caller picks this via `docker build --target warmed`. Cold-boot
# becomes ~1-2min instead of ~10-20min because Maven downloads + war
# unpack + initial DB schema are pre-populated. -o (offline) keeps
# Maven from reaching out at runtime since the cache is fully populated.
FROM base AS warmed
COPY --from=warmer /root/.m2 /root/.m2
COPY --from=warmer /opt/jira-plugin/target /opt/jira-plugin/target
# -DskipAllPrompts=true: AMPS hardcodes a call to the shut-down
# Atlassian Marketplace v1 endpoint at startup. This flag makes the
# resulting 404 non-fatal so the boot proceeds.
# Caller MUST run with -it; atlas-run exits without a TTY.
ENTRYPOINT ["atlas-run", "-DskipAllPrompts=true", "-o"]

# === unwarmed (default target) ===============================================
# Default `docker build .` target. Boots cold every container start
# (~5-10min for Jira 8). Use `--target warmed` to opt into the
# pre-baked variant when the upfront ~15-20min build cost is acceptable.
FROM base AS unwarmed
# -DskipAllPrompts=true: same Marketplace v1 endpoint workaround as
# above. Caller MUST run with -it; atlas-run exits without a TTY.
ENTRYPOINT ["atlas-run", "-DskipAllPrompts=true"]
