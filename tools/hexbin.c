/*
 * Intel Hex to binary converter
 *
 * Copyright (c) 2022, 2024 Aleksander Mazur
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>

static unsigned baseoffset;
static unsigned binsize;
static unsigned *datasource;
static uint8_t *binary;
static unsigned binlen;
static unsigned esa, linear;
static const char *fin = "";
static int error;

static inline void need_size(unsigned size)
{
	if (binsize < size) {
		binary = realloc(binary, size);
		datasource = realloc(datasource, size * sizeof(*datasource));
		binsize = size;
	}
}

static int import_hex(const char *buf, unsigned address, unsigned len, unsigned lineno)
{
	unsigned cksum = 0;

	if (address + len > binsize) {
		fprintf(stderr, "%s:%u: %u bytes at 0x%X exceed maximum length\n", fin, lineno, len, address);
		error++;
	}

	while (len--) {
		unsigned byte;

		if (sscanf(buf, "%02X", &byte) != 1) {
			fprintf(stderr, "%s:%u: invalid hex value\n", fin, lineno);
			error++;
			return -1;
		}
		buf += 2;

		cksum = (cksum + byte) & 0xFF;

		if (address < binsize) {
			if (datasource[address]) {
				fprintf(stderr, "%s:%u: byte at 0x%X set in line %u to 0x%02X overwritten with 0x%02X\n",
					fin, lineno, address, datasource[address], binary[address], byte);
				error++;
			}

			binary[address] = byte;
			datasource[address] = lineno;

			address++;
			if (binlen < address) {
				memset(binary + binlen, 0xFF, address - binlen - 1);
				binlen = address;
			}
		}
	}

	return cksum;
}

static unsigned process_line(const char *fin, unsigned lineno, const char *buf)
{
	const char *p = strchr(buf, ':');
	unsigned len, address, record, cksum, byte, eof = 0;
	int r;

	if (!p) {
		fprintf(stderr, "%s:%u: no colon\n", fin, lineno);
		error++;
		return 0;
	}
	if (sscanf(++p, "%02X%04X%02X", &len, &address, &record) != 3) {
		fprintf(stderr, "%s:%u: invalid header\n", fin, lineno);
		error++;
		return 0;
	}
	p += 2 + 4 + 2;

	cksum = (len + ((address >> 8) & 0xFF) + (address & 0xFF) + record) & 0xFF;

	switch (record) {
		case 0:	/* data */
			need_size(0x10000);
			r = import_hex(p, linear + esa + address - baseoffset, len, lineno);
			if (r < 0) {
				return 0;
			}
			cksum = (cksum + r) & 0xFF;
			break;
		case 1:	/* EOF */
			if (len || address) {
				error++;
				fprintf(stderr, "%s:%u: invalid eof record\n", fin, lineno);
			}
			eof++;
			break;
		case 2:	/* extended segment address */
		case 4:	/* extended linear address */
			if (len != 2) {
				error++;
				fprintf(stderr, "%s:%u: record %u length %u instead of 2\n", fin, lineno, record, len);
			}
			if (sscanf(p, "%04X", &byte) != 1) {
				error++;
				fprintf(stderr, "%s:%u: garbage instead of record %u address\n", fin, lineno, record);
				byte = 0;
			}
			cksum = (cksum + ((byte >> 8) & 0xFF) + (byte & 0xFF)) & 0xFF;
			switch (record) {
				case 2:
					esa = byte << 4;
					break;
				case 4:
					linear = byte << 16;
					if (!binsize) {
						baseoffset = linear;
						fprintf(stderr, "%s:%u: taking 0x%X as base offset\n", fin, lineno, baseoffset);
					}
					break;
			}
			need_size(0x100000);
			break;
		default:
			fprintf(stderr, "%s:%u: unknown record type %u\n", fin, lineno, record);
			error++;
			break;
	}

	if (strlen(p) <= 2 * len) {
		fprintf(stderr, "%s:%u: short line\n", fin, lineno);
		error++;
	} else {
		p += 2 * len;

		if (sscanf(p, "%02X", &byte) != 1) {
			fprintf(stderr, "%s:%u: garbage instead of checksum\n", fin, lineno);
			error++;
		} else {
			cksum = (cksum + byte) & 0xFF;
			if (cksum) {
				fprintf(stderr, "%s:%u: wrong checksum 0x%02X\n", fin, lineno, cksum);
				error++;
			}
		}
	}

	return eof;
}

int main(int argc, char **argv)
{
	static char buf[2048];
	unsigned lineno, eof = 0;

	if (argc > 1) {
		if (!freopen(argv[1], "r", stdin)) {
			perror(argv[1]);
			return -1;
		}
		fin = argv[1];
	}
	if (argc > 2) {
		if (!freopen(argv[2], "wb", stdout)) {
			perror(argv[2]);
			return -2;
		}
	}

	for (lineno = 1; fgets(buf, sizeof(buf), stdin); lineno++) {
		if (eof) {
			fprintf(stderr, "%s:%u: data after eof\n", fin, lineno);
			error++;
		}
		eof |= process_line(fin, lineno, buf);
	}

	fwrite(binary, binlen, 1, stdout);
	return error;
}
