# Test makefile for the Pilot interpreter

check:
	@$(MAKE) tap | ./tapview

tap:
	echo "1..$$(ls *.tst | wc -l)"
	@for testfile in *.tst; \
	do \
	    stem=$${testfile%.*}; \
	    ./testrunner "$${testfile}" | ./tapdiffer "$${stem}" "$${stem}.chk"; \
	done


rebuild:
	@for testfile in *.tst; \
	do \
	    stem=$${testfile%.*}; \
	    echo "Rebuilding $${stem}.chk"; \
	    ./testrunner $${testfile} >$${stem}.chk; \
	done

# end
