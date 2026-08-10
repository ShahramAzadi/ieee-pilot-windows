/******************************************************************************

NAME
  nonstd.c -- implementation of non-IEEE functions

SYNOPSIS
   void do_help(void)		-- semantic action for HELP command

   void initvar(variable *var)	-- variable-initialization hook

DESCRIPTION
   Code for functions involving implementation choices not specified
by the IEEE PILOT standard 1154-1991 is concentrated here.  See also
file.c and numconv.c.  The runtime library does *not* use this code.

LICENSE
  SPDX-License-Identifier: BSD-2-Clause

******************************************************************************/

/*LINTLIBRARY*/
#include "pilot.h"
#include <stdio.h>

#include "gencode.h"

void do_help(void) {
#define P(s) (void)printf(s)
	P("Pilot commands are:\n\n");

	// clang-format off
	P("T <cond> : <text>        -- type <text> followed by newline.\n");
	P("A <cond> : {<id>}        -- accept input to %%answer {assign it to id}.\n");
	P("M <cond> : <text>        -- set %%matched, %%left, %%matched, and %%right.\n");
	P("                            if <text> can be found in %%answer.\n");
	P("J <cond> : <label>       -- jump to <label>.\n");
	P("U <cond> : <label>       -- jump to <label>, preparing to return on E.\n");
	P("C <cond> : <id> = <expr> -- give <id> the value computed by <expr>.\n");
	P("F <cond> : <text>        -- F action is not defined by Std 1154-1991.\n");
	P("G <cond> : <text>        -- G action is not defined by Std 1154-1991.\n");
	P("R <cond> : <text>        -- no effect.\n");
	P("E <cond> :               -- exit from current U.\n");
	P("Y <cond> : <text>        -- type <text> if %%matched is TRUE.\n");
	P("N <cond> : <text>        -- type <text> if %%matched is FALSE.\n\n");

	P("All statements do not execute if their <cond> part is false.\n");
	P("Any <text> part may be empty; the <id> in the A command is optional.\n");
	P("The <expr> in the C statement may be a <text> or a numeric expression.\n");

	P("\nFor details on the syntax of expressions and other topics, consult\n");
	P("IEEE Standard 1154-1991 and its correction sheet.\n");
	// clang-format on
}

void initvar(variable *var) {
	/*
	 * For now, do nothing.  C's static allocation rules ensure that new
	 * variable cells will be initialized to all zeros, which is exactly
	 * what's desired.
	 */
}

/* nonstd.c ends here */
