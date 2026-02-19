
CC = gcc
CFLAGS = -Wall -Wextra -O2 -I../inc -lm
TARGET = ../bms_test.exe

SOURCES = ../src/bms_model.c \
          ../src/safety_fsm.c \
          ../src/soc_estimator.c \
          ../src/soh_estimator.c \
          ../test/test_bms.c

HEADERS = ../inc/bms_config.h \
          ../inc/bms_model.h \
          ../inc/safety_fsm.h \
          ../inc/soc_estimator.h \
          ../inc/soh_estimator.h \
          ../test/test_vectors.h

all: $(TARGET)

$(TARGET): $(SOURCES) $(HEADERS)
	$(CC) $(SOURCES) -o $(TARGET) $(CFLAGS)
	@echo "✅ Compilation complete!"

clean:
	rm -f $(TARGET) ../*.exe

run: $(TARGET)
	$(TARGET)

.PHONY: all clean run
