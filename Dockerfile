# Search BUMP-JIRA-AUDIT in this file to find every ARG that must be
# reviewed when targeting a different Jira version.

# BUMP-JIRA-AUDIT: Java runtime image. Jira 11.x = JDK 21 only;
# Jira 10.x = JDK 17; Jira 9.x = JDK 11; Jira 8.x = JDK 8.
# https://confluence.atlassian.com/adminjiraserver/supported-platforms-938846830.html
ARG JAVA_IMAGE=eclipse-temurin:21-jdk-jammy

FROM ${JAVA_IMAGE}

# BUMP-JIRA-AUDIT: AMPS (Atlassian Maven Plugin Suite). Verify the
# version is actually published in the Maven repo (release-notes pages
# can announce versions before they ship to Maven):
#   curl https://packages.atlassian.com/maven-external/com/atlassian/amps/atlassian-plugin-sdk/maven-metadata.xml
# Take the <release> value (or the latest <version> in the line you
# need). 9.11.x = Jira 11 (latest published as of Apr 2026);
# 9.0-9.2.x = Jira 10. Release-notes index for context only:
# https://developer.atlassian.com/server/framework/atlassian-sdk/amps-sdk-release-notes/
ARG AMPS_VERSION=9.11.2

# BUMP-JIRA-AUDIT: Jira version baked as default for atlas-run.
# Caller can override at runtime: docker run -e JIRA_VERSION=11.3.5 ...
# Latest 11.3.x LTS (Apr 2026) = 11.3.4.
# https://confluence.atlassian.com/jirasoftware/jira-software-11-3-x-release-notes-1689288832.html
ARG JIRA_VERSION=11.3.4
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

# -DskipAllPrompts=true: AMPS hardcodes a call to the shut-down
# Atlassian Marketplace v1 endpoint at startup. This flag makes the
# resulting 404 non-fatal so the boot proceeds.
# Caller MUST run with -it; atlas-run exits without a TTY.
ENTRYPOINT ["atlas-run", "-DskipAllPrompts=true"]
