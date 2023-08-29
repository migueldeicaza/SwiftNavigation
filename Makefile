ODOCS=../SwiftNavigation/docs

all:
	echo Targets:
	echo    - build-docs: Builds the documentation
	echo    - push-docs: Pushes the existing documentation, requires SwiftNavigationDocs peer checked out
	echo    - release: Builds an xcframework package, documentation and pushes documentation

build-docs:
	GENERATE_DOCS=1 swift package --allow-writing-to-directory $(ODOCS) generate-documentation --target SwiftNavigation --disable-indexing --transform-for-static-hosting --hosting-base-path /SwiftNavigationDocs --emit-digest --output-path $(ODOCS) >& build-docs.log

push-docs:
	(cd ../SwiftNavigationDocs; mv docs tmp; git reset --hard 7b1ef07db61d5ae7674dbe2dcffc7b82b9e5b53d; mv tmp docs; git add docs/*; git commit -m "Import Docs"; git push -f; git prune)

release: check-args build-release build-docs push-docs

build-release: check-args
	sh scripts/release $(VERSION) $(NOTES)

check-args:
	@if test x$(VERSION)$(NOTES) = x; then echo You need to provide both VERSION=XX NOTES=FILENAME arguments to this makefile target; exit 1; fi

