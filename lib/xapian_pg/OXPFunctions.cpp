/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


#include "OXPCommon.h"
#include "OXPController.h"
#include "OXPGlue.h"
#include "KXapianWriter.h"

#include <sys/types.h>
#include <sys/stat.h>
#include <dirent.h>
#include <string>
#include <strings.h>
#include <stdlib.h>

// Make PG interface C compatible
extern "C" {

// Mark it as a PG module
PG_MODULE_MAGIC;

/* -----------------------------------------------------------------------------------------------------------------
    OXP_FN_BEGIN
        :name => 'oxp_reset_all',
        :args => [],
        :returns => 'void'
    OXP_FN_END
*/

// Mainly for testing; closes all databases
PG_FUNCTION_INFO_V1(oxp_reset_all);
Datum oxp_reset_all(PG_FUNCTION_ARGS) {
    OXP_WRAP_CPP_BEGIN
        OXPController::GetController().PgResetAll();
    OXP_WRAP_CPP_END

    PG_RETURN_VOID();
}


/* -----------------------------------------------------------------------------------------------------------------
    OXP_FN_BEGIN
        :name => 'oxp_reset',
        :args => [],
        :returns => 'void'
    OXP_FN_END
*/

PG_FUNCTION_INFO_V1(oxp_reset);
Datum oxp_reset(PG_FUNCTION_ARGS) {
    OXP_WRAP_CPP_BEGIN
        OXPController::GetController().PgReset();
    OXP_WRAP_CPP_END

    PG_RETURN_VOID();
}


/* -----------------------------------------------------------------------------------------------------------------
    OXP_FN_BEGIN
        :name => 'oxp_open',
        :args => [
            ['integer', 'slot'],        # which slot the database is opened into
            ['cstring', 'pathname']     # full pathname to the db on disc
        ],
        :returns => 'void'
    OXP_FN_END
*/

PG_FUNCTION_INFO_V1(oxp_open);
Datum oxp_open(PG_FUNCTION_ARGS) {
    int32 slot = PG_GETARG_INT32(0);
    const char *pathname = PG_GETARG_CSTRING(1);

    OXP_WRAP_CPP_BEGIN
        OXPController::GetController().PgOpen(slot, pathname);
    OXP_WRAP_CPP_END

    PG_RETURN_VOID();
}


/* -----------------------------------------------------------------------------------------------------------------
    OXP_FN_BEGIN
        :name => 'oxp_simple_query',
        :args => [
            ['integer', 'slot'],        # which database to use
            ['cstring', 'query'],       # the query string
            ['cstring', 'prefixes']     # the prefixes to use, single string with , separator
        ],
        :returns => 'SETOF integer'
    OXP_FN_END
*/

PG_FUNCTION_INFO_V1(oxp_simple_query);
Datum oxp_simple_query(PG_FUNCTION_ARGS) {
    FuncCallContext  *funcctx;
    std::vector<int> *presults = 0;

    // TODO: Would this be better done as something returning an array?

    if(SRF_IS_FIRSTCALL()) {
        funcctx = SRF_FIRSTCALL_INIT();

        int32 slot = PG_GETARG_INT32(0);
        const char *query = PG_GETARG_CSTRING(1);
        std::string prefixes (PG_GETARG_CSTRING(2));

        std::set<const char *>prefix_set;

        // Split prefixes on , into prefix_set
        unsigned int start = 0;
        unsigned int i = 0;
        while(i < prefixes.length()) {
            if(prefixes[i] == ',') {
                if(i != start) {
                    prefix_set.insert(strdup(prefixes.substr(start, i-start).c_str()));
                    start = i+1;
                }
            }
            i++;
        }
        if(i != start) {
            prefix_set.insert(strdup(prefixes.substr(start, i-start).c_str()));
            start = i+1;
        }

        OXP_WRAP_CPP_BEGIN
            presults = new std::vector<int>;
            try {
                OXPController::GetController().PgSimpleQuery(slot, query, prefix_set, *presults);
            }
            catch(...) {
                delete presults;
                throw;
            }
        OXP_WRAP_CPP_END

        funcctx->user_fctx = presults;
        funcctx->max_calls = presults->size();
    }

    funcctx = SRF_PERCALL_SETUP();
    presults = (std::vector<int> *)funcctx->user_fctx;

    if(funcctx->call_cntr < funcctx->max_calls) {
        int r = (*presults)[funcctx->call_cntr];
        SRF_RETURN_NEXT(funcctx, Int32GetDatum(r));
    } else {
        delete presults;
        SRF_RETURN_DONE(funcctx);
    }
}


/* -----------------------------------------------------------------------------------------------------------------
    OXP_FN_BEGIN
        :name => 'oxp_disable_relevancy',
        :args => [],
        :returns => 'void'
    OXP_FN_END
*/

PG_FUNCTION_INFO_V1(oxp_disable_relevancy);
Datum oxp_disable_relevancy(PG_FUNCTION_ARGS) {
    OXP_WRAP_CPP_BEGIN
        OXPController::GetController().PgDisableRelevancy();
    OXP_WRAP_CPP_END

    PG_RETURN_VOID();
}


/* -----------------------------------------------------------------------------------------------------------------
    OXP_FN_BEGIN
        :name => 'oxp_relevancy',
        :args => [
            ['integer', 'docid']        # which document
        ],
        :returns => 'integer'
    OXP_FN_END
*/

PG_FUNCTION_INFO_V1(oxp_relevancy);
Datum oxp_relevancy(PG_FUNCTION_ARGS) {
    int32 docid = PG_GETARG_INT32(0);
    int score = 0;

    OXP_WRAP_CPP_BEGIN
        score = OXPController::GetController().PgGetRelevancy(docid);
    OXP_WRAP_CPP_END

    PG_RETURN_INT32(score);
}


/* -----------------------------------------------------------------------------------------------------------------
    OXP_FN_BEGIN
        :name => 'oxp_spelling',
        :args => [
            ['integer', 'slot'],    # which database to use
            ['cstring', 'word']     # word to check spelling
        ],
        :returns => 'cstring'
    OXP_FN_END
*/

PG_FUNCTION_INFO_V1(oxp_spelling);
Datum oxp_spelling(PG_FUNCTION_ARGS) {
    int32 slot = PG_GETARG_INT32(0);
    const char *word = PG_GETARG_CSTRING(1);
    std::string spelled;

    OXP_WRAP_CPP_BEGIN
        spelled = OXPController::GetController().PgSpelling(slot, word);
    OXP_WRAP_CPP_END

    PG_RETURN_CSTRING(spelled.c_str());
}




/*
   =================================================================================================================
                                                   WRITER FUNCTIONS
   =================================================================================================================
*/


/* -----------------------------------------------------------------------------------------------------------------
    OXP_FN_BEGIN
        :name => 'oxp_w_init_empty_index',
        :args => [
            ['cstring', 'pathname']     # full pathname to the full db on disc
        ],
        :returns => 'void'
    OXP_FN_END
*/

PG_FUNCTION_INFO_V1(oxp_w_init_empty_index);
Datum oxp_w_init_empty_index(PG_FUNCTION_ARGS) {
    const char *pathname_c = PG_GETARG_CSTRING(0);

    OXP_WRAP_CPP_BEGIN
        std::string pathname(pathname_c);

        // Make sure the containing directory exists
        std::string::size_type last_slash = pathname.find_last_of('/');
        if(last_slash != std::string::npos) {
            // Stat the container directory name to see if it exists
            std::string container(pathname.substr(0, last_slash));
            struct stat st;
            if(::stat(container.c_str(), &st) == -1 && errno == ENOENT) {
                // Doesn't exist, attempt to create it
                if(::mkdir(container.c_str(), 0750) != 0) {
                    throw std::runtime_error("Couldn't create directory "+container);
                }
            }
        }

        Xapian::WritableDatabase(pathname, Xapian::DB_CREATE);
    OXP_WRAP_CPP_END

    PG_RETURN_VOID();
}


/* -----------------------------------------------------------------------------------------------------------------
    OXP_FN_BEGIN
        :name => 'oxp_w_remove_index',
        :args => [
            ['cstring', 'pathname'],    # full pathname to the full db on disc
            ['boolean', 'try_to_remove_parent'] # whether to try and remove the parent directory, if it's empty
        ],
        :returns => 'void'
    OXP_FN_END
*/

PG_FUNCTION_INFO_V1(oxp_w_remove_index);
Datum oxp_w_remove_index(PG_FUNCTION_ARGS) {
    const char *pathname_c = PG_GETARG_CSTRING(0);
    bool try_to_remove_parent = PG_GETARG_BOOL(1);

    OXP_WRAP_CPP_BEGIN
        std::string pathname(pathname_c);

        // Try to open the database for writing, which makes sure it's a valid database and nothing else is locking it
        try {
            Xapian::WritableDatabase(pathname, Xapian::DB_OPEN);
        }
        catch(...) {
            throw std::runtime_error("Couldn't open index for removal");
        }

        // Read the contents
        DIR *dirHandle = ::opendir(pathname.c_str());
        std::vector<std::string> entries;
        if(dirHandle == 0) { throw std::runtime_error("Couldn't open dir "+pathname); }
        try {
            struct dirent *en = 0;
            while((en = ::readdir(dirHandle)) != 0) {
                entries.push_back(std::string(en->d_name));
            }
        }
        catch(...) {
            ::closedir(dirHandle);
            throw;
        }
        if(::closedir(dirHandle) != 0) { throw std::runtime_error("Couldn't close dir "+pathname); }

        // Delete the contents
        for(std::vector<std::string>::const_iterator i(entries.begin()); i != entries.end(); ++i) {
            if(*i != "." && *i != "..") {
                // Delete this file
                std::string f(pathname + '/' + *i);
                if(::unlink(f.c_str()) != 0) { throw std::runtime_error("Couldn't delete file "+f); }
            }
        }

        // Delete the directory
        if(::rmdir(pathname.c_str()) != 0) { throw std::runtime_error("Couldn't remove dir "+pathname); }

        // Try to remove the parent?
        if(try_to_remove_parent) {
            std::string::size_type last_slash = pathname.find_last_of('/');
            if(last_slash != std::string::npos) {
                std::string container(pathname.substr(0, last_slash));
                ::rmdir(container.c_str()); // ignoring errors
            }
        }
    OXP_WRAP_CPP_END

    PG_RETURN_VOID();
}


/* -----------------------------------------------------------------------------------------------------------------
    OXP_FN_BEGIN
        :name => 'oxp_w_open',
        :args => [
            ['cstring', 'pathname_full'],       # full pathname to the full db on disc
            ['cstring', 'pathname_fields']      # full pathname to the fields db on disc
        ],
        :returns => 'integer'                   # handle to the writer
    OXP_FN_END
*/

PG_FUNCTION_INFO_V1(oxp_w_open);
Datum oxp_w_open(PG_FUNCTION_ARGS) {
    const char *pathname_full = PG_GETARG_CSTRING(0);
    const char *pathname_fields = PG_GETARG_CSTRING(1);
    int handle = 0;

    OXP_WRAP_CPP_BEGIN
        handle = KXapianWriter::OpenHandle(pathname_full, pathname_fields);
    OXP_WRAP_CPP_END

    PG_RETURN_INT32(handle);
}


/* -----------------------------------------------------------------------------------------------------------------
    OXP_FN_BEGIN
        :name => 'oxp_w_close',
        :args => [
            ['integer', 'handle']       # which writer
        ],
        :returns => 'void'
    OXP_FN_END
*/

PG_FUNCTION_INFO_V1(oxp_w_close);
Datum oxp_w_close(PG_FUNCTION_ARGS) {
    int32 handle = PG_GETARG_INT32(0);

    OXP_WRAP_CPP_BEGIN
        KXapianWriter::CloseHandle(handle);
    OXP_WRAP_CPP_END

    PG_RETURN_VOID();
}


/* -----------------------------------------------------------------------------------------------------------------
    OXP_FN_BEGIN
        :name => 'oxp_w_start_transaction',
        :args => [
            ['integer', 'handle']       # which writer
        ],
        :returns => 'void'
    OXP_FN_END
*/

PG_FUNCTION_INFO_V1(oxp_w_start_transaction);
Datum oxp_w_start_transaction(PG_FUNCTION_ARGS) {
    int32 handle = PG_GETARG_INT32(0);

    OXP_WRAP_CPP_BEGIN
        KXapianWriter &writer(KXapianWriter::FromHandle(handle));
        writer.StartTransaction();
    OXP_WRAP_CPP_END

    PG_RETURN_VOID();
}


/* -----------------------------------------------------------------------------------------------------------------
    OXP_FN_BEGIN
        :name => 'oxp_w_start_document',
        :args => [
            ['integer', 'handle']       # which writer
        ],
        :returns => 'void'
    OXP_FN_END
*/

PG_FUNCTION_INFO_V1(oxp_w_start_document);
Datum oxp_w_start_document(PG_FUNCTION_ARGS) {
    int32 handle = PG_GETARG_INT32(0);

    OXP_WRAP_CPP_BEGIN
        KXapianWriter &writer(KXapianWriter::FromHandle(handle));
        writer.StartDocument();
    OXP_WRAP_CPP_END

    PG_RETURN_VOID();
}


/* -----------------------------------------------------------------------------------------------------------------
    OXP_FN_BEGIN
        :name => 'oxp_w_post_terms',
        :args => [
            ['integer', 'handle'],
            ['cstring', 'terms'],
            ['cstring', 'labels'],
            ['cstring', 'prefix1'],
            ['cstring', 'prefix2'],             # may be NULL
            ['integer', 'term_position_start'],
            ['integer', 'weight']
        ],
        :returns => 'integer'
    OXP_FN_END
*/

PG_FUNCTION_INFO_V1(oxp_w_post_terms);
Datum oxp_w_post_terms(PG_FUNCTION_ARGS) {
    int32 handle = PG_GETARG_INT32(0);
    const char *terms = PG_GETARG_CSTRING(1);
    std::string labels(PG_GETARG_CSTRING(2));
    const char *prefix1 = PG_GETARG_CSTRING(3);
    const char *prefix2 = (PG_ARGISNULL(4)) ? 0 : (PG_GETARG_CSTRING(4));
    int32 term_position_start = PG_GETARG_INT32(5);
    int32 weight = PG_GETARG_INT32(6);
    int32 final_term_position = 0;

    std::set<const char *>label_set;
    // Split labels on , into label_set
    unsigned int start = 0;
    unsigned int i = 0;
    while(i < labels.length()) {
        if(labels[i] == ',') {
            if(i != start) {
                label_set.insert(strdup(labels.substr(start, i-start).c_str()));
                start = i+1;
            }
        }
        i++;
    }
    if(i != start) {
        label_set.insert(strdup(labels.substr(start, i-start).c_str()));
        start = i+1;
    }
    OXP_WRAP_CPP_BEGIN
        KXapianWriter &writer(KXapianWriter::FromHandle(handle));
        final_term_position = writer.PostTerms(terms, label_set, prefix1, prefix2, term_position_start, weight);
    OXP_WRAP_CPP_END

    // Deallocate strdup() strings
    for(std::set<const char *>::iterator it = label_set.begin(); it != label_set.end(); ++it) {
        const char *label = *it;
        if (label) {
            free((void*)(*it));
        }
    }

    PG_RETURN_INT32(final_term_position);
}


/* -----------------------------------------------------------------------------------------------------------------
    OXP_FN_BEGIN
        :name => 'oxp_w_finish_document',
        :args => [
            ['integer', 'handle'],
            ['integer', 'docid']
        ],
        :returns => 'void'
    OXP_FN_END
*/

PG_FUNCTION_INFO_V1(oxp_w_finish_document);
Datum oxp_w_finish_document(PG_FUNCTION_ARGS) {
    int32 handle = PG_GETARG_INT32(0);
    int32 docid = PG_GETARG_INT32(1);

    OXP_WRAP_CPP_BEGIN
        KXapianWriter &writer(KXapianWriter::FromHandle(handle));
        writer.FinishDocument(docid);
    OXP_WRAP_CPP_END

    PG_RETURN_VOID();
}


/* -----------------------------------------------------------------------------------------------------------------
    OXP_FN_BEGIN
        :name => 'oxp_w_delete_document',
        :args => [
            ['integer', 'handle'],
            ['integer', 'docid']
        ],
        :returns => 'void'
    OXP_FN_END
*/

PG_FUNCTION_INFO_V1(oxp_w_delete_document);
Datum oxp_w_delete_document(PG_FUNCTION_ARGS) {
    int32 handle = PG_GETARG_INT32(0);
    int32 docid = PG_GETARG_INT32(1);

    OXP_WRAP_CPP_BEGIN
        KXapianWriter &writer(KXapianWriter::FromHandle(handle));
        writer.DeleteDocument(docid);
    OXP_WRAP_CPP_END

    PG_RETURN_VOID();
}


/* -----------------------------------------------------------------------------------------------------------------
    OXP_FN_BEGIN
        :name => 'oxp_w_cancel_transaction',
        :args => [
            ['integer', 'handle']       # which writer
        ],
        :returns => 'void'
    OXP_FN_END
*/

PG_FUNCTION_INFO_V1(oxp_w_cancel_transaction);
Datum oxp_w_cancel_transaction(PG_FUNCTION_ARGS) {
    int32 handle = PG_GETARG_INT32(0);

    OXP_WRAP_CPP_BEGIN
        KXapianWriter &writer(KXapianWriter::FromHandle(handle));
        writer.CancelTransaction();
    OXP_WRAP_CPP_END

    PG_RETURN_VOID();
}


/* -----------------------------------------------------------------------------------------------------------------
    OXP_FN_BEGIN
        :name => 'oxp_w_commit_transaction',
        :args => [
            ['integer', 'handle']       # which writer
        ],
        :returns => 'void'
    OXP_FN_END
*/

PG_FUNCTION_INFO_V1(oxp_w_commit_transaction);
Datum oxp_w_commit_transaction(PG_FUNCTION_ARGS) {
    int32 handle = PG_GETARG_INT32(0);

    OXP_WRAP_CPP_BEGIN
        KXapianWriter &writer(KXapianWriter::FromHandle(handle));
        writer.CommitTransaction();
    OXP_WRAP_CPP_END

    PG_RETURN_VOID();
}


/* -----------------------------------------------------------------------------------------------------------------
*/
}   // extern "C"

