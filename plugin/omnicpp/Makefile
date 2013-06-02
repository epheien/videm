
pyfiles := \
    CppParser.py \
    CppTokenizer.py \
    CxxHWParser.py \
    CxxParser.py \
    FileReader.py \
    OmniCpp.py \
    CtagsDatabase/FileEntry.py \
    CtagsDatabase/ITagsStorage.py \
    CtagsDatabase/TagEntry.py \
    CtagsDatabase/TagsStorageSQLite.py \
    CtagsDatabase/VimTagsManager.py \


vimfiles := \
    complete.vim \
    includes.vim \
    resolvers.vim \
    scopes.vim \
    settings.vim \
    tokenizer.vim \
    utils.vim \


PY_TARGET_DIR = $(VIMDIR)/autoload/omnicpp
VIM_TARGET_DIR = $(VIMDIR)/autoload/omnicpp
VIDEM_PLUGIN_DIR = $(VIMDIR)/autoload/videm/plugin

all:

clean:

install:
	@mkdir -p $(PY_TARGET_DIR)
	@for d in $(pyfiles); do cp "$$d" $(PY_TARGET_DIR); done
	@mkdir -p $(VIM_TARGET_DIR)
	@for d in $(vimfiles); do cp "$$d" $(VIM_TARGET_DIR); done
	@mkdir -p $(VIDEM_PLUGIN_DIR)
	@cp omnicpp.vim $(VIDEM_PLUGIN_DIR)
# vltagmgr.vim
	@mkdir -p $(VIMDIR)/plugin
	@cp CtagsDatabase/vltagmgr.vim $(VIMDIR)/autoload


.PHONY: all clean install
