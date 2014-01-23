DESTDIR=/home/necromant/bin
APPLETS_DIR=~/.lunartool
APPLETS=pw-ctl

LUAV=$(shell lua -v 2>&1|awk '{print $2}'|cut -d"." -f 2)
LUA_VERSION=5.$(LUAV)


all: 
	@echo "Applets avaliable: $(APPLETS)"

install:
	cp ./lunarusb.lua /usr/local/share/lua/$(LUA_VERSION)/

%-install: applets/%.lua
	mkdir -p $(APPLETS_DIR)
	echo cp -f $^ $(APPLETS_DIR)/$*.lua 
	ln -sf $(DESTDIR)/lunartool $(DESTDIR)/$*

lunar:
	cp -f lunartool $(DESTDIR)/lunartool

install: lunar $(addsuffix -install,$(APPLETS))
