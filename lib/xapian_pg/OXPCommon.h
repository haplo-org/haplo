/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


#ifndef OXPCOMMON__H
#define OXPCOMMON__H

extern "C" {
    #include "postgres.h"
    #include "fmgr.h"
    #include "funcapi.h"
}

#include <unistd.h>

#include <string>
#include <stdexcept>
#include <xapian.h>

#ifdef DEBUG
    #define TRACE0(n) {ereport(NOTICE, (errcode(ERRCODE_WARNING), errmsg(n)));}
    #define TRACE1(n,a) {ereport(NOTICE, (errcode(ERRCODE_WARNING), errmsg(n,a)));}
    #define TRACE2(n,a,b) {ereport(NOTICE, (errcode(ERRCODE_WARNING), errmsg(n,a,b)));}
    #define TRACE3(n,a,b,c) {ereport(NOTICE, (errcode(ERRCODE_WARNING), errmsg(n,a,b,c)));}
    #define TRACE4(n,a,b,c,d) {ereport(NOTICE, (errcode(ERRCODE_WARNING), errmsg(n,a,b,c,d)));}
#else
    #define TRACE0(n)
    #define TRACE1(n,a)
    #define TRACE2(n,a,b)
    #define TRACE3(n,a,b,c)
    #define TRACE4(n,a,b,c,d)
#endif  // DEBUG

#endif // OXPCOMMON__H
