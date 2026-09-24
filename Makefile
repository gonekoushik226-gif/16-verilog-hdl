# Convenience wrapper around scripts/run.py
#   make sim P=017            simulate + synthesize + lint one program
#   make docs P=017           same, and refresh README results / PROJECT_STATUS.md
#   make regress              run every implemented program (4 jobs)
#   make regress-docs         full regression and refresh all generated sections
#   make clean                remove build/ directories

P    ?=
JOBS ?= 4

.PHONY: sim docs regress regress-docs clean

sim:
	python3 scripts/run.py $(P)

docs:
	python3 scripts/run.py $(P) --update-docs

regress:
	python3 scripts/run.py --all -j $(JOBS)

regress-docs:
	python3 scripts/run.py --all -j $(JOBS) --update-docs

clean:
	find . -name build -type d -prune -exec rm -rf {} +
