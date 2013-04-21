.PHONY: clean All

All:
	@echo ----------Building project:[ CTest - Debug ]----------
	@cd "CTest" && "$(MAKE)" -f "CTest.mk"
clean:
	@echo ----------Cleaning project:[ CTest - Debug ]----------
	@cd "CTest" && "$(MAKE)" -f "CTest.mk" clean
