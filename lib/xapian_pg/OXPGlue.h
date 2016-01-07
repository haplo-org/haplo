/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


// Glue for the Xapian/C++/C/PG interfaces

#ifndef OXPGLUE__H
#define OXPGLUE__H

#define OXP_WRAP_CPP_BEGIN  try {
#define OXP_WRAP_CPP_END    \
}                                                                                                           \
catch(Xapian::Error &e)                                                                                     \
{                                                                                                           \
    static std::string lastExceptionMsg;                                                                    \
    lastExceptionMsg = "OXP:Xapian: ";                                                                      \
    lastExceptionMsg += e.get_msg();                                                                        \
    ereport(ERROR, (errcode(ERRCODE_EXTERNAL_ROUTINE_EXCEPTION), errmsg(lastExceptionMsg.c_str())));        \
}                                                                                                           \
catch(std::exception &e)                                                                                    \
{                                                                                                           \
    static std::string lastExceptionMsg;                                                                    \
    lastExceptionMsg = "OXP:C: ";                                                                           \
    lastExceptionMsg += e.what();                                                                           \
    ereport(ERROR, (errcode(ERRCODE_EXTERNAL_ROUTINE_EXCEPTION), errmsg(lastExceptionMsg.c_str())));        \
}


#endif // OXPGLUE__H

