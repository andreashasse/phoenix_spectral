SHELL    := /bin/bash
PID_FILE := /tmp/example_phoenix_server.pid
PORT     := 4000
BASE_URL := http://localhost:$(PORT)

start:
	mix phx.server & echo $$! > $(PID_FILE)

stop:
	@if [ -f $(PID_FILE) ]; then \
		kill $$(cat $(PID_FILE)) 2>/dev/null; rm -f $(PID_FILE); \
	else \
		lsof -ti:$(PORT) | xargs kill -9 2>/dev/null; true; \
	fi

restart: stop start

integration-test:
	mix test

kill-port:
	@lsof -ti:$(PORT) | xargs kill -9 2>/dev/null; true

.PHONY: start stop restart integration-test kill-port
