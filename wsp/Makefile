
files := \
    BuildConfig.py \
    BuilderGnuMake.py \
    BuilderManager.py \
    Builder.py \
    BuildMatrix.py \
    BuildSettings.py \
    BuildSystem.py \
    Compiler.py \
    EnvVarSettings.py \
    GetTemplateDict.py \
    Project.py \
    ProjectSettings.py \
    TagsSettings.py \
    VLProject.py \
    VLProjectSettings.py \
    VLWorkspace.py \
    VLWorkspaceSettings.py \
    XmlUtils.py \
    VidemSession.py \


all:

clean:

install:
	@for d in $(files); do cp "$$d" $(VIDEM_PYDIR)/; done
	@mkdir -p $(DESTDIR)/autoload/videm
	@cp videm.vim $(DESTDIR)/plugin
	@cp settings.vim wsp.vim wsp.py $(DESTDIR)/autoload/videm
	@mkdir -p $(DESTDIR)/syntax
	@cp syntax/* $(DESTDIR)/syntax
	@mkdir -p $(VIDEM_DIR)/config
	@cp BuildSettings.jcnf $(VIDEM_DIR)/config
	@-cp -r templates/ $(VIDEM_DIR)/ 2>/dev/null
	@-cp -r bitmaps/ $(VIDEM_DIR)/ 2>/dev/null
	@-cp tools/* $(VIDEM_DIR)


.PHONY: all clean install
