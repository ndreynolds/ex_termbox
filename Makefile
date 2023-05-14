PREFIX = $(MIX_APP_PATH)/priv
BUILD  = $(MIX_APP_PATH)/obj

TERMBOX_PATH = c_src/termbox
TERMBOX_BUILD = $(MIX_APP_PATH)/termbox_build

ifeq ($(CROSSCOMPILE),)
    # Normal build. Set shared library flags according to the platform.
    ifeq ($(shell uname),Darwin)
	LDFLAGS += -dynamiclib -undefined dynamic_lookup
    endif
    ifeq ($(shell uname -s),Linux)
        LDFLAGS += -fPIC -shared
        CFLAGS += -fPIC
    endif
else
    # Crosscompiled build. Assume Linux flags
    LDFLAGS += -fPIC -shared
    CFLAGS += -fPIC
endif

NIF_CFLAGS += -I$(ERTS_INCLUDE_DIR) -I$(TERMBOX_PATH)/src

SOURCES = c_src/termbox_bindings.c $(TERMBOX_BUILD)/src/libtermbox.a

calling_from_make:
	mix compile

all: $(PREFIX)/termbox_bindings.so
	@:

$(TERMBOX_BUILD)/src/libtermbox.%: $(TERMBOX_BUILD)
	cd $(TERMBOX_PATH) && CFLAGS="$(CFLAGS)" waf configure --prefix=. -o $(TERMBOX_BUILD) && waf

$(PREFIX)/termbox_bindings.so: $(SOURCES) $(PREFIX)
	$(CC) $(CFLAGS) $(NIF_CFLAGS) $(LDFLAGS) -o $@ $(SOURCES)

$(PREFIX) $(TERMBOX_BUILD):
	mkdir -p $@

clean:
	rm -rf $(TERMBOX_BUILD) $(PREFIX)/termbox_bindings.so

.PHONY: calling_from_make all clean
