PHONY := all clean install

DIRS := ~/.vim/_videm ~/.vim/bundle/videm/_videm

all:
	@echo "----------Building Project:[ CxxParser - Release_Unix_dll ]----------"
	@cd CxxParser && $(MAKE) $@
	@echo "----------Building Project:[ DataTypes - Release_SL ]----------"
	@cd ftcb/DataTypes && $(MAKE) $@
	@echo "----------Building Project:[ IntExpr - lib_release ]----------"
	@cd IntExpr && $(MAKE) $@
	@echo "----------Building Project:[ vlctags2 - Release_Unix ]----------"
	@cd vlctags2 && $(MAKE) $@

clean:
	@echo "----------Cleaning Project:[ CxxParser - Release_Unix_dll ]----------"
	@cd CxxParser && $(MAKE) $@
	@echo "----------Cleaning Project:[ DataTypes - Release_SL ]----------"
	@cd ftcb/DataTypes && $(MAKE) $@
	@echo "----------Cleaning Project:[ IntExpr - lib_release ]----------"
	@cd IntExpr && $(MAKE) $@
	@echo "----------Cleaning Project:[ vlctags2 - Release_Unix ]----------"
	@cd vlctags2 && $(MAKE) $@

install: _videm
	@for d in $(DIRS); do \
	  [ -d "$$d" ] && { cp -rv _videm/* "$$d" && break; } \
	done; [ $$? -eq 0 ] || { echo "Can not find directory to install automatically"; \
	echo "You need install files which in _videm ( _videm/* ) manually"; }

.PHONY: $(PHONY)
