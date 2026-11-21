#!/bin/sh
set -eu
cd "$(dirname "$0")"
go mod download
go mod verify
