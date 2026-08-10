/*****************************************************************************

NAME
   rpilot.c -- basic runtime support for PILOT

DESCRIPTION
   System variables live here.

LICENSE
  SPDX-License-Identifier: BSD-2-Clause

******************************************************************************/

/*LINTLIBRARY*/
#include "pilot.h"

int sys_expression;      /* value of latest numeric sum */
int sys_term;            /* value of latest numeric product */
int sys_factor;          /* value of literal, value, or expression */
int sys_nextstmt;        /* location of next statement */
int sys_uselevel;        /* number of USE statements executed */
char sys_answer[MAXSTR]; /* latest user response line */
int sys_matched;         /* true iff last match succeeded */
char sys_left[MAXSTR];   /* the part of %answer before %match */
char sys_match[MAXSTR];  /* the part of %anser matched */
char sys_right[MAXSTR];  /* the part of %answer before %match */
bool sys_satisfied;      /* true iff current guard is satisfied */
bool sys_relation;       /* true iff current rel_expr is satisfied */
char sys_text[MAXSTR];   /* value of current text buffer */
int sys_return[MAXUSES]; /* use return stack */
int sys_status;          /* status of last SYSTEM command */

/* rpilot.c ends here */
