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

wait:
	@echo "Waiting for server on port $(PORT)..."
	@for i in $$(seq 1 30); do \
		curl -sf $(BASE_URL)/users > /dev/null 2>&1 && echo "Server ready." && exit 0; \
		sleep 1; \
	done; \
	echo "Server did not become ready in 30 seconds." && exit 1

check:
	@_check() { \
		local desc=$$1 expected=$$2; shift 2; \
		local actual; actual=$$(curl -s -o /dev/null -w "%{http_code}" "$$@"); \
		if [ "$$actual" = "$$expected" ]; then \
			echo "PASS: $$desc"; \
		else \
			echo "FAIL: $$desc — expected $$expected, got $$actual"; \
			exit 1; \
		fi; \
	}; \
	_check_body_absent() { \
		local desc=$$1 key=$$2; shift 2; \
		local http_code body; \
		body=$$(curl -s -w "\n%{http_code}" "$$@"); \
		http_code=$$(echo "$$body" | tail -1); \
		body=$$(echo "$$body" | head -n -1); \
		if [ "$$http_code" != "200" ]; then \
			echo "FAIL: $$desc — expected 200, got $$http_code"; \
			exit 1; \
		fi; \
		if echo "$$body" | grep -q "\"$$key\""; then \
			echo "FAIL: $$desc — \"$$key\" found in response: $$body"; \
			exit 1; \
		else \
			echo "PASS: $$desc"; \
		fi; \
	}; \
	_check "GET /users returns 200" \
		200 $(BASE_URL)/users; \
	_check "GET /users/user:1 returns 200" \
		200 "$(BASE_URL)/users/user:1"; \
	_check "GET /users/user:99 returns 404" \
		404 "$(BASE_URL)/users/user:99"; \
	_check "POST /users without x-api-key returns 400" \
		400 -X POST \
		    -H "content-type: application/json" \
		    -d '{"name":"Test","email":"test@example.com"}' \
		    $(BASE_URL)/users; \
	_check "POST /users with x-api-key returns 201" \
		201 -X POST \
		    -H "content-type: application/json" \
		    -H "x-api-key: secret" \
		    -d '{"name":"Test","email":"test@example.com"}' \
		    $(BASE_URL)/users; \
	_check "POST /users without email returns 201 (email is optional)" \
		201 -X POST \
		    -H "content-type: application/json" \
		    -H "x-api-key: secret" \
		    -d '{"name":"NoEmail"}' \
		    $(BASE_URL)/users; \
	_check_body_absent "GET /users/user:1 omits password_hash" \
		password_hash "$(BASE_URL)/users/user:1"; \
	_check "GET /openapi returns 200" \
		200 $(BASE_URL)/openapi

integration-test:
	mix test

kill-port:
	@lsof -ti:$(PORT) | xargs kill -9 2>/dev/null; true

.PHONY: start stop restart wait check integration-test kill-port
