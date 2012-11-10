DESTDIR=/usr/bin
APPLETS_DIR=~/.lunartool
APPLETS=pw-ctl

all: 
	@echo "Applets avaliable: $(APPLETS)"

%-install: applets/%.lua
	mkdir -p $(APPLETS_DIR)
	echo cp -f $^ $(APPLETS_DIR)/$*.lua 
	ln -sf $(DESTDIR)/lunartool /usr/bin/$*

lunar:
	cp -f lunartool $(DESTDIR)/lunartool

install: lunar $(addsuffix -install,$(APPLETS))
