#!/usr/bin/env bash

API_URL=/ envsubst < build/Environment.elm > src/Environment.elm
elm-live src/Pokertool.elm --hot --host=localhost --dir=dist --proxy-host=https://ndcnd2zhda.execute-api.eu-west-1.amazonaws.com/room --proxy-prefix=/room -- --output=dist/app.js --debug
