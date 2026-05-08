#!/usr/bin/env bash

source $(dirname "$0")/testlib.sh

header "testlib.sh Showcase"

comment "simple echo with quoting"
run echo "run pretty prints the command" "and runs it"

comment "inline json"
apicall -X POST https://jsonplaceholder.typicode.com/posts \
  -H 'Content-Type: application/json' \
  -d '{"title": "test", "body": "bar", "userId": 1}'

comment "headers"
apicall -X PUT https://httpbin.org/anything \
  -H 'Authorization: Bearer token123' \
  -d 'param1=value1&param2=value2'
