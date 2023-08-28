# File build order: tables, procedures, functions, matviews, views

EXTENSION = pgmonitor
EXTVERSION = $(shell grep default_version $(EXTENSION).control | \
               sed -e "s/default_version[[:space:]]*=[[:space:]]*'\([^']*\)'/\1/")

PG_CONFIG = pg_config
PG12 = $(shell $(PG_CONFIG) --version | egrep " 11\." > /dev/null && echo no || echo yes)

ifeq ($(PG12),yes)

MODULES = src/pgmonitor_bgw

# If user does not want the background worker, run: make NO_BGW=1
ifneq ($(NO_BGW),)
	MODULES=
endif

all: sql/$(EXTENSION)--$(EXTVERSION).sql

sql/$(EXTENSION)--$(EXTVERSION).sql: $(sort $(wildcard sql/tables/*.sql)) $(sort $(wildcard sql/procedures/*.sql)) $(sort $(wildcard sql/functions/*.sql)) $(sort $(wildcard sql/matviews/*.sql)) $(sort $(wildcard sql/views/*.sql))
	cat $^ > $@

DATA = $(wildcard updates/*--*.sql) sql/$(EXTENSION)--$(EXTVERSION).sql
EXTRA_CLEAN = sql/$(EXTENSION)--$(EXTVERSION).sql
else
$(error Minimum version of PostgreSQL required is 12.0)

# end PG12 if
endif

PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
