.DEFAULT_GOAL := default

.PHONY: push default

default: help

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

push:
	git push origin && git push public && git push projprod

coverage:
    cargo llvm-cov --workspace --packages core tui --cobertura --output-path coverage/cobertura.xml

run-clippy-and-convert:
    cargo clippy --workspace --message-format json > clippy-report.json && cargo sonar --issues clippy --clippy-path clippy-report.json
