QMLTESTRUNNER := $(shell command -v qmltestrunner 2>/dev/null || echo /usr/lib/qt6/bin/qmltestrunner)
QMLLINT := $(shell command -v qmllint 2>/dev/null || echo /usr/lib/qt6/bin/qmllint)
.PHONY: test lint package install screenshots
test:
	QMLTESTRUNNER=$(QMLTESTRUNNER) ./scripts/test.sh
lint:
	$(QMLLINT) -I contents/ui contents/ui/*.qml contents/config/config.qml
package:
	./scripts/package.sh
install:
	./scripts/install.sh
screenshots:
	QMLTESTRUNNER=$(QMLTESTRUNNER) ./scripts/test.sh scripts/tst_preview.qml
