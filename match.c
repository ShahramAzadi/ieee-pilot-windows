/******************************************************************************

NAME
   match.c -- match routine for PILOT programs

SYNOPSIS
   int do_match(char *s, *t)

DESCRIPTION
   This routine does the string-matching with ?,*, and or-characters
required for PILOT.  The return value is the number of the alternation
matched, 0 if there was no match.

LICENSE
  SPDX-License-Identifier: BSD-2-Clause

******************************************************************************/

/* LINTLIBRARY */
#include <ctype.h>
#include <string.h>

#include "pilot.h"

static void copy_bounded(char *dst, const char *src, size_t n) {
	if (n >= MAXSTR) {
		n = MAXSTR - 1;
	}
	memcpy(dst, src, n);
	dst[n] = '\0';
}

int do_match(char *s, char *t) {
	/* MATCH s in t, with wildcarding; may set %left, %right, and %match */
	char *orpart, *nextpart, *anchor, *sp, *ep;
	int matchcount;

	/* for each segment bounded by or characters... */
	for (matchcount = 1, orpart = nextpart = s; nextpart;
	     orpart = nextpart, matchcount++) {
		/* look for any of the alternation delimiters */
		if ((nextpart = strchr(orpart, ',')) == (char *)0) {
			if ((nextpart = strchr(orpart, '|')) == (char *)0) {
				nextpart = strchr(orpart, '!');
			}
		}
		if (nextpart) {
			*nextpart++ = '\0';
		}

		/* ignore whitespace after or-bar characters */
		while (*orpart && isspace(*orpart)) {
			orpart++;
		}

		/* look for an anchored match for it at any offset in the target
		 */
		for (anchor = t; *anchor; anchor++) {
			ep = anchor;
			for (sp = orpart; *sp; sp++) {
				if (*sp == '\\') {
					if (tolower(*++sp) != tolower(*ep)) {
						goto nextanchor;
					}
					ep++;
				} else if (*sp == '*') {
					while (*ep && *ep != sp[1]) {
						ep++;
					}
				} else if (*sp == '?' ||
				           tolower(*sp) == tolower(*ep)) {
					ep++;
				} else {
					goto nextanchor;
				}
			}

			/* an entire segment matched */
			copy_bounded(sys_match, anchor, (size_t)(ep - anchor));

			copy_bounded(sys_left, t, (size_t)(anchor - t));

			copy_bounded(sys_right, ep, strlen(ep));

			return (matchcount);

		nextanchor:;
		}
	}

	sys_match[0] = sys_left[0] = sys_right[0] = '\0';
	return (FALSE);
}

/* match.c ends here */
