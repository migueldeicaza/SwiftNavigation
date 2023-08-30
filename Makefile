ODOCS=../SwiftNavigationDocs/docs
BASECOMMIT=4bc7fc2e3c1fd1b845a1d7b9c739006581add88e

all:
	@echo Targets:
	@echo - build-docs: Builds the documentation
	@echo - push-docs: Pushes the existing documentation, requires SwiftNavigationDocs peer checked out
	@echo - release: Builds an xcframework package, documentation and pushes documentation

build-docs:
	GENERATE_DOCS=1 swift package --allow-writing-to-directory $(ODOCS) generate-documentation --target SwiftNavigation --disable-indexing --transform-for-static-hosting --hosting-base-path /SwiftNavigation --output-path $(ODOCS) #>& build-docs.log

push-docs:
	(cd ../SwiftNavigationDocs; git reset --hard $BASECOMMIT; git add docs/* docs/*/*; git commit -m "Import Docs"; git push -f; git prune)

release: check-args build-release build-docs push-docs

build-release: check-args
	sh scripts/release $(VERSION) $(NOTES)

check-args:
	@if test x$(VERSION)$(NOTES) = x; then echo You need to provide both VERSION=XX NOTES=FILENAME arguments to this makefile target; exit 1; fi

