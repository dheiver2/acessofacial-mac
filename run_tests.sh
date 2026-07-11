#!/bin/bash
set -e
cd "$(dirname "$0")"
swift build
.build/debug/AcessoFacial --test
