
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


all:

clean:

install:
	@for d in $(files); do cp "$$d" $(PYDIR)/; done
	@mkdir -p $(VIMDIR)/autoload/videm
	@cp videm.vim $(VIMDIR)/plugin
	@cp settings.vim wsp.vim wsp.py $(VIMDIR)/autoload/videm
	@mkdir -p $(VIMDIR)/syntax
	@cp syntax/* $(VIMDIR)/syntax
	@mkdir -p $(VIDEMDIR)/config
	@cp BuildSettings.jcnf $(VIDEMDIR)/config
	@-cp -r templates/ $(VIDEMDIR)/ 2>/dev/null


.PHONY: all clean install
