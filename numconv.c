/******************************************************************************

NAME
  numconv.c -- numeric conversion for PILOT

SYNOPSIS
   int numconv(char *str)	-- function for implicit numeric conversion

DESCRIPTION
   See also nonstd.c and file.c.

LICENSE
  SPDX-License-Identifier: BSD-2-Clause

******************************************************************************/

/*LINTLIBRARY*/
#include "pilot.h"
#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>

#include "gencode.h"

int numconv(const char *str) {
	/* forced (implicit) numeric-conversion function */
	char *end = (char *)NULL;
	long val;

	if (str == NULL) {
		return 0;
	}
	errno = 0;
	val = strtol(str, &end, 10);
	if (end == str) {
		return 0;
	}
	if (errno == ERANGE || val > INT_MAX) {
		return INT_MAX;
	}
	if (val < INT_MIN) {
		return INT_MIN;
	}
	return (int)val;
}

/* numconv.c ends here */
