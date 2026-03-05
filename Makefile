SHELL := powershell.exe

all: build

build:
	@echo "Building the project..."
ifeq (,$(shell git rev-parse --is-inside-work-tree))
	@echo "Not in a git repository. Skipping build."
else
	@cargo build --workspace
endif

fmt:
	@echo "Checking formatting..."
ifeq (,$(shell git rev-parse --is-inside-work-tree))
	@echo "Not in a git repository. Skipping formatting check."
else
	@cargo fmt --all -- --check
endif

clippy:
	@echo "Checking linting with clippy..."
ifeq (,$(shell git rev-parse --is-inside-work-tree))
	@echo "Not in a git repository. Skipping clippy check."
else
	@cargo clippy --workspace --all-targets --all-features -- -D warnings
endif

test:
	@echo "Running tests..."
ifeq (,$(shell git rev-parse --is-inside-work-tree))
	@echo "Not in a git repository. Skipping tests."
else
	@cargo test --workspace
endif

push:
	@echo "Pushing to all remotes..."
	@# Get remote names using git remote -v and process the output
	@REMOTE_NAMES := $(shell git remote -v | awk '{print $$1}' | uniq)
	@if [ -z "$(REMOTE_NAMES)" ]; then
	@	 echo "No git remotes found. Exiting."
	@else
	@	 for remote in $(REMOTE_NAMES);
	@	do
	@		echo "Pushing to $$remote..."
	@	 git push "$$remote" --all
	@	done
	@fi
