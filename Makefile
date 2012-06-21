LUA_INC    = ../luafwk/linux/liblua
WARN       = -Wall
INCS       = -I$(LUA_INC) -Ic
CFLAGS     = -O2 $(WARN) $(INCS) $(DEFS) -fPIC
CC         = gcc
LIB_OPTION = -shared #for Linux
#LIB_OPTION= -bundle -undefined dynamic_lookup #for MacOS X

# Where C sources can be found
SRC = c

all: checks.so log/store.so socket/core.so telnet.so pack.so sched/posixsignal.so luatobin.so

fetch:
	lua fetch.lua

.PHONY: all fetch clean doc

CHECKS_H1 = checks
CHECKS_H  = $(patsubst %,$(SRC)/%.h,$(CHECKS_H1))
CHECKS_O1 = checks
CHECKS_O  = $(patsubst %,$(SRC)/%.o,$(CHECKS_O1))


LOG_H1 = log_store log_storeflash
LOG_H  = $(patsubst %,$(SRC)/log/%.h,$(LOG_H1))
LOG_O1 = log_store log_storeflash
LOG_O  = $(patsubst %,$(SRC)/log/%.o,$(LOG_O1))


SOCKET_H1 = auxiliar except io options socket timeout unix \
            buffer inet luasocket select tcp udp usocket
SOCKET_H  = $(patsubst %,$(SRC)/socket/%.h,$(SOCKET_H1))
SOCKET_O1 = auxiliar buffer except inet io luasocket	\
            options select tcp timeout udp usocket
SOCKET_O  = $(patsubst %,$(SRC)/socket/%.o,$(SOCKET_O1))

POSIXSIGNAL_H1 = lposixsignal
POSIXSIGNAL_H = $(patsubst %,$(SRC)/%.h,$(POSIXSIGNAL_H1))
POSIXSIGNAL_O1 = lposixsignal
POSIXSIGNAL_O = $(patsubst %,$(SRC)/%.o,$(POSIXSIGNAL_O1))

TELNET_H1 = actions buffers editor history teel \
            teel_internal telnet
TELNET_H  = $(patsubst %,$(SRC)/telnet/%.h,$(TELNET_H1))
TELNET_O1 = history actions buffers editor teel telnet
TELNET_O  = $(patsubst %,$(SRC)/telnet/%.o,$(TELNET_O1))


LPACK_H1 = lpack
LPACK_H  = $(patsubst %,$(SRC)/%.h,$(LPACK_H1))
LPACK_O1 = lpack
LPACK_O  = $(patsubst %,$(SRC)/%.o,$(LPACK_O1))


MIME_H1 = mime
MIME_H  = $(patsubst %,$(SRC)/%.h,$(MIME_H1))
MIME_O1 = mime
MIME_O  = $(patsubst %,$(SRC)/%.c,$(MIME_O1))

LUATOBIN_O1 = luatobin awt_endian
LUATOBIN_O = $(patsubst %,$(SRC)/%.c,$(LUATOBIN_O1))


checks.so: $(CHECKS_O) $(CHECKS_H)
	$(CC) $(CFLAGS) -o $@ $(LIB_OPTION) $(CHECKS_O)

log/store.so: $(LOG_O) $(LOG_H)
	$(CC) $(CFLAGS) -Ilog -o $@ $(LIB_OPTION) $(LOG_O)

socket/core.so: $(SOCKET_O) $(SOCKET_H)
	$(CC) $(CFLAGS) -o $@ $(LIB_OPTION) $(SOCKET_O)

sched/posixsignal.so: $(POSIXSIGNAL_O) $(POSIXSIGNAL_H)
	$(CC) $(CFLAGS) -o $@ $(LIB_OPTION) $(POSIXSIGNAL_O)

telnet.so: $(TELNET_O) $(TELNET_H)
	$(CC) $(CFLAGS) -o $@ $(LIB_OPTION) $(TELNET_O)

pack.so: $(LPACK_O) $(LPACK_H)
	$(CC) $(CFLAGS) -o $@ $(LIB_OPTION) $(LPACK_O)

mime.so: $(MIME_O) $(MIME_H)
	$(CC) $(CFLAGS) -o $@ $(LIB_OPTION) $(MIME_O)

luatobin.so: $(LUATOBIN_O) $(LUATOBIN_H)
	$(CC) $(CFLAGS) -o $@ $(LIB_OPTION) $(LUATOBIN_O)

clean:
	rm -f *.so $(SRC)/*.o $(SRC)/log/*.o log/*.so $(SRC)/socket/*.o socket/*.so $(SRC)/telnet/*.o $(SRC)/sched/*.so

doc:
	ldoc .