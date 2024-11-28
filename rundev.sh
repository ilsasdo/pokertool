#!/usr/bin/env bash

elm-live src/Pokertool.elm --hot --host=localhost --dir=dist --proxy-host=https://ndcnd2zhda.execute-api.eu-west-1.amazonaws.com/room --proxy-prefix=/room -- --output=dist/app.js --debug
