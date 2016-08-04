/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


#include "OXPCommon.h"
#include "OXPController.h"
#include "OXPConfig.h"

OXPController OXPController::msController;

OXPController::OXPController()
    : mOpenSerial(0), mRelevancyEnabled(true) {
}

OXPController::~OXPController() {
    CloseAllDatabases();
}

void OXPController::PgResetAll() {
    PgReset();
    CloseAllDatabases();
}

void OXPController::PgReset() {
    mDatabaseSlots.clear();
    mRelevancy.clear();
    mRelevancyEnabled = true;
}

void OXPController::PgOpen(unsigned int Slot, const char *Pathname) {
    // Check slot size is sensible
    if(Slot < 0 || Slot > OXP_MAX_DATABASE_SLOTS) {
        throw std::runtime_error("Max slot size exceeded to oxp_open");
    }
    // Check it's an absolute path
    if(Pathname[0] != '/') {
        throw std::runtime_error("Pathname given to oxp_open was not an absolute path");
    }

    std::string dbpath(Pathname);
    OpenDatabase *pdb = 0;

    // See if it's already open
    OXPOpenDatabaseMap::iterator existing(mOpenDatabases.find(dbpath));
    if(existing != mOpenDatabases.end()) {
        TRACE0("Reusing existing open Xapian database")
        pdb = existing->second;

        // Reopen it to get the latest changes (required to get latest changes)
        // This is a fairly light operation unlikely to cause any performance problems.
        pdb->GetXapianDatabase().reopen();
    }

    // Open a new one?
    if(pdb == 0) {
        // Close existing DBs if too many are open
        int safety = 32;
        while(mOpenDatabases.size() > OXP_MAX_DATABASES_OPEN && (safety--) > 0) {
            CloseLeastRecentlyUsedDatabase();
        }

        // Two step initialisation
        TRACE1("Open new Xapian database: %s", Pathname);
        pdb = new OpenDatabase(dbpath);
        pdb->Open();

        mOpenDatabases[dbpath] = pdb;
    }

    pdb->UpdateOpenSerial(mOpenSerial++);

    // Make sure the slot list is big enough
    if(mDatabaseSlots.size() <= Slot) {
        // Need to expand it with zeros
        mDatabaseSlots.resize(Slot + 1, 0);
    }

    mDatabaseSlots[Slot] = pdb;
}

void OXPController::PgSimpleQuery(unsigned int Slot, const char *Query, std::set<const char *>Prefixes, std::vector<int> &rResultsOut) {
    Xapian::Database &db = GetDatabase(Slot);

    int attempts = 32;
    while(true) {
        try {
            // Try the query
            ImplSimpleQuery(db, Query, Prefixes, rResultsOut);
            break;
        }
        catch(Xapian::DatabaseModifiedError &e) {
            // Ignore, do a retry
            if((--attempts) > 0) {
                TRACE0("Caught Xapian::DatabaseModifiedError, reopening and retrying");
                // Reopen database before retrying. Should be fast.
                db.reopen();
            } else {
                // Too many times, give up
                throw;
            }
        }
    }
}

void OXPController::ImplSimpleQuery(Xapian::Database &db, const char *Query, std::set<const char *>Prefixes, std::vector<int> &rResultsOut) {
    // Parse the query
    Xapian::QueryParser parser;
    parser.set_default_op(Xapian::Query::OP_AND);
    parser.set_stemming_strategy(Xapian::QueryParser::STEM_NONE);
    parser.set_stopper(NULL);
    parser.set_database(db);

    // Repeat the rest for every prefix supplied, and UNION the results
    std::set<Xapian::Query *> queries;
    Xapian::Query *rootQuery = NULL;
    for(std::set<const char *>::iterator it = Prefixes.begin(); it != Prefixes.end(); ++it) {
        Xapian::Query *q =
            new Xapian::Query(parser.parse_query(std::string(Query),
                              Xapian::QueryParser::FLAG_PHRASE | Xapian::QueryParser::FLAG_BOOLEAN | Xapian::QueryParser::FLAG_LOVEHATE | Xapian::QueryParser::FLAG_WILDCARD,
                              std::string(*it)));
        queries.insert(q);

        if(rootQuery != NULL) {
            rootQuery = new Xapian::Query(Xapian::Query::OP_OR,
                                          *q,
                                          *rootQuery);
            queries.insert(rootQuery);
        } else {
            rootQuery = q;
        }
    }

    if(rootQuery == NULL) {
        // No prefixes specified, so use no prefix
        rootQuery =
            new Xapian::Query(parser.parse_query(std::string(Query),
                                                 Xapian::QueryParser::FLAG_PHRASE | Xapian::QueryParser::FLAG_BOOLEAN | Xapian::QueryParser::FLAG_LOVEHATE | Xapian::QueryParser::FLAG_WILDCARD,
                                                 std::string("")));
    }

    // Do the query
    Xapian::Enquire enquire(db);
    enquire.set_query(*rootQuery);
    Xapian::MSet matches = enquire.get_mset(0, db.get_doccount());
    Xapian::MSetIterator i;
    for(i = matches.begin(); i != matches.end(); ++i) {
        rResultsOut.push_back(*i);
        if(mRelevancyEnabled) {
            // Add in relevancy score
            mRelevancy[*i] += i.get_percent();
        }
    }

    // Deallocate query parts
    for(std::set<Xapian::Query *>::iterator it = queries.begin(); it != queries.end(); ++it) {
        delete (*it);
    }
}

void OXPController::PgDisableRelevancy() {
    mRelevancyEnabled = false;
}

int OXPController::PgGetRelevancy(unsigned int Docid) {
    // Return 0 if relevancy isn't enabled
    if(!mRelevancyEnabled) { return 0; }

    return mRelevancy[Docid];
}

std::string OXPController::PgSpelling(unsigned int Slot, const char *Word) {
    Xapian::Database &db = GetDatabase(Slot);
    return db.get_spelling_suggestion(Word);
}


/* --------------------------------------------------------------------------------------------------------------- */

Xapian::Database &OXPController::GetDatabase(unsigned int Slot) {
    if(Slot < 0 || Slot >= mDatabaseSlots.size()) {
        throw std::runtime_error("Bad slot number");
    }
    OpenDatabase *pdb = mDatabaseSlots[Slot];
    if(pdb == 0) {
        throw std::runtime_error("Nothing in given slot");
    }
    return pdb->GetXapianDatabase();
}

void OXPController::CloseLeastRecentlyUsedDatabase() {
    OXPOpenDatabaseMap::iterator toClose(mOpenDatabases.end());
    int s = -1;

    // Find least recently used database
    for(OXPOpenDatabaseMap::iterator i(mOpenDatabases.begin()); i != mOpenDatabases.end(); ++i) {
        if(s == -1 || s > i->second->GetOpenSerial()) {
            s = i->second->GetOpenSerial();
            toClose = i;
        }
    }

    // Close the choosen database
    if(toClose != mOpenDatabases.end()) {
        TRACE1("CloseLeastRecentlyUsedDatabase(), close %s", toClose->first.c_str());
        delete toClose->second;
        mOpenDatabases.erase(toClose);
    }
}

void OXPController::CloseAllDatabases() {
    for(OXPOpenDatabaseMap::iterator i(mOpenDatabases.begin()); i != mOpenDatabases.end(); ++i) {
        delete i->second;
    }
    mOpenDatabases.clear();
}


/* --------------------------------------------------------------------------------------------------------------- */

OXPController::OpenDatabase::OpenDatabase(std::string &rPathname)
    : mpDatabase(0), mDatabasePathname(rPathname), mOpenSerial(-1) {
}

OXPController::OpenDatabase::~OpenDatabase() {
    if(mpDatabase != 0) {
        delete mpDatabase;
    }
}

void OXPController::OpenDatabase::Open() {
    if(mpDatabase != 0) {
        throw std::runtime_error("DB already open");
    }
    mpDatabase = new Xapian::Database(mDatabasePathname);
}

Xapian::Database &OXPController::OpenDatabase::GetXapianDatabase() {
    if(mpDatabase == 0) {
        throw std::runtime_error("DB not open");
    }
    return *mpDatabase;
}

