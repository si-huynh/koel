# Overview

This document provides the complete epic and story breakdown for koel, decomposing the requirements from the PRD, Addendum, and Architecture into implementable stories.

koel is a 10-package Dart/Flutter SDK implementing the AG-UI protocol. Architectural decisions (`koel_lints` is path-dependency for every other package; lock-step foundations; hybrid versioning; vendor-inline RFC 6902; hand-rolled web SSE transport; etc.) constrain the order and shape of stories. The architecture document already names the implementation block order; this document operationalizes it as epics + stories with acceptance criteria.
